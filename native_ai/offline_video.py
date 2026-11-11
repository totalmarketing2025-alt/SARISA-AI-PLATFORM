"""Offline video frame sampling using the local ONNX detector."""
import argparse
import json
from pathlib import Path
from tempfile import TemporaryDirectory

import cv2
from PIL import Image

from offline_detector import infer


def analyze_video(model: Path, video: Path, every_seconds: float = 1.0,
                  max_frames: int = 300):
    if not video.is_file():
        raise FileNotFoundError("Video file missing")
    if every_seconds <= 0 or max_frames < 1 or max_frames > 10000:
        raise ValueError("Invalid sampling configuration")
    cap = cv2.VideoCapture(str(video))
    if not cap.isOpened():
        raise ValueError("Video codec unsupported")
    fps = cap.get(cv2.CAP_PROP_FPS)
    if fps <= 0 or fps > 1000:
        cap.release()
        raise ValueError("Invalid video frame rate")
    stride = max(1, round(fps * every_seconds))
    frame_index = 0
    processed = 0
    with TemporaryDirectory() as temp:
        frame_file = Path(temp) / "frame.jpg"
        try:
            while processed < max_frames:
                ok, frame = cap.read()
                if not ok:
                    break
                if frame_index % stride == 0:
                    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                    Image.fromarray(rgb).save(frame_file, format="JPEG", quality=90)
                    result = infer(model, frame_file)
                    yield {"time_seconds": round(frame_index / fps, 3),
                           "detections": result["detections"], "offline": True}
                    processed += 1
                frame_index += 1
        finally:
            cap.release()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--video", type=Path, required=True)
    parser.add_argument("--every-seconds", type=float, default=1.0)
    parser.add_argument("--max-frames", type=int, default=300)
    args = parser.parse_args()
    for result in analyze_video(args.model, args.video,
                                args.every_seconds, args.max_frames):
        print(json.dumps(result), flush=True)


if __name__ == "__main__":
    main()
