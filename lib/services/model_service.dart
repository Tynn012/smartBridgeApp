import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

class SignPrediction {
  final String label;
  final double confidence;
  final List<double> rawScores;

  SignPrediction({
    required this.label,
    required this.confidence,
    required this.rawScores,
  });

  @override
  String toString() =>
      'SignPrediction(label: $label, confidence: $confidence%)';
}

class DebugScoreEntry {
  final int index;
  final String label;
  final double score;

  const DebugScoreEntry({
    required this.index,
    required this.label,
    required this.score,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'index': index,
    'label': label,
    'score': score,
    'percent': score * 100.0,
  };
}

class ModelDebugInfo {
  final DateTime updatedAt;
  final String stage;
  final String note;
  final bool modelLoaded;
  final bool runtimeLoaded;
  final String status;
  final int detectedHands;
  final int selectedHandIndex;
  final double? handMinX;
  final double? handMaxX;
  final double? handMinY;
  final double? handMaxY;
  final int inputWidth;
  final int inputHeight;
  final int inputChannels;
  final String inputLayout;
  final int outputClasses;
  final int labelsCount;
  final double inputMin;
  final double inputMax;
  final double inputMean;
  final int inputNonZero;
  final int inputTotal;
  final int inferenceMs;
  final String normalizationMode;
  final double rawMin;
  final double rawMax;
  final double rawSum;
  final double normalizedSum;
  final double normalizedEntropy;
  final List<DebugScoreEntry> topRawScores;
  final List<DebugScoreEntry> topNormalizedScores;

  const ModelDebugInfo({
    required this.updatedAt,
    required this.stage,
    required this.note,
    required this.modelLoaded,
    required this.runtimeLoaded,
    required this.status,
    required this.detectedHands,
    required this.selectedHandIndex,
    required this.handMinX,
    required this.handMaxX,
    required this.handMinY,
    required this.handMaxY,
    required this.inputWidth,
    required this.inputHeight,
    required this.inputChannels,
    required this.inputLayout,
    required this.outputClasses,
    required this.labelsCount,
    required this.inputMin,
    required this.inputMax,
    required this.inputMean,
    required this.inputNonZero,
    required this.inputTotal,
    required this.inferenceMs,
    required this.normalizationMode,
    required this.rawMin,
    required this.rawMax,
    required this.rawSum,
    required this.normalizedSum,
    required this.normalizedEntropy,
    required this.topRawScores,
    required this.topNormalizedScores,
  });

  factory ModelDebugInfo.initial() => ModelDebugInfo(
    updatedAt: DateTime.now(),
    stage: 'idle',
    note: 'No frames processed yet.',
    modelLoaded: false,
    runtimeLoaded: false,
    status: 'Not initialized',
    detectedHands: 0,
    selectedHandIndex: -1,
    handMinX: null,
    handMaxX: null,
    handMinY: null,
    handMaxY: null,
    inputWidth: 0,
    inputHeight: 0,
    inputChannels: 0,
    inputLayout: 'unknown',
    outputClasses: 0,
    labelsCount: 0,
    inputMin: 0.0,
    inputMax: 0.0,
    inputMean: 0.0,
    inputNonZero: 0,
    inputTotal: 0,
    inferenceMs: 0,
    normalizationMode: 'none',
    rawMin: 0.0,
    rawMax: 0.0,
    rawSum: 0.0,
    normalizedSum: 0.0,
    normalizedEntropy: 0.0,
    topRawScores: const <DebugScoreEntry>[],
    topNormalizedScores: const <DebugScoreEntry>[],
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'updatedAt': updatedAt.toIso8601String(),
    'stage': stage,
    'note': note,
    'modelLoaded': modelLoaded,
    'runtimeLoaded': runtimeLoaded,
    'status': status,
    'detectedHands': detectedHands,
    'selectedHandIndex': selectedHandIndex,
    'handBounds': <String, double?>{
      'minX': handMinX,
      'maxX': handMaxX,
      'minY': handMinY,
      'maxY': handMaxY,
    },
    'input': <String, dynamic>{
      'width': inputWidth,
      'height': inputHeight,
      'channels': inputChannels,
      'layout': inputLayout,
      'min': inputMin,
      'max': inputMax,
      'mean': inputMean,
      'nonZero': inputNonZero,
      'total': inputTotal,
    },
    'output': <String, dynamic>{
      'classes': outputClasses,
      'labelsCount': labelsCount,
      'inferenceMs': inferenceMs,
      'normalizationMode': normalizationMode,
      'rawMin': rawMin,
      'rawMax': rawMax,
      'rawSum': rawSum,
      'normalizedSum': normalizedSum,
      'normalizedEntropy': normalizedEntropy,
    },
    'topRawScores': topRawScores.map((entry) => entry.toJson()).toList(),
    'topNormalizedScores': topNormalizedScores
        .map((entry) => entry.toJson())
        .toList(),
  };
}

class _ScoreNormalizationResult {
  final List<double> scores;
  final String mode;

  const _ScoreNormalizationResult({required this.scores, required this.mode});
}

class ModelService {
  static final ModelService _instance = ModelService._internal();

  factory ModelService() => _instance;

  ModelService._internal();

  static const int _defaultInputSize = 64;
  static const int _defaultInputChannels = 3;
  static const int _renderCanvasSize = 600;
  static const MethodChannel _modelChannel = MethodChannel('smartbridge/lstm');

  // MediaPipe hand topology edges.
  static const List<List<int>> _handConnections = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [0, 5],
    [5, 6],
    [6, 7],
    [7, 8],
    [5, 9],
    [9, 10],
    [10, 11],
    [11, 12],
    [9, 13],
    [13, 14],
    [14, 15],
    [15, 16],
    [13, 17],
    [17, 18],
    [18, 19],
    [19, 20],
    [0, 17],
  ];

  HandLandmarkerPlugin? _landmarker;

  bool _isModelLoaded = false;
  bool _isRuntimeLoaded = false;
  int _lastDetectedHands = 0;
  String _lastStatus = 'Not initialized';
  int _outputClasses = 59;
  int _modelInputWidth = _defaultInputSize;
  int _modelInputHeight = _defaultInputSize;
  int _modelInputChannels = _defaultInputChannels;
  bool _inputIsNchw = false;
  ModelDebugInfo _lastDebugInfo = ModelDebugInfo.initial();

  final List<String> _signLabels = [
    '<pad>',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
    'g',
    'h',
    'i',
    'j',
    'k',
    'l',
    'm',
    'n',
    'o',
    'p',
    'q',
    'r',
    's',
    't',
    'u',
    'v',
    'w',
    'x',
    'y',
    'z',
    'space',
    "'",
    '.',
    ',',
    '?',
    '<blank>',
  ];

  bool get isModelLoaded => _isModelLoaded;
  List<String> get signLabels => _signLabels;
  ModelDebugInfo get debugInfo => _lastDebugInfo;

  Future<void> loadModel() async {
    try {
      if (kIsWeb || !Platform.isAndroid) {
        throw Exception(
          'ColdSlim model path is currently supported on Android only.',
        );
      }

      await _loadLabelMapping();

      _landmarker = HandLandmarkerPlugin.create(
        numHands: 2,
        minHandDetectionConfidence: 0.45,
        delegate: HandLandmarkerDelegate.cpu,
      );

      await _initializeNativeModel();

      if (!_isRuntimeLoaded) {
        throw Exception('Native model runtime could not be initialized.');
      }

      _isModelLoaded = true;
      _lastStatus = 'Ready (ColdSlim ASL edge runtime)';
      _updateDebugInfo(
        stage: 'init',
        note: 'Model initialized successfully.',
        detectedHands: _lastDetectedHands,
        selectedHandIndex: -1,
      );

      if (kDebugMode) {
        print('Model service initialized: $_lastStatus');
      }
    } catch (e) {
      _isModelLoaded = false;
      _isRuntimeLoaded = false;
      _lastStatus = 'Failed to initialize: $e';
      _updateDebugInfo(
        stage: 'error',
        note: _lastStatus,
        detectedHands: _lastDetectedHands,
        selectedHandIndex: -1,
      );
      if (kDebugMode) {
        print('Error loading model service: $e');
      }
      throw Exception('Failed to initialize model service: $_lastStatus');
    }
  }

  Future<void> _loadLabelMapping() async {
    try {
      final String raw = await rootBundle.loadString(
        'assets/models/coldslim_labels.json',
      );
      final dynamic decoded = jsonDecode(raw);

      final List<String> labels;
      if (decoded is List) {
        labels = decoded.map((e) => e.toString()).toList();
      } else if (decoded is Map<String, dynamic> && decoded['labels'] is List) {
        labels = (decoded['labels'] as List).map((e) => e.toString()).toList();
      } else {
        labels = _signLabels;
      }

      if (labels.isNotEmpty) {
        _signLabels
          ..clear()
          ..addAll(labels);
      }
    } catch (_) {
      // Keep defaults when custom mapping file is not available.
    }
  }

  Future<void> _initializeNativeModel() async {
    try {
      final Map<Object?, Object?>? response = await _modelChannel
          .invokeMethod('initAslEdge', {
            'modelAssetPath': 'assets/models/coldslim_asl_edge_model.tflite',
            'numThreads': 2,
          });

      final Map<String, dynamic> info = (response ?? <Object?, Object?>{})
          .cast<String, dynamic>();

      _outputClasses = (info['outputClasses'] as int?) ?? 59;
      _applyInputShapeInfo(info['inputShape']);
      _isRuntimeLoaded = (info['ok'] as bool?) ?? false;
      if (_isRuntimeLoaded) {
        _lastStatus =
            (info['status'] as String?) ?? 'Native ASL runtime initialized';
        _updateDebugInfo(
          stage: 'init',
          note: _lastStatus,
          detectedHands: _lastDetectedHands,
          selectedHandIndex: -1,
        );
      }
    } on PlatformException catch (e) {
      _isRuntimeLoaded = false;
      _lastStatus = 'Native model init failed: ${e.message}';
      _updateDebugInfo(
        stage: 'error',
        note: _lastStatus,
        detectedHands: _lastDetectedHands,
        selectedHandIndex: -1,
      );
      if (kDebugMode) {
        print('Native model init error: ${e.code} ${e.message}');
      }
    }
  }

  void _applyInputShapeInfo(dynamic inputShapeRaw) {
    if (inputShapeRaw is! List) {
      return;
    }

    final List<int> shape = inputShapeRaw
        .whereType<num>()
        .map((value) => value.toInt())
        .toList(growable: false);

    if (shape.length != 4) {
      return;
    }

    int width = _defaultInputSize;
    int height = _defaultInputSize;
    int channels = _defaultInputChannels;
    bool isNchw = false;

    if (shape[3] >= 1 && shape[3] <= 4) {
      // NHWC layout
      height = shape[1];
      width = shape[2];
      channels = shape[3];
    } else if (shape[1] >= 1 && shape[1] <= 4) {
      // NCHW layout fallback
      isNchw = true;
      channels = shape[1];
      height = shape[2];
      width = shape[3];
    }

    _modelInputWidth = width.clamp(16, 1024);
    _modelInputHeight = height.clamp(16, 1024);
    _modelInputChannels = channels.clamp(1, 4);
    _inputIsNchw = isNchw;
  }

  Future<SignPrediction> runInference(
    CameraImage image, {
    required int sensorOrientation,
  }) async {
    try {
      if (!_isModelLoaded || _landmarker == null || !_isRuntimeLoaded) {
        throw Exception('Model service is not loaded. Call loadModel() first.');
      }

      if (image.planes.length < 3) {
        throw Exception('Unsupported camera format. Expected YUV420 image.');
      }

      final List<Hand> hands = _landmarker!.detect(image, sensorOrientation);
      _lastDetectedHands = hands.length;

      if (hands.isEmpty) {
        _updateDebugInfo(
          stage: 'detect',
          note: 'No hand detected on frame.',
          detectedHands: 0,
          selectedHandIndex: -1,
          inferenceMs: 0,
        );
        return SignPrediction(
          label: 'No hand',
          confidence: 0.0,
          rawScores: List<double>.filled(_signLabels.length, 0.0),
        );
      }

      final Hand selectedHand = _selectLikelyRightHand(hands);
      final int selectedHandIndex = hands.indexOf(selectedHand);
      final Map<String, double> handBounds = _computeHandBounds(
        selectedHand.landmarks,
      );
      final List<double> inputTensor = _buildLandmarkImageInput(
        selectedHand.landmarks,
        mirrorX: false,
        normalizeToHandBox: false,
        valueScale: 1.0,
      );
      final Map<String, num> inputStats = _computeTensorStats(inputTensor);

      final SignPrediction? prediction = await _runNativeAslInference(
        inputTensor,
        detectedHands: hands.length,
        selectedHandIndex: selectedHandIndex,
        handBounds: handBounds,
        inputStats: inputStats,
      );

      if (prediction != null) {
        return prediction;
      }

      throw Exception('Native ASL inference failed.');
    } catch (e) {
      if (kDebugMode) {
        print('Error running inference: $e');
      }
      _updateDebugInfo(
        stage: 'error',
        note: 'runInference exception: $e',
        detectedHands: _lastDetectedHands,
        selectedHandIndex: -1,
      );
      return SignPrediction(
        label: 'Error',
        confidence: 0.0,
        rawScores: List<double>.filled(_signLabels.length, 0.0),
      );
    }
  }

  Hand _selectLikelyRightHand(List<Hand> hands) {
    if (hands.length == 1) {
      return hands.first;
    }

    // Prefer hand with greater wrist x-position as a best-effort right-hand proxy.
    Hand selected = hands.first;
    double bestX = hands.first.landmarks.isNotEmpty
        ? hands.first.landmarks.first.x
        : -1.0;

    for (final Hand hand in hands.skip(1)) {
      final double wristX = hand.landmarks.isNotEmpty
          ? hand.landmarks.first.x
          : -1.0;
      if (wristX > bestX) {
        bestX = wristX;
        selected = hand;
      }
    }

    return selected;
  }

  List<double> _buildLandmarkImageInput(
    List<Landmark> landmarks, {
    required bool mirrorX,
    required bool normalizeToHandBox,
    required double valueScale,
  }) {
    final List<double> canvas = List<double>.filled(
      _renderCanvasSize * _renderCanvasSize * 3,
      0.0,
    );

    if (landmarks.isEmpty) {
      return List<double>.filled(
        _modelInputWidth * _modelInputHeight * _modelInputChannels,
        0.0,
      );
    }

    void setPixel(int x, int y, double r, double g, double b) {
      if (x < 0 || y < 0 || x >= _renderCanvasSize || y >= _renderCanvasSize) {
        return;
      }
      final int offset = (y * _renderCanvasSize + x) * 3;
      canvas[offset] = math.max(canvas[offset], r);
      canvas[offset + 1] = math.max(canvas[offset + 1], g);
      canvas[offset + 2] = math.max(canvas[offset + 2], b);
    }

    void drawDisk(int cx, int cy, int radius, double r, double g, double b) {
      for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
          if ((dx * dx) + (dy * dy) <= radius * radius) {
            setPixel(cx + dx, cy + dy, r, g, b);
          }
        }
      }
    }

    void drawLine(
      int x0,
      int y0,
      int x1,
      int y1,
      int thickness,
      double r,
      double g,
      double b,
    ) {
      final int steps = math.max((x1 - x0).abs(), (y1 - y0).abs());
      if (steps <= 0) {
        drawDisk(x0, y0, thickness, r, g, b);
        return;
      }

      for (int i = 0; i <= steps; i++) {
        final double t = i / steps;
        final int x = (x0 + ((x1 - x0) * t)).round();
        final int y = (y0 + ((y1 - y0) * t)).round();
        drawDisk(x, y, thickness, r, g, b);
      }
    }

    final int validCount = math.min(landmarks.length, 21);
    double minX = 1.0;
    double minY = 1.0;
    double maxX = 0.0;
    double maxY = 0.0;

    if (normalizeToHandBox && validCount > 0) {
      for (int i = 0; i < validCount; i++) {
        final double rawX = mirrorX ? 1.0 - landmarks[i].x : landmarks[i].x;
        final double nx = rawX.clamp(0.0, 1.0);
        final double ny = landmarks[i].y.clamp(0.0, 1.0);
        minX = math.min(minX, nx);
        minY = math.min(minY, ny);
        maxX = math.max(maxX, nx);
        maxY = math.max(maxY, ny);
      }
    }

    final double spanX = math.max(maxX - minX, 1e-6);
    final double spanY = math.max(maxY - minY, 1e-6);
    final double span = math.max(spanX, spanY);
    const double margin = 0.08;
    final double usable = 1.0 - (margin * 2);

    final List<List<int>> points = List<List<int>>.generate(21, (index) {
      if (index >= landmarks.length) {
        return <int>[0, 0];
      }
      final double rawX = mirrorX
          ? 1.0 - landmarks[index].x
          : landmarks[index].x;
      double nx = rawX.clamp(0.0, 1.0);
      double ny = landmarks[index].y.clamp(0.0, 1.0);

      if (normalizeToHandBox && validCount > 0) {
        nx = (((nx - minX) / span) * (spanX / span)).clamp(0.0, 1.0);
        ny = (((ny - minY) / span) * (spanY / span)).clamp(0.0, 1.0);
        nx = margin + (nx * usable);
        ny = margin + (ny * usable);
      }

      final int x = (nx * (_renderCanvasSize - 1)).round().clamp(
        0,
        _renderCanvasSize - 1,
      );
      final int y = (ny * (_renderCanvasSize - 1)).round().clamp(
        0,
        _renderCanvasSize - 1,
      );
      return <int>[x, y];
    });

    for (final edge in _handConnections) {
      final List<int> p0 = points[edge[0]];
      final List<int> p1 = points[edge[1]];
      drawLine(p0[0], p0[1], p1[0], p1[1], 2, 0.88, 0.88, 0.88);
    }

    for (final p in points) {
      drawDisk(p[0], p[1], 3, 1.0, 1.0, 1.0);
    }

    final List<double> image = List<double>.filled(
      _modelInputWidth * _modelInputHeight * _modelInputChannels,
      0.0,
    );

    for (int y = 0; y < _modelInputHeight; y++) {
      final int srcY = ((y + 0.5) * _renderCanvasSize / _modelInputHeight)
          .floor()
          .clamp(0, _renderCanvasSize - 1);
      for (int x = 0; x < _modelInputWidth; x++) {
        final int srcX = ((x + 0.5) * _renderCanvasSize / _modelInputWidth)
            .floor()
            .clamp(0, _renderCanvasSize - 1);

        final int srcOffset = (srcY * _renderCanvasSize + srcX) * 3;
        final double r = canvas[srcOffset] * valueScale;
        final double g = canvas[srcOffset + 1] * valueScale;
        final double b = canvas[srcOffset + 2] * valueScale;

        if (_inputIsNchw) {
          final int hw = _modelInputWidth * _modelInputHeight;
          final int pixelIndex = (y * _modelInputWidth) + x;

          if (_modelInputChannels == 1) {
            image[pixelIndex] = (r + g + b) / 3.0;
          } else {
            image[pixelIndex] = r;
            if (_modelInputChannels > 1) {
              image[hw + pixelIndex] = g;
            }
            if (_modelInputChannels > 2) {
              image[(hw * 2) + pixelIndex] = b;
            }
            if (_modelInputChannels > 3) {
              image[(hw * 3) + pixelIndex] = valueScale;
            }
          }
        } else {
          final int dstOffset =
              (y * _modelInputWidth + x) * _modelInputChannels;

          if (_modelInputChannels == 1) {
            image[dstOffset] = (r + g + b) / 3.0;
          } else {
            image[dstOffset] = r;
            if (_modelInputChannels > 1) {
              image[dstOffset + 1] = g;
            }
            if (_modelInputChannels > 2) {
              image[dstOffset + 2] = b;
            }
            if (_modelInputChannels > 3) {
              image[dstOffset + 3] = valueScale;
            }
          }
        }
      }
    }

    return image;
  }

  Future<SignPrediction?> _runNativeAslInference(
    List<double> inputTensor, {
    required int detectedHands,
    required int selectedHandIndex,
    required Map<String, double> handBounds,
    required Map<String, num> inputStats,
  }) async {
    try {
      final Stopwatch watch = Stopwatch()..start();
      final Map<Object?, Object?>? response = await _modelChannel
          .invokeMethod('runAslEdge', {
            'input': inputTensor,
            'width': _modelInputWidth,
            'height': _modelInputHeight,
            'channels': _modelInputChannels,
          });
      watch.stop();

      if (response == null) {
        _updateDebugInfo(
          stage: 'inference',
          note: 'Native inference returned null response.',
          detectedHands: detectedHands,
          selectedHandIndex: selectedHandIndex,
          handBounds: handBounds,
          inputStats: inputStats,
          inferenceMs: watch.elapsedMilliseconds,
        );
        return null;
      }

      final Map<String, dynamic> data = response.cast<String, dynamic>();
      final int nativeLabelIndex = (data['labelIndex'] as int?) ?? 0;

      final List<dynamic> rawList = (data['scores'] as List<dynamic>?) ?? [];
      if (rawList.isEmpty) {
        _updateDebugInfo(
          stage: 'inference',
          note: 'Native inference returned empty score list.',
          detectedHands: detectedHands,
          selectedHandIndex: selectedHandIndex,
          handBounds: handBounds,
          inputStats: inputStats,
          inferenceMs: watch.elapsedMilliseconds,
        );
        return null;
      }

      final List<double> scores = rawList
          .map((value) => (value as num).toDouble())
          .toList();
      final _ScoreNormalizationResult normalizedResult = _normalizeScores(
        scores,
      );
      final List<double> normalizedScores = normalizedResult.scores;

      final List<double> paddedRawScores = _fitScoresToLabels(scores);
      final List<double> paddedScores = _fitScoresToLabels(normalizedScores);
      final int bestIndex =
          (nativeLabelIndex >= 0 && nativeLabelIndex < paddedScores.length)
          ? nativeLabelIndex
          : paddedScores.indexWhere(
              (value) => value == paddedScores.reduce(math.max),
            );
      final int safeIndex = bestIndex < 0 ? 0 : bestIndex;
      final double confidence = (paddedScores[safeIndex] * 100.0).clamp(
        0.0,
        100.0,
      );
      final String label = confidence < 8.0
          ? 'Unknown'
          : _labelForIndex(safeIndex);

      _updateDebugInfo(
        stage: 'inference',
        note: 'Prediction ready: $label (${confidence.toStringAsFixed(2)}%).',
        detectedHands: detectedHands,
        selectedHandIndex: selectedHandIndex,
        handBounds: handBounds,
        inputStats: inputStats,
        inferenceMs: watch.elapsedMilliseconds,
        normalizationMode: normalizedResult.mode,
        rawScores: paddedRawScores,
        normalizedScores: paddedScores,
      );

      return SignPrediction(
        label: label,
        confidence: confidence,
        rawScores: paddedScores,
      );
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Native ASL inference error: ${e.code} ${e.message}');
      }
      _updateDebugInfo(
        stage: 'error',
        note: 'Native inference failed: ${e.code} ${e.message}',
        detectedHands: detectedHands,
        selectedHandIndex: selectedHandIndex,
        handBounds: handBounds,
        inputStats: inputStats,
      );
      return null;
    }
  }

  List<double> _fitScoresToLabels(List<double> rawScores) {
    if (rawScores.length == _signLabels.length) {
      return rawScores;
    }

    final List<double> padded = List<double>.filled(_signLabels.length, 0.0);
    final int copyLen = math.min(rawScores.length, padded.length);
    for (int i = 0; i < copyLen; i++) {
      padded[i] = rawScores[i];
    }
    return padded;
  }

  _ScoreNormalizationResult _normalizeScores(List<double> scores) {
    if (scores.isEmpty) {
      return const _ScoreNormalizationResult(scores: <double>[], mode: 'empty');
    }

    final List<double> sanitized = scores
        .map((value) => value.isFinite ? value : 0.0)
        .toList(growable: false);
    final bool allNonNegative = sanitized.every((value) => value >= 0.0);
    final double maxValue = sanitized.reduce(math.max);
    final double sum = sanitized.fold(0.0, (acc, value) => acc + value);
    final bool looksLikeProbabilities =
        allNonNegative && maxValue <= 1.0 && sum > 0.75 && sum < 1.25;

    if (looksLikeProbabilities) {
      return _ScoreNormalizationResult(
        scores: _renormalize(sanitized),
        mode: 'renormalize',
      );
    }

    return _ScoreNormalizationResult(
      scores: _softmax(sanitized),
      mode: 'softmax',
    );
  }

  List<double> _renormalize(List<double> values) {
    final double sum = values.fold(0.0, (acc, value) => acc + value);
    if (sum <= 0.0) {
      return List<double>.filled(values.length, 0.0);
    }
    return values.map((value) => value / sum).toList(growable: false);
  }

  List<double> _softmax(List<double> values) {
    if (values.isEmpty) {
      return values;
    }

    final double maxValue = values.reduce(math.max);
    final List<double> exps = values
        .map((value) => math.exp(value - maxValue).toDouble())
        .toList(growable: false);
    final double expSum = exps.fold(0.0, (acc, value) => acc + value);

    if (expSum <= 0) {
      return List<double>.filled(values.length, 0.0);
    }

    return exps.map((value) => value / expSum).toList(growable: false);
  }

  String _labelForIndex(int index) {
    if (index >= 0 && index < _signLabels.length) {
      return _signLabels[index];
    }
    return 'Unknown';
  }

  List<SignPrediction> getTopKPredictions(
    List<double> predictions, {
    int topK = 3,
  }) {
    final List<double> normalized = _normalizeScores(predictions).scores;
    final List<SignPrediction> allPredictions = [];
    final int total = math.min(normalized.length, _signLabels.length);

    for (int i = 0; i < total; i++) {
      allPredictions.add(
        SignPrediction(
          label: _labelForIndex(i),
          confidence: (normalized[i] * 100.0).clamp(0.0, 100.0),
          rawScores: normalized,
        ),
      );
    }

    allPredictions.sort((a, b) => b.confidence.compareTo(a.confidence));
    return allPredictions.take(topK).toList();
  }

  Map<String, double> _computeHandBounds(List<Landmark> landmarks) {
    if (landmarks.isEmpty) {
      return <String, double>{
        'minX': 0.0,
        'maxX': 0.0,
        'minY': 0.0,
        'maxY': 0.0,
      };
    }

    double minX = 1.0;
    double minY = 1.0;
    double maxX = 0.0;
    double maxY = 0.0;

    for (final Landmark point in landmarks) {
      final double x = point.x.clamp(0.0, 1.0);
      final double y = point.y.clamp(0.0, 1.0);
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }

    return <String, double>{
      'minX': minX,
      'maxX': maxX,
      'minY': minY,
      'maxY': maxY,
    };
  }

  Map<String, num> _computeTensorStats(List<double> values) {
    if (values.isEmpty) {
      return <String, num>{
        'min': 0.0,
        'max': 0.0,
        'mean': 0.0,
        'nonZero': 0,
        'total': 0,
      };
    }

    double minValue = double.infinity;
    double maxValue = -double.infinity;
    double sum = 0.0;
    int nonZero = 0;

    for (final double value in values) {
      if (value < minValue) {
        minValue = value;
      }
      if (value > maxValue) {
        maxValue = value;
      }
      sum += value;
      if (value.abs() > 1e-8) {
        nonZero++;
      }
    }

    return <String, num>{
      'min': minValue.isFinite ? minValue : 0.0,
      'max': maxValue.isFinite ? maxValue : 0.0,
      'mean': sum / values.length,
      'nonZero': nonZero,
      'total': values.length,
    };
  }

  List<DebugScoreEntry> _buildTopScores(List<double> scores, {int topK = 5}) {
    if (scores.isEmpty) {
      return const <DebugScoreEntry>[];
    }

    final List<int> indices = List<int>.generate(scores.length, (i) => i);
    indices.sort((a, b) => scores[b].compareTo(scores[a]));

    return indices
        .take(topK)
        .map((int index) {
          return DebugScoreEntry(
            index: index,
            label: _labelForIndex(index),
            score: scores[index],
          );
        })
        .toList(growable: false);
  }

  double _normalizedEntropy(List<double> values) {
    if (values.isEmpty) {
      return 0.0;
    }

    final double sum = values.fold(0.0, (acc, value) => acc + value);
    if (sum <= 0.0) {
      return 0.0;
    }

    final List<double> probs = values
        .map((value) => (value / sum).clamp(0.0, 1.0))
        .toList(growable: false);

    double entropy = 0.0;
    for (final double p in probs) {
      if (p > 0.0) {
        entropy -= p * math.log(p);
      }
    }

    final double maxEntropy = math.log(math.max(probs.length, 2));
    if (maxEntropy <= 0.0) {
      return 0.0;
    }
    return (entropy / maxEntropy).clamp(0.0, 1.0);
  }

  void _updateDebugInfo({
    required String stage,
    required String note,
    required int detectedHands,
    required int selectedHandIndex,
    Map<String, double>? handBounds,
    Map<String, num>? inputStats,
    int inferenceMs = 0,
    String normalizationMode = 'none',
    List<double>? rawScores,
    List<double>? normalizedScores,
  }) {
    final List<double> safeRaw = rawScores ?? const <double>[];
    final List<double> safeNormalized = normalizedScores ?? const <double>[];

    final double rawMin = safeRaw.isEmpty ? 0.0 : safeRaw.reduce(math.min);
    final double rawMax = safeRaw.isEmpty ? 0.0 : safeRaw.reduce(math.max);
    final double rawSum = safeRaw.fold(0.0, (acc, value) => acc + value);
    final double normalizedSum = safeNormalized.fold(
      0.0,
      (acc, value) => acc + value,
    );

    _lastDebugInfo = ModelDebugInfo(
      updatedAt: DateTime.now(),
      stage: stage,
      note: note,
      modelLoaded: _isModelLoaded,
      runtimeLoaded: _isRuntimeLoaded,
      status: _lastStatus,
      detectedHands: detectedHands,
      selectedHandIndex: selectedHandIndex,
      handMinX: handBounds?['minX'],
      handMaxX: handBounds?['maxX'],
      handMinY: handBounds?['minY'],
      handMaxY: handBounds?['maxY'],
      inputWidth: _modelInputWidth,
      inputHeight: _modelInputHeight,
      inputChannels: _modelInputChannels,
      inputLayout: _inputIsNchw ? 'NCHW' : 'NHWC',
      outputClasses: _outputClasses,
      labelsCount: _signLabels.length,
      inputMin: (inputStats?['min'] as num?)?.toDouble() ?? 0.0,
      inputMax: (inputStats?['max'] as num?)?.toDouble() ?? 0.0,
      inputMean: (inputStats?['mean'] as num?)?.toDouble() ?? 0.0,
      inputNonZero: (inputStats?['nonZero'] as num?)?.toInt() ?? 0,
      inputTotal: (inputStats?['total'] as num?)?.toInt() ?? 0,
      inferenceMs: inferenceMs,
      normalizationMode: normalizationMode,
      rawMin: rawMin,
      rawMax: rawMax,
      rawSum: rawSum,
      normalizedSum: normalizedSum,
      normalizedEntropy: _normalizedEntropy(safeNormalized),
      topRawScores: _buildTopScores(safeRaw),
      topNormalizedScores: _buildTopScores(safeNormalized),
    );
  }

  String getModelInfo() {
    if (!_isModelLoaded) {
      return 'Model not loaded';
    }

    return 'Hugging Face ASL pipeline\n'
        'Repo: ColdSlim/ASL-TFLite-Edge\n'
        'Landmarks: MediaPipe Hand Landmarker\n'
        'Input: ${_modelInputWidth} x ${_modelInputHeight} x ${_modelInputChannels} landmark rendering\n'
        'Layout: ${_inputIsNchw ? 'NCHW' : 'NHWC'}\n'
        'Native runtime loaded: ${_isRuntimeLoaded ? 'Yes' : 'No'}\n'
        'Output classes: $_outputClasses\n'
        'Detected hands (last frame): $_lastDetectedHands\n'
        'Status: $_lastStatus\n'
        'Gestures: ${_signLabels.join(', ')}';
  }

  Future<void> dispose() async {
    try {
      await _modelChannel.invokeMethod('disposeAslEdge');

      if (_landmarker != null) {
        _landmarker!.dispose();
        _landmarker = null;
      }

      _isModelLoaded = false;
      _isRuntimeLoaded = false;
      _lastStatus = 'Disposed';
      _updateDebugInfo(
        stage: 'dispose',
        note: 'Model runtime disposed.',
        detectedHands: 0,
        selectedHandIndex: -1,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error disposing model service: $e');
      }
    }
  }

  void setCustomLabels(List<String> labels) {
    if (labels.isEmpty) return;
    _signLabels
      ..clear()
      ..addAll(labels);

    if (!_signLabels.contains('Unknown')) {
      _signLabels.add('Unknown');
    }
  }
}
