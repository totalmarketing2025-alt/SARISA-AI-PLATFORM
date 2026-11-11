"""Real offline ONNX image detection, once a compatible model is provisioned.

Supports YOLO11/YOLOv8 exported ONNX detect models with output [1,4+C,N]
or [1,N,4+C]. No face recognition, network access or external inference.
"""
import argparse
import json
from pathlib import Path

import cv2
import numpy as np
import onnxruntime as ort
from PIL import Image

COCO_VEHICLES = {1, 2, 3, 5, 6, 7, 8}


def infer(model_path: Path, image_path: Path, confidence: float = 0.5):
    if not model_path.is_file() or not image_path.is_file():
        raise FileNotFoundError("Local model or image missing")
    if not 0 < confidence <= 1:
        raise ValueError("Confidence must be in (0,1]")
    session = ort.InferenceSession(str(model_path), providers=["CPUExecutionProvider"])
    inputs = session.get_inputs()
    if len(inputs) != 1:
        raise ValueError("Expected one ONNX image input")
    shape = inputs[0].shape
    if len(shape) != 4 or not isinstance(shape[2], int) or not isinstance(shape[3], int):
        raise ValueError("Export model with static NCHW input size")
    height, width = shape[2], shape[3]
    if height < 32 or width < 32:
        raise ValueError("Invalid model input dimensions")
    with Image.open(image_path) as original:
        image = np.asarray(original.convert("RGB"))
    ih, iw = image.shape[:2]
    if ih * iw > 16_000_000:
        raise ValueError("Image too large")
    scale = min(width / iw, height / ih)
    rw, rh = round(iw * scale), round(ih * scale)
    resized = cv2.resize(image, (rw, rh))
    canvas = np.full((height, width, 3), 114, dtype=np.uint8)
    left, top = (width - rw) // 2, (height - rh) // 2
    canvas[top:top + rh, left:left + rw] = resized
    tensor = np.transpose(canvas, (2, 0, 1))[None].astype(np.float32) / 255.0
    raw = np.asarray(session.run(None, {inputs[0].name: tensor})[0])
    if raw.ndim != 3 or raw.shape[0] != 1:
        raise ValueError("Unsupported detection output shape")
    matrix = raw[0]
    if matrix.shape[0] in (84, 85):
        matrix = matrix.T
    if matrix.ndim != 2 or matrix.shape[1] not in (84, 85):
        raise ValueError("Expected COCO YOLO detection tensor with 80 classes")
    # YOLOv8/11: 4 + 80 class scores; YOLOv5: 4 + objectness + 80
    is_v5 = matrix.shape[1] == 85
    scores = matrix[:, 5:] * matrix[:, 4:5] if is_v5 else matrix[:, 4:]
    class_ids = scores.argmax(axis=1)
    best = scores[np.arange(len(scores)), class_ids]
    candidates = []
    for row, cls, score in zip(matrix[best >= confidence],
                               class_ids[best >= confidence],
                               best[best >= confidence]):
        cls = int(cls)
        if cls == 0:
            category = "person"
        elif cls in COCO_VEHICLES:
            category = "vehicle"
        else:
            category = "object"
        cx, cy, bw, bh = map(float, row[:4])
        x1 = max(0.0, min(float(iw), (cx - bw / 2 - left) / scale))
        y1 = max(0.0, min(float(ih), (cy - bh / 2 - top) / scale))
        x2 = max(0.0, min(float(iw), (cx + bw / 2 - left) / scale))
        y2 = max(0.0, min(float(ih), (cy + bh / 2 - top) / scale))
        if x2 <= x1 or y2 <= y1:
            continue
        candidates.append((category, cls, float(score), [x1, y1, x2 - x1, y2 - y1]))
    # Class-aware NMS: suppress duplicate detections without merging categories.
    results = []
    for category, cls in sorted({(c, k) for c, k, _, _ in candidates}):
        group = [(s, b) for c, k, s, b in candidates if c == category and k == cls]
        boxes = [b for _, b in group]
        scores_group = [s for s, _ in group]
        indices = cv2.dnn.NMSBoxes(boxes, scores_group, confidence, 0.45)
        for idx in np.asarray(indices).reshape(-1):
            score, box = group[int(idx)]
            x, y, bw, bh = box
            results.append({"category": category, "confidence": round(score, 5),
                            "box": [round(x / iw, 6), round(y / ih, 6),
                                    round(bw / iw, 6), round(bh / ih, 6)]})
    results.sort(key=lambda d: d["confidence"], reverse=True)
    return {"detections": results[:100], "offline": True, "model": model_path.name}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--confidence", type=float, default=0.5)
    args = parser.parse_args()
    print(json.dumps(infer(args.model, args.image, args.confidence)))


if __name__ == "__main__":
    main()
