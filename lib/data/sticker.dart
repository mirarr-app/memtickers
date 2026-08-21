class Sticker {
  const Sticker({
    required this.id,
    this.boardId = 'default',
    required this.imagePath,
    required this.createdAt,
    required this.x,
    required this.y,
    required this.rotation,
    required this.scale,
    required this.zIndex,
    this.latitude,
    this.longitude,
    this.placeLabel,
    this.tags = const [],
  });

  final String id;
  final String boardId;
  final String imagePath;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final String? placeLabel;
  final double x;
  final double y;
  final double rotation;
  final double scale;
  final int zIndex;
  final List<String> tags;

  Sticker copyWith({
    String? boardId,
    String? imagePath,
    DateTime? createdAt,
    double? latitude,
    double? longitude,
    String? placeLabel,
    double? x,
    double? y,
    double? rotation,
    double? scale,
    int? zIndex,
    List<String>? tags,
    bool clearLocation = false,
  }) {
    return Sticker(
      id: id,
      boardId: boardId ?? this.boardId,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      placeLabel: clearLocation ? null : (placeLabel ?? this.placeLabel),
      x: x ?? this.x,
      y: y ?? this.y,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      zIndex: zIndex ?? this.zIndex,
      tags: tags ?? this.tags,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'boardId': boardId,
      'imagePath': imagePath,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'latitude': latitude,
      'longitude': longitude,
      'placeLabel': placeLabel,
      'x': x,
      'y': y,
      'rotation': rotation,
      'scale': scale,
      'zIndex': zIndex,
    };
  }

  factory Sticker.fromMap(
    Map<String, Object?> map, {
    List<String> tags = const [],
  }) {
    return Sticker(
      id: map['id']! as String,
      boardId: (map['boardId'] as String?) ?? 'default',
      imagePath: map['imagePath']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']! as int),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      placeLabel: map['placeLabel'] as String?,
      x: (map['x']! as num).toDouble(),
      y: (map['y']! as num).toDouble(),
      rotation: (map['rotation']! as num).toDouble(),
      scale: (map['scale']! as num).toDouble(),
      zIndex: map['zIndex']! as int,
      tags: tags,
    );
  }
}
