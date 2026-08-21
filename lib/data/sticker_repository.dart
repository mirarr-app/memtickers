import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'sticker.dart';
import 'sticker_database.dart';
import 'sticker_settings.dart';
import 'sticker_tag.dart';

class StickerRepository extends ChangeNotifier {
  final List<Sticker> _stickers = [];
  final List<StickerTag> _tags = [];
  StickerSettings _settings = const StickerSettings();
  Directory? _imagesDir;

  List<Sticker> get stickers => List.unmodifiable(_stickers);
  List<StickerTag> get tags => List.unmodifiable(_tags);
  StickerSettings get settings => _settings;

  Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    _imagesDir = Directory(p.join(docs.path, 'stickers'));
    if (!await _imagesDir!.exists()) {
      await _imagesDir!.create(recursive: true);
    }
    final db = await StickerDatabase.instance();

    // Load tags
    final tagRows = await db.query('tags', orderBy: 'name COLLATE NOCASE ASC');
    _tags
      ..clear()
      ..addAll(tagRows.map(StickerTag.fromMap));

    // Load sticker-tag relations
    final stickerTagRows = await db.rawQuery('''
      SELECT st.stickerId, t.name as tagName
      FROM sticker_tags st
      INNER JOIN tags t ON st.tagId = t.id
      ORDER BY t.name COLLATE NOCASE ASC
    ''');
    final stickerTagsMap = <String, List<String>>{};
    for (final row in stickerTagRows) {
      final stickerId = row['stickerId'] as String;
      final tagName = row['tagName'] as String;
      stickerTagsMap.putIfAbsent(stickerId, () => []).add(tagName);
    }

    // Load stickers
    final rows = await db.query('stickers', orderBy: 'zIndex ASC');
    _stickers
      ..clear()
      ..addAll(
        rows.map((row) {
          final id = row['id'] as String;
          return Sticker.fromMap(row, tags: stickerTagsMap[id] ?? const []);
        }),
      );

    try {
      final settingsRows = await db.query('settings');
      final settingsMap = <String, dynamic>{};
      for (final row in settingsRows) {
        final key = row['key'] as String;
        final val = double.tryParse(row['value'] as String);
        if (val != null) {
          settingsMap[key] = val;
        }
      }
      _settings = StickerSettings.fromMap(settingsMap);
    } catch (_) {}

    notifyListeners();
  }

  int getStickerCountForTag(String tagName) {
    return _stickers.where((s) => s.tags.contains(tagName)).length;
  }

  Future<StickerTag> createTag(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Tag name cannot be empty');
    }
    final existing = _tags
        .where((t) => t.name.toLowerCase() == trimmed.toLowerCase())
        .firstOrNull;
    if (existing != null) {
      return existing;
    }

    final db = await StickerDatabase.instance();
    final newTag = StickerTag(
      id: const Uuid().v4(),
      name: trimmed,
      createdAt: DateTime.now(),
    );
    await db.insert(
      'tags',
      newTag.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _tags.add(newTag);
    _tags.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
    return newTag;
  }

  Future<void> updateTag(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Tag name cannot be empty');
    }
    final tagIndex = _tags.indexWhere((t) => t.id == id);
    if (tagIndex == -1) return;

    final oldName = _tags[tagIndex].name;
    if (oldName == trimmed) return;

    final db = await StickerDatabase.instance();
    await db.update(
      'tags',
      {'name': trimmed},
      where: 'id = ?',
      whereArgs: [id],
    );

    _tags[tagIndex] = _tags[tagIndex].copyWith(name: trimmed);
    _tags.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // Update in-memory stickers
    for (var i = 0; i < _stickers.length; i++) {
      final sticker = _stickers[i];
      if (sticker.tags.contains(oldName)) {
        final updatedTags = sticker.tags
            .map((t) => t == oldName ? trimmed : t)
            .toList();
        _stickers[i] = sticker.copyWith(tags: updatedTags);
      }
    }

    notifyListeners();
  }

  Future<void> deleteTag(String id) async {
    final tag = _tags.where((t) => t.id == id).firstOrNull;
    if (tag == null) return;

    final db = await StickerDatabase.instance();
    await db.delete('tags', where: 'id = ?', whereArgs: [id]);
    await db.delete('sticker_tags', where: 'tagId = ?', whereArgs: [id]);

    _tags.removeWhere((t) => t.id == id);

    // Update in-memory stickers
    for (var i = 0; i < _stickers.length; i++) {
      final sticker = _stickers[i];
      if (sticker.tags.contains(tag.name)) {
        final updatedTags = sticker.tags.where((t) => t != tag.name).toList();
        _stickers[i] = sticker.copyWith(tags: updatedTags);
      }
    }

    notifyListeners();
  }

  Future<void> updateSettings(StickerSettings newSettings) async {
    _settings = newSettings;
    final db = await StickerDatabase.instance();
    await db.insert('settings', {
      'key': 'saturation',
      'value': newSettings.saturation.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('settings', {
      'key': 'brightness',
      'value': newSettings.brightness.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
  }

  String imagePathFor(String id) {
    final dir = _imagesDir;
    if (dir == null) {
      throw StateError('StickerRepository.init() has not completed.');
    }
    return p.join(dir.path, '$id.png');
  }

  int nextZIndex() {
    if (_stickers.isEmpty) return 0;
    return _stickers.map((s) => s.zIndex).reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<void> save(Sticker sticker) async {
    final db = await StickerDatabase.instance();
    await db.insert(
      'stickers',
      sticker.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Ensure tags in sticker.tags exist in db and link them
    await db.delete(
      'sticker_tags',
      where: 'stickerId = ?',
      whereArgs: [sticker.id],
    );
    final tagNames = sticker.tags;
    final resolvedTags = <String>[];

    for (final name in tagNames) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) continue;
      var tag = _tags
          .where((t) => t.name.toLowerCase() == trimmed.toLowerCase())
          .firstOrNull;
      if (tag == null) {
        tag = StickerTag(
          id: const Uuid().v4(),
          name: trimmed,
          createdAt: DateTime.now(),
        );
        await db.insert(
          'tags',
          tag.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        _tags.add(tag);
      }
      await db.insert('sticker_tags', {
        'stickerId': sticker.id,
        'tagId': tag.id,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      resolvedTags.add(tag.name);
    }
    _tags.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final updatedSticker = sticker.copyWith(tags: resolvedTags);
    final index = _stickers.indexWhere((s) => s.id == sticker.id);
    if (index >= 0) {
      _stickers[index] = updatedSticker;
    } else {
      _stickers.add(updatedSticker);
    }
    notifyListeners();
  }

  Future<void> setStickerTags(
    String stickerId,
    List<String> newTagNames,
  ) async {
    final index = _stickers.indexWhere((s) => s.id == stickerId);
    if (index == -1) return;

    final sticker = _stickers[index];
    final updated = sticker.copyWith(tags: newTagNames);
    await save(updated);
  }

  Future<void> updateTransform(Sticker sticker) async {
    final db = await StickerDatabase.instance();
    await db.update(
      'stickers',
      {
        'x': sticker.x,
        'y': sticker.y,
        'rotation': sticker.rotation,
        'scale': sticker.scale,
        'zIndex': sticker.zIndex,
      },
      where: 'id = ?',
      whereArgs: [sticker.id],
    );
    final index = _stickers.indexWhere((s) => s.id == sticker.id);
    if (index >= 0) {
      _stickers[index] = _stickers[index].copyWith(
        x: sticker.x,
        y: sticker.y,
        rotation: sticker.rotation,
        scale: sticker.scale,
        zIndex: sticker.zIndex,
      );
      notifyListeners();
    }
  }

  Future<void> delete(String id) async {
    final db = await StickerDatabase.instance();
    final existing = _stickers.where((s) => s.id == id).firstOrNull;
    await db.delete('stickers', where: 'id = ?', whereArgs: [id]);
    await db.delete('sticker_tags', where: 'stickerId = ?', whereArgs: [id]);
    _stickers.removeWhere((s) => s.id == id);
    if (existing != null) {
      final file = File(existing.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    notifyListeners();
  }
}
