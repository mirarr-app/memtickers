import 'board_background_style.dart';

class StickerBoard {
  const StickerBoard({
    required this.id,
    required this.name,
    required this.createdAt,
    this.isNavigationMode = false,
    this.backgroundStyle = BoardBackgroundStyle.minimalSurface,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final bool isNavigationMode;
  final BoardBackgroundStyle backgroundStyle;

  StickerBoard copyWith({
    String? name,
    DateTime? createdAt,
    bool? isNavigationMode,
    BoardBackgroundStyle? backgroundStyle,
  }) {
    return StickerBoard(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isNavigationMode: isNavigationMode ?? this.isNavigationMode,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isNavigationMode': isNavigationMode ? 1 : 0,
      'backgroundStyle': backgroundStyle.id,
    };
  }

  factory StickerBoard.fromMap(Map<String, Object?> map) {
    return StickerBoard(
      id: map['id']! as String,
      name: map['name']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']! as int),
      isNavigationMode: (map['isNavigationMode'] as int? ?? 0) == 1,
      backgroundStyle: BoardBackgroundStyle.fromString(
        map['backgroundStyle'] as String?,
      ),
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
          isNavigationMode == other.isNavigationMode &&
          backgroundStyle == other.backgroundStyle;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        createdAt,
        isNavigationMode,
        backgroundStyle,
      );
}
