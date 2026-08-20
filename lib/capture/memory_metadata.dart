class MemoryMetadata {
  const MemoryMetadata({
    required this.capturedAt,
    this.latitude,
    this.longitude,
    this.placeLabel,
  });

  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;
  final String? placeLabel;

  MemoryMetadata copyWith({String? placeLabel}) {
    return MemoryMetadata(
      capturedAt: capturedAt,
      latitude: latitude,
      longitude: longitude,
      placeLabel: placeLabel ?? this.placeLabel,
    );
  }
}
