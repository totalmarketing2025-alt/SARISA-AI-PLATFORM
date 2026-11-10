# SARISA Phase 11 — Live AI adapter

Phase 11 can process real JPEG camera snapshots with an **operator-configured external AI model**. The Flutter app does not ship with a trained model. Do not label this integration as on-device inference or full-motion video analysis.

## Input requirements
- Camera: authorized HTTPS endpoint returning a single JPEG image (not HLS, RTSP or MJPEG).
- Inference: HTTPS POST endpoint accepting raw image/jpeg bytes.
- Response: JSON with normalized bounding boxes:
```json
{"detections":[{"category":"person","confidence":0.94,"box":[0.1,0.2,0.3,0.4]}]}
```
Supported categories: person, vehicle, object, hazard. Confidence is 0..1. Box is [left, top, width, height], normalized 0..1.

## Behavior
- Live polling at most once every 3 seconds; processing is serialized and bounded to 4 MB JPEG and 100 boxes.
- Image bytes are sent to the configured HTTPS inference endpoint. Only use trusted, authorized services. No credentials in URLs.
- Returned boxes are drawn on the displayed JPEG snapshot, not on Phase 10's video_player video stream.
- Accepted detections are saved locally to AI Event Center and remain pending until operator review.
- Verified findings with a matching mission ID are appended to the mission's local history. Unrecognized IDs fail verification.
- Simulation is separate and explicitly marked. No face identification, drone command, or automated pursuit.

## Not yet provided
A deployed inference model/server, direct frame extraction from video_player/HLS/RTSP, authentication tokens for private endpoints, persistent camera endpoint settings, deduplication/tracking, or performance validation on physical Android/Windows devices.

## Validation
Run `flutter analyze`, `flutter test`, and both GitHub Actions build jobs. End-to-end inference must be tested with an authorized HTTPS JPEG source and a model server that implements the JSON contract.
