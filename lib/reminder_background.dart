import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import 'data/database.dart';
import 'features/notes/reminder_store.dart';
import 'features/notes/reminder_device_zone.dart';

/// Headless entry for boot/time changes and replenishing the rolling horizon.
Future<void> reminderBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.my_little_budget/reminder_background');
  final db = AppDatabase();
  try {
    final now = DateTime.now();
    await db.notesDao.reconcileRecurringNotes(now);
    final zone = await reminderDeviceZone(channel: channel);
    await ReminderStore(
      db,
    ).plan(await db.notesDao.listNotificationEntries(), now, zone);
    await channel.invokeMethod<void>('reschedule');
  } finally {
    await db.close();
    await channel.invokeMethod<void>('finished');
  }
}
