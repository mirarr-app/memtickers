import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/sticker_database.dart';
import '../data/sticker_repository.dart';
import 'backup_metadata.dart';

class BackupRestoreService {
  BackupRestoreService._();

  static const String manifestFileName = 'manifest.json';
  static const String databaseFileName = 'memtickers.db';
  static const String stickersFolderName = 'stickers';

  /// Creates a complete ZIP backup of the app data, including SQLite database and stickers.
  static Future<File> createBackup({
    required StickerRepository repository,
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('Preparing database...');
    // Ensure all WAL data is checkpointed to the main SQLite database file.
    await StickerDatabase.checkpoint();

    final dbPath = await StickerDatabase.getDatabasePath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw StateError('Database file not found at $dbPath');
    }

    final docs = await getApplicationDocumentsDirectory();
    final stickersDir = Directory(p.join(docs.path, stickersFolderName));

    onProgress?.call('Gathering stickers and metadata...');
    final stickerFiles = <File>[];
    if (await stickersDir.exists()) {
      final entities = await stickersDir.list().toList();
      for (final entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.png')) {
          stickerFiles.add(entity);
        }
      }
    }

    final metadata = BackupMetadata(
      version: 1,
      createdAt: DateTime.now(),
      stickerCount: repository.allStickers.length,
      boardCount: repository.boards.length,
    );

    onProgress?.call('Building backup archive...');
    final archive = Archive();

    // 1. Add manifest
    final manifestBytes = utf8.encode(metadata.toJson());
    archive.addFile(
      ArchiveFile(manifestFileName, manifestBytes.length, manifestBytes),
    );

    // 2. Add SQLite database
    final dbBytes = await dbFile.readAsBytes();
    archive.addFile(
      ArchiveFile(databaseFileName, dbBytes.length, dbBytes),
    );

    // 3. Add all sticker images
    var processedStickers = 0;
    for (final file in stickerFiles) {
      final name = p.basename(file.path);
      final bytes = await file.readAsBytes();
      archive.addFile(
        ArchiveFile('$stickersFolderName/$name', bytes.length, bytes),
      );
      processedStickers++;
      if (processedStickers % 10 == 0 || processedStickers == stickerFiles.length) {
        onProgress?.call(
          'Compressing stickers ($processedStickers/${stickerFiles.length})...',
        );
      }
    }

    onProgress?.call('Finalizing ZIP file...');
    final zipEncoder = ZipEncoder();
    final encodedZipBytes = zipEncoder.encode(archive);

    // Save to temp directory with timestamped filename
    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now();
    String pad(int n) => n.toString().padLeft(2, '0');
    final timestamp =
        '${now.year}-${pad(now.month)}-${pad(now.day)}_${pad(now.hour)}${pad(now.minute)}${pad(now.second)}';
    final backupFileName = 'memtickers_backup_$timestamp.zip';
    final backupFile = File(p.join(tempDir.path, backupFileName));
    await backupFile.writeAsBytes(encodedZipBytes, flush: true);

    return backupFile;
  }

  /// Shares a backup file using the Android system share sheet.
  static Future<ShareResult> shareBackup(File backupFile) async {
    return Share.shareXFiles(
      [
        XFile(
          backupFile.path,
          mimeType: 'application/zip',
          name: p.basename(backupFile.path),
        ),
      ],
      subject: 'Memtickers Backup',
      text: 'Memtickers complete backup archive',
    );
  }

  /// Inspects a backup ZIP file and returns its [BackupMetadata] without full extraction.
  static Future<BackupMetadata> inspectBackup(File zipFile) async {
    if (!await zipFile.exists()) {
      throw ArgumentError('Selected backup file does not exist: ${zipFile.path}');
    }

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Check for manifest
    final manifestFile = archive.findFile(manifestFileName);
    if (manifestFile != null) {
      final content = utf8.decode(manifestFile.content as List<int>);
      return BackupMetadata.fromJson(content);
    }

    // Fallback if manifest is absent: count files
    final hasDb = archive.findFile(databaseFileName) != null;
    if (!hasDb) {
      throw const FormatException(
        'Invalid backup: Missing database file (memtickers.db).',
      );
    }

    var stickerCount = 0;
    for (final file in archive.files) {
      if (file.name.startsWith('$stickersFolderName/') &&
          file.name.toLowerCase().endsWith('.png')) {
        stickerCount++;
      }
    }

    return BackupMetadata(
      version: 1,
      createdAt: (await zipFile.lastModified()),
      stickerCount: stickerCount,
      boardCount: 0, // Unknown without querying DB
    );
  }

  /// Restores data from the specified backup ZIP file.
  /// This performs a clean replace: existing stickers, boards, tags, and settings are wiped
  /// and replaced with the contents of the backup. Sticker file paths in the database are
  /// updated to match the current device's storage paths.
  static Future<void> restoreBackup({
    required File zipFile,
    required StickerRepository repository,
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('Verifying backup archive...');
    if (!await zipFile.exists()) {
      throw ArgumentError('Selected backup file does not exist: ${zipFile.path}');
    }

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final dbArchiveFile = archive.findFile(databaseFileName);
    if (dbArchiveFile == null) {
      throw const FormatException(
        'Invalid backup archive: Missing memtickers.db',
      );
    }

    onProgress?.call('Closing active database...');
    await StickerDatabase.closeDatabase();

    final docs = await getApplicationDocumentsDirectory();
    final targetDbPath = p.join(docs.path, databaseFileName);
    final targetDbFile = File(targetDbPath);
    final walFile = File('$targetDbPath-wal');
    final shmFile = File('$targetDbPath-shm');

    // Remove old DB and WAL/SHM files to guarantee clean state
    if (await targetDbFile.exists()) await targetDbFile.delete();
    if (await walFile.exists()) await walFile.delete();
    if (await shmFile.exists()) await shmFile.delete();

    onProgress?.call('Restoring database...');
    await targetDbFile.writeAsBytes(
      dbArchiveFile.content as List<int>,
      flush: true,
    );

    // Extract sticker images
    final targetStickersDir = Directory(p.join(docs.path, stickersFolderName));
    if (await targetStickersDir.exists()) {
      try {
        await targetStickersDir.delete(recursive: true);
      } catch (_) {}
    }
    await targetStickersDir.create(recursive: true);

    onProgress?.call('Restoring sticker images...');
    var restoredStickers = 0;
    for (final file in archive.files) {
      if (file.isFile &&
          file.name.startsWith('$stickersFolderName/') &&
          file.name.toLowerCase().endsWith('.png')) {
        final filename = p.basename(file.name);
        if (filename.isNotEmpty) {
          final outFile = File(p.join(targetStickersDir.path, filename));
          await outFile.writeAsBytes(file.content as List<int>, flush: true);
          restoredStickers++;
        }
      }
    }

    onProgress?.call('Restored $restoredStickers stickers. Remapping paths...');
    // Open the restored DB and update image paths to current directory
    final db = await StickerDatabase.instance();
    final rows = await db.query('stickers', columns: ['id']);
    final batch = db.batch();
    for (final row in rows) {
      final id = row['id'] as String;
      final remappedPath = p.join(targetStickersDir.path, '$id.png');
      batch.update(
        'stickers',
        {'imagePath': remappedPath},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);

    onProgress?.call('Refreshing scrapbook...');
    await repository.reload();
  }
}
