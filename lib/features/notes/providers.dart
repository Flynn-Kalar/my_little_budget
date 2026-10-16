import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:drift/drift.dart' show Variable;

import '../../data/providers.dart';
import '../../features/notes/note_notification_service.dart';
import '../../features/notes/checklist.dart';
import 'reminder_store.dart';

final notesProvider = StreamProvider.autoDispose<List<NoteWithChecklist>>(
  (ref) => ref.watch(notesDaoProvider).watchNotesWithChecklist(),
);

final pendingReminderCountProvider = FutureProvider<int>(
  (ref) => ref.watch(notesDaoProvider).pendingReminderCount(DateTime.now()),
);

final noteNotificationServiceProvider = Provider<NoteNotificationService>(
  (ref) => NoteNotificationService(database: ref.watch(appDatabaseProvider)),
);

final noteScheduleRevisionProvider = StateProvider<int>((ref) => 0);

final noteNotificationPermissionProvider =
    FutureProvider<NoteNotificationPermission>(
      (ref) => ref.watch(noteNotificationServiceProvider).permissionStatus(),
    );

final reminderStatusProvider = FutureProvider.autoDispose.family<String, int>((
  ref,
  id,
) async {
  ref.watch(noteScheduleRevisionProvider);
  final permission = await ref.watch(noteNotificationPermissionProvider.future);
  if (!ref.read(noteNotificationServiceProvider).isSupported) {
    return '이 기기는 알람 미지원';
  }
  final db = ref.watch(appDatabaseProvider);
  final rows = await db
      .customSelect(
        '''SELECT j.state,j.snoozed_until FROM reminder_jobs j
    JOIN reminder_occurrences o ON o.id=j.occurrence_id
    WHERE o.note_id=? AND j.state IN ('pending','scheduled','blocked','failed')
    ORDER BY COALESCE(j.snoozed_until,j.fire_at)''',
        variables: [Variable(id)],
      )
      .get();
  if (!permission.granted) return '알림·정확한 알람 권한 필요';
  if (rows.any((r) => r.read<String>('state') == 'failed')) {
    return '예약 실패 · 앱 복귀 시 재시도';
  }
  if (rows.any((r) => r.read<String>('state') == 'blocked')) {
    return '알림 권한 또는 채널 설정 확인';
  }
  if (rows.any((r) => r.readNullable<int>('snoozed_until') != null)) {
    return '다시 알림 예약됨';
  }
  if (rows.any((r) => r.read<String>('state') == 'scheduled')) return '예약됨';
  if (rows.isNotEmpty) return '예약 대기';
  return '대기 중인 알림 없음';
});

final missedReminderCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  ref.watch(noteScheduleRevisionProvider);
  final row = await ref
      .watch(appDatabaseProvider)
      .customSelect(
        "SELECT COUNT(*) AS n FROM reminder_jobs WHERE state='missed'",
      )
      .getSingle();
  return row.read<int>('n');
});

final reminderOptionsProvider = FutureProvider.autoDispose
    .family<ReminderOptions, int>((ref, id) {
      ref.watch(noteScheduleRevisionProvider);
      return ReminderStore(ref.watch(appDatabaseProvider)).options(id);
    });

void refreshReminderBadge(WidgetRef ref) {
  ref.invalidate(pendingReminderCountProvider);
}

Future<void> rebuildNoteNotifications(WidgetRef ref) async {
  final dao = ref.read(notesDaoProvider);
  final service = ref.read(noteNotificationServiceProvider);
  final revision = ref.read(noteScheduleRevisionProvider.notifier);
  ref.invalidate(noteNotificationPermissionProvider);
  try {
    await service.cleanupUnusedAudio(await dao.listNotes());
    await service.rebuild(await dao.listNotificationEntries());
  } catch (error) {
    debugPrint('note notification rebuild failed: $error');
  }
  revision.state++;
}
