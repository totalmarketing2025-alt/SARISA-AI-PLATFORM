"""Offline video sampling tests; inference is mocked to avoid model weights."""
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import numpy as np

from offline_video import AnonymousObjectTracker, analyze_video


class FakeCapture:
    def __init__(self, frame_count=20, fps=10.0, opened=True):
        self.frame_count = frame_count
        self.fps = fps
        self.opened = opened
        self.read_count = 0
        self.released = False

    def isOpened(self):
        return self.opened

    def get(self, prop):
        return self.fps

    def read(self):
        if self.read_count >= self.frame_count:
            return False, None
        self.read_count += 1
        return True, np.zeros((8, 8, 3), dtype=np.uint8)

    def release(self):
        self.released = True


class OfflineVideoTest(unittest.TestCase):
    def test_tracker_associates_objects_but_never_people(self):
        tracker = AnonymousObjectTracker()
        def detection(category, label, x):
            return {"category": category, "label": label,
                    "box": [x, 0.2, 0.2, 0.2], "confidence": 0.9}

        first = tracker.update([
            detection("person", "person", 0.1),
            detection("vehicle", "car", 0.3),
        ])
        second = tracker.update([
            detection("person", "person", 0.12),
            detection("vehicle", "car", 0.32),
        ])
        self.assertEqual(len(first), 1)
        self.assertEqual(len(second), 1)
        self.assertEqual(first[0]["track_id"], second[0]["track_id"])
        self.assertEqual(first[0]["category"], "vehicle")

    def test_tracker_drops_expired_tracks_and_rejects_bad_settings(self):
        tracker = AnonymousObjectTracker(max_missed_frames=0)
        detection = {"category": "object", "label": "backpack",
                     "box": [0.2, 0.2, 0.2, 0.2]}
        first = tracker.update([detection])[0]["track_id"]
        tracker.update([])
        second = tracker.update([detection])[0]["track_id"]
        self.assertNotEqual(first, second)
        with self.assertRaises(ValueError):
            AnonymousObjectTracker(iou_threshold=0)

    def test_sampling_interval_and_frame_limit_are_enforced(self):
        with tempfile.TemporaryDirectory() as directory:
            video = Path(directory) / "authorized-local-video.mp4"
            video.touch()
            capture = FakeCapture(frame_count=20)
            with patch("offline_video.cv2.VideoCapture", return_value=capture), \
                    patch("offline_video.infer", return_value={
                        "detections": [], "offline": True,
                    }) as inference:
                results = list(analyze_video(
                    Path(directory) / "model.onnx", video,
                    every_seconds=0.2, max_frames=3,
                ))

        self.assertEqual([item["time_seconds"] for item in results],
                         [0.0, 0.2, 0.4])
        self.assertTrue(all(item["offline"] for item in results))
        self.assertTrue(all("tracks" in item for item in results))
        self.assertEqual(inference.call_count, 3)
        self.assertTrue(capture.released)

    def test_invalid_sampling_settings_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            video = Path(directory) / "video.mp4"
            video.touch()
            for interval, frame_limit in ((0, 1), (1, 0), (1, 10001)):
                with self.subTest(interval=interval, frame_limit=frame_limit):
                    with self.assertRaises(ValueError):
                        list(analyze_video(Path("model.onnx"), video,
                                           interval, frame_limit))

    def test_unsupported_video_codec_releases_capture(self):
        with tempfile.TemporaryDirectory() as directory:
            video = Path(directory) / "video.mp4"
            video.touch()
            capture = FakeCapture(opened=False)
            with patch("offline_video.cv2.VideoCapture", return_value=capture):
                with self.assertRaisesRegex(ValueError, "Video codec unsupported"):
                    list(analyze_video(Path("model.onnx"), video))
        self.assertTrue(capture.released)


if __name__ == "__main__":
    unittest.main()
