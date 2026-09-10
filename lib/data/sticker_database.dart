import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class StickerDatabase {
  StickerDatabase._();

  static Database? _db;

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final docs = await getApplicationDocumentsDirectory();
    final path = p.join(docs.path, 'memtickers.db');
    _db = await openDatabase(
      path,
      version: 7,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE boards (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  createdAt INTEGER NOT NULL,
  isNavigationMode INTEGER NOT NULL DEFAULT 0,
  backgroundStyle TEXT NOT NULL DEFAULT 'minimalSurface'
)
''');
        await db.rawInsert(
          'INSERT OR IGNORE INTO boards (id, name, createdAt, isNavigationMode, backgroundStyle) VALUES (?, ?, ?, ?, ?)',
          ['default', 'Main Board', DateTime.now().millisecondsSinceEpoch, 0, 'minimalSurface'],
        );
        await db.execute('''
CREATE TABLE stickers (
  id TEXT PRIMARY KEY,
  boardId TEXT NOT NULL DEFAULT 'default',
  imagePath TEXT NOT NULL,
  createdAt INTEGER NOT NULL,
  latitude REAL,
  longitude REAL,
  placeLabel TEXT,
  x REAL NOT NULL,
  y REAL NOT NULL,
  rotation REAL NOT NULL,
  scale REAL NOT NULL,
  zIndex INTEGER NOT NULL
)
''');
        await db.execute('''
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''');
        await db.execute('''
CREATE TABLE IF NOT EXISTS tags (
  id TEXT PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  createdAt INTEGER NOT NULL
)
''');
        await db.execute('''
CREATE TABLE IF NOT EXISTS sticker_tags (
  stickerId TEXT NOT NULL,
  tagId TEXT NOT NULL,
  PRIMARY KEY (stickerId, tagId)
)
''');
        await db.execute('''
CREATE TABLE IF NOT EXISTS sticker_model_tags (
  stickerId TEXT NOT NULL,
  tag TEXT NOT NULL,
  PRIMARY KEY (stickerId, tag)
)
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_stickers_boardId ON stickers(boardId);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sticker_tags_stickerId ON sticker_tags(stickerId);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sticker_tags_tagId ON sticker_tags(tagId);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sticker_model_tags_stickerId ON sticker_model_tags(stickerId);',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
CREATE TABLE IF NOT EXISTS tags (
  id TEXT PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  createdAt INTEGER NOT NULL
)
''');
          await db.execute('''
CREATE TABLE IF NOT EXISTS sticker_tags (
  stickerId TEXT NOT NULL,
  tagId TEXT NOT NULL,
  PRIMARY KEY (stickerId, tagId)
)
''');
        }
        if (oldVersion < 3) {
          await db.execute('''
CREATE TABLE IF NOT EXISTS boards (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  createdAt INTEGER NOT NULL
)
''');
          await db.rawInsert(
            'INSERT OR IGNORE INTO boards (id, name, createdAt) VALUES (?, ?, ?)',
            ['default', 'Main Board', DateTime.now().millisecondsSinceEpoch],
          );
          try {
            await db.execute(
              "ALTER TABLE stickers ADD COLUMN boardId TEXT NOT NULL DEFAULT 'default'",
            );
          } catch (_) {}
        }
        if (oldVersion < 4) {
          await db.execute('''
CREATE TABLE IF NOT EXISTS sticker_model_tags (
  stickerId TEXT NOT NULL,
  tag TEXT NOT NULL,
  PRIMARY KEY (stickerId, tag)
)
''');
        }
        if (oldVersion < 5) {
          try {
            await db.execute(
              "ALTER TABLE boards ADD COLUMN isNavigationMode INTEGER NOT NULL DEFAULT 0",
            );
          } catch (_) {}
        }
        if (oldVersion < 6) {
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_stickers_boardId ON stickers(boardId);',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_sticker_tags_stickerId ON sticker_tags(stickerId);',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_sticker_tags_tagId ON sticker_tags(tagId);',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_sticker_model_tags_stickerId ON sticker_model_tags(stickerId);',
          );
        }
        if (oldVersion < 7) {
          try {
            await db.execute(
              "ALTER TABLE boards ADD COLUMN backgroundStyle TEXT NOT NULL DEFAULT 'minimalSurface'",
            );
          } catch (_) {}
        }
      },
    );
    return _db!;
  }

  static Future<String> getDatabasePath() async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'memtickers.db');
  }

  static Future<void> checkpoint() async {
    final db = await instance();
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(FULL);');
    } catch (_) {}
  }

  static Future<void> closeDatabase() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
