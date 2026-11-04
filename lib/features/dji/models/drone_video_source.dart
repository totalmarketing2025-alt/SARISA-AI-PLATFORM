enum DroneConnectionStatus {
  offline,
  connecting,
  connected,
  streaming,
  error,
}

class DroneVideoSource {
  final String id;
  final String modelId;
  final String displayName;
  final DroneConnectionStatus status;
  final bool enabled;
  final String? streamUrl;

  const DroneVideoSource({
    required this.id,
    required this.modelId,
    required this.displayName,
    this.status = DroneConnectionStatus.offline,
    this.enabled = true,
    this.streamUrl,
  });

  DroneVideoSource copyWith({
    DroneConnectionStatus? status,
    bool? enabled,
    String? streamUrl,
    bool clearStreamUrl = false,
  }) {
    return DroneVideoSource(
      id: id,
      modelId: modelId,
      displayName: displayName,
      status: status ?? this.status,
      enabled: enabled ?? this.enabled,
      streamUrl: clearStreamUrl ? null : streamUrl ?? this.streamUrl,
    );
  }
}
