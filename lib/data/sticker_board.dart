class StickerBoard {
  const StickerBoard({
    required this.id,
    required this.name,
    required this.createdAt,
    this.isNavigationMode = false,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final bool isNavigationMode;

  StickerBoard copyWith({
    String? name,
    DateTime? createdAt,
    bool? isNavigationMode,
  }) {
    return StickerBoard(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isNavigationMode: isNavigationMode ?? this.isNavigationMode,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isNavigationMode': isNavigationMode ? 1 : 0,
    };
  }

  factory StickerBoard.fromMap(Map<String, Object?> map) {
    return StickerBoard(
      id: map['id']! as String,
      name: map['name']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']! as int),
      isNavigationMode: (map['isNavigationMode'] as int? ?? 0) == 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StickerBoard &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          createdAt == other.createdAt &&
          isNavigationMode == other.isNavigationMode;

  @override
  int get hashCode => Object.hash(id, name, createdAt, isNavigationMode);
}
