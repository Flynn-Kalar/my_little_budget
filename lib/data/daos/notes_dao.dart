import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../features/notes/checklist.dart';
import '../../features/notes/note_alarm.dart';
import '../../features/notes/note_schedule.dart';
import '../../features/notes/rich_note.dart';
import '../database.dart';
import '../tables/note_checklist_items.dart';
import '../tables/notes.dart';

part 'notes_dao.g.dart';

@DriftAccessor(tables: [Notes, NoteChecklistItems])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  Stream<List<Note>> watchNotes() {
    return (select(notes)..orderBy([
          (n) => OrderingTerm(expression: n.pinned, mode: OrderingMode.desc),
          (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Stream<List<NoteWithChecklist>> watchNotesWithChecklist() {
    final query = select(notes).join([
      leftOuterJoin(
        noteChecklistItems,
        noteChecklistItems.noteId.equalsExp(notes.id),
      ),
    ]);
    return query.watch().map((rows) {
      final grouped = <int, NoteWithChecklist>{};
      for (final row in rows) {
        final note = row.readTable(notes);
        final item = row.readTableOrNull(noteChecklistItems);
        final entry = grouped.putIfAbsent(
          note.id,
          () => NoteWithChecklist(note: note, items: []),
        );
        if (item != null) entry.items.add(item);
      }
      final result = grouped.values.toList();
      for (final entry in result) {
        entry.items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      }
      result.sort((a, b) {
        final pinned = (b.note.pinned ? 1 : 0).compareTo(a.note.pinned ? 1 : 0);
        if (pinned != 0) return pinned;
        return b.note.updatedAt.compareTo(a.note.updatedAt);
      });
      return result;
    });
  }

  Future<int> pendingReminderCount(DateTime now) async {
    final cutoff = now.toUtc().toIso8601String();
    final row = await customSelect(
      '''
SELECT COUNT(*) AS total
FROM notes n
WHERE (
  n.schedule_type IN (
    'daily', 'weekly', 'weekdays', 'weekends', 'monthly', 'yearly', 'interval'
  )
  OR (n.schedule_type = 'once' AND n.reminder_at IS NOT NULL AND n.reminder_at <= ?)
)
AND EXISTS (
  SELECT 1 FROM note_checklist_items i
  WHERE i.note_id = n.id AND i.is_checked = 0
)
''',
      variables: [Variable<String>(cutoff)],
      readsFrom: {notes, noteChecklistItems},
    ).getSingle();
    return row.read<int>('total');
  }

  Future<int> saveNote({
    int? id,
    required String title,
    required String content,
    String? richContent,
    DateTime? reminderAt,
    NoteScheduleDraft? schedule,
    List<ChecklistItemDraft>? checklistItems,
    bool completed = false,
    bool pinned = false,
    bool showOnCalendar = false,
    NoteAlarmSettings alarmSettings = const NoteAlarmSettings(),
  }) {
    final effectiveItems =
        checklistItems ??
        (richContent == null ? null : _itemsFromRich(richContent));
    final normalizedItems = effectiveItems == null
        ? null
        : normalizeChecklistItems(effectiveItems);
    return transaction(() async {
      final noteId = await _saveNoteRow(
        id: id,
        title: title,
        content: content,
        richContent: richContent,
        reminderAt: reminderAt,
        schedule: schedule,
        completed: completed,
        pinned: pinned,
        showOnCalendar: showOnCalendar,
        alarmSettings: alarmSettings,
      );
      if (normalizedItems != null) {
        await _saveChecklistItems(noteId, normalizedItems);
      }
      return noteId;
    });
  }

  Future<int> _saveNoteRow({
    required int? id,
    required String title,
    required String content,
    required String? richContent,
    required DateTime? reminderAt,
    required NoteScheduleDraft? schedule,
    required bool completed,
    required bool pinned,
    required bool showOnCalendar,
    required NoteAlarmSettings alarmSettings,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', '제목을 입력하세요.');
    }
    final effectiveSchedule =
        schedule ??
        NoteScheduleDraft(
          type: reminderAt == null
              ? NoteScheduleType.none
              : NoteScheduleType.once,
          oneTimeAt: reminderAt,
          notificationEnabled: reminderAt != null,
        );
    final scheduleError = validateNoteSchedule(effectiveSchedule);
    if (scheduleError != null) throw ArgumentError(scheduleError, 'schedule');
    final localNow = DateTime.now();
    final now = localNow.toUtc().toIso8601String();
    final reminder = effectiveSchedule.type == NoteScheduleType.once
        ? effectiveSchedule.oneTimeAt?.toUtc().toIso8601String()
        : null;
    final nextReset = nextNoteResetAfter(
      effectiveSchedule,
      localNow,
    )?.toUtc().toIso8601String();
    final scheduleCompanion = _scheduleCompanion(
      effectiveSchedule,
      reminder: reminder,
      nextReset: nextReset,
    );
    if (id == null) {
      return into(notes).insert(
        NotesCompanion.insert(
          title: normalizedTitle,
          content: Value(content.trim()),
          richContent: Value(richContent),
          completed: Value(completed),
          pinned: Value(pinned),
          showOnCalendar: Value(showOnCalendar),
          alarmSoundKind: Value(alarmSettings.soundKind.name),
          alarmSoundUri: Value(alarmSettings.soundUri),
          alarmSoundName: Value(alarmSettings.soundName),
          alarmClipStartMs: Value(alarmSettings.clipStartMs),
          alarmClipEndMs: Value(alarmSettings.clipEndMs),
          alarmVibrationEnabled: Value(alarmSettings.vibrationEnabled),
        ).copyWith(
          reminderAt: scheduleCompanion.reminderAt,
          scheduleType: scheduleCompanion.scheduleType,
          resetTime: scheduleCompanion.resetTime,
          notificationEnabled: scheduleCompanion.notificationEnabled,
          notificationTime: scheduleCompanion.notificationTime,
          notificationDaysBefore: scheduleCompanion.notificationDaysBefore,
          notificationExtraDaysBefore:
              scheduleCompanion.notificationExtraDaysBefore,
          notificationLeadMinutes: scheduleCompanion.notificationLeadMinutes,
          resetWeekday: scheduleCompanion.resetWeekday,
          resetWeekdays: scheduleCompanion.resetWeekdays,
          resetDayOfMonth: scheduleCompanion.resetDayOfMonth,
          intervalDays: scheduleCompanion.intervalDays,
          anchorDate: scheduleCompanion.anchorDate,
          nextResetAt: scheduleCompanion.nextResetAt,
          snoozeMinutes: scheduleCompanion.snoozeMinutes,
        ),
      );
    }
    await (update(notes)..where((n) => n.id.equals(id))).write(
      scheduleCompanion.copyWith(
        title: Value(normalizedTitle),
        content: Value(content.trim()),
        richContent: Value(richContent),
        pinned: Value(pinned),
        showOnCalendar: Value(showOnCalendar),
        updatedAt: Value(now),
        alarmSoundKind: Value(alarmSettings.soundKind.name),
        alarmSoundUri: Value(alarmSettings.soundUri),
        alarmSoundName: Value(alarmSettings.soundName),
        alarmClipStartMs: Value(alarmSettings.clipStartMs),
        alarmClipEndMs: Value(alarmSettings.clipEndMs),
        alarmVibrationEnabled: Value(alarmSettings.vibrationEnabled),
      ),
    );
    return id;
  }

  Future<void> _saveChecklistItems(
    int noteId,
    List<ChecklistItemDraft> drafts,
  ) async {
    final existing = await (select(
      noteChecklistItems,
    )..where((item) => item.noteId.equals(noteId))).get();
    final existingIds = existing.map((item) => item.id).toSet();
    final keptIds = drafts
        .map((item) => item.id)
        .whereType<int>()
        .where(existingIds.contains)
        .toSet();
    final deleteQuery = delete(noteChecklistItems)
      ..where((item) => item.noteId.equals(noteId));
    if (keptIds.isEmpty) {
      await deleteQuery.go();
    } else {
      deleteQuery.where((item) => item.id.isNotIn(keptIds));
      await deleteQuery.go();
    }

    final now = DateTime.now().toUtc().toIso8601String();
    for (var index = 0; index < drafts.length; index++) {
      final draft = drafts[index];
      if (draft.id != null && existingIds.contains(draft.id)) {
        await (update(
          noteChecklistItems,
        )..where((item) => item.id.equals(draft.id!))).write(
          NoteChecklistItemsCompanion(
            itemText: Value(draft.text),
            isChecked: Value(draft.isChecked),
            sortOrder: Value(index),
            updatedAt: Value(now),
          ),
        );
      } else {
        await into(noteChecklistItems).insert(
          NoteChecklistItemsCompanion.insert(
            noteId: noteId,
            itemText: draft.text,
            isChecked: Value(draft.isChecked),
            sortOrder: Value(index),
          ),
        );
      }
    }
  }

  Future<void> toggleChecklistItem(int itemId, bool isChecked) async {
    await transaction(() async {
      final item = await (select(
        noteChecklistItems,
      )..where((row) => row.id.equals(itemId))).getSingleOrNull();
      if (item == null) return;
      final now = DateTime.now().toUtc().toIso8601String();
      await (update(
        noteChecklistItems,
      )..where((row) => row.id.equals(itemId))).write(
        NoteChecklistItemsCompanion(
          isChecked: Value(isChecked),
          updatedAt: Value(now),
        ),
      );
      final siblings =
          await (select(noteChecklistItems)
                ..where((row) => row.noteId.equals(item.noteId))
                ..orderBy([(row) => OrderingTerm(expression: row.sortOrder)]))
              .get();
      final index = siblings.indexWhere((row) => row.id == itemId);
      final note = await (select(
        notes,
      )..where((row) => row.id.equals(item.noteId))).getSingleOrNull();
      if (note == null || index < 0) return;
      final rich = setChecklistStateInRichContent(
        note.richContent,
        checklistIndex: index,
        isChecked: isChecked,
      );
      await (update(notes)..where((note) => note.id.equals(item.noteId))).write(
        NotesCompanion(richContent: Value(rich), updatedAt: Value(now)),
      );
    });
  }

  Future<void> reorderChecklistItems(int noteId, List<int> orderedIds) async {
    await transaction(() async {
      for (var index = 0; index < orderedIds.length; index++) {
        await (update(noteChecklistItems)..where(
              (item) =>
                  item.noteId.equals(noteId) &
                  item.id.equals(orderedIds[index]),
            ))
            .write(NoteChecklistItemsCompanion(sortOrder: Value(index)));
      }
      await (update(notes)..where((note) => note.id.equals(noteId))).write(
        NotesCompanion(
          updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
        ),
      );
    });
  }

  /// Legacy compatibility only. Checklist UIs don't use note-level completion.
  Future<void> setCompleted(int id, bool completed) async {
    await (update(notes)..where((note) => note.id.equals(id))).write(
      NotesCompanion(
        completed: Value(completed),
        updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
      ),
    );
  }

  Future<void> setPinned(int id, bool pinned) async {
    await (update(notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        pinned: Value(pinned),
        updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
      ),
    );
  }

  Future<int> deleteNote(int id) {
    return (delete(notes)..where((n) => n.id.equals(id))).go();
  }

  Future<Note?> getNote(int id) {
    return (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();
  }

  Future<NoteWithChecklist?> getNoteWithChecklist(int id) async {
    final note = await getNote(id);
    if (note == null) return null;
    final items =
        await (select(noteChecklistItems)
              ..where((item) => item.noteId.equals(id))
              ..orderBy([(item) => OrderingTerm(expression: item.sortOrder)]))
            .get();
    return NoteWithChecklist(note: note, items: items);
  }

  Future<List<Note>> listNotificationNotes() {
    return (select(notes)..where(
          (n) =>
              n.notificationEnabled.equals(true) &
              n.scheduleType.isNotValue(NoteScheduleType.none.storageValue),
        ))
        .get();
  }

  Future<List<NoteWithChecklist>> listNotificationEntries() async {
    final noteRows = await listNotificationNotes();
    final result = <NoteWithChecklist>[];
    for (final note in noteRows) {
      final items =
          await (select(noteChecklistItems)
                ..where((item) => item.noteId.equals(note.id))
                ..orderBy([(item) => OrderingTerm(expression: item.sortOrder)]))
              .get();
      result.add(NoteWithChecklist(note: note, items: items));
    }
    return result;
  }

  Future<List<Note>> listNotes() => select(notes).get();

  Future<int> reconcileRecurringNotes(DateTime now) async {
    final cutoff = now.toUtc().toIso8601String();
    final due =
        await (select(notes)..where(
              (n) =>
                  n.scheduleType.isIn(
                    NoteScheduleType.values
                        .where((type) => type.isRepeating)
                        .map((type) => type.storageValue),
                  ) &
                  n.nextResetAt.isNotNull() &
                  n.nextResetAt.isSmallerOrEqualValue(cutoff),
            ))
            .get();
    if (due.isEmpty) return 0;

    await transaction(() async {
      for (final note in due) {
        final next = nextNoteResetAfter(noteScheduleFromNote(note), now);
        await (update(
          noteChecklistItems,
        )..where((item) => item.noteId.equals(note.id))).write(
          NoteChecklistItemsCompanion(
            isChecked: const Value(false),
            updatedAt: Value(now.toUtc().toIso8601String()),
          ),
        );
        await (update(notes)..where((n) => n.id.equals(note.id))).write(
          NotesCompanion(
            richContent: Value(uncheckedChecklistRichContent(note.richContent)),
            nextResetAt: Value(next?.toUtc().toIso8601String()),
            updatedAt: Value(now.toUtc().toIso8601String()),
          ),
        );
      }
    });
    return due.length;
  }

  Future<DateTime?> earliestNextReset() async {
    final row =
        await (select(notes)
              ..where((n) => n.nextResetAt.isNotNull())
              ..orderBy([(n) => OrderingTerm(expression: n.nextResetAt)])
              ..limit(1))
            .getSingleOrNull();
    return row?.nextResetAt == null
        ? null
        : DateTime.tryParse(row!.nextResetAt!)?.toLocal();
  }
}

List<ChecklistItemDraft> _itemsFromRich(String richContent) {
  try {
    return checklistFromDocument(
      Document.fromJson(jsonDecode(richContent) as List),
    );
  } catch (_) {
    return const [];
  }
}

NoteScheduleDraft noteScheduleFromNote(Note note) {
  return NoteScheduleDraft(
    type: NoteScheduleTypeStorage.parse(note.scheduleType),
    oneTimeAt: note.reminderAt == null
        ? null
        : DateTime.tryParse(note.reminderAt!)?.toLocal(),
    resetTime: note.resetTime,
    notificationEnabled: note.notificationEnabled,
    notificationTime: note.notificationTime,
    notificationDaysBefore: note.notificationDaysBefore,
    notificationExtraDaysBefore: parseNoteIntList(
      note.notificationExtraDaysBefore,
    ),
    notificationLeadMinutes: parseNoteIntList(note.notificationLeadMinutes),
    weekday: note.resetWeekday,
    weekdays: parseNoteIntList(note.resetWeekdays),
    dayOfMonth: note.resetDayOfMonth,
    intervalDays: note.intervalDays,
    anchorDate: note.anchorDate,
    snoozeMinutes: note.snoozeMinutes,
  );
}

NotesCompanion _scheduleCompanion(
  NoteScheduleDraft schedule, {
  required String? reminder,
  required String? nextReset,
}) {
  return NotesCompanion(
    reminderAt: Value(reminder),
    scheduleType: Value(schedule.type.storageValue),
    resetTime: Value(schedule.isRepeating ? schedule.resetTime : null),
    notificationEnabled: Value(schedule.notificationEnabled),
    notificationTime: Value(
      schedule.isRepeating && schedule.notificationEnabled
          ? schedule.notificationTime
          : null,
    ),
    notificationDaysBefore: Value(
      schedule.isRepeating && schedule.notificationEnabled
          ? schedule.notificationDaysBefore
          : 0,
    ),
    notificationExtraDaysBefore: Value(
      schedule.isRepeating && schedule.notificationEnabled
          ? encodeNoteIntList(schedule.notificationExtraDaysBefore)
          : '',
    ),
    notificationLeadMinutes: Value(
      schedule.type == NoteScheduleType.once && schedule.notificationEnabled
          ? encodeNoteIntList(schedule.notificationLeadMinutes)
          : '',
    ),
    resetWeekday: Value(
      schedule.type == NoteScheduleType.weekly &&
              schedule.effectiveWeekdays.isNotEmpty
          ? schedule.effectiveWeekdays.first
          : null,
    ),
    resetWeekdays: Value(
      schedule.type == NoteScheduleType.weekly
          ? encodeNoteIntList(schedule.effectiveWeekdays)
          : null,
    ),
    resetDayOfMonth: Value(
      schedule.type == NoteScheduleType.monthly ||
              schedule.type == NoteScheduleType.yearly
          ? schedule.dayOfMonth
          : null,
    ),
    intervalDays: Value(
      schedule.type == NoteScheduleType.interval ? schedule.intervalDays : null,
    ),
    anchorDate: Value(
      schedule.type == NoteScheduleType.interval ||
              schedule.type == NoteScheduleType.yearly
          ? schedule.anchorDate
          : null,
    ),
    nextResetAt: Value(nextReset),
    snoozeMinutes: Value(schedule.snoozeMinutes),
  );
}
