import 'package:flutter_test/flutter_test.dart';
import 'package:within/models/teaching.dart';
import 'package:within/services/teaching_service.dart';

Teaching _teaching(String id) => Teaching(
  id: id,
  tradition: 'buddhism',
  scripture: 'Test',
  reference: 'Test $id',
  text: 'Text $id',
  shortText: 'Short $id',
  contentType: ContentType.paraphrase,
  language: 'en',
);

void main() {
  group('dayNumber', () {
    test('epoch is day 0', () {
      expect(TeachingService.dayNumber(DateTime(2025, 1, 1)), 0);
    });

    // Anchor values shared with the Swift tests so both platforms agree.
    test('known anchors', () {
      expect(TeachingService.dayNumber(DateTime(2025, 12, 31)), 364);
      expect(TeachingService.dayNumber(DateTime(2026, 1, 1)), 365);
      expect(TeachingService.dayNumber(DateTime(2026, 10, 26)), 663);
      expect(TeachingService.dayNumber(DateTime(2028, 2, 29)), 1154);
      expect(TeachingService.dayNumber(DateTime(2024, 12, 31)), -1);
    });

    test('time of day does not matter', () {
      expect(
        TeachingService.dayNumber(DateTime(2026, 3, 8, 0, 0)),
        TeachingService.dayNumber(DateTime(2026, 3, 8, 23, 59, 59)),
      );
    });

    // Walks every local day for four years, crossing every DST transition and
    // a leap day in whatever time zone the tests run in.
    test('advances by exactly one per local calendar day', () {
      var previous = TeachingService.dayNumber(DateTime(2025, 1, 1));
      for (var i = 1; i < 365 * 4; i++) {
        final day = DateTime(2025, 1, 1 + i, 12);
        final current = TeachingService.dayNumber(day);
        expect(current, previous + 1, reason: 'at $day');
        previous = current;
      }
    });
  });

  group('forDate', () {
    final service = TeachingService([
      _teaching('buddha_003'),
      _teaching('buddha_001'),
      _teaching('buddha_002'),
    ]);

    test('sorts by id regardless of file order', () {
      expect(service.teachings.map((t) => t.id), [
        'buddha_001',
        'buddha_002',
        'buddha_003',
      ]);
    });

    test('rotates daily and wraps around', () {
      expect(service.forDate(DateTime(2025, 1, 1)).id, 'buddha_001');
      expect(service.forDate(DateTime(2025, 1, 2)).id, 'buddha_002');
      expect(service.forDate(DateTime(2025, 1, 3)).id, 'buddha_003');
      expect(service.forDate(DateTime(2025, 1, 4)).id, 'buddha_001');
    });

    test('is stable across repeated calls on the same day', () {
      final morning = service.forDate(DateTime(2026, 6, 1, 6));
      final night = service.forDate(DateTime(2026, 6, 1, 23));
      expect(night.id, morning.id);
    });

    test('dates before the epoch still map to a valid teaching', () {
      expect(service.forDate(DateTime(2024, 12, 31)).id, 'buddha_003');
    });

    test('rejects an empty library', () {
      expect(() => TeachingService([]), throwsStateError);
    });
  });
}
