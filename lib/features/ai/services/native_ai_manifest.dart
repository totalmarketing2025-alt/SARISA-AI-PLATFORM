/// Describes offline model artifacts without downloading or executing them.
/// Model packages must be license-reviewed and integrity-checked before use.
enum NativeModelRole { objectDetection, vehicleSimilarity, plateDetection, plateOcr }

class NativeModelArtifact {
  final NativeModelRole role;
  final String filename;
  final String sha256;
  final String licenseId;
  final String version;

  const NativeModelArtifact({
    required this.role,
    required this.filename,
    required this.sha256,
    required this.licenseId,
    required this.version,
  });

  bool get hasValidDigest =>
      RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256);
  bool get hasMetadata => filename.endsWith('.onnx') &&
      !filename.contains('/') && !filename.contains('\\') &&
      licenseId.trim().isNotEmpty && version.trim().isNotEmpty;
}

/// Only assets with a pinned source, digest and license are listed here.
const approvedNativeModels = <NativeModelArtifact>[
  NativeModelArtifact(
    role: NativeModelRole.objectDetection,
    filename: 'yolox_nano.onnx',
    sha256: 'c789161ed43c8269fcd4e67c67eeeb4e80c622da2eb296a20bc6007bd18a0b7d',
    licenseId: 'Apache-2.0',
    version: 'YOLOX-Nano COCO-80 0.1.1rc0',
  ),
  NativeModelArtifact(
    role: NativeModelRole.plateDetection,
    filename: 'ocr_det.onnx',
    sha256: 'd7fe3ea74652890722c0f4d02458b7261d9f5ae6c92904d05707c9eb155c7924',
    licenseId: 'Apache-2.0',
    version: 'PP-OCRv5 mobile text detector v1',
  ),
  NativeModelArtifact(
    role: NativeModelRole.plateOcr,
    filename: 'ocr_rec_latin.onnx',
    sha256: '995b0f5f28d2073896a78c03b5b863eae6af3744bafa0245b8522beea6994927',
    licenseId: 'Apache-2.0',
    version: 'PP-OCRv5 Latin mobile recognizer v1',
  ),
];
