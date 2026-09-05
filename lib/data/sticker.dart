import 'package:flutter/foundation.dart';

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
    this.modelTags = const [],
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
  final List<String> modelTags;

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
    List<String>? modelTags,
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
      modelTags: modelTags ?? this.modelTags,
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
    List<String> modelTags = const [],
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
      modelTags: modelTags,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sticker &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          boardId == other.boardId &&
          imagePath == other.imagePath &&
          createdAt == other.createdAt &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          placeLabel == other.placeLabel &&
          x == other.x &&
          y == other.y &&
          rotation == other.rotation &&
          scale == other.scale &&
          zIndex == other.zIndex &&
          listEquals(tags, other.tags) &&
          listEquals(modelTags, other.modelTags);

  @override
  int get hashCode => Object.hash(
        id,
        boardId,
        imagePath,
        createdAt,
        latitude,
        longitude,
        placeLabel,
        x,
        y,
        rotation,
        scale,
        zIndex,
        Object.hashAll(tags),
        Object.hashAll(modelTags),
      );
}
