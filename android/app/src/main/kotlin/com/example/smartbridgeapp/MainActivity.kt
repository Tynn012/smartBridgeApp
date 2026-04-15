package com.example.smartbridgeapp

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity
import org.tensorflow.lite.DataType
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel

class MainActivity : FlutterActivity() {
	companion object {
		private const val MODEL_CHANNEL = "smartbridge/lstm"
		private const val DEFAULT_INPUT_WIDTH = 64
		private const val DEFAULT_INPUT_HEIGHT = 64
		private const val DEFAULT_INPUT_CHANNELS = 3
	}

	private var edgeInterpreter: Interpreter? = null
	private var outputClasses: Int = 8
	private var inputShape: IntArray = intArrayOf(1, DEFAULT_INPUT_HEIGHT, DEFAULT_INPUT_WIDTH, DEFAULT_INPUT_CHANNELS)
	private var inputType: DataType = DataType.FLOAT32
	private var inputAuxType: DataType? = null
	private var outputType: DataType = DataType.FLOAT32

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MODEL_CHANNEL)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"initAslEdge" -> initAslEdge(call, result)
					"runAslEdge" -> runAslEdge(call, result)
					"disposeAslEdge" -> {
						disposeAslEdge()
						result.success(true)
					}
					else -> result.notImplemented()
				}
			}
	}

	override fun onDestroy() {
		disposeAslEdge()
		super.onDestroy()
	}

	private fun initAslEdge(call: MethodCall, result: MethodChannel.Result) {
		try {
			disposeAslEdge()

			val modelAssetPath =
				call.argument<String>("modelAssetPath")
					?: "assets/models/qualcomm_hand_gesture_classifier.tflite"
			val numThreads = call.argument<Int>("numThreads") ?: 2

			val modelBuffer = loadModelBuffer(modelAssetPath)

			val options = Interpreter.Options().apply {
				setNumThreads(numThreads)
			}

			edgeInterpreter = Interpreter(modelBuffer, options)
			inputShape = edgeInterpreter?.getInputTensor(0)?.shape() ?: inputShape
			inputType = edgeInterpreter?.getInputTensor(0)?.dataType() ?: DataType.FLOAT32
			inputAuxType = if ((edgeInterpreter?.inputTensorCount ?: 1) > 1) {
				edgeInterpreter?.getInputTensor(1)?.dataType() ?: DataType.FLOAT32
			} else {
				null
			}
			outputType = edgeInterpreter?.getOutputTensor(0)?.dataType() ?: DataType.FLOAT32
			outputClasses = edgeInterpreter?.getOutputTensor(0)?.shape()?.lastOrNull() ?: 8

			result.success(
				mapOf(
					"ok" to true,
					"outputClasses" to outputClasses,
					"inputShape" to inputShape.toList(),
					"status" to "Qualcomm hand gesture classifier initialized",
				),
			)
		} catch (e: Exception) {
			result.error("ASL_EDGE_INIT_FAILED", e.message, null)
		}
	}

	private fun loadModelBuffer(modelAssetPath: String): ByteBuffer {
		val candidatePaths = listOf(modelAssetPath, "flutter_assets/$modelAssetPath")

		var lastError: Exception? = null

		for (candidate in candidatePaths) {
			try {
				val fileDescriptor = assets.openFd(candidate)
				return FileInputStream(fileDescriptor.fileDescriptor).channel.use { channel ->
					channel.map(
						FileChannel.MapMode.READ_ONLY,
						fileDescriptor.startOffset,
						fileDescriptor.declaredLength,
					)
				}
			} catch (_: Exception) {
				try {
					assets.open(candidate).use { input ->
						val bytes = input.readBytes()
						val directBuffer = ByteBuffer.allocateDirect(bytes.size)
							directBuffer.order(ByteOrder.nativeOrder())
						directBuffer.put(bytes)
						directBuffer.rewind()
						return directBuffer
					}
				} catch (streamError: Exception) {
					lastError = streamError
				}
			}
		}

		throw Exception(
			"Unable to load model asset '$modelAssetPath' (or flutter_assets/$modelAssetPath). " +
				(lastError?.message ?: "unknown error"),
		)
	}

	private fun runAslEdge(call: MethodCall, result: MethodChannel.Result) {
		val interpreter = edgeInterpreter
		if (interpreter == null) {
			result.error("ASL_EDGE_NOT_READY", "Interpreter is not initialized.", null)
			return
		}

		try {
			val rawInput = call.argument<List<*>>("input")
			if (rawInput.isNullOrEmpty()) {
				result.error("BAD_INPUT", "input is required", null)
				return
			}

			val rawAuxInput = call.argument<List<*>>("inputAux")

			val inputTensor = interpreter.getInputTensor(0)
			val expected = (inputTensor.numBytes() / bytesPerElement(inputType)).coerceAtLeast(1)

			val floatInput = FloatArray(expected)
			val copyCount = minOf(expected, rawInput.size)
			for (i in 0 until copyCount) {
				val value = rawInput[i]
				floatInput[i] = when (value) {
					is Number -> value.toFloat()
					else -> 0f
				}
			}

			var floatAuxInput: FloatArray? = null
			if (interpreter.inputTensorCount > 1) {
				val auxType = inputAuxType ?: interpreter.getInputTensor(1).dataType()
				val auxTensor = interpreter.getInputTensor(1)
				val expectedAux = (auxTensor.numBytes() / bytesPerElement(auxType)).coerceAtLeast(1)
				floatAuxInput = FloatArray(expectedAux)
				val source = if (!rawAuxInput.isNullOrEmpty()) rawAuxInput else rawInput
				val auxCopyCount = minOf(expectedAux, source.size)
				for (i in 0 until auxCopyCount) {
					val value = source[i]
					floatAuxInput[i] = when (value) {
						is Number -> value.toFloat()
						else -> 0f
					}
				}
			}

			val scores = runAndCollectScores(interpreter, floatInput, floatAuxInput)
			var bestIndex = 0
			for (i in 1 until scores.size) {
				if (scores[i] > scores[bestIndex]) {
					bestIndex = i
				}
			}

			result.success(
				mapOf(
					"labelIndex" to bestIndex,
					"confidence" to (scores[bestIndex] * 100.0),
					"scores" to scores,
					"inputElements" to expected,
				),
			)
		} catch (e: Exception) {
			result.error("ASL_EDGE_RUN_FAILED", e.message, null)
		}
	}

	private fun bytesPerElement(type: DataType): Int {
		return when (type) {
			DataType.FLOAT32 -> 4
			DataType.UINT8, DataType.INT8 -> 1
			else -> throw IllegalStateException("Unsupported tensor type: $type")
		}
	}

	private fun runAndCollectScores(
		interpreter: Interpreter,
		floatInput: FloatArray,
		floatInputAux: FloatArray?,
	): List<Double> {
		val primaryInputBuffer = buildInputBuffer(
			interpreter = interpreter,
			tensorIndex = 0,
			values = floatInput,
			tensorType = inputType,
		)

		val outputTensor = interpreter.getOutputTensor(0)
		val outputCount = (outputTensor.numBytes() / bytesPerElement(outputType)).coerceAtLeast(1)
		val outputBuffer = ByteBuffer.allocateDirect(outputTensor.numBytes())
			.order(ByteOrder.nativeOrder())

		if (interpreter.inputTensorCount > 1) {
			val auxValues = floatInputAux ?: floatInput
			val auxType = inputAuxType ?: interpreter.getInputTensor(1).dataType()
			val auxInputBuffer = buildInputBuffer(
				interpreter = interpreter,
				tensorIndex = 1,
				values = auxValues,
				tensorType = auxType,
			)

			interpreter.runForMultipleInputsOutputs(
				arrayOf(primaryInputBuffer, auxInputBuffer),
				mutableMapOf<Int, Any>(0 to outputBuffer),
			)
		} else {
			interpreter.run(primaryInputBuffer, outputBuffer)
		}
		outputBuffer.rewind()

		return when (outputType) {
			DataType.FLOAT32 -> {
				List(outputCount) {
					outputBuffer.float.toDouble()
				}
			}
			DataType.UINT8 -> {
				val qParams = outputTensor.quantizationParams()
				val scale = if (qParams.scale == 0f) 1f else qParams.scale
				val zeroPoint = qParams.zeroPoint

				List(outputCount) {
					val unsigned = outputBuffer.get().toInt() and 0xFF
					((unsigned - zeroPoint) * scale).toDouble()
				}
			}
			DataType.INT8 -> {
				val qParams = outputTensor.quantizationParams()
				val scale = if (qParams.scale == 0f) 1f else qParams.scale
				val zeroPoint = qParams.zeroPoint

				List(outputCount) {
					val signed = outputBuffer.get().toInt()
					((signed - zeroPoint) * scale).toDouble()
				}
			}
			else -> throw IllegalStateException("Unsupported output tensor type: $outputType")
		}
	}

	private fun buildInputBuffer(
		interpreter: Interpreter,
		tensorIndex: Int,
		values: FloatArray,
		tensorType: DataType,
	): ByteBuffer {
		val inputQuantParams = interpreter.getInputTensor(tensorIndex).quantizationParams()
		val inputScale = if (inputQuantParams.scale == 0f) 1f else inputQuantParams.scale
		val inputZeroPoint = inputQuantParams.zeroPoint

		return when (tensorType) {
			DataType.FLOAT32 -> {
				ByteBuffer.allocateDirect(values.size * 4)
					.order(ByteOrder.nativeOrder())
					.apply {
						for (v in values) {
							putFloat(v)
						}
						rewind()
					}
			}
			DataType.UINT8 -> {
				ByteBuffer.allocateDirect(values.size)
					.order(ByteOrder.nativeOrder())
					.apply {
						for (v in values) {
							val q = ((v / inputScale) + inputZeroPoint)
								.toInt()
								.coerceIn(0, 255)
							put(q.toByte())
						}
						rewind()
					}
			}
			DataType.INT8 -> {
				ByteBuffer.allocateDirect(values.size)
					.order(ByteOrder.nativeOrder())
					.apply {
						for (v in values) {
							val q = ((v / inputScale) + inputZeroPoint)
								.toInt()
								.coerceIn(-128, 127)
							put(q.toByte())
						}
						rewind()
					}
			}
			else -> throw IllegalStateException("Unsupported input tensor type: $tensorType")
		}
	}

	private fun disposeAslEdge() {
		edgeInterpreter?.close()
		edgeInterpreter = null
		outputClasses = 8
		inputShape = intArrayOf(1, DEFAULT_INPUT_HEIGHT, DEFAULT_INPUT_WIDTH, DEFAULT_INPUT_CHANNELS)
		inputType = DataType.FLOAT32
		inputAuxType = null
		outputType = DataType.FLOAT32
	}
}
