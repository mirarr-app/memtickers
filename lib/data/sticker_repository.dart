import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../capture/auto_tag_service.dart';
import '../theme/app_haptics.dart';
import 'sticker.dart';
import 'sticker_board.dart';
import 'sticker_database.dart';
import 'sticker_settings.dart';
import 'sticker_tag.dart';

class StickerRepository extends ChangeNotifier {
  final List<Sticker> _stickers = [];
  final List<StickerTag> _tags = [];
  final List<StickerBoard> _boards = [];
  String _activeBoardId = 'default';
  StickerSettings _settings = const StickerSettings();
  Directory? _imagesDir;

  bool _isTestMode = false;

  List<Sticker> get stickers =>
      List.unmodifiable(_stickers.where((s) => s.boardId == _activeBoardId));
  List<Sticker> get allStickers => List.unmodifiable(_stickers);
  List<StickerTag> get tags => List.unmodifiable(_tags);
  List<StickerBoard> get boards => List.unmodifiable(_boards);
  String get activeBoardId => _activeBoardId;

  StickerBoard get activeBoard {
    return _boards.firstWhere(
      (b) => b.id == _activeBoardId,
      orElse: () => _boards.isNotEmpty
          ? _boards.first
          : StickerBoard(
              id: 'default',
              name: 'Main Board',
              createdAt: DateTime.now(),
            ),
    );
  }

  StickerSettings get settings => _settings;

  Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    _imagesDir = Directory(p.join(docs.path, 'stickers'));
    if (!await _imagesDir!.exists()) {
      await _imagesDir!.create(recursive: true);
    }
    final db = await StickerDatabase.instance();

    // Load boards
    final boardRows = await db.query('boards', orderBy: 'createdAt ASC');
    _boards
      ..clear()
      ..addAll(boardRows.map(StickerBoard.fromMap));

    if (_boards.isEmpty) {
      final defaultBoard = StickerBoard(
        id: 'default',
        name: 'Main Board',
        createdAt: DateTime.now(),
      );
      await db.insert('boards', defaultBoard.toMap());
      _boards.add(defaultBoard);
    }

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

    // Load sticker-model-tags relations
    final modelTagRows = await db.query(
      'sticker_model_tags',
      orderBy: 'tag COLLATE NOCASE ASC',
    );
    final stickerModelTagsMap = <String, List<String>>{};
    for (final row in modelTagRows) {
      final stickerId = row['stickerId'] as String;
      final tag = row['tag'] as String;
      stickerModelTagsMap.putIfAbsent(stickerId, () => []).add(tag);
    }

    // Load stickers
    final rows = await db.query('stickers', orderBy: 'zIndex ASC');
    _stickers
      ..clear()
      ..addAll(
        rows.map((row) {
          final id = row['id'] as String;
          return Sticker.fromMap(
            row,
            tags: stickerTagsMap[id] ?? const [],
            modelTags: stickerModelTagsMap[id] ?? const [],
          );
        }),
      );

    try {
      final settingsRows = await db.query('settings');
      final settingsMap = <String, dynamic>{};
      for (final row in settingsRows) {
        final key = row['key'] as String;
        final value = row['value'] as String;
        if (key == 'activeBoardId') {
          if (_boards.any((b) => b.id == value)) {
            _activeBoardId = value;
          }
        } else if (key == 'hapticFeedbackEnabled') {
          settingsMap[key] = value == '1' || value.toLowerCase() == 'true';
        } else {
          final val = double.tryParse(value);
          if (val != null) {
            settingsMap[key] = val;
          }
        }
      }
      _settings = StickerSettings.fromMap(settingsMap);
      AppHaptics.enabled = _settings.hapticFeedbackEnabled;
    } catch (_) {}

    if (!_boards.any((b) => b.id == _activeBoardId)) {
      _activeBoardId = _boards.first.id;
    }

    notifyListeners();
  }

  int getStickerCountForTag(String tagName) {
    return stickers.where((s) => s.tags.contains(tagName)).length;
  }

  int getStickerCountForBoard(String boardId) {
    return _stickers.where((s) => s.boardId == boardId).length;
  }

  Future<void> setActiveBoard(String boardId) async {
    if (_activeBoardId == boardId) return;
    if (!_boards.any((b) => b.id == boardId)) return;
    _activeBoardId = boardId;
    if (!_isTestMode) {
      try {
        final db = await StickerDatabase.instance();
        await db.insert('settings', {
          'key': 'activeBoardId',
          'value': boardId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<StickerBoard> createBoard(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Board name cannot be empty');
    }
    final newBoard = StickerBoard(
      id: const Uuid().v4(),
      name: trimmed,
      createdAt: DateTime.now(),
    );
    _boards.add(newBoard);
    _activeBoardId = newBoard.id;
    notifyListeners();

    if (!_isTestMode) {
      try {
        final db = await StickerDatabase.instance();
        await db.insert(
          'boards',
          newBoard.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await db.insert('settings', {
          'key': 'activeBoardId',
          'value': newBoard.id,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}
    }
    return newBoard;
  }

  Future<void> updateBoard(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Board name cannot be empty');
    }
    final index = _boards.indexWhere((b) => b.id == id);
    if (index == -1) return;

    _boards[index] = _boards[index].copyWith(name: trimmed);
    notifyListeners();

    if (!_isTestMode) {
      try {
        final db = await StickerDatabase.instance();
        await db.update(
          'boards',
          {'name': trimmed},
          where: 'id = ?',
          whereArgs: [id],
        );
      } catch (_) {}
    }
  }

  Future<void> setBoardNavigationMode(String id, bool isNavigationMode) async {
    final index = _boards.indexWhere((b) => b.id == id);
    if (index == -1) return;
    if (_boards[index].isNavigationMode == isNavigationMode) return;

    _boards[index] = _boards[index].copyWith(isNavigationMode: isNavigationMode);
    notifyListeners();

    if (!_isTestMode) {
      try {
        final db = await StickerDatabase.instance();
        await db.update(
          'boards',
          {'isNavigationMode': isNavigationMode ? 1 : 0},
          where: 'id = ?',
          whereArgs: [id],
        );
      } catch (_) {}
    }
  }

  Future<void> toggleBoardNavigationMode(String id) async {
    final index = _boards.indexWhere((b) => b.id == id);
    if (index == -1) return;
    await setBoardNavigationMode(id, !_boards[index].isNavigationMode);
  }

  Future<void> deleteBoard(String id) async {
    if (_boards.length <= 1) {
      throw StateError('Cannot delete the only remaining board');
    }
    final board = _boards.where((b) => b.id == id).firstOrNull;
    if (board == null) return;

    _stickers.removeWhere((s) => s.boardId == id);
    _boards.removeWhere((b) => b.id == id);

    if (_activeBoardId == id) {
      _activeBoardId = _boards.first.id;
    }
    notifyListeners();

    if (!_isTestMode) {
      try {
        final db = await StickerDatabase.instance();
        final boardStickers = _stickers.where((s) => s.boardId == id).toList();
        for (final sticker in boardStickers) {
          await db.delete('stickers', where: 'id = ?', whereArgs: [sticker.id]);
          await db.delete(
            'sticker_tags',
            where: 'stickerId = ?',
            whereArgs: [sticker.id],
          );
          final file = File(sticker.imagePath);
          if (await file.exists()) {
            try {
              await file.delete();
            } catch (_) {}
          }
        }
        await db.delete('boards', where: 'id = ?', whereArgs: [id]);
        await db.insert('settings', {
          'key': 'activeBoardId',
          'value': _activeBoardId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}
    }
  }

  Future<void> moveStickerToBoard(
    String stickerId,
    String targetBoardId,
  ) async {
    if (!_boards.any((b) => b.id == targetBoardId)) return;
    final index = _stickers.indexWhere((s) => s.id == stickerId);
    if (index == -1) return;

    final sticker = _stickers[index];
    if (sticker.boardId == targetBoardId) return;

    final updated = sticker.copyWith(boardId: targetBoardId);
    _stickers[index] = updated;
    notifyListeners();

    if (!_isTestMode) {
      try {
        final db = await StickerDatabase.instance();
        await db.update(
          'stickers',
          {'boardId': targetBoardId},
          where: 'id = ?',
          whereArgs: [stickerId],
        );
      } catch (_) {}
    }
  }

  @visibleForTesting
  void populateForTesting({
    List<Sticker>? stickers,
    List<StickerBoard>? boards,
    List<StickerTag>? tags,
    String? activeBoardId,
  }) {
    _isTestMode = true;
    if (stickers != null) {
      _stickers
        ..clear()
        ..addAll(stickers);
    }
    if (boards != null) {
      _boards
        ..clear()
        ..addAll(boards);
    }
    if (tags != null) {
      _tags
        ..clear()
        ..addAll(tags);
    }
    if (activeBoardId != null) {
      _activeBoardId = activeBoardId;
    }
    notifyListeners();
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
    AppHaptics.enabled = newSettings.hapticFeedbackEnabled;
    final db = await StickerDatabase.instance();
    await db.insert('settings', {
      'key': 'saturation',
      'value': newSettings.saturation.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('settings', {
      'key': 'brightness',
      'value': newSettings.brightness.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('settings', {
      'key': 'hapticFeedbackEnabled',
      'value': newSettings.hapticFeedbackEnabled ? '1' : '0',
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
    final current = stickers;
    if (current.isEmpty) return 0;
    return current.map((s) => s.zIndex).reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<void> save(Sticker sticker) async {
    final db = await StickerDatabase.instance();
    final effectiveBoardId = sticker.boardId.isEmpty
        ? _activeBoardId
        : sticker.boardId;
    final preparedSticker = sticker.copyWith(boardId: effectiveBoardId);

    await db.insert(
      'stickers',
      preparedSticker.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Ensure tags in sticker.tags exist in db and link them
    await db.delete(
      'sticker_tags',
      where: 'stickerId = ?',
      whereArgs: [preparedSticker.id],
    );
    final tagNames = preparedSticker.tags;
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
        'stickerId': preparedSticker.id,
        'tagId': tag.id,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      resolvedTags.add(tag.name);
    }
    _tags.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final updatedSticker = preparedSticker.copyWith(tags: resolvedTags);

    // Save model tags in db
    await db.delete(
      'sticker_model_tags',
      where: 'stickerId = ?',
      whereArgs: [preparedSticker.id],
    );
    for (final tag in preparedSticker.modelTags) {
      final trimmed = tag.trim();
      if (trimmed.isEmpty) continue;
      await db.insert('sticker_model_tags', {
        'stickerId': preparedSticker.id,
        'tag': trimmed,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final index = _stickers.indexWhere((s) => s.id == preparedSticker.id);
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

  Future<void> setStickerModelTags(
    String stickerId,
    List<String> newModelTags,
  ) async {
    final index = _stickers.indexWhere((s) => s.id == stickerId);
    if (index == -1) return;

    final sticker = _stickers[index];
    final updated = sticker.copyWith(modelTags: newModelTags);
    await save(updated);
  }

  Future<void> promoteModelTagToUserTag(String stickerId, String tag) async {
    final index = _stickers.indexWhere((s) => s.id == stickerId);
    if (index == -1) return;

    final sticker = _stickers[index];
    final userTags = Set<String>.from(sticker.tags)..add(tag);
    final updated = sticker.copyWith(tags: userTags.toList());
    await save(updated);
  }

  Future<void> removeModelTag(String stickerId, String tag) async {
    final index = _stickers.indexWhere((s) => s.id == stickerId);
    if (index == -1) return;

    final sticker = _stickers[index];
    final modelTags = List<String>.from(sticker.modelTags)..remove(tag);
    final updated = sticker.copyWith(modelTags: modelTags);
    await save(updated);
  }

  List<String> get allModelTags {
    final set = <String>{};
    for (final s in _stickers) {
      set.addAll(s.modelTags);
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return List.unmodifiable(list);
  }

  /// Asynchronously predicts AI model tags in the background for a sticker after it is placed/saved.
  Future<void> generateModelTags(String stickerId) async {
    final sticker = _stickers.where((s) => s.id == stickerId).firstOrNull;
    if (sticker == null) return;
    final file = File(sticker.imagePath);
    if (!await file.exists()) return;

    try {
      final tags = await AutoTagService.predictTags(
        file,
        topK: 5,
        minConfidence: 0.12,
      );
      if (tags.isNotEmpty) {
        await setStickerModelTags(stickerId, tags);
      }
    } catch (e) {
      debugPrint('Error generating model tags in background: $e');
    }
  }

  Future<void> updateTransform(Sticker sticker) async {
    if (!_isTestMode) {
      try {
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
      } catch (_) {}
    }
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
    final existing = _stickers.where((s) => s.id == id).firstOrNull;
    if (!_isTestMode) {
      try {
        final db = await StickerDatabase.instance();
        await db.delete('stickers', where: 'id = ?', whereArgs: [id]);
        await db.delete('sticker_tags', where: 'stickerId = ?', whereArgs: [id]);
        await db.delete('sticker_model_tags', where: 'stickerId = ?', whereArgs: [id]);
      } catch (_) {}
    }
    _stickers.removeWhere((s) => s.id == id);
    notifyListeners();

    if (!_isTestMode && existing != null) {
      final file = File(existing.imagePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }
}
