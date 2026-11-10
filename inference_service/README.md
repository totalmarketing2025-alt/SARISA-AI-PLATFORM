# SARISA Phase 11 — deployable object detection

This is a **real** YOLO object-detection service, not the simulated detector. It recognizes generic persons, vehicles and objects; it does not identify individuals or perform biometric matching. The model weights are downloaded by Ultralytics on first startup, so internet access and acceptance of the model's license are required. Hazard detection is not implemented.

## Local start
Use Python 3.11+ in a virtual environment:

```bash
pip install -r inference_service/requirements.txt
uvicorn inference_service.app:app --host 127.0.0.1 --port 8000
```

The Flutter application requires an **HTTPS** endpoint. Deploy behind a TLS reverse proxy and use access controls; do not expose the unauthenticated service to the public internet. Configure a trusted HTTPS JPEG snapshot camera URL and `https://YOUR-HOST/detect` in SARISA AI Analysis. For now the Flutter client does not support auth headers; use a private gateway/network with TLS and restrict access. The camera must return a standalone JPEG snapshot, not RTSP/HLS.

Verify with an authorized test JPEG:
```bash
curl -X POST -H 'Content-Type: image/jpeg' --data-binary @frame.jpg http://127.0.0.1:8000/detect
```

The response uses `{"detections":[{"category":"person","confidence":0.9,"box":[0.1,0.2,0.3,0.4]}]}` with normalized x,y,width,height. A camera-to-video frame bridge, production authentication, benchmarking, Android/Windows end-to-end validation, and hazard-specific training are still outstanding. This service runs on a separate machine, not embedded in Flutter.
