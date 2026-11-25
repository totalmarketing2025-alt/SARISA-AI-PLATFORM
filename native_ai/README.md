# SARISA offline ONNX object detection

The Android/Windows build packages **YOLOX-Nano trained on COCO-80**, fetched from the official YOLOX release and verified against a pinned SHA-256. The model runs on local images without an inference server or internet access. Its Apache-2.0 license, tensor contract, hash, and provenance are in `assets/models/manifest.json` and `assets/models/LICENSE-YOLOX.txt`. Model weights are downloaded at build/provisioning time rather than stored in Git.

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

Each detection includes a broad category (`person`, `vehicle`, `animal`, or `object`), the specific COCO label, class ID, confidence, and normalized box. People are detected as a class only; there is no identity matching or biometric recognition.

## Scope and limitations

- COCO-80 includes person, common animals such as dog/cat/bird/cow/horse, trucks and other common vehicles, and everyday objects. It cannot detect arbitrary/untrained classes.
- This packaged model is a general COCO model, **not trained for aerial/drone imagery**. Small or distant objects in drone frames may be missed. An aerial-specific model trained and evaluated on VisDrone is a separate next stage; VisDrone's released detection classes do not include animals.
- The app runs explicit Android camera snapshots and selected Windows images through the local engine. This is not continuous live-video inference.
- Vehicle image similarity search and license-plate OCR are separate models/features and are not included.

## Tests

```bash
python -m pip install -r native_ai/requirements-test.txt
python -m unittest discover -s native_ai -p 'test_*.py' -v
```

CI fetches and verifies the pinned YOLOX-Nano weights, then executes both a synthetic model for precise decoder edge cases and the real model through ONNX Runtime CPU. The synthetic fixture tests expected boxes/categories; the real-weight smoke test confirms the actual model loads and returns a valid offline result, not detection accuracy. Accuracy/FPS still require device-level validation.
