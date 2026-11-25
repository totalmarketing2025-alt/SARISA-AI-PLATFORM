"""Fetch the pinned model for a release build and verify it before use."""
import hashlib
import json
from pathlib import Path
from urllib.request import urlopen


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets" / "models" / "manifest.json"


def fetch():
    entries = json.loads(MANIFEST.read_text(encoding="utf-8"))["models"]
    for artifact in entries:
        filename = artifact["file"]
        if Path(filename).name != filename or not filename.endswith(".onnx"):
            raise ValueError("Unsafe model filename in manifest")
        target = MANIFEST.parent / filename
        expected_sha = artifact["sha256"].lower()
        if target.is_file():
            actual_sha = hashlib.sha256(target.read_bytes()).hexdigest()
            if actual_sha == expected_sha:
                print(f"Verified existing model {target.name}")
                continue
        temporary = target.with_suffix(target.suffix + ".download")
        try:
            digest = hashlib.sha256()
            size = 0
            with urlopen(artifact["source"], timeout=90) as response, temporary.open("wb") as out:
                while chunk := response.read(1024 * 1024):
                    size += len(chunk)
                    digest.update(chunk)
                    out.write(chunk)
            if size != artifact["bytes"]:
                raise ValueError(f"Model size mismatch: expected {artifact['bytes']}, got {size}")
            if digest.hexdigest() != expected_sha:
                raise ValueError("Model SHA-256 does not match the pinned manifest")
            temporary.replace(target)
            print(f"Downloaded and verified {target.name} ({size} bytes)")
        finally:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    fetch()
