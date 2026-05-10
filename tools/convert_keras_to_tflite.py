#!/usr/bin/env python3
"""Download a Keras .h5 model from GitHub and convert it to TFLite.

Usage:
  python tools/convert_keras_to_tflite.py

It will download NF1.h5 from the Senyas-FSL-Translator repo, convert
to assets/models/NF1.tflite, and save a labels file if available.
"""
import os
import sys
from pathlib import Path

MODEL_URL = "https://raw.githubusercontent.com/antoineross/Senyas-FSL-Translator/main/models/NF1.h5"
OUT_DIR = Path("assets/models")
OUT_DIR.mkdir(parents=True, exist_ok=True)


def download(url: str, dest: Path):
    import requests

    print(f"Downloading {url} -> {dest}")
    r = requests.get(url, stream=True)
    r.raise_for_status()
    with open(dest, "wb") as f:
        for chunk in r.iter_content(8192):
            f.write(chunk)


def convert(h5_path: Path, tflite_path: Path):
    import tensorflow as tf

    print(f"Loading Keras model from {h5_path}")
    model = tf.keras.models.load_model(str(h5_path))
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    # Default optimizations; user can modify as needed.
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    # Allow select TF ops when lowering complex ops (e.g., TensorList/TensorArray)
    try:
        converter.target_spec.supported_ops = [
            tf.lite.OpsSet.TFLITE_BUILTINS,
            tf.lite.OpsSet.SELECT_TF_OPS,
        ]
        # Disable experimental lowering of tensor list ops which can fail for LSTM/TensorArray patterns
        # (this uses an internal flag surfaced by TF error messages)
        setattr(converter, "_experimental_lower_tensor_list_ops", False)
    except Exception:
        # If the converter API does not support these fields, continue with defaults
        pass

    tflite_model = converter.convert()
    tflite_path.write_bytes(tflite_model)
    print(f"Saved TFLite model to {tflite_path}")


def main():
    h5_path = OUT_DIR / "NF1.h5"
    tflite_path = OUT_DIR / "NF1.tflite"

    # Check for requests and tensorflow
    try:
        import requests  # noqa: F401
    except Exception:
        print("The 'requests' package is required. Install with: pip install requests")
        sys.exit(2)

    try:
        import tensorflow  # noqa: F401
    except Exception:
        print("TensorFlow is required to run this conversion. Install with: pip install tensorflow")
        sys.exit(2)

    if not h5_path.exists():
        download(MODEL_URL, h5_path)
    else:
        print(f"Using existing file {h5_path}")

    convert(h5_path, tflite_path)


if __name__ == "__main__":
    main()
