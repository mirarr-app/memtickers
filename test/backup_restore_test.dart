import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:memtickers/backup/backup_metadata.dart';
import 'package:memtickers/backup/backup_restore_service.dart';
import 'package:memtickers/data/sticker.dart';
import 'package:memtickers/data/sticker_board.dart';
import 'package:memtickers/data/sticker_repository.dart';
import 'package:memtickers/data/sticker_tag.dart';
import 'package:memtickers/settings/sticker_settings_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupMetadata', () {
    test('toMap and fromMap serializes correctly', () {
      final now = DateTime.utc(2026, 9, 6, 13, 0);
      final meta = BackupMetadata(
        version: 1,
        createdAt: now,
        stickerCount: 42,
        boardCount: 3,
        appVersion: '1.2.0',
      );

      final map = meta.toMap();
      expect(map['version'], 1);
      expect(map['stickerCount'], 42);
      expect(map['boardCount'], 3);
      expect(map['appVersion'], '1.2.0');
      expect(map['createdAt'], now.toIso8601String());

      final restored = BackupMetadata.fromMap(map);
      expect(restored.version, 1);
      expect(restored.stickerCount, 42);
      expect(restored.boardCount, 3);
      expect(restored.appVersion, '1.2.0');
      expect(restored.createdAt, now);
    });

    test('toJson and fromJson handles string roundtrip', () {
      final now = DateTime.utc(2026, 9, 6, 13, 0);
      final meta = BackupMetadata(
        version: 1,
        createdAt: now,
        stickerCount: 10,
        boardCount: 2,
      );

      final jsonStr = meta.toJson();
      final decoded = BackupMetadata.fromJson(jsonStr);

      expect(decoded.version, 1);
      expect(decoded.stickerCount, 10);
      expect(decoded.boardCount, 2);
      expect(decoded.createdAt, now);
    });
  });

  group('Backup Inspection', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('memtickers_inspect_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('inspects zip with manifest correctly', () async {
      final zipFile = File(p.join(tempDir.path, 'valid_backup.zip'));
      final archive = Archive();

      final meta = BackupMetadata(
        version: 1,
        createdAt: DateTime.utc(2026, 9, 6, 10, 30),
        stickerCount: 15,
        boardCount: 4,
      );
      final manifestBytes = utf8.encode(meta.toJson());
      archive.addFile(
        ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
      );
      archive.addFile(
        ArchiveFile('memtickers.db', 4, [1, 2, 3, 4]),
      );

      final zipBytes = ZipEncoder().encode(archive);
      await zipFile.writeAsBytes(zipBytes);

      final inspected = await BackupRestoreService.inspectBackup(zipFile);
      expect(inspected.stickerCount, 15);
      expect(inspected.boardCount, 4);
      expect(inspected.version, 1);
      expect(inspected.createdAt, DateTime.utc(2026, 9, 6, 10, 30));
    });

    test('throws FormatException if memtickers.db is missing', () async {
      final zipFile = File(p.join(tempDir.path, 'invalid_backup.zip'));
      final archive = Archive();
      archive.addFile(ArchiveFile('random.txt', 4, [1, 2, 3, 4]));

      final zipBytes = ZipEncoder().encode(archive);
      await zipFile.writeAsBytes(zipBytes);

      expect(
        () => BackupRestoreService.inspectBackup(zipFile),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('StickerSettingsSheet Backup UI', () {
    testWidgets('renders Backup & Restore card with buttons and counts', (tester) async {
      final repo = StickerRepository();
      repo.populateForTesting(
        stickers: [
          Sticker(
            id: 's-1',
            boardId: 'default',
            imagePath: '/path/to/s1.png',
            createdAt: DateTime.now(),
            x: 0,
            y: 0,
            rotation: 0,
            scale: 1,
            zIndex: 1,
          ),
          Sticker(
            id: 's-2',
            boardId: 'default',
            imagePath: '/path/to/s2.png',
            createdAt: DateTime.now(),
            x: 10,
            y: 10,
            rotation: 0,
            scale: 1,
            zIndex: 2,
          ),
        ],
        boards: [
          StickerBoard(
            id: 'default',
            name: 'Main Board',
            createdAt: DateTime.now(),
          ),
        ],
        tags: [
          StickerTag(
            id: 't-1',
            name: 'Travel',
            createdAt: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => showStickerSettings(
                    context: context,
                    repository: repo,
                  ),
                  child: const Text('Open Settings'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Backup & Restore'), findsOneWidget);
      expect(find.text('2 stickers'), findsOneWidget);
      expect(find.text('1 boards'), findsOneWidget);
      expect(find.text('1 tags'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Backup'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Restore'), findsOneWidget);
    });
  });

  group('Database Schema Migration & Older Version Backup Restoration', () {
    test('legacy board database row without backgroundStyle deserializes cleanly', () {
      final now = DateTime.utc(2026, 9, 1);
      final legacyRow = <String, Object?>{
        'id': 'b-legacy-1',
        'name': 'Trip to Tokyo',
        'createdAt': now.millisecondsSinceEpoch,
        'isNavigationMode': 1,
        // backgroundStyle is omitted, matching older database schema versions (v1-v6)
      };

      final board = StickerBoard.fromMap(legacyRow);
      expect(board.id, 'b-legacy-1');
      expect(board.name, 'Trip to Tokyo');
      expect(board.isNavigationMode, true);
      // Backward compatibility guarantee: defaults to minimalSurface without crash or data loss
      expect(board.backgroundStyle, BoardBackgroundStyle.minimalSurface);
    });

    test('modern board row with backgroundStyle deserializes correctly', () {
      final now = DateTime.utc(2026, 9, 1);
      final row = <String, Object?>{
        'id': 'b-v7',
        'name': 'Vintage Scrapbook',
        'createdAt': now.millisecondsSinceEpoch,
        'isNavigationMode': 0,
        'backgroundStyle': 'craftPaper',
      };

      final board = StickerBoard.fromMap(row);
      expect(board.backgroundStyle, BoardBackgroundStyle.craftPaper);
    });

    test('StickerBoard serialization roundtrip preserves backgroundStyle', () {
      final board = StickerBoard(
        id: 'b-roundtrip',
        name: 'Noir Gallery',
        createdAt: DateTime(2026, 9, 2),
        backgroundStyle: BoardBackgroundStyle.studioNoir,
      );

      final map = board.toMap();
      expect(map['backgroundStyle'], 'studioNoir');

      final restored = StickerBoard.fromMap(map);
      expect(restored.id, board.id);
      expect(restored.name, board.name);
      expect(
        restored.createdAt.millisecondsSinceEpoch,
        board.createdAt.millisecondsSinceEpoch,
      );
      expect(restored.backgroundStyle, BoardBackgroundStyle.studioNoir);
    });

    test('corrupted or unrecognized backgroundStyle safely falls back to minimalSurface', () {
      final row = <String, Object?>{
        'id': 'b-fallback',
        'name': 'Unknown Style',
        'createdAt': 123456789,
        'isNavigationMode': 0,
        'backgroundStyle': 'some_unknown_nonexistent_style',
      };

      final board = StickerBoard.fromMap(row);
      expect(board.backgroundStyle, BoardBackgroundStyle.minimalSurface);
    });

    test('all BoardBackgroundStyle values have valid configurations', () {
      for (final style in BoardBackgroundStyle.values) {
        expect(style.id.isNotEmpty, true);
        expect(style.label.isNotEmpty, true);
        expect(style.description.isNotEmpty, true);
        expect(style.primaryColor.a, greaterThan(0));
      }
    });
  });
}
