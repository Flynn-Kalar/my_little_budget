import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/notes/note_schedule.dart';

void main() {
  group('반복 메모 일정 계산', () {
    test('매일 리셋은 같은 날 경계 전후를 구분한다', () {
      const schedule = NoteScheduleDraft(
        type: NoteScheduleType.daily,
        resetTime: '06:00',
      );
      expect(
        nextNoteResetAfter(schedule, DateTime(2026, 6, 21, 5, 59)),
        DateTime(2026, 6, 21, 6),
      );
      expect(
        nextNoteResetAfter(schedule, DateTime(2026, 6, 21, 6)),
        DateTime(2026, 6, 22, 6),
      );
    });

    test('매주 지정 요일과 시각을 계산한다', () {
      const schedule = NoteScheduleDraft(
        type: NoteScheduleType.weekly,
        resetTime: '09:30',
        weekday: DateTime.monday,
      );
      expect(
        nextNoteResetAfter(schedule, DateTime(2026, 6, 21, 12)),
        DateTime(2026, 6, 22, 9, 30),
      );
    });

    test('매월 31일은 해당 달 말일로 보정한다', () {
      const schedule = NoteScheduleDraft(
        type: NoteScheduleType.monthly,
        resetTime: '00:00',
        dayOfMonth: 31,
      );
      expect(
        nextNoteResetAfter(schedule, DateTime(2028, 2, 1)),
        DateTime(2028, 2, 29),
      );
    });

    test('N일 일정은 기준일부터 달력 날짜 간격으로 계산한다', () {
      const schedule = NoteScheduleDraft(
        type: NoteScheduleType.interval,
        resetTime: '08:00',
        intervalDays: 3,
        anchorDate: '2026-06-01',
      );
      expect(
        nextNoteResetAfter(schedule, DateTime(2026, 6, 7, 8)),
        DateTime(2026, 6, 10, 8),
      );
    });

    test('당일 알림은 리셋 시각보다 빠를 수 없다', () {
      const schedule = NoteScheduleDraft(
        type: NoteScheduleType.daily,
        resetTime: '09:00',
        notificationEnabled: true,
        notificationTime: '08:59',
      );
      expect(validateNoteSchedule(schedule), contains('리셋 시각 이후'));
    });

    test('알림 시각은 현재 주기의 다음 알림을 선택한다', () {
      const schedule = NoteScheduleDraft(
        type: NoteScheduleType.daily,
        resetTime: '00:00',
        notificationEnabled: true,
        notificationTime: '09:00',
      );
      expect(
        nextNoteNotificationAfter(schedule, DateTime(2026, 6, 21, 8)),
        DateTime(2026, 6, 21, 9),
      );
    });

    test('매주 리셋 N일 전 알림을 계산한다', () {
      const schedule = NoteScheduleDraft(
        type: NoteScheduleType.weekly,
        resetTime: '08:00',
        notificationEnabled: true,
        notificationTime: '09:00',
        notificationDaysBefore: 1,
        weekday: DateTime.monday,
      );
      expect(
        nextNoteNotificationAfter(schedule, DateTime(2026, 6, 21, 8)),
        DateTime(2026, 6, 21, 9),
      );
    });

    test('매월 리셋 N일 전 알림을 계산한다', () {
      const schedule = NoteScheduleDraft(
        type: NoteScheduleType.monthly,
        resetTime: '08:00',
        notificationEnabled: true,
        notificationTime: '09:00',
        notificationDaysBefore: 3,
        dayOfMonth: 25,
      );
      expect(
        nextNoteNotificationAfter(schedule, DateTime(2026, 6, 20, 12)),
        DateTime(2026, 6, 22, 9),
      );
    });

    test('N일 반복 리셋 N일 전 알림을 계산한다', () {
      const schedule = NoteScheduleDraft(
        type: NoteScheduleType.interval,
        resetTime: '08:00',
        notificationEnabled: true,
        notificationTime: '09:00',
        notificationDaysBefore: 2,
        intervalDays: 5,
        anchorDate: '2026-06-01',
      );
      expect(
        nextNoteNotificationAfter(schedule, DateTime(2026, 6, 3, 8)),
        DateTime(2026, 6, 4, 9),
      );
    });
    test('multiple weekly weekdays choose the nearest selected day', () {
      const schedule = NoteScheduleDraft(
        type: NoteScheduleType.weekly,
        resetTime: '08:00',
        weekdays: [DateTime.monday, DateTime.wednesday],
      );
      expect(
        nextNoteResetAfter(schedule, DateTime(2026, 6, 22, 8)),
        DateTime(2026, 6, 24, 8),
      );
    });

    test('weekday and weekend presets calculate from the preset days', () {
      const weekdays = NoteScheduleDraft(
        type: NoteScheduleType.weekdays,
        resetTime: '09:00',
      );
      const weekends = NoteScheduleDraft(
        type: NoteScheduleType.weekends,
        resetTime: '09:00',
      );
      expect(
        nextNoteResetAfter(weekdays, DateTime(2026, 6, 26, 9)),
        DateTime(2026, 6, 29, 9),
      );
      expect(
        nextNoteResetAfter(weekends, DateTime(2026, 6, 26, 9)),
        DateTime(2026, 6, 27, 9),
      );
    });

    test('yearly reset uses the anchor month and requested day', () {
      const schedule = NoteScheduleDraft(
        type: NoteScheduleType.yearly,
        resetTime: '07:30',
        dayOfMonth: 29,
        anchorDate: '2024-02-01',
      );
      expect(
        nextNoteResetAfter(schedule, DateTime(2026, 3, 1)),
        DateTime(2027, 2, 28, 7, 30),
      );
    });

    test('extra notification days are included in occurrence selection', () {
      const schedule = NoteScheduleDraft(
        type: NoteScheduleType.monthly,
        resetTime: '08:00',
        notificationEnabled: true,
        notificationTime: '09:00',
        notificationDaysBefore: 1,
        notificationExtraDaysBefore: [3],
        dayOfMonth: 25,
      );
      expect(
        nextNoteNotificationAfter(schedule, DateTime(2026, 6, 20, 12)),
        DateTime(2026, 6, 22, 9),
      );
      expect(
        nextNoteNotificationAfter(schedule, DateTime(2026, 6, 22, 9)),
        DateTime(2026, 6, 24, 9),
      );
    });

    test('one time reminders can schedule multiple lead notifications', () {
      final schedule = NoteScheduleDraft(
        type: NoteScheduleType.once,
        oneTimeAt: DateTime(2026, 6, 26, 12),
        notificationEnabled: true,
        notificationLeadMinutes: const [10, 60],
      );
      expect(
        oneTimeNotificationOccurrences(
          schedule,
          from: DateTime(2026, 6, 26, 10),
        ),
        [
          DateTime(2026, 6, 26, 11),
          DateTime(2026, 6, 26, 11, 50),
          DateTime(2026, 6, 26, 12),
        ],
      );
    });
  });
}
