"""
==============================================================
 Senyas FSL Translator — Full TFLite Conversion Pipeline
 Converts NF1.h5 (Keras weights) → TFLite (.tflite)
 
 Architecture: Conv1D → LSTM×3 → Dense×3
 Input:  (1, 30, 258)  — 30 frames × 258 MediaPipe landmarks
 Output: (1, 15)       — softmax probabilities for 15 FSL signs
 
 Generates 3 variants:
   model_float32.tflite     — baseline, highest accuracy
   model_float16.tflite     — recommended (50% smaller, ~same accuracy)
   model_dynamic_range.tflite — smallest (67% smaller, slight accuracy drop)
   model.tflite             — copy of float16 (primary deliverable)
==============================================================
"""

import os
import sys
import shutil
import numpy as np

os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'

try:
    import tensorflow as tf
except ImportError:
    print("❌ TensorFlow not found. Install with: pip install tensorflow")
    sys.exit(1)

print(f"✅ TensorFlow {tf.__version__}")

# ── CONFIG ────────────────────────────────────────────────────
H5_WEIGHTS_PATH  = "../models/NF1.h5"          # Path to original weights
OUTPUT_DIR       = "../tflite_models"           # Where to save .tflite files
SEQUENCE_LENGTH  = 30
FEATURE_DIM      = 258  # 33*4 (pose) + 21*3 (left hand) + 21*3 (right hand)

ACTIONS = [
    'ako', 'bakit', 'F', 'hi', 'hindi', 'ikaw',
    'kamusta', 'L', 'maganda', 'magandang umaga',
    'N', 'O', 'oo', 'P', 'salamat'
]
# ─────────────────────────────────────────────────────────────

def build_model():
    """Rebuild the exact architecture from train_model.py."""
    from tensorflow.keras.models import Sequential
    from tensorflow.keras.layers import LSTM, Dense, Conv1D

    model = Sequential([
        Conv1D(64, kernel_size=3, activation='relu',
               input_shape=(SEQUENCE_LENGTH, FEATURE_DIM)),
        LSTM(64,  return_sequences=True,  activation='relu'),
        LSTM(128, return_sequences=True,  activation='relu'),
        LSTM(64,  return_sequences=False, activation='relu'),
        Dense(64, activation='relu'),
        Dense(32, activation='relu'),
        Dense(len(ACTIONS), activation='softmax'),
    ])
    model.compile(optimizer='Adam', loss='categorical_crossentropy',
                  metrics=['categorical_accuracy'])
    return model


def load_weights(model, weights_path):
    if not os.path.exists(weights_path):
        raise FileNotFoundError(f"Weights not found: {weights_path}")
    model.load_weights(weights_path)
    print(f"✅ Weights loaded: {weights_path}")
    return model


def get_concrete_function(model):
    """Trace a concrete TF function — avoids the Keras 3 SavedModel export bug."""
    @tf.function(input_signature=[
        tf.TensorSpec(shape=[1, SEQUENCE_LENGTH, FEATURE_DIM],
                      dtype=tf.float32, name='input')
    ])
    def run_model(x):
        return model(x, training=False)

    cf = run_model.get_concrete_function()
    print("✅ Concrete function traced")
    return cf, model


def convert_float32(cf, model, out_path):
    converter = tf.lite.TFLiteConverter.from_concrete_functions([cf], model)
    tflite_model = converter.convert()
    with open(out_path, 'wb') as f:
        f.write(tflite_model)
    print(f"✅ Float32 TFLite: {out_path} ({os.path.getsize(out_path)/1024:.1f} KB)")
    return tflite_model


def convert_float16(cf, model, out_path):
    converter = tf.lite.TFLiteConverter.from_concrete_functions([cf], model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    tflite_model = converter.convert()
    with open(out_path, 'wb') as f:
        f.write(tflite_model)
    print(f"✅ Float16 TFLite: {out_path} ({os.path.getsize(out_path)/1024:.1f} KB)")
    return tflite_model


def convert_dynamic_range(cf, model, out_path):
    converter = tf.lite.TFLiteConverter.from_concrete_functions([cf], model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    with open(out_path, 'wb') as f:
        f.write(tflite_model)
    print(f"✅ Dynamic Range TFLite: {out_path} ({os.path.getsize(out_path)/1024:.1f} KB)")
    return tflite_model


def run_tflite_inference(tflite_path, input_data):
    """Run a single inference with TFLite interpreter."""
    interp = tf.lite.Interpreter(model_path=tflite_path)
    interp.allocate_tensors()
    in_d  = interp.get_input_details()
    out_d = interp.get_output_details()
    interp.set_tensor(in_d[0]['index'], input_data.astype(np.float32))
    interp.invoke()
    return interp.get_tensor(out_d[0]['index'])[0]


def benchmark_accuracy(keras_model, paths, n_samples=50):
    """Compare Keras vs TFLite predictions on random inputs."""
    test_inputs = np.random.rand(n_samples, 1, SEQUENCE_LENGTH, FEATURE_DIM).astype(np.float32)
    keras_preds = [
        np.argmax(keras_model.predict(x, verbose=0)[0])
        for x in test_inputs
    ]

    print("\n📊 Accuracy vs Keras baseline:")
    for name, path in paths.items():
        tflite_preds = [np.argmax(run_tflite_inference(path, x)) for x in test_inputs]
        match = np.mean([k == t for k, t in zip(keras_preds, tflite_preds)]) * 100
        size  = os.path.getsize(path) / 1024
        print(f"   {name:<25} {match:6.1f}% match  |  {size:6.1f} KB")


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # 1. Build & load
    model = build_model()
    model = load_weights(model, H5_WEIGHTS_PATH)

    # 2. Trace
    cf, model = get_concrete_function(model)

    # 3. Convert all variants
    paths = {
        "Float32":       os.path.join(OUTPUT_DIR, "model_float32.tflite"),
        "Float16":       os.path.join(OUTPUT_DIR, "model_float16.tflite"),
        "Dynamic Range": os.path.join(OUTPUT_DIR, "model_dynamic_range.tflite"),
    }
    convert_float32(cf, model, paths["Float32"])
    convert_float16(cf, model, paths["Float16"])
    convert_dynamic_range(cf, model, paths["Dynamic Range"])

    # 4. Copy primary model
    primary = os.path.join(OUTPUT_DIR, "model.tflite")
    shutil.copy(paths["Float16"], primary)
    print(f"\n✅ Primary model.tflite → {primary}")

    # 5. Write labels
    labels_path = os.path.join(OUTPUT_DIR, "labels.txt")
    with open(labels_path, 'w') as f:
        f.write('\n'.join(ACTIONS) + '\n')
    print(f"✅ labels.txt → {labels_path}")

    # 6. Benchmark
    benchmark_accuracy(model, paths)

    print("\n🎉 Conversion complete!")
    print(f"   Primary model : {primary}")
    print(f"   Labels        : {labels_path}")


if __name__ == '__main__':
    main()
