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

/// Empty until verified model binaries and licenses are selected.
const approvedNativeModels = <NativeModelArtifact>[];
