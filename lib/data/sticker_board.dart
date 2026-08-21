class StickerBoard {
  const StickerBoard({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  StickerBoard copyWith({String? name, DateTime? createdAt}) {
    return StickerBoard(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory StickerBoard.fromMap(Map<String, Object?> map) {
    return StickerBoard(
      id: map['id']! as String,
      name: map['name']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']! as int),
    );
  }
}
