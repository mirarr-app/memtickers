import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';

class SegmentationException implements Exception {
  const SegmentationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SegmentationService {
  SubjectSegmenter? _segmenter;

  SubjectSegmenter get _client {
    return _segmenter ??= SubjectSegmenter(
      options: SubjectSegmenterOptions(
        enableForegroundBitmap: true,
        enableForegroundConfidenceMask: false,
        enableMultipleSubjects: SubjectResultOptions(
          enableConfidenceMask: false,
          enableSubjectBitmap: true,
        ),
      ),
    );
  }

  Future<Uint8List> cutOut(File imageFile) async {
    final input = InputImage.fromFile(imageFile);
    final result = await _client.processImage(input);

    final bytes = result.foregroundBitmap ??
        (result.subjects.isNotEmpty ? result.subjects.first.bitmap : null);

    if (bytes == null || bytes.isEmpty) {
      throw const SegmentationException(
        'No subject found. Try another photo with a clearer foreground.',
      );
    }
    return bytes;
  }

  Future<void> dispose() async {
    await _segmenter?.close();
    _segmenter = null;
  }
}
