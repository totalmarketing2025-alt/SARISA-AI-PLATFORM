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
];
