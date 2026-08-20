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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE stickers (
  id TEXT PRIMARY KEY,
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
      },
    );
    return _db!;
  }
}
