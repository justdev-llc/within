import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/teaching.dart';

/// Loads a tradition's teachings and picks the one assigned to a calendar date.
///
/// The selection rule must stay identical to `TeachingStore.swift` in the
/// widget extension, otherwise the app and widgets will disagree:
///
///   dayNumber = whole days from 2025-01-01 to the local calendar date
///   index     = dayNumber mod teachings.length  (teachings sorted by id)
class TeachingService {
  TeachingService(List<Teaching> teachings)
    : teachings = List.unmodifiable(
        [...teachings]..sort((a, b) => a.id.compareTo(b.id)),
      ) {
    if (this.teachings.isEmpty) {
      throw StateError('Teaching library is empty');
    }
  }

  static final DateTime epoch = DateTime.utc(2025, 1, 1);

  final List<Teaching> teachings;

  static Future<TeachingService> load({
    String tradition = 'buddhism',
    AssetBundle? bundle,
  }) async {
    final raw = await (bundle ?? rootBundle).loadString(
      'assets/teachings/$tradition.json',
    );
    return TeachingService.fromJsonString(raw);
  }

  factory TeachingService.fromJsonString(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final items = (json['teachings'] as List)
        .map((item) => Teaching.fromJson(item as Map<String, dynamic>))
        .toList();
    return TeachingService(items);
  }

  /// Whole calendar days between [epoch] and [date]'s local Y/M/D.
  ///
  /// Only the date components are used, re-anchored in UTC, so DST transitions
  /// (23- or 25-hour days) and time zones can't shift the result.
  static int dayNumber(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).difference(epoch).inDays;

  /// The teaching for [date]'s local calendar day (defaults to today).
  Teaching forDate([DateTime? date]) {
    final local = (date ?? DateTime.now()).toLocal();
    // Dart's % is Euclidean, so dates before the epoch still map to a valid index.
    return teachings[dayNumber(local) % teachings.length];
  }
}
