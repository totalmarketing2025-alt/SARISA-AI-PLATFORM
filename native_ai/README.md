# SARISA offline ONNX object detection

The Android/Windows build packages **YOLOX-Nano trained on COCO-80** and **PP-OCRv5 Latin** text detection/recognition ONNX models. The models and OCR dictionary are fetched during provisioning, verified against pinned byte counts and SHA-256 hashes, and run on CPU without an inference server or runtime internet access. Provenance and hashes are in `assets/models/manifest.json`; model licenses and attribution are in `assets/models/LICENSE-YOLOX.txt`, `assets/models/LICENSE-PPOCR.txt`, and `assets/models/NOTICE-PPOCR.txt`.

The decoder supports the official raw YOLOX output `[1, anchors, 85]`, with grid/stride decoding, confidence filtering, class-aware NMS, and normalized bounding boxes. YOLOv8 COCO output remains supported with `--format yolov8`.

## Run locally

```bash
python native_ai/fetch_model.py
python -m pip install -r native_ai/requirements.txt
python native_ai/offline_detector.py \
  --model assets/models/yolox_nano.onnx \
  --format yolox \
  --image sample.jpg
```

Select a local image in the Android/Windows camera wall, run offline detection,
then use **READ PLATE TEXT OFFLINE** to inspect OCR suggestions from detected
vehicle crops. The OCR model is loaded on demand. Every candidate is temporary
and requires the operator to compare it with the image; no owner or registry
lookup is performed.

Offline video sampling with anonymous vehicle/animal/object tracks and optional
plate text suggestions is available in the native AI command line:

```bash
python native_ai/offline_video.py \
  --model assets/models/yolox_nano.onnx \
  --video authorized-local-video.mp4 \
  --every-seconds 1 --max-frames 300 --ocr
```

Each sampled frame includes detections, short-lived `T1`, `T2`, … object track
labels, and `plate_candidates`. Person detections remain in the general
detection list but are deliberately excluded from tracking and plate OCR.
Track identifiers reset for each clip and are not persisted.

Each detection includes a broad category (`person`, `vehicle`, `animal`, or `object`), the specific COCO label, class ID, confidence, and normalized box. People are detected as a class only; there is no identity matching or biometric recognition.

## SAR scope and limitations

- COCO-80 includes person, common animals such as dog/cat/bird/cow/horse, trucks and other common vehicles, and everyday objects. It cannot detect arbitrary/untrained classes.
- This packaged model is a general COCO model, **not trained for aerial/drone imagery**. Small or distant objects in drone frames may be missed. An aerial-specific model trained and evaluated on VisDrone is a separate next stage; VisDrone's released detection classes do not include animals.
- The app runs explicit Android camera snapshots and locally selected images through the local engine. External streams remain preview-only; continuous live-video inference is not active.
- Vehicle search uses a compact color/layout descriptor over locally detected vehicle crops. Results are appearance-similarity candidates, not proof of vehicle identity. Search history stays in memory for the current app session.
- Plate OCR is general Latin text recognition on vehicle crops, not a plate-specific detector. It filters for a Macedonian-style plate pattern, can misread small, angled, dirty, or distant plates, and always requires visual operator confirmation. It does not perform owner identification or external registry queries.
- SARISA does not perform face recognition, biometric identity matching, or person tracking. Human presence detections are object detections only.

## Tests

```bash
python -m pip install -r native_ai/requirements-test.txt
python -m unittest discover -s native_ai -p 'test_*.py' -v
```

CI fetches and verifies the pinned YOLOX-Nano weights, then executes both a synthetic model for precise decoder edge cases and the real model through ONNX Runtime CPU. The synthetic fixture tests expected boxes/categories; the real-weight smoke test confirms the actual model loads and returns a valid offline result, not detection accuracy. Accuracy/FPS still require device-level validation.
