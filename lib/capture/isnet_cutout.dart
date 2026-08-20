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
}
