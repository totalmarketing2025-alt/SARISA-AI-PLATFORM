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
COCO_ANIMALS = set(range(14, 24))
COCO_LABELS = (
    "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train",
    "truck", "boat", "traffic_light", "fire_hydrant", "stop_sign",
    "parking_meter", "bench", "bird", "cat", "dog", "horse", "sheep",
    "cow", "elephant", "bear", "zebra", "giraffe", "backpack", "umbrella",
    "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard",
    "sports_ball", "kite", "baseball_bat", "baseball_glove", "skateboard",
    "surfboard", "tennis_racket", "bottle", "wine_glass", "cup", "fork",
    "knife", "spoon", "bowl", "banana", "apple", "sandwich", "orange",
    "broccoli", "carrot", "hot_dog", "pizza", "donut", "cake", "chair",
    "couch", "potted_plant", "bed", "dining_table", "toilet", "tv",
    "laptop", "mouse", "remote", "keyboard", "cell_phone", "microwave",
    "oven", "toaster", "sink", "refrigerator", "book", "clock", "vase",
    "scissors", "teddy_bear", "hair_drier", "toothbrush",
)


def _decode_yolox_raw(predictions: np.ndarray, height: int, width: int):
    """Decode the raw [1, anchors, 85] output used by official YOLOX ONNX files."""
    strides = (8, 16, 32)
    grids = []
    expanded_strides = []
    for stride in strides:
        grid_h, grid_w = height // stride, width // stride
        if grid_h < 1 or grid_w < 1:
            raise ValueError("YOLOX input must be at least 32x32")
        grid_x, grid_y = np.meshgrid(np.arange(grid_w), np.arange(grid_h))
        grids.append(np.stack((grid_x, grid_y), axis=-1).reshape(-1, 2))
        expanded_strides.append(np.full((grid_h * grid_w, 1), stride))
    grid = np.concatenate(grids, axis=0).astype(np.float32)
    stride = np.concatenate(expanded_strides, axis=0).astype(np.float32)
    if predictions.shape[0] != len(grid):
        raise ValueError("YOLOX output anchor count does not match its input size")
    decoded = predictions.astype(np.float32, copy=True)
    decoded[:, :2] = (decoded[:, :2] + grid) * stride
    # Clip malformed exponent values to prevent overflow from corrupt models.
    decoded[:, 2:4] = np.exp(np.clip(decoded[:, 2:4], -10, 10)) * stride
    return decoded


def infer(model_path: Path, image_path: Path, confidence: float = 0.5,
          model_format: str = "yolox"):
    if not model_path.is_file() or not image_path.is_file():
        raise FileNotFoundError("Local model or image missing")
    if not 0 < confidence <= 1:
        raise ValueError("Confidence must be in (0,1]")
    if model_format not in {"yolox", "yolov8"}:
        raise ValueError("Model format must be 'yolox' or 'yolov8'")
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
    if model_format == "yolox":
        # Official YOLOX preprocessing reads OpenCV BGR and keeps pixel range 0..255.
        image = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
        if image is None:
            raise ValueError("Could not decode local image")
    else:
        with Image.open(image_path) as original:
            image = np.asarray(original.convert("RGB"))
    ih, iw = image.shape[:2]
    if ih * iw > 16_000_000:
        raise ValueError("Image too large")
    scale = min(width / iw, height / ih)
    if model_format == "yolox":
        # Match the official YOLOX preprocessor's integer truncation exactly.
        rw, rh = int(iw * scale), int(ih * scale)
    else:
        rw, rh = round(iw * scale), round(ih * scale)
    resized = cv2.resize(image, (rw, rh))
    canvas = np.full((height, width, 3), 114, dtype=np.uint8)
    # Official YOLOX preproc anchors the resized image at top-left; YOLOv8
    # exports in this runner use centered letterboxing.
    left, top = ((0, 0) if model_format == "yolox"
                 else ((width - rw) // 2, (height - rh) // 2))
    canvas[top:top + rh, left:left + rw] = resized
    tensor = np.transpose(canvas, (2, 0, 1))[None].astype(np.float32)
    if model_format == "yolov8":
        tensor /= 255.0
    raw = np.asarray(session.run(None, {inputs[0].name: tensor})[0])
    if raw.ndim != 3 or raw.shape[0] != 1:
        raise ValueError("Unsupported detection output shape")
    matrix = raw[0]
    if model_format == "yolox":
        # Official YOLOX releases have raw [1, anchors, 5 + 80] output.
        # Some exported models place the class/channel dimension in axis 1.
        if matrix.shape[0] == 85 and matrix.shape[1] != 85:
            matrix = matrix.T
        if matrix.ndim != 2 or matrix.shape[1] != 85:
            raise ValueError("Expected YOLOX COCO output [1, anchors, 85]")
        matrix = _decode_yolox_raw(matrix, height, width)
        scores = matrix[:, 5:] * matrix[:, 4:5]
    else:
        if matrix.shape[0] == 84 and matrix.shape[1] != 84:
            matrix = matrix.T
        if matrix.ndim != 2 or matrix.shape[1] != 84:
            raise ValueError("Expected YOLOv8 COCO output [1, 84, anchors]")
        scores = matrix[:, 4:]
    class_ids = scores.argmax(axis=1)
    best = scores[np.arange(len(scores)), class_ids]
    candidates = []
    for row, cls, score in zip(matrix[best >= confidence],
                               class_ids[best >= confidence],
                               best[best >= confidence]):
        cls = int(cls)
        category = ("person" if cls == 0 else "vehicle" if cls in COCO_VEHICLES
                    else "animal" if cls in COCO_ANIMALS else "object")
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
            results.append({"category": category, "label": COCO_LABELS[cls],
                            "class_id": cls, "confidence": round(score, 5),
                            "box": [round(x / iw, 6), round(y / ih, 6),
                                    round(bw / iw, 6), round(bh / ih, 6)]})
    results.sort(key=lambda d: d["confidence"], reverse=True)
    return {"detections": results[:100], "offline": True, "model": model_path.name}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--confidence", type=float, default=0.5)
    parser.add_argument("--format", choices=("yolox", "yolov8"), default="yolox")
    args = parser.parse_args()
    print(json.dumps(infer(args.model, args.image, args.confidence, args.format)))


if __name__ == "__main__":
    main()
