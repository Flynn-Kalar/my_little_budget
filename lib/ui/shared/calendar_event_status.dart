import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/sync_metadata.dart';
import '../../features/notes/providers.dart';
import '../../features/calendar/providers.dart';

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

class CalendarEventStatus extends ConsumerWidget {
  const CalendarEventStatus({super.key, required this.event});
  final CalendarEvent event;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest =
        ref
            .watch(calendarEventsProvider)
            .value
            ?.where((e) => e.id == event.id)
            .firstOrNull ??
        event;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '기기에 저장됨 · ${[syncStatusSynced, syncStatusRemote].contains(latest.syncStatus) ? '서버 동기화됨' : '서버 동기화 미완료'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (event.notificationEnabled)
            ref
                .watch(calendarReminderStatusProvider(event.id))
                .when(
                  data: (status) => Text(
                    status,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  loading: () => const Text('알림 예약 확인 중'),
                  error: (_, _) => const Text('알림 예약 상태 확인 실패'),
                ),
        ],
      ),
    );
  }
}
