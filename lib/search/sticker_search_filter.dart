import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/sticker.dart';

class StickerSearchFilter {
  const StickerSearchFilter({
    this.tags = const [],
    this.dateRange,
    this.locationQuery,
  });

  final List<String> tags;
  final DateTimeRange? dateRange;
  final String? locationQuery;

  bool get isEmpty =>
      tags.isEmpty &&
      dateRange == null &&
      (locationQuery == null || locationQuery!.trim().isEmpty);

  bool get isNotEmpty => !isEmpty;

  int get activeFilterCount {
    var count = 0;
    if (tags.isNotEmpty) count++;
    if (dateRange != null) count++;
    if (locationQuery != null && locationQuery!.trim().isNotEmpty) count++;
    return count;
  }

  bool matches(Sticker sticker) {
    if (isEmpty) return true;

    // Filter by tags: match if sticker has any of the selected tags
    if (tags.isNotEmpty) {
      final stickerTagsLower = sticker.tags.map((t) => t.toLowerCase()).toSet();
      final hasMatch = tags.any(
        (t) => stickerTagsLower.contains(t.toLowerCase()),
      );
      if (!hasMatch) return false;
    }

    // Filter by date range (inclusive of entire days)
    if (dateRange != null) {
      final start = DateTime(
        dateRange!.start.year,
        dateRange!.start.month,
        dateRange!.start.day,
      );
      final end = DateTime(
        dateRange!.end.year,
        dateRange!.end.month,
        dateRange!.end.day,
        23,
        59,
        59,
        999,
      );
      if (sticker.createdAt.isBefore(start) || sticker.createdAt.isAfter(end)) {
        return false;
      }
    }

    // Filter by location query (checks placeLabel)
    if (locationQuery != null && locationQuery!.trim().isNotEmpty) {
      final query = locationQuery!.trim().toLowerCase();
      final place = sticker.placeLabel?.toLowerCase() ?? '';
      if (!place.contains(query)) {
        return false;
      }
    }

    return true;
  }

  StickerSearchFilter copyWith({
    List<String>? tags,
    DateTimeRange? dateRange,
    String? locationQuery,
    bool clearDateRange = false,
    bool clearLocation = false,
  }) {
    return StickerSearchFilter(
      tags: tags ?? this.tags,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      locationQuery: clearLocation
          ? null
          : (locationQuery ?? this.locationQuery),
    );
  }

  String get summaryDescription {
    final parts = <String>[];
    if (tags.isNotEmpty) {
      parts.add(tags.map((t) => '#$t').join(', '));
    }
    if (dateRange != null) {
      final formatter = DateFormat('MMM d, yyyy');
      parts.add(
        '${formatter.format(dateRange!.start)} – ${formatter.format(dateRange!.end)}',
      );
    }
    if (locationQuery != null && locationQuery!.trim().isNotEmpty) {
      parts.add(locationQuery!.trim());
    }
    return parts.join(' • ');
  }
}
