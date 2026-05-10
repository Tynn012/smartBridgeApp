"""
==============================================================
 Senyas FSL — Live Webcam TFLite Inference
 
 Real-time Filipino Sign Language recognition using:
   • MediaPipe Holistic (landmark extraction)
   • TFLite interpreter (fast inference)
   • OpenCV (webcam + display)
 
 Controls:
   Q  — quit
   C  — clear sentence
   S  — save current sentence to file
==============================================================
"""

import os
import sys
import time
import numpy as np
import cv2

os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'

# ── CONFIG ────────────────────────────────────────────────────
TFLITE_MODEL    = "model.tflite"
LABELS_FILE     = "labels.txt"
SEQUENCE_LENGTH = 30
THRESHOLD       = 0.50    # min confidence to accept prediction
SMOOTHING_FRAMES = 10     # how many frames to average for stable prediction
# ─────────────────────────────────────────────────────────────

ACTIONS = open(LABELS_FILE).read().strip().split('\n')
NUM_CLASSES = len(ACTIONS)

# ── Load TFLite model ─────────────────────────────────────────
try:
    import tensorflow as tf
    interpreter = tf.lite.Interpreter(model_path=TFLITE_MODEL)
except ImportError:
    from ai_edge_litert.interpreter import Interpreter
    interpreter = Interpreter(model_path=TFLITE_MODEL)

interpreter.allocate_tensors()
in_details  = interpreter.get_input_details()
out_details = interpreter.get_output_details()
print(f"✅ Model loaded: {TFLITE_MODEL}")

# ── Load MediaPipe ────────────────────────────────────────────
try:
    import mediapipe as mp
except ImportError:
    print("❌ mediapipe not found. Install with: pip install mediapipe")
    sys.exit(1)

mp_holistic = mp.solutions.holistic
mp_draw     = mp.solutions.drawing_utils


# ── Helper functions ──────────────────────────────────────────
def mediapipe_detection(image, model):
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    image.flags.writeable = False
    results = model.process(image)
    image.flags.writeable = True
    return cv2.cvtColor(image, cv2.COLOR_RGB2BGR), results


def extract_keypoints(results):
    """Extract and flatten pose + hands landmarks → (258,) vector."""
    pose = (np.array([[r.x, r.y, r.z, r.visibility]
                      for r in results.pose_landmarks.landmark]).flatten()
            if results.pose_landmarks else np.zeros(33 * 4))
    lh   = (np.array([[r.x, r.y, r.z]
                      for r in results.left_hand_landmarks.landmark]).flatten()
            if results.left_hand_landmarks else np.zeros(21 * 3))
    rh   = (np.array([[r.x, r.y, r.z]
                      for r in results.right_hand_landmarks.landmark]).flatten()
            if results.right_hand_landmarks else np.zeros(21 * 3))
    return np.concatenate([pose, lh, rh])  # shape: (258,)


def draw_landmarks(image, results):
    mp_draw.draw_landmarks(image, results.pose_landmarks,
        mp_holistic.POSE_CONNECTIONS,
        mp_draw.DrawingSpec(color=(80, 22, 10), thickness=2, circle_radius=3),
        mp_draw.DrawingSpec(color=(80, 44, 121), thickness=2, circle_radius=1))
    mp_draw.draw_landmarks(image, results.left_hand_landmarks,
        mp_holistic.HAND_CONNECTIONS,
        mp_draw.DrawingSpec(color=(121, 22, 76), thickness=2, circle_radius=3),
        mp_draw.DrawingSpec(color=(121, 44, 250), thickness=2, circle_radius=1))
    mp_draw.draw_landmarks(image, results.right_hand_landmarks,
        mp_holistic.HAND_CONNECTIONS,
        mp_draw.DrawingSpec(color=(245, 117, 66), thickness=2, circle_radius=3),
        mp_draw.DrawingSpec(color=(245, 66, 230), thickness=2, circle_radius=1))


def run_tflite(sequence_array):
    """Run TFLite inference. Input: (1, 30, 258). Output: (15,) probs."""
    interpreter.set_tensor(in_details[0]['index'],
                           sequence_array[np.newaxis].astype(np.float32))
    interpreter.invoke()
    return interpreter.get_tensor(out_details[0]['index'])[0]


def draw_probabilities(frame, probs):
    """Draw a probability bar chart overlay on the frame."""
    h, w = frame.shape[:2]
    bar_h = min(20, (h - 60) // NUM_CLASSES)
    for i, (p, label) in enumerate(zip(probs, ACTIONS)):
        y = 60 + i * bar_h
        color = (0, 200, 0) if i == np.argmax(probs) else (100, 100, 100)
        cv2.rectangle(frame, (w - 160, y), (w - 160 + int(p * 150), y + bar_h - 2), color, -1)
        cv2.putText(frame, f"{label[:12]}", (w - 160, y + bar_h - 4),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.35, (255, 255, 255), 1)
    return frame


# ── Main loop ─────────────────────────────────────────────────
def main():
    sequence    = []
    sentence    = []
    predictions = []
    fps_times   = []

    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 720)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    if not cap.isOpened():
        print("❌ Cannot open webcam")
        sys.exit(1)

    print("🎥 Webcam started. Press Q to quit, C to clear, S to save sentence.")

    with mp_holistic.Holistic(min_detection_confidence=0.5,
                              min_tracking_confidence=0.5) as holistic:
        while cap.isOpened():
            t0  = time.time()
            ret, frame = cap.read()
            if not ret:
                break

            frame = cv2.flip(frame, 1)   # mirror
            image, results = mediapipe_detection(frame, holistic)
            draw_landmarks(image, results)

            keypoints = extract_keypoints(results)
            sequence.append(keypoints)
            sequence = sequence[-SEQUENCE_LENGTH:]

            probs = np.zeros(NUM_CLASSES)
            label = "Collecting frames..."
            confidence = 0.0

            if len(sequence) == SEQUENCE_LENGTH:
                seq_arr = np.array(sequence)         # (30, 258)
                probs   = run_tflite(seq_arr)
                predictions.append(int(np.argmax(probs)))

                if len(predictions) >= SMOOTHING_FRAMES:
                    majority = int(np.bincount(predictions[-SMOOTHING_FRAMES:]).argmax())
                    confidence = float(probs[majority])

                    if confidence > THRESHOLD:
                        label = ACTIONS[majority]
                        if not sentence or sentence[-1] != label:
                            sentence.append(label)
                        if len(sentence) > 6:
                            sentence = sentence[-6:]
                    else:
                        label = f"? ({confidence:.0%})"

            # ── HUD ──────────────────────────────────────────
            # Top bar — sentence
            cv2.rectangle(image, (0, 0), (image.shape[1], 45), (50, 50, 50), -1)
            cv2.putText(image, ' '.join(sentence), (10, 32),
                        cv2.FONT_HERSHEY_SIMPLEX, 1.0, (255, 255, 255), 2)

            # Bottom bar — current sign
            cv2.rectangle(image, (0, image.shape[0] - 45),
                          (image.shape[1], image.shape[0]), (30, 30, 30), -1)
            color = (0, 200, 100) if confidence >= THRESHOLD else (80, 80, 200)
            cv2.putText(image, f"Sign: {label}", (10, image.shape[0] - 12),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, color, 2)

            # FPS counter
            fps_times.append(time.time() - t0)
            fps_times = fps_times[-20:]
            fps = 1.0 / (sum(fps_times) / len(fps_times))
            cv2.putText(image, f"FPS: {fps:.0f}", (image.shape[1] - 90, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (200, 200, 200), 1)

            # Prob bars
            image = draw_probabilities(image, probs)
            cv2.imshow('Senyas FSL — TFLite', image)

            key = cv2.waitKey(1) & 0xFF
            if key == ord('q'):
                break
            elif key == ord('c'):
                sentence.clear()
                print("🗑  Sentence cleared")
            elif key == ord('s'):
                with open("sentence_log.txt", 'a') as f:
                    f.write(' '.join(sentence) + '\n')
                print(f"💾 Saved: {' '.join(sentence)}")

    cap.release()
    cv2.destroyAllWindows()
    print("✅ Session ended.")


if __name__ == '__main__':
    main()
