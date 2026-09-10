import 'dart:convert';

class BackupMetadata {
  const BackupMetadata({
    required this.version,
    required this.createdAt,
    required this.stickerCount,
    required this.boardCount,
    this.appVersion = '1.2.0',
  });

  final int version;
  final DateTime createdAt;
  final int stickerCount;
  final int boardCount;
  final String appVersion;

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'createdAt': createdAt.toIso8601String(),
      'stickerCount': stickerCount,
      'boardCount': boardCount,
      'appVersion': appVersion,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory BackupMetadata.fromMap(Map<String, dynamic> map) {
    return BackupMetadata(
      version: (map['version'] as num?)?.toInt() ?? 1,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      stickerCount: (map['stickerCount'] as num?)?.toInt() ?? 0,
      boardCount: (map['boardCount'] as num?)?.toInt() ?? 0,
      appVersion: (map['appVersion'] as String?) ?? '1.0.0',
    );
  }

  factory BackupMetadata.fromJson(String jsonStr) {
    return BackupMetadata.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
  }
}
