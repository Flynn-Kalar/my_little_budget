import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../notes/providers.dart';

final calendarEventsProvider = StreamProvider.autoDispose<List<CalendarEvent>>(
  (ref) => ref.watch(calendarEventsDaoProvider).watchEvents(),
);

final calendarReminderStatusProvider = FutureProvider.autoDispose
    .family<String, int>((ref, id) async {
      ref.watch(noteScheduleRevisionProvider);
      final service = ref.watch(noteNotificationServiceProvider);
      if (!service.isSupported) return '이 기기의 일정 알림은 미지원';
      final permission = await ref.watch(
        noteNotificationPermissionProvider.future,
      );
      if (!permission.granted) return '알림·정확한 알람 권한 필요';
      final rows = await ref
          .watch(appDatabaseProvider)
          .customSelect(
            '''SELECT j.state,j.snoozed_until
    FROM calendar_jobs j JOIN calendar_occurrences o ON o.id=j.occurrence_id
    WHERE o.event_id=? AND j.state IN ('pending','scheduled','failed','blocked')''',
            variables: [Variable(id)],
          )
          .get();
      if (rows.any((r) => r.read<String>('state') == 'failed')) {
        return '알림 예약 실패 · 앱 복귀 시 재시도';
      }
      if (rows.any((r) => r.read<String>('state') == 'blocked')) {
        return '알림 권한 또는 채널 설정 확인';
      }
      if (rows.any((r) => r.readNullable<int>('snoozed_until') != null)) {
        return '다시 알림 예약됨';
      }
      if (rows.any((r) => r.read<String>('state') == 'scheduled')) {
        return '알림 예약됨';
      }
      return rows.isEmpty ? '대기 중인 알림 없음' : '알림 예약 대기';
    });

void refreshCalendarEvents(WidgetRef ref) {
  ref.invalidate(calendarEventsProvider);
}
