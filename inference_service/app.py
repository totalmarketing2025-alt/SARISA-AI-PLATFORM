"""SARISA Phase 11: operator-hosted real object detection service.

Run only on a trusted host behind an HTTPS reverse proxy. No face recognition.
"""
import io
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from PIL import Image, UnidentifiedImageError
from ultralytics import YOLO

MODEL_NAME = os.getenv("SARISA_MODEL", "yolo11n.pt")
MAX_BYTES = 4_000_000
model = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global model
    model = YOLO(MODEL_NAME)
    yield
    model = None

app = FastAPI(title="SARISA Phase 11 Inference", lifespan=lifespan)

@app.get("/health")
def health():
    return {"ready": model is not None, "model": MODEL_NAME}

@app.post("/detect")
async def detect(request: Request):
    if request.headers.get("content-type", "").split(";")[0].strip() != "image/jpeg":
        raise HTTPException(415, "Expected image/jpeg")
    payload = await request.body()
    if not payload or len(payload) > MAX_BYTES:
        raise HTTPException(413, "JPEG must be 1..4000000 bytes")
    try:
        image = Image.open(io.BytesIO(payload))
        image.verify()
        image = Image.open(io.BytesIO(payload)).convert("RGB")
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        raise HTTPException(422, "Invalid JPEG") from exc
    if image.width * image.height > 16_000_000:
        raise HTTPException(413, "Image dimensions too large")
    results = model.predict(source=image, verbose=False, conf=0.4, imgsz=640)
    detections = []
    for result in results:
        for box in result.boxes:
            label = result.names[int(box.cls.item())]
            if label == "person":
                category = "person"
            elif label in {"car", "truck", "bus", "motorcycle", "bicycle", "train", "boat", "airplane"}:
                category = "vehicle"
            else:
                category = "object"
            x1, y1, x2, y2 = (float(v) for v in box.xyxy[0].tolist())
            x = max(0.0, min(1.0, x1 / image.width))
            y = max(0.0, min(1.0, y1 / image.height))
            w = max(0.0, min(1.0 - x, (x2 - x1) / image.width))
            h = max(0.0, min(1.0 - y, (y2 - y1) / image.height))
            detections.append({"category": category,
                "confidence": float(box.conf.item()), "box": [x, y, w, h]})
            if len(detections) >= 100:
                break
        if len(detections) >= 100:
            break
    return JSONResponse({"detections": detections})
