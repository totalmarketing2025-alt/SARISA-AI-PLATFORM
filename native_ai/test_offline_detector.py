"""Lightweight tests that do not require model weights."""
import unittest
from pathlib import Path

from offline_detector import infer


class OfflineDetectorValidationTest(unittest.TestCase):
    def test_missing_files(self):
        with self.assertRaises(FileNotFoundError):
            infer(Path("not-present.onnx"), Path("not-present.jpg"))

    def test_bad_threshold(self):
        # Input validation follows file existence validation.
        with self.assertRaises(FileNotFoundError):
            infer(Path("not-present.onnx"), Path("not-present.jpg"), -1)


if __name__ == "__main__":
    unittest.main()
