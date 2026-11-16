import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../data/sync_metadata.dart';
import '../../features/calendar/providers.dart';

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
