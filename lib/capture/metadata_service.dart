import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_exif/native_exif.dart';

import 'memory_metadata.dart';

class MetadataService {
  Future<MemoryMetadata> fromLiveCapture() async {
    final now = DateTime.now();
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return MemoryMetadata(capturedAt: now);

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return MemoryMetadata(capturedAt: now);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final place = await _placeLabel(position.latitude, position.longitude);
      return MemoryMetadata(
        capturedAt: now,
        latitude: position.latitude,
        longitude: position.longitude,
        placeLabel: place,
      );
    } catch (_) {
      return MemoryMetadata(capturedAt: now);
    }
  }

  /// Gallery photos use EXIF only — never the current GPS.
  Future<MemoryMetadata> fromGalleryFile(String path) async {
    DateTime capturedAt = DateTime.now();
    double? lat;
    double? lng;
    try {
      final exif = await Exif.fromPath(path);
      capturedAt = await exif.getOriginalDate() ?? capturedAt;
      final gps = await exif.getLatLong();
      lat = gps?.latitude;
      lng = gps?.longitude;
      await exif.close();
    } catch (_) {
      // Missing EXIF is fine.
    }

    String? place;
    if (lat != null && lng != null) {
      place = await _placeLabel(lat, lng);
    }
    return MemoryMetadata(
      capturedAt: capturedAt,
      latitude: lat,
      longitude: lng,
      placeLabel: place,
    );
  }

  Future<String?> _placeLabel(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return null;
      final mark = marks.first;
      final parts = [
        mark.locality,
        mark.subAdministrativeArea,
        mark.administrativeArea,
        mark.country,
      ].whereType<String>().where((s) => s.trim().isNotEmpty);
      if (parts.isEmpty) return null;
      return parts.take(3).join(', ');
    } catch (_) {
      return null;
    }
  }
}
