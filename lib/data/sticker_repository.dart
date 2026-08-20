import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'sticker.dart';
import 'sticker_database.dart';

class StickerRepository extends ChangeNotifier {
  final List<Sticker> _stickers = [];
  Directory? _imagesDir;

  List<Sticker> get stickers => List.unmodifiable(_stickers);

  Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    _imagesDir = Directory(p.join(docs.path, 'stickers'));
    if (!await _imagesDir!.exists()) {
      await _imagesDir!.create(recursive: true);
    }
    final db = await StickerDatabase.instance();
    final rows = await db.query('stickers', orderBy: 'zIndex ASC');
    _stickers
      ..clear()
      ..addAll(rows.map(Sticker.fromMap));
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
    final index = _stickers.indexWhere((s) => s.id == sticker.id);
    if (index >= 0) {
      _stickers[index] = sticker;
    } else {
      _stickers.add(sticker);
    }
    notifyListeners();
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
      _stickers[index] = sticker;
      notifyListeners();
    }
  }

  Future<void> delete(String id) async {
    final db = await StickerDatabase.instance();
    final existing = _stickers.where((s) => s.id == id).firstOrNull;
    await db.delete('stickers', where: 'id = ?', whereArgs: [id]);
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
