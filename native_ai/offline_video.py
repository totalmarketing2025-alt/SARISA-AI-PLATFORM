"""Offline video frame sampling using the local ONNX detector."""
import argparse
import json
from pathlib import Path
from tempfile import TemporaryDirectory

import cv2
from PIL import Image

from offline_detector import infer


class AnonymousObjectTracker:
    """Greedy IoU association for vehicles/animals/objects; people are omitted."""
    def __init__(self, iou_threshold: float = 0.25, max_missed_frames: int = 2):
        if not 0 < iou_threshold <= 1 or not 0 <= max_missed_frames <= 30:
            raise ValueError("Invalid tracking configuration")
        self.iou_threshold = iou_threshold
        self.max_missed_frames = max_missed_frames
        self.frame = 0
        self.next_id = 1
        self.tracks = {}

    @staticmethod
    def _iou(a, b):
        ax, ay, aw, ah = a["box"]
        bx, by, bw, bh = b["box"]
        left, top = max(ax, bx), max(ay, by)
        right, bottom = min(ax + aw, bx + bw), min(ay + ah, by + bh)
        intersection = max(0.0, right - left) * max(0.0, bottom - top)
        union = aw * ah + bw * bh - intersection
        return intersection / union if union > 0 else 0.0

    def update(self, detections):
        self.frame += 1
        eligible = [(index, item) for index, item in enumerate(detections)
                    if item.get("category") != "person"]
        pairs = []
        for track_id, track in self.tracks.items():
            for index, item in eligible:
                if item.get("label") != track["detection"].get("label"):
                    continue
                overlap = self._iou(track["detection"], item)
                if overlap >= self.iou_threshold:
                    pairs.append((overlap, track_id, index))
        pairs.sort(reverse=True)
        used_tracks, used_detections, assigned = set(), set(), {}
        for _, track_id, index in pairs:
            if track_id in used_tracks or index in used_detections:
                continue
            used_tracks.add(track_id)
            used_detections.add(index)
            assigned[index] = track_id

        updated, output = {}, []
        for index, item in eligible:
            track_id = assigned.get(index)
            if track_id is None:
                track_id = f"T{self.next_id}"
                self.next_id += 1
            copy = dict(item)
            copy["track_id"] = track_id
            updated[track_id] = {"detection": copy, "last_frame": self.frame}
            output.append(copy)
        for track_id, track in self.tracks.items():
            if (track_id not in updated and
                    self.frame - track["last_frame"] <= self.max_missed_frames):
                updated[track_id] = track
        self.tracks = updated
        return output


def analyze_video(model: Path, video: Path, every_seconds: float = 1.0,
                  max_frames: int = 300, plate_ocr=None):
    if not video.is_file():
        raise FileNotFoundError("Video file missing")
    if every_seconds <= 0 or max_frames < 1 or max_frames > 10000:
        raise ValueError("Invalid sampling configuration")
    cap = cv2.VideoCapture(str(video))
    if not cap.isOpened():
        cap.release()
        raise ValueError("Video codec unsupported")
    fps = cap.get(cv2.CAP_PROP_FPS)
    if fps <= 0 or fps > 1000:
        cap.release()
        raise ValueError("Invalid video frame rate")
    stride = max(1, round(fps * every_seconds))
    frame_index = 0
    processed = 0
    tracker = AnonymousObjectTracker()
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
                    tracks = tracker.update(result["detections"])
                    plates = (plate_ocr.read_vehicle_candidates(
                        frame_file, result["detections"]) if plate_ocr else [])
                    yield {"time_seconds": round(frame_index / fps, 3),
                           "detections": result["detections"], "tracks": tracks,
                           "plate_candidates": plates,
                           "offline": True}
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
    parser.add_argument("--ocr", action="store_true",
                        help="Run local PP-OCRv5 against detected vehicle crops")
    parser.add_argument("--ocr-model-dir", type=Path, default=Path("assets/models"))
    args = parser.parse_args()
    if args.ocr:
        from offline_ocr import OfflinePlateOcr
        plate_ocr = OfflinePlateOcr(args.ocr_model_dir)
    else:
        plate_ocr = None
    for result in analyze_video(args.model, args.video,
                                args.every_seconds, args.max_frames, plate_ocr):
        print(json.dumps(result), flush=True)


if __name__ == "__main__":
    main()
