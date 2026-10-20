import 'dart:math';

const syncStatusPending = 'pending';
const syncStatusSynced = 'synced';
const syncStatusRemote = 'remote';
const syncStatusRemoteDelete = 'remote_delete';

/// Local entity tables mirrored to Supabase. Relation tables are embedded in
/// their parent payload (`transactions` and `budget_groups`).
const localSyncTableNames = <String>[
  'accounts',
  'categories',
  'transactions',
  'budget_groups',
  'monthly_income',
  'investments',
  'recurring_transactions',
  'transaction_presets',
  'tags',
  'calendar_events',
  'notes',
];

/// Alarm preferences and runtime reminder state deliberately stay on-device.
const noteSyncColumns = <String>[
  'title',
  'content',
  'rich_content',
  'goal_target_amount',
  'goal_current_amount',
  'goal_start_date',
  'goal_due_date',
  'reminder_at',
  'schedule_type',
  'reset_time',
  'reset_weekday',
  'reset_weekdays',
  'reset_day_of_month',
  'interval_days',
  'anchor_date',
  'show_on_calendar',
  'completed',
  'pinned',
  'created_at',
];

const noteSeriesSyncColumns = <String>[
  'time_zone',
  'anchor_date',
  'due_date',
  'repeat_every',
  'until_date',
];

final Random _secureRandom = Random.secure();

String newSyncUuid() {
  final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
  final chars = bytes.map(hex).join();
  return '${chars.substring(0, 8)}-'
      '${chars.substring(8, 12)}-'
      '${chars.substring(12, 16)}-'
      '${chars.substring(16, 20)}-'
      '${chars.substring(20)}';
}
