"""Offline YOLO/ONNX detector tests, including a tiny executable ONNX fixture."""
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

import numpy as np
import onnx
from onnx import TensorProto, helper, numpy_helper
from PIL import Image

from offline_detector import COCO_LABELS, infer

PACKAGED_YOLOX_NANO = Path(__file__).parent.parent / "assets" / "models" / "yolox_nano.onnx"


def make_smoke_model(path: Path) -> None:
    """Write a tiny valid ONNX graph with fixed YOLO-shaped test detections.

    The graph consumes the image and adds its zero-scaled mean to two fixed
    80-class detections. It exercises ONNX Runtime, tensor loading, output
    validation, letterbox reversal, class mapping and NMS without model weights.
    """
    detections = np.zeros((1, 84, 2), dtype=np.float32)
    detections[0, :4, 0] = [32, 32, 20, 20]
    detections[0, 4 + 0, 0] = 0.95  # person presence only
    detections[0, :4, 1] = [32, 32, 20, 20]
    detections[0, 4 + 2, 1] = 0.90  # car -> vehicle

    image_input = helper.make_tensor_value_info(
        "images", TensorProto.FLOAT, [1, 3, 64, 64]
    )
    output = helper.make_tensor_value_info(
        "detections", TensorProto.FLOAT, [1, 84, 2]
    )
    zero = numpy_helper.from_array(np.array(0.0, dtype=np.float32), name="zero")
    fixed = numpy_helper.from_array(detections, name="fixed_detections")
    graph = helper.make_graph(
        [
            helper.make_node(
                "ReduceMean", ["images"], ["image_mean"],
                axes=[0, 1, 2, 3], keepdims=0,
            ),
            helper.make_node("Mul", ["image_mean", "zero"], ["zero_mean"]),
            helper.make_node(
                "Add", ["zero_mean", "fixed_detections"], ["detections"]
            ),
        ],
        "sarisa_onnx_smoke",
        [image_input],
        [output],
        [zero, fixed],
    )
    model = helper.make_model(
        graph, producer_name="sarisa-ci-smoke",
        opset_imports=[helper.make_opsetid("", 11)],
    )
    model.ir_version = 7
    onnx.checker.check_model(model)
    onnx.save(model, path)


def make_yolox_model(path: Path) -> None:
    """Create an executable raw YOLOX [1, 84, 85] ONNX test model."""
    detections = np.zeros((1, 84, 85), dtype=np.float32)
    for anchor, class_id, score in ((0, 0, 0.95), (1, 7, 0.90), (2, 16, 0.85)):
        detections[0, anchor, :5] = [3.5 - anchor, 3.5, np.log(2),
                                     np.log(2), 1.0]
        detections[0, anchor, 5 + class_id] = score

    image_input = helper.make_tensor_value_info(
        "images", TensorProto.FLOAT, [1, 3, 64, 64]
    )
    output = helper.make_tensor_value_info(
        "detections", TensorProto.FLOAT, [1, 84, 85]
    )
    zero = numpy_helper.from_array(np.array(0.0, dtype=np.float32), name="zero")
    fixed = numpy_helper.from_array(detections, name="fixed_detections")
    graph = helper.make_graph(
        [
            helper.make_node("ReduceMean", ["images"], ["image_mean"],
                             axes=[0, 1, 2, 3], keepdims=0),
            helper.make_node("Mul", ["image_mean", "zero"], ["zero_mean"]),
            helper.make_node("Add", ["zero_mean", "fixed_detections"],
                             ["detections"]),
        ],
        "sarisa_yolox_smoke", [image_input], [output], [zero, fixed],
    )
    model = helper.make_model(
        graph, producer_name="sarisa-yolox-ci",
        opset_imports=[helper.make_opsetid("", 11)],
    )
    model.ir_version = 7
    onnx.checker.check_model(model)
    onnx.save(model, path)


class OfflineDetectorValidationTest(unittest.TestCase):
    def test_missing_files(self):
        with self.assertRaises(FileNotFoundError):
            infer(Path("not-present.onnx"), Path("not-present.jpg"))

    def test_bad_threshold_is_rejected_after_paths_exist(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            model = root / "model.onnx"
            model.touch()
            image = root / "image.jpg"
            Image.new("RGB", (16, 16)).save(image)
            for threshold in (0, -0.1, 1.01, float("nan")):
                with self.subTest(threshold=threshold):
                    with self.assertRaises(ValueError):
                        infer(model, image, threshold)

    def test_cpu_onnx_model_runs_and_returns_bounded_normalized_detections(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            model = root / "smoke.onnx"
            image = root / "sample.jpg"
            make_smoke_model(model)
            Image.new("RGB", (100, 50), color=(120, 100, 80)).save(image)

            result = infer(model, image, confidence=0.5, model_format="yolov8")

        self.assertTrue(result["offline"])
        self.assertEqual(result["model"], "smoke.onnx")
        self.assertEqual([item["category"] for item in result["detections"]],
                         ["person", "vehicle"])
        self.assertEqual([item["label"] for item in result["detections"]],
                         ["person", "car"])
        for detection in result["detections"]:
            self.assertGreaterEqual(detection["confidence"], 0.5)
            self.assertLessEqual(detection["confidence"], 1.0)
            x, y, width, height = detection["box"]
            self.assertTrue(all(0 <= value <= 1 for value in
                                (x, y, width, height)))
            self.assertLessEqual(x + width, 1.001)
            self.assertLessEqual(y + height, 1.001)

    def test_yolox_decoder_maps_person_truck_and_animal_labels(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            model = root / "yolox.onnx"
            image = root / "sample.jpg"
            make_yolox_model(model)
            Image.new("RGB", (64, 64), color=(120, 100, 80)).save(image)

            result = infer(model, image, confidence=0.5)

        detections = result["detections"]
        self.assertEqual(
            [(item["category"], item["label"]) for item in detections],
            [("person", "person"), ("vehicle", "truck"), ("animal", "dog")],
        )
        self.assertEqual([item["class_id"] for item in detections], [0, 7, 16])
        self.assertTrue(all(item["confidence"] >= 0.5 for item in detections))
        self.assertTrue(all(item["box"] == [0.3125, 0.3125, 0.25, 0.25]
                            for item in detections))

    def test_packaged_yolox_nano_runs_offline_with_real_weights(self):
        self.assertTrue(PACKAGED_YOLOX_NANO.is_file())
        self.assertEqual(PACKAGED_YOLOX_NANO.stat().st_size, 3659407)
        manifest = json.loads((PACKAGED_YOLOX_NANO.parent / "manifest.json").read_text())
        artifact = manifest["models"][0]
        self.assertEqual(artifact["file"], PACKAGED_YOLOX_NANO.name)
        self.assertEqual(hashlib.sha256(PACKAGED_YOLOX_NANO.read_bytes()).hexdigest(),
                         artifact["sha256"])
        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "blank.jpg"
            Image.new("RGB", (320, 240), color=(120, 100, 80)).save(image)
            result = infer(PACKAGED_YOLOX_NANO, image, confidence=0.25)

        self.assertTrue(result["offline"])
        self.assertEqual(result["model"], "yolox_nano.onnx")
        self.assertLessEqual(len(result["detections"]), 100)
        for item in result["detections"]:
            self.assertIn(item["category"], {"person", "vehicle", "animal", "object"})
            self.assertIn(item["label"], COCO_LABELS)
            self.assertIn(item["class_id"], range(80))


if __name__ == "__main__":
    unittest.main()
