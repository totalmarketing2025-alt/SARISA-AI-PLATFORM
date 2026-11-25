"""Offline, operator-reviewed plate text candidates from detected vehicles."""
import argparse
import math
import re
from pathlib import Path

import cv2
from rapidocr import EngineType, LangDet, LangRec, OCRVersion, RapidOCR


_PLATE = re.compile(r"^(?:NMK|MK)?[A-Z]{2}[0-9]{3,4}[A-Z]{2,3}$")


def normalize_plate(text: str) -> str:
    return re.sub(r"[^A-Z0-9]", "", text.upper())


def plate_shaped(text: str) -> bool:
    return bool(_PLATE.fullmatch(normalize_plate(text)))


class OfflinePlateOcr:
    """Runs PP-OCRv5 ONNX on local vehicle crops; makes no registry requests."""
    def __init__(self, model_dir: Path, engine=None):
        self.model_dir = Path(model_dir)
        self.detector = self.model_dir / "ocr_det.onnx"
        self.recognizer = self.model_dir / "ocr_rec_latin.onnx"
        self.dictionary = self.model_dir / "ppocrv5_latin_dict.txt"
        if not all(path.is_file() for path in
                   (self.detector, self.recognizer, self.dictionary)):
            raise FileNotFoundError("Pinned local PP-OCRv5 artifacts are missing")
        # Both model paths and the character dictionary are local. Disable the
        # angle classifier so this pipeline never tries to fetch another model.
        self.engine = engine or RapidOCR(params={
            "Det.model_path": str(self.detector),
            "Det.engine_type": EngineType.ONNXRUNTIME,
            "Det.ocr_version": OCRVersion.PPOCRV5,
            "Det.lang_type": LangDet.CH,
            "Rec.model_path": str(self.recognizer),
            "Rec.engine_type": EngineType.ONNXRUNTIME,
            "Rec.ocr_version": OCRVersion.PPOCRV5,
            "Rec.lang_type": LangRec.LATIN,
            "Rec.rec_keys_path": str(self.dictionary),
            "Global.use_cls": False,
        })

    def read_vehicle_candidates(self, image_path: Path, detections):
        image = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
        if image is None:
            raise ValueError("Could not decode local image for OCR")
        height, width = image.shape[:2]
        if height * width > 16_000_000:
            raise ValueError("Image exceeds 16 megapixel safety limit")
        output = []
        for detection_index, item in enumerate(detections):
            if item.get("category") != "vehicle":
                continue
            box = item.get("box")
            if not isinstance(box, (list, tuple)) or len(box) != 4:
                continue
            x, y, w, h = box
            if not all(isinstance(value, (int, float)) and math.isfinite(value)
                       for value in box) or w <= 0 or h <= 0:
                continue
            left = max(0, min(width - 1, int(x * width)))
            top = max(0, min(height - 1, int(y * height)))
            right = max(left + 1, min(width, int(math.ceil((x + w) * width))))
            bottom = max(top + 1, min(height, int(math.ceil((y + h) * height))))
            crop = image[top:bottom, left:right]
            if crop.size == 0:
                continue
            result = self.engine(crop)
            if result is None:
                continue
            texts = getattr(result, "txts", None)
            scores = getattr(result, "scores", None)
            if texts is None or scores is None:
                continue
            for text, score in zip(texts, scores):
                normalized = normalize_plate(str(text))
                score = float(score)
                if plate_shaped(normalized) and math.isfinite(score) and 0 <= score <= 1:
                    output.append({
                        "detection_index": detection_index,
                        "text": normalized,
                        "confidence": round(score, 4),
                        "operator_review_required": True,
                        "source": "local_vehicle_crop",
                    })
        return output


def main():
    parser = argparse.ArgumentParser(
        description="Run local PP-OCRv5 against YOLO vehicle crops; review every result.")
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--model-dir", type=Path, default=Path("assets/models"))
    parser.add_argument("--detections-json", type=Path, required=True,
                        help="JSON array of normalized YOLO detections for this image")
    args = parser.parse_args()
    import json
    detections = json.loads(args.detections_json.read_text(encoding="utf-8"))
    if not isinstance(detections, list):
        raise ValueError("Detections file must contain a JSON array")
    ocr = OfflinePlateOcr(args.model_dir)
    print(json.dumps({
        "offline": True,
        "operator_review_required": True,
        "candidates": ocr.read_vehicle_candidates(args.image, detections),
    }))


if __name__ == "__main__":
    main()
