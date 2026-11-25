# Phase 11.9 — INTERNAL AI implementation status

**Status: offline object-detection prototype integrated; NOT production ready.**

- The Flutter app now packages the 3.66 MB official YOLOX-Nano COCO-80 ONNX model and uses `flutter_onnxruntime` CPU inference on Android and Windows.
- `YoloxOnnxEngine` decodes local JPEG snapshots or a selected Windows image. It applies the official BGR / 0–255 / top-left preprocessing, raw YOLOX stride decoding, confidence filtering, class-aware NMS and normalized boxes.
- Each detection includes a broad category plus a specific COCO label. Person is presence-only; there is no identity matching, biometric recognition, or tracking.
- The ONNX artifact is pinned in `assets/models/manifest.json` by source and SHA-256 and includes the YOLOX Apache-2.0 license text.
- CI covers synthetic output decoding and an inference smoke test against the packaged real weights on ONNX Runtime CPU. Flutter unit tests cover person/truck/animal decoding.
- The tactical camera wall runs explicit snapshot analysis for the local Android camera and local image-file analysis on Windows. External video feeds remain preview-only.
- The external YOLO inference service from earlier Phase 11 work is separate and is not an internal model.
- Person detection is presence-only, never identity or face recognition.
- Vehicle image retrieval requires a licensed embedding model, local index, and quality evaluation. Not implemented.
- Plate OCR requires a licensed plate detector and OCR model, jurisdiction-specific validation, access controls and privacy review. Not implemented.
- Continuous live-video frame extraction, overlays on the live preview and device performance/accuracy validation are not implemented.
- The general COCO model is not tuned for drone imagery. Small/distant aerial people, vehicles and animals require an aerial-specific model and evaluation dataset.
- No VisDrone-finetuned model, vehicle similarity model, plate detector or OCR model is included.

## Next release gates
1. Verify Flutter plugin/runtime integration with the Android APK and Windows release CI; Windows pins ONNX Runtime 1.22.0 as a workaround for the currently unavailable upstream 1.28.3 download.
2. Benchmark COCO accuracy and speed on supported Android/Windows hardware, and evaluate SARISA drone footage for missed small objects.
3. Train/evaluate a VisDrone-specific ONNX detector for aerial pedestrian and vehicle classes; keep the COCO model for animals and general objects.
4. Add continuous local frame sampling and detection overlays only after bounded-queue, thermal and frame-rate tests.
5. Add locally encrypted evidence storage, access controls, retention policy and audit trail before persisting imagery or sensitive results.
6. Keep vehicle-image similarity and OCR as separate reviewed model integrations.

Do not claim that a stub, a mock test engine, or the external inference service is working offline AI.

## Integration preparation added (2026-11-11)
- `native_ai_manifest.dart`: pinned model metadata contract (SHA-256, license, version), with **no approved models** until review.
- `vehicle_visual_search.dart`: local cosine similarity and ranked candidate search over embeddings supplied by a future on-device vehicle model. It cannot extract embeddings from photographs yet.
- `plate_ocr_validation.dart`: format normalization and confidence review gate for output from a future local OCR model. It does not detect or read plates from images yet.
- `test/native_ai_components_test.dart`: deterministic unit tests for these components; CI outcome has not yet been verified.
- `native_ai/test_offline_detector.py`: CI creates a tiny synthetic ONNX graph for contract/box tests and also loads the packaged YOLOX-Nano model through ONNX Runtime CPU, verifying the pinned digest and valid offline inference. Neither smoke test measures real-world accuracy.
- `native_ai/test_offline_video.py`: checks local frame sampling limits, offline event results and capture cleanup without shipping video or model data.
- The combined Android/Windows workflow now runs `flutter analyze`, `flutter test`, both release builds, and the Python ONNX/video tests on pull requests and pushes to `main`.

### Release gate

The packaged model is working in the Python CPU smoke test; Flutter on-device inference remains pending the new Android and Windows release CI run and hardware validation. Do not describe the model as aerial-accurate, continuous-video AI, vehicle image search or plate OCR.
