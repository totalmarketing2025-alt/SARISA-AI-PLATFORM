# SARISA Offline ONNX Detection — first executable engine

This directory contains a **real CPU ONNX inference implementation** for a compatible YOLO11/YOLOv8 COCO object-detection model. It processes local JPEG/PNG files without an inference server. It is a Python reference runner, **not yet connected to the Flutter Android/Windows UI**.

## Provision a model (once, on an authorized development computer)

Review the Ultralytics license (AGPL-3.0 or a suitable enterprise license) before using the model. Do not ship weights without license review.

```bash
python -m pip install ultralytics
python -c "from ultralytics import YOLO; YOLO('yolo11n.pt').export(format='onnx', imgsz=640, dynamic=False)"
```

Exported ONNX model must have static NCHW input and standard COCO 80-class output. Verify its checksum, origin and license before packaging. No weights are committed to the repository.

## Execute locally

```bash
python -m pip install -r native_ai/requirements.txt
python native_ai/offline_detector.py --model yolo11n.onnx --image sample.jpg
```

Output is normalized JSON detections for `person`, `vehicle`, and `object`. It does **not** identify people. It does not perform vehicle-image embedding search or plate OCR. The Python runner needs no internet at inference time after dependencies and model weights are installed.

## Remaining Android and Windows app integration

- Package and verify a licensed model and compatible native ONNX Runtime for Android and Windows.
- Implement native Flutter platform bindings, frame decoding and UI integration.
- Implement separate vehicle-image embedding and plate detector/OCR inference.
- Test model tensor shapes, actual inference and memory/FPS on both target platforms.
- Protect stored imagery, plate text and results with access controls, encryption and retention.

The Python runner is not an Android APK feature; do not label Phase 11.9 complete until the device builds pass end-to-end.
