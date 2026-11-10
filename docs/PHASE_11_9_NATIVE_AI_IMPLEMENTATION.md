# Phase 11.9 — INTERNAL AI implementation status

**Status: foundation implemented; NOT production ready.**

- Dart offline-only native inference interface, normalized detection validation, operator-review event conversion and unit tests are committed.
- No native Android/Windows ONNX runtime binaries or licensed trained model weights are packaged. `UnavailableNativeAiEngine` explicitly fails closed and **does not fabricate detections**.
- The external YOLO inference service from earlier Phase 11 work is separate and is not an internal model.
- Person detection is presence-only, never identity or face recognition.
- Vehicle image retrieval requires a licensed embedding model, local index, and quality evaluation. Not implemented.
- Plate OCR requires a licensed plate detector and OCR model, jurisdiction-specific validation, access controls and privacy review. Not implemented.
- Video decoding and native frame extraction require platform integration and real device testing. Not implemented.

## Next release gates
1. Select and review commercially compatible ONNX model licenses, verify SHA-256 hashes and pin model versions.
2. Implement Kotlin/JNI Android and C++ Windows ONNX Runtime bindings with verified ABI and CPU fallback.
3. Integrate frame decoding without silently sending images off-device.
4. Add locally encrypted data store, access controls, retention policy and audit trail before storing plate text.
5. Benchmark detection accuracy and throughput on actual Android and Windows hardware.
6. Pass flutter analyze, flutter test, Android APK and Windows build CI.

Do not claim that a stub, a mock test engine, or the external inference service is working offline AI.
