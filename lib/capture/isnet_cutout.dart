import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Bundled IS-Net general-use (uint8 quantized) native background cutout.
///
/// Runs natively in Kotlin on Android to avoid method channel tensor overhead,
/// passing only file paths and cutout PNG results.
class IsnetCutout {
  IsnetCutout._();

  static const MethodChannel _channel = MethodChannel('com.mirarrapp.memtickers/cutout');
  static const _uuid = Uuid();

  static Future<bool> isModelReady() async {
    try {
      final ready = await _channel.invokeMethod<bool>('isModelReady');
      return ready ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> ensureLoaded() async {
    try {
      await _channel.invokeMethod<bool>('ensureModel');
    } on PlatformException catch (e) {
      throw StateError(e.message ?? 'Failed to load IS-Net model.');
    }
  }

  static Future<File> removeBackgroundFile(
    File sourceFile, {
    String? outputPath,
  }) async {
    try {
      final resultPath = await _channel.invokeMethod<String>('cutout', {
        'imagePath': sourceFile.path,
        'outputPath': ?outputPath,
      });
      if (resultPath == null || resultPath.isEmpty) {
        throw const FormatException('Cutout failed to produce an output file.');
      }
      final file = File(resultPath);
      if (!await file.exists()) {
        throw const FormatException('Cutout output file not found.');
      }
      return file;
    } on PlatformException catch (e) {
      throw FormatException(e.message ?? 'Cutout failed.');
    }
  }

  static Future<Uint8List> removeBackground(Uint8List sourceBytes) async {
    final tempDir = await getTemporaryDirectory();
    final tempInput = File('${tempDir.path}/input_${_uuid.v4()}.jpg');
    await tempInput.writeAsBytes(sourceBytes, flush: true);
    try {
      final outputFile = await removeBackgroundFile(tempInput);
      final bytes = await outputFile.readAsBytes();
      try {
        await outputFile.delete();
      } catch (_) {}
      return bytes;
    } finally {
      try {
        await tempInput.delete();
      } catch (_) {}
    }
  }

  static Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
    } catch (_) {}
  }

  static Future<bool> hasRefineSession() async {
    try {
      final ready = await _channel.invokeMethod<bool>('hasRefineSession');
      return ready ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<RefineSessionInfo> startRefineSession({
    String? imagePath,
    String? cutoutPath,
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'startRefineSession',
        {
          'imagePath': ?imagePath,
          'cutoutPath': ?cutoutPath,
        },
      );
      if (res == null) {
        throw const FormatException('Failed to start refine session.');
      }
      return RefineSessionInfo(
        sessionId: res['sessionId'] as String,
        width: (res['width'] as num).toInt(),
        height: (res['height'] as num).toInt(),
        workingImagePath: res['workingImagePath'] as String,
        overlayPath: res['overlayPath'] as String,
        canUndo: (res['canUndo'] as bool?) ?? false,
        canRedo: (res['canRedo'] as bool?) ?? false,
      );
    } on PlatformException catch (e) {
      throw FormatException(e.message ?? 'Failed to start refine session.');
    }
  }

  static Future<StrokeResult> applyRefineStroke({
    required String sessionId,
    required List<double> points,
    required double radius,
    required bool isRestore,
    required bool isSmart,
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'applyRefineStroke',
        {
          'sessionId': sessionId,
          'points': points,
          'radius': radius,
          'isRestore': isRestore,
          'isSmart': isSmart,
        },
      );
      if (res == null) {
        throw const FormatException('Failed to apply refine stroke.');
      }
      return StrokeResult(
        overlayPath: res['overlayPath'] as String?,
        canUndo: (res['canUndo'] as bool?) ?? false,
        canRedo: (res['canRedo'] as bool?) ?? false,
      );
    } on PlatformException catch (e) {
      throw FormatException(e.message ?? 'Stroke failed.');
    }
  }

  static Future<StrokeResult> undoRefineStroke(String sessionId) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'undoRefineStroke',
        {'sessionId': sessionId},
      );
      if (res == null) {
        throw const FormatException('Failed to undo.');
      }
      return StrokeResult(
        overlayPath: res['overlayPath'] as String?,
        canUndo: (res['canUndo'] as bool?) ?? false,
        canRedo: (res['canRedo'] as bool?) ?? false,
      );
    } on PlatformException catch (e) {
      throw FormatException(e.message ?? 'Undo failed.');
    }
  }

  static Future<StrokeResult> redoRefineStroke(String sessionId) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'redoRefineStroke',
        {'sessionId': sessionId},
      );
      if (res == null) {
        throw const FormatException('Failed to redo.');
      }
      return StrokeResult(
        overlayPath: res['overlayPath'] as String?,
        canUndo: (res['canUndo'] as bool?) ?? false,
        canRedo: (res['canRedo'] as bool?) ?? false,
      );
    } on PlatformException catch (e) {
      throw FormatException(e.message ?? 'Redo failed.');
    }
  }

  static Future<StrokeResult> resetRefine(String sessionId) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'resetRefine',
        {'sessionId': sessionId},
      );
      if (res == null) {
        throw const FormatException('Failed to reset.');
      }
      return StrokeResult(
        overlayPath: res['overlayPath'] as String?,
        canUndo: (res['canUndo'] as bool?) ?? false,
        canRedo: (res['canRedo'] as bool?) ?? false,
      );
    } on PlatformException catch (e) {
      throw FormatException(e.message ?? 'Reset failed.');
    }
  }

  static Future<RefineCropResult> finishRefineSession(String sessionId) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'finishRefineSession',
        {'sessionId': sessionId},
      );
      if (res == null) {
        throw const FormatException('Failed to finish refine session.');
      }
      return RefineCropResult(
        path: res['path'] as String,
        width: (res['width'] as num).toInt(),
        height: (res['height'] as num).toInt(),
      );
    } on PlatformException catch (e) {
      throw FormatException(e.message ?? 'Finish refine failed.');
    }
  }

  static Future<void> disposeRefineSession(String sessionId) async {
    try {
      await _channel.invokeMethod('disposeRefineSession', {'sessionId': sessionId});
    } catch (_) {}
  }
}

class RefineSessionInfo {
  const RefineSessionInfo({
    required this.sessionId,
    required this.width,
    required this.height,
    required this.workingImagePath,
    required this.overlayPath,
    required this.canUndo,
    required this.canRedo,
  });

  final String sessionId;
  final int width;
  final int height;
  final String workingImagePath;
  final String overlayPath;
  final bool canUndo;
  final bool canRedo;
}

class StrokeResult {
  const StrokeResult({
    required this.overlayPath,
    required this.canUndo,
    required this.canRedo,
  });

  final String? overlayPath;
  final bool canUndo;
  final bool canRedo;
}

class RefineCropResult {
  const RefineCropResult({
    required this.path,
    required this.width,
    required this.height,
  });

  final String path;
  final int width;
  final int height;
}
