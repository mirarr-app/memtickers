import 'dart:io';
import 'dart:typed_data';

import 'isnet_cutout.dart';

class SegmentationException implements Exception {
  const SegmentationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class CutoutStatus {
  const CutoutStatus(this.message, {this.ready = false, this.failed = false});

  final String message;
  final bool ready;
  final bool failed;
}

class SegmentationService {
  Future<void> ensureModel({
    void Function(CutoutStatus status)? onStatus,
  }) async {
    onStatus?.call(const CutoutStatus('Loading cutout model…'));
    try {
      await IsnetCutout.ensureLoaded();
      onStatus?.call(const CutoutStatus('Cutout model ready', ready: true));
    } catch (error) {
      throw SegmentationException(
        'Could not load the on-device cutout model. $error',
      );
    }
  }

  Future<Uint8List> cutOut(
    File imageFile, {
    void Function(CutoutStatus status)? onStatus,
  }) async {
    await ensureModel(onStatus: onStatus);
    onStatus?.call(const CutoutStatus('Cutting the subject out…'));
    try {
      final cutoutFile = await IsnetCutout.removeBackgroundFile(imageFile);
      final bytes = await cutoutFile.readAsBytes();
      try {
        await cutoutFile.delete();
      } catch (_) {}
      return bytes;
    } on FormatException catch (error) {
      throw SegmentationException(error.message);
    } catch (error) {
      throw SegmentationException('Could not cut out this photo. $error');
    }
  }

  Future<void> dispose() async {
    await IsnetCutout.dispose();
  }
}
