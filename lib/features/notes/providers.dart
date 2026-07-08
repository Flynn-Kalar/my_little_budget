import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/providers.dart';
import '../../features/notes/note_notification_service.dart';
import '../../features/notes/checklist.dart';

final notesProvider = StreamProvider.autoDispose<List<NoteWithChecklist>>(
  (ref) => ref.watch(notesDaoProvider).watchNotesWithChecklist(),
);

final pendingReminderCountProvider = FutureProvider<int>(
  (ref) => ref.watch(notesDaoProvider).pendingReminderCount(DateTime.now()),
);

final noteNotificationServiceProvider = Provider<NoteNotificationService>(
  (ref) => NoteNotificationService(),
);

final noteScheduleRevisionProvider = StateProvider<int>((ref) => 0);

final noteNotificationPermissionProvider =
    FutureProvider<NoteNotificationPermission>(
      (ref) => ref.watch(noteNotificationServiceProvider).permissionStatus(),
    );

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
