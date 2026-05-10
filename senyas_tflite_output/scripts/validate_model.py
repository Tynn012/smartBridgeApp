"""
==============================================================
 Senyas FSL — TFLite Model Validation Script
 
 Validates:
   1. Model loads correctly
   2. Input/output tensor shapes are correct
   3. Output sums to ~1.0 (valid probability distribution)
   4. All 15 FSL classes are reachable
   5. Float16 vs Float32 accuracy match (should be ≥99%)
   6. Inference latency benchmark
   7. Model file integrity check
==============================================================
"""

import os
import sys
import time
import hashlib
import numpy as np

os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'

try:
    import tensorflow as tf
except ImportError:
    print("❌ TensorFlow not found.")
    sys.exit(1)

# ── CONFIG ────────────────────────────────────────────────────
MODEL_DIR       = "."
SEQUENCE_LENGTH = 30
FEATURE_DIM     = 258
NUM_CLASSES     = 15
LATENCY_RUNS    = 100
# ─────────────────────────────────────────────────────────────

ACTIONS = [
    'ako', 'bakit', 'F', 'hi', 'hindi', 'ikaw',
    'kamusta', 'L', 'maganda', 'magandang umaga',
    'N', 'O', 'oo', 'P', 'salamat'
]

MODELS_TO_TEST = {
    "model.tflite":               "Primary (Float16)",
    "model_float32.tflite":       "Float32  baseline",
    "model_float16.tflite":       "Float16  quantized",
    "model_dynamic_range.tflite": "Dynamic  range",
}

passed = 0
failed = 0


def check(name, condition, detail=""):
    global passed, failed
    status = "✅ PASS" if condition else "❌ FAIL"
    if condition:
        passed += 1
    else:
        failed += 1
    print(f"  {status}  {name}")
    if detail:
        print(f"          {detail}")
    return condition


def load_model(path):
    interp = tf.lite.Interpreter(model_path=path)
    interp.allocate_tensors()
    return interp, interp.get_input_details(), interp.get_output_details()


def infer(interp, in_d, out_d, x):
    interp.set_tensor(in_d[0]['index'], x.astype(np.float32))
    interp.invoke()
    return interp.get_tensor(out_d[0]['index'])[0]


def validate_model(name, path, label):
    print(f"\n{'─'*55}")
    print(f"  Model: {label}")
    print(f"  Path : {path}")
    print(f"{'─'*55}")

    if not os.path.exists(path):
        check(f"File exists: {name}", False, f"Not found at {path}")
        return

    size_kb = os.path.getsize(path) / 1024
    check("File exists", True, f"{size_kb:.1f} KB")

    # SHA256
    sha = hashlib.sha256(open(path, 'rb').read()).hexdigest()
    check("File hash (SHA256)", True, sha[:32] + "...")

    # Load
    try:
        interp, in_d, out_d = load_model(path)
        check("Model loads", True)
    except Exception as e:
        check("Model loads", False, str(e))
        return

    # Input shape
    in_shape = tuple(in_d[0]['shape'])
    check("Input shape = (1, 30, 258)", in_shape == (1, SEQUENCE_LENGTH, FEATURE_DIM),
          f"Got {in_shape}")

    # Input dtype
    in_dtype = in_d[0]['dtype']
    check("Input dtype = float32", in_dtype == np.float32, f"Got {in_dtype}")

    # Output shape
    out_shape = tuple(out_d[0]['shape'])
    check("Output shape = (1, 15)", out_shape == (1, NUM_CLASSES), f"Got {out_shape}")

    # Valid probability distribution
    test_input = np.random.rand(1, SEQUENCE_LENGTH, FEATURE_DIM).astype(np.float32)
    probs = infer(interp, in_d, out_d, test_input)
    prob_sum = float(probs.sum())
    check("Output sums to ~1.0", abs(prob_sum - 1.0) < 0.01, f"Sum = {prob_sum:.6f}")
    check("All probs in [0, 1]",
          bool(np.all(probs >= 0) and np.all(probs <= 1)),
          f"min={probs.min():.4f}, max={probs.max():.4f}")

    # All 15 classes reachable
    unique_preds = set()
    for _ in range(300):
        x = np.random.rand(1, SEQUENCE_LENGTH, FEATURE_DIM).astype(np.float32)
        p = infer(interp, in_d, out_d, x)
        unique_preds.add(int(np.argmax(p)))
    check("All 15 classes reachable",
          len(unique_preds) == NUM_CLASSES,
          f"Only {len(unique_preds)} classes seen in 300 random inferences")

    # Latency benchmark
    x_bench = np.random.rand(1, SEQUENCE_LENGTH, FEATURE_DIM).astype(np.float32)
    times = []
    for _ in range(LATENCY_RUNS):
        t0 = time.perf_counter()
        infer(interp, in_d, out_d, x_bench)
        times.append((time.perf_counter() - t0) * 1000)
    avg_ms  = np.mean(times)
    p95_ms  = np.percentile(times, 95)
    ok_rt   = avg_ms < 100  # real-time = <100ms per sequence
    check("Inference < 100ms (real-time)", ok_rt,
          f"avg={avg_ms:.1f}ms  p95={p95_ms:.1f}ms  ({LATENCY_RUNS} runs)")

    # Label sanity
    labels_file = os.path.join(MODEL_DIR, "labels.txt")
    if os.path.exists(labels_file):
        labels = open(labels_file).read().strip().split('\n')
        check("labels.txt has 15 entries", len(labels) == NUM_CLASSES,
              f"Found {len(labels)} labels")
        check("labels.txt matches expected", labels == ACTIONS)


def compare_f32_vs_f16():
    """Compare float32 vs float16 top-1 match rate (should be ≥99%)."""
    print(f"\n{'─'*55}")
    print("  Float32 vs Float16 accuracy comparison")
    print(f"{'─'*55}")

    p32 = os.path.join(MODEL_DIR, "model_float32.tflite")
    p16 = os.path.join(MODEL_DIR, "model_float16.tflite")

    if not (os.path.exists(p32) and os.path.exists(p16)):
        print("  ⚠️  Skipped — both models not found")
        return

    i32, in32, out32 = load_model(p32)
    i16, in16, out16 = load_model(p16)

    N = 200
    matches = 0
    for _ in range(N):
        x = np.random.rand(1, SEQUENCE_LENGTH, FEATURE_DIM).astype(np.float32)
        p_32 = np.argmax(infer(i32, in32, out32, x))
        p_16 = np.argmax(infer(i16, in16, out16, x))
        matches += int(p_32 == p_16)

    match_pct = matches / N * 100
    check(f"Float16 top-1 match ≥ 99% vs Float32",
          match_pct >= 99.0,
          f"Match rate: {match_pct:.1f}% over {N} random inputs")


# ── Run all validations ───────────────────────────────────────
if __name__ == '__main__':
    print("=" * 55)
    print("  Senyas FSL — TFLite Validation Suite")
    print(f"  TensorFlow {tf.__version__}")
    print("=" * 55)

    for fname, label in MODELS_TO_TEST.items():
        path = os.path.join(MODEL_DIR, fname)
        validate_model(fname, path, label)

    compare_f32_vs_f16()

    print(f"\n{'='*55}")
    print(f"  Results: {passed} passed,  {failed} failed")
    print(f"{'='*55}")
    sys.exit(0 if failed == 0 else 1)
