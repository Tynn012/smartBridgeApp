"""
==============================================================
 Senyas FSL — TFLite Inference Example
 
 Shows how to run predictions from your own landmark arrays.
 Use this as a template to integrate into any Python project.
 
 Input shape:  (30, 258) — 30 frames of MediaPipe landmarks
 Output:       label string + confidence float
==============================================================
"""

import os
import numpy as np

# ── CONFIG ────────────────────────────────────────────────────
TFLITE_MODEL = "model.tflite"          # path to model.tflite
LABELS_FILE  = "labels.txt"            # path to labels.txt
THRESHOLD    = 0.5                     # minimum confidence to accept a prediction
# ─────────────────────────────────────────────────────────────

ACTIONS = open(LABELS_FILE).read().strip().split('\n')


class SenyasInference:
    """Lightweight TFLite inference wrapper for Senyas FSL."""

    def __init__(self, model_path=TFLITE_MODEL):
        try:
            import tensorflow as tf
            self._interp = tf.lite.Interpreter(model_path=model_path)
        except ImportError:
            # Fallback: use ai_edge_litert (TF 2.20+)
            from ai_edge_litert.interpreter import Interpreter
            self._interp = Interpreter(model_path=model_path)

        self._interp.allocate_tensors()
        self._in  = self._interp.get_input_details()
        self._out = self._interp.get_output_details()

        inp_shape = self._in[0]['shape']
        print(f"✅ Model loaded  | input shape: {inp_shape}")

    def predict(self, sequence: np.ndarray):
        """
        Args:
            sequence: np.ndarray of shape (30, 258) — one sequence of landmarks
        Returns:
            label (str), confidence (float), all_probs (np.ndarray shape [15])
        """
        if sequence.shape != (30, 258):
            raise ValueError(f"Expected (30, 258), got {sequence.shape}")

        x = sequence[np.newaxis].astype(np.float32)  # → (1, 30, 258)
        self._interp.set_tensor(self._in[0]['index'], x)
        self._interp.invoke()
        probs = self._interp.get_tensor(self._out[0]['index'])[0]  # (15,)

        idx        = int(np.argmax(probs))
        confidence = float(probs[idx])
        label      = ACTIONS[idx] if confidence >= THRESHOLD else "..."

        return label, confidence, probs


# ── Demo ──────────────────────────────────────────────────────
if __name__ == '__main__':
    model = SenyasInference(TFLITE_MODEL)

    # Simulate a 30-frame sequence of MediaPipe landmarks
    # In real use: replace this with extracted landmark data from MediaPipe
    fake_sequence = np.random.rand(30, 258).astype(np.float32)

    label, conf, probs = model.predict(fake_sequence)

    print(f"\n📌 Predicted sign : '{label}'")
    print(f"   Confidence      : {conf:.2%}")
    print(f"\n   All probabilities:")
    for i, (sign, p) in enumerate(zip(ACTIONS, probs)):
        bar = '█' * int(p * 30)
        print(f"   [{i:2d}] {sign:<20} {p:.3f}  {bar}")
