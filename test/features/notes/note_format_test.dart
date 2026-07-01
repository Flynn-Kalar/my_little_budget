import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/notes/note_format.dart';

void main() {
  group('note D-day formatting', () {
    test('shows D-day for the same calendar date', () {
      expect(
        formatNoteDday(
          DateTime(2026, 6, 27, 23, 59),
          now: DateTime(2026, 6, 27, 0, 1),
        ),
        'D-day',
      );
    });

    test('shows remaining and elapsed days by calendar date', () {
      final now = DateTime(2026, 6, 27, 12);

      expect(formatNoteDday(DateTime(2026, 6, 30), now: now), 'D-3');
      expect(formatNoteDday(DateTime(2026, 6, 25), now: now), 'D+2');
    });
  });
}
