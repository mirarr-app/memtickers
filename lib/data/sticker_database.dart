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
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE boards (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  createdAt INTEGER NOT NULL
)
''');
        await db.execute('''
INSERT OR IGNORE INTO boards (id, name, createdAt) VALUES ('default', 'Main Board', ${DateTime.now().millisecondsSinceEpoch})
''');
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
          await db.execute('''
INSERT OR IGNORE INTO boards (id, name, createdAt) VALUES ('default', 'Main Board', ${DateTime.now().millisecondsSinceEpoch})
''');
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
      },
      onOpen: (db) async {
        await db.execute('''
CREATE TABLE IF NOT EXISTS boards (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  createdAt INTEGER NOT NULL
)
''');
        await db.execute('''
INSERT OR IGNORE INTO boards (id, name, createdAt) VALUES ('default', 'Main Board', ${DateTime.now().millisecondsSinceEpoch})
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
        try {
          await db.execute(
            "ALTER TABLE stickers ADD COLUMN boardId TEXT NOT NULL DEFAULT 'default'",
          );
        } catch (_) {}
      },
    );
    return _db!;
  }
}
