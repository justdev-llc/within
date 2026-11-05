import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:within/models/teaching.dart';
import 'package:within/services/teaching_service.dart';

/// Guards the bundled library: every entry must be well-formed and fit widgets.
void main() {
  // Roughly three lines in the lock screen's accessoryRectangular widget.
  const maxShortTextLength = 80;

  final service = TeachingService.fromJsonString(
    File('assets/teachings/buddhism.json').readAsStringSync(),
  );

  test('library is not empty', () {
    expect(service.teachings, isNotEmpty);
  });

  test('ids are unique and zero-padded so sorting is stable', () {
    final ids = service.teachings.map((t) => t.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(id, matches(RegExp(r'^buddha_\d{3}$')));
    }
  });

  for (final teaching in service.teachings) {
    test('${teaching.id} is well-formed', () {
      expect(teaching.tradition, 'buddhism');
      expect(teaching.reference, isNotEmpty);
      expect(teaching.text, isNotEmpty);
      expect(
        teaching.shortText.length,
        lessThanOrEqualTo(maxShortTextLength),
        reason: '"${teaching.shortText}"',
      );
      if (teaching.contentType == ContentType.translationExcerpt) {
        expect(
          teaching.attribution,
          isNotNull,
          reason: 'translation excerpts must name their translation',
        );
      }
    });
  }
}
