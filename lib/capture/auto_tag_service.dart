import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for generating AI-based model tags for stickers/memories.
///
/// Runs MobileCLIP-S0 visual encoder on Android via ONNX Runtime to compare
/// image embeddings against a precomputed semantic tag dictionary.
class AutoTagService {
  AutoTagService._();

  static const MethodChannel _channel =
      MethodChannel('com.mirarrapp.memtickers/autotag');

  static Future<bool> isModelReady() async {
    try {
      final ready = await _channel.invokeMethod<bool>('isModelReady');
      return ready ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> ensureModel({void Function(String)? onStatus}) async {
    try {
      onStatus?.call('Loading AI auto-tagging model…');
      await _channel.invokeMethod<bool>('ensureModel');
    } on PlatformException catch (e) {
      debugPrint('AutoTagService.ensureModel error: ${e.message}');
    } catch (e) {
      debugPrint('AutoTagService.ensureModel unexpected error: $e');
    }
  }

  /// Predicts the top matching semantic tags for an image file.
  static Future<List<String>> predictTags(
    File imageFile, {
    int topK = 5,
    double minConfidence = 0.12,
  }) async {
    try {
      if (!await imageFile.exists()) return const [];

      final result = await _channel.invokeMethod<List<dynamic>>('predictTags', {
        'imagePath': imageFile.path,
        'topK': topK,
        'minConfidence': minConfidence,
      });

      if (result == null) return const [];
      return result
          .map((e) => e.toString().trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('AutoTagService.predictTags error: $e');
      return const [];
    }
  }

  static Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
    } catch (_) {}
  }
}
