"""Offline plate OCR policy and crop-routing tests."""
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import numpy as np
import cv2

from offline_ocr import OfflinePlateOcr, normalize_plate, plate_shaped


class FakeOcr:
    def __init__(self):
        self.calls = 0

    def __call__(self, crop):
        self.calls += 1
        return SimpleNamespace(txts=["SK 1234 AB", "random sign"], scores=[0.91, 0.99])


class OfflinePlateOcrTest(unittest.TestCase):
    def test_macedonian_plate_normalization_and_shape_filter(self):
        self.assertEqual(normalize_plate("NMK-SK 1234 AB"), "NMKSK1234AB")
        self.assertTrue(plate_shaped("SK 1234 AB"))
        self.assertTrue(plate_shaped("NMK-SK 1234 AB"))
        self.assertFalse(plate_shaped("SEARCH AND RESCUE"))

    def test_ocr_runs_only_on_vehicle_crops_and_marks_manual_review(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("ocr_det.onnx", "ocr_rec_latin.onnx", "ppocrv5_latin_dict.txt"):
                (root / name).touch()
            engine = FakeOcr()
            pipeline = OfflinePlateOcr(root, engine=engine)
            detections = [
                {"category": "person", "box": [0.1, 0.1, 0.2, 0.5]},
                {"category": "vehicle", "box": [0.2, 0.2, 0.5, 0.5]},
            ]
            with patch("offline_ocr.cv2.imread", return_value=np.zeros((100, 120, 3), dtype=np.uint8)):
                candidates = pipeline.read_vehicle_candidates(root / "frame.jpg", detections)

        self.assertEqual(engine.calls, 1)
        self.assertEqual(candidates, [{
            "detection_index": 1,
            "text": "SK1234AB",
            "confidence": 0.91,
            "operator_review_required": True,
            "source": "local_vehicle_crop",
        }])

    def test_missing_models_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(FileNotFoundError):
                OfflinePlateOcr(Path(directory), engine=FakeOcr())

    def test_packaged_ocr_models_run_on_cpu_without_network_fallback(self):
        model_dir = Path(__file__).resolve().parents[1] / "assets" / "models"
        pipeline = OfflinePlateOcr(model_dir)
        with tempfile.TemporaryDirectory() as directory:
            image_path = Path(directory) / "blank.jpg"
            self.assertTrue(cv2.imwrite(str(image_path), np.zeros((128, 256, 3), dtype=np.uint8)))
            result = pipeline.read_vehicle_candidates(image_path, [
                {"category": "vehicle", "box": [0.1, 0.1, 0.8, 0.8]},
            ])
        self.assertEqual(result, [])


if __name__ == "__main__":
    unittest.main()
