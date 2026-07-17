import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../features/notes/checklist.dart';
import '../../../features/notes/note_alarm.dart';
import '../../../features/notes/note_format.dart';
import '../../../features/notes/rich_note.dart';
import '../../../features/notes/note_schedule.dart';
import 'package:my_little_budget/features/notes/providers.dart';
import '../../shared/rich_note_editor.dart';
import '../mobile_widgets.dart';

enum _MobileNoteFilter { all, inProgress, completed }

class MobileNotesScreen extends ConsumerStatefulWidget {
  const MobileNotesScreen({super.key, this.openNoteId, this.openRequest});

  final int? openNoteId;
  final String? openRequest;

  @override
  ConsumerState<MobileNotesScreen> createState() => _MobileNotesScreenState();
}

class _MobileNotesScreenState extends ConsumerState<MobileNotesScreen> {
  final _search = TextEditingController();
  _MobileNoteFilter _filter = _MobileNoteFilter.all;
  String? _openedRequest;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openRequestedNote(List<NoteWithChecklist> notes) {
    final id = widget.openNoteId;
    if (id == null || widget.openRequest == _openedRequest) return;
    final entry = notes.where((item) => item.note.id == id).firstOrNull;
    if (entry == null) return;
    _openedRequest = widget.openRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _MobileNoteSheet.show(context, entry: entry);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    return MobilePageScaffold(
      title: '메모장',
      actions: [
        FilledButton.tonalIcon(
          key: const ValueKey('mobile-notes-calendar-button'),
          onPressed: () {
            context.push('/calendar');
          },
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: const Text('캘린더'),
        ),
      ],
      onAdd: () => _MobileNoteSheet.show(context),
      addTooltip: '새 메모',
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: '메모 검색',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<_MobileNoteFilter>(
            segments: const [
              ButtonSegment(value: _MobileNoteFilter.all, label: Text('전체')),
              ButtonSegment(
                value: _MobileNoteFilter.inProgress,
                label: Text('진행 중'),
              ),
              ButtonSegment(
                value: _MobileNoteFilter.completed,
                label: Text('완료'),
              ),
            ],
            selected: {_filter},
            onSelectionChanged: (value) =>
                setState(() => _filter = value.first),
          ),
        ),
        const SizedBox(height: 8),
        MobileAsync(
          value: notes,
          builder: (value) {
            _openRequestedNote(value);
            final query = _search.text.trim().toLowerCase();
            final filtered = value.where((entry) {
              final note = entry.note;
              final matchesQuery =
                  query.isEmpty ||
                  note.title.toLowerCase().contains(query) ||
                  note.content.toLowerCase().contains(query);
              final matchesFilter = switch (_filter) {
                _MobileNoteFilter.all => true,
                _MobileNoteFilter.inProgress =>
                  entry.hasChecklist && entry.hasIncompleteItems,
                _MobileNoteFilter.completed => entry.isChecklistComplete,
              };
              return matchesQuery && matchesFilter;
            }).toList();
            if (filtered.isEmpty) {
              return const EmptyMobileCard('표시할 메모가 없습니다.');
            }
            return Column(
              children: [
                for (final entry in filtered) _MobileNoteCard(entry: entry),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MobileNoteCard extends ConsumerWidget {
  const _MobileNoteCard({required this.entry});

  final NoteWithChecklist entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = entry.note;
    final nextReset = noteNextResetDate(note);
    final ddayDate = noteDdayDate(note);
    final overdue = isNoteOverdue(
      note,
      hasIncompleteItems: entry.hasIncompleteItems,
    );
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MobileCard(
        child: InkWell(
          onTap: () => _MobileNoteSheet.show(context, entry: entry),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: note.pinned ? '고정 해제' : '상단 고정',
                    onPressed: () async {
                      await ref
                          .read(notesDaoProvider)
                          .setPinned(note.id, !note.pinned);
                    },
                    icon: Icon(
                      note.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 19,
                    ),
                  ),
                ],
              ),
              if (note.content.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  note.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    height: 1.4,
                    color: colors.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ],
              if (entry.hasChecklist) ...[
                const SizedBox(height: 10),
                Text(
                  '${entry.checkedCount}/${entry.totalCount} 완료',
                  style: TextStyle(
                    color: entry.isChecklistComplete
                        ? colors.primary
                        : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (note.scheduleType != 'none') ...[
                const SizedBox(height: 12),
                if (ddayDate != null)
                  _MobileScheduleLine(
                    icon: Icons.event_available_outlined,
                    text:
                        '${formatNoteDday(ddayDate)} · ${formatNoteReminder(ddayDate)}',
                    color: overdue ? colors.error : colors.primary,
                  ),
                _MobileScheduleLine(
                  icon: overdue
                      ? Icons.notification_important
                      : Icons.restart_alt,
                  text: noteScheduleSummary(note),
                  color: overdue ? colors.error : colors.primary,
                ),
                if (nextReset != null)
                  _MobileScheduleLine(
                    icon: Icons.update,
                    text: '다음 리셋 ${formatNoteReminder(nextReset)}',
                    color: colors.onSurfaceVariant,
                  ),
                if (note.notificationEnabled)
                  _MobileScheduleLine(
                    icon: Icons.notifications_active_outlined,
                    text: noteNotificationSummary(note),
                    color: colors.onSurfaceVariant,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileScheduleLine extends StatelessWidget {
  const _MobileScheduleLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}

class _MobileNoteSheet extends ConsumerStatefulWidget {
  const _MobileNoteSheet({this.entry});

  final NoteWithChecklist? entry;

  static Future<void> show(BuildContext context, {NoteWithChecklist? entry}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MobileNoteSheet(entry: entry),
    );
  }

  @override
  ConsumerState<_MobileNoteSheet> createState() => _MobileNoteSheetState();
}

class _MobileNoteSheetState extends ConsumerState<_MobileNoteSheet> {
  late NoteWithChecklist? _entry = widget.entry;
  Note? get _note => _entry?.note;

  late final _title = TextEditingController(text: _note?.title ?? '');
  late final _richController = QuillController(
    document: _note == null ? Document() : documentFromNote(_note!),
    selection: const TextSelection.collapsed(offset: 0),
  );
  final _richFocus = FocusNode();
  final _richScroll = ScrollController();
  late final _dayOfMonth = TextEditingController(
    text: '${_note?.resetDayOfMonth ?? 1}',
  );
  late final _intervalDays = TextEditingController(
    text: '${_note?.intervalDays ?? 7}',
  );
  late final _notificationDaysBefore = TextEditingController(
    text: '${_note?.notificationDaysBefore ?? 0}',
  );
  late final _notificationExtraDaysBefore = TextEditingController(
    text: parseNoteIntList(_note?.notificationExtraDaysBefore).join(', '),
  );
  late final _notificationLeadMinutes = TextEditingController(
    text: parseNoteIntList(_note?.notificationLeadMinutes).join(', '),
  );
  late final _snoozeMinutes = TextEditingController(
    text: '${_note?.snoozeMinutes ?? 0}',
  );
  late NoteScheduleType _scheduleType = _note == null
      ? NoteScheduleType.none
      : NoteScheduleTypeStorage.parse(_note!.scheduleType);
  late DateTime? _oneTimeAt = _note == null ? null : noteReminderDate(_note!);
  late String _resetTime = _note?.resetTime ?? '00:00';
  late String _notificationTime = _note?.notificationTime ?? '09:00';
  late bool _notificationEnabled = _note?.notificationEnabled ?? false;
  late int _weekday = _note?.resetWeekday ?? DateTime.monday;
  late Set<int> _weekdays = parseNoteIntList(_note?.resetWeekdays).toSet();
  late DateTime _anchorDate =
      parseNoteDate(_note?.anchorDate) ?? DateTime.now();
  late bool _pinned = _note?.pinned ?? false;
  late bool _showOnCalendar = _note?.showOnCalendar ?? false;
  late NoteAlarmSettings _alarmSettings = _note == null
      ? const NoteAlarmSettings()
      : noteAlarmSettingsFromNote(_note!);
  int? _audioDurationMs;
  bool _busy = false;
  late bool _editing = _entry == null;
  String? _error;

  @override
  void initState() {
    super.initState();
    final uri = _alarmSettings.soundUri;
    if (uri != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final duration = await ref
            .read(noteNotificationServiceProvider)
            .audioDuration(uri);
        if (mounted) setState(() => _audioDurationMs = duration);
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _richController.dispose();
    _richFocus.dispose();
    _richScroll.dispose();
    _dayOfMonth.dispose();
    _intervalDays.dispose();
    _notificationDaysBefore.dispose();
    _notificationExtraDaysBefore.dispose();
    _notificationLeadMinutes.dispose();
    _snoozeMinutes.dispose();
    super.dispose();
  }

  Future<void> _pickOneTime() async {
    final initial = _oneTimeAt ?? DateTime.now().add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: _force24HourTimePicker,
    );
    if (time == null) return;
    setState(() {
      _oneTimeAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickTime({required bool notification}) async {
    final parsed =
        parseNoteTime(notification ? _notificationTime : _resetTime) ?? (0, 0);
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: parsed.$1, minute: parsed.$2),
      builder: _force24HourTimePicker,
    );
    if (selected == null) return;
    final value = noteTimeKey(
      DateTime(2000, 1, 1, selected.hour, selected.minute),
    );
    setState(() {
      if (notification) {
        _notificationTime = value;
      } else {
        _resetTime = value;
      }
    });
  }

  Future<void> _pickAnchorDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null) setState(() => _anchorDate = selected);
  }

  Future<void> _pickSystemSound() async {
    final picked = await ref
        .read(noteNotificationServiceProvider)
        .pickSystemAlarmSound();
    if (picked == null || !mounted) return;
    setState(() {
      _alarmSettings = NoteAlarmSettings(
        soundKind: NoteAlarmSoundKind.system,
        soundUri: picked.uri,
        soundName: picked.name,
        vibrationEnabled: _alarmSettings.vibrationEnabled,
        snoozeMinutes: _alarmSettings.snoozeMinutes,
      );
      _audioDurationMs = picked.durationMs;
    });
  }

  Future<void> _pickCustomSound() async {
    final picked = await FilePicker.pickFiles(type: FileType.audio);
    final sourcePath = picked?.files.single.path;
    if (sourcePath == null) return;
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}note_alarm_audio',
    );
    await directory.create(recursive: true);
    final originalName = picked!.files.single.name;
    final extension = originalName.contains('.')
        ? '.${originalName.split('.').last}'
        : '';
    final target = File(
      '${directory.path}${Platform.pathSeparator}${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await File(sourcePath).copy(target.path);
    final uri = target.uri.toString();
    final duration = await ref
        .read(noteNotificationServiceProvider)
        .audioDuration(uri);
    if (!mounted) return;
    setState(() {
      _audioDurationMs = duration;
      _alarmSettings = NoteAlarmSettings(
        soundKind: NoteAlarmSoundKind.custom,
        soundUri: uri,
        soundName: originalName,
        clipEndMs: duration,
        vibrationEnabled: _alarmSettings.vibrationEnabled,
        snoozeMinutes: _alarmSettings.snoozeMinutes,
      );
    });
  }

  void _restoreDraftAndEdit() {
    final entry = _entry;
    if (entry == null) return;
    final note = entry.note;
    setState(() {
      _title.text = note.title;
      _richController.document = documentFromNote(note);
      _dayOfMonth.text = '${note.resetDayOfMonth ?? 1}';
      _intervalDays.text = '${note.intervalDays ?? 7}';
      _notificationDaysBefore.text = '${note.notificationDaysBefore}';
      _notificationExtraDaysBefore.text = parseNoteIntList(
        note.notificationExtraDaysBefore,
      ).join(', ');
      _notificationLeadMinutes.text = parseNoteIntList(
        note.notificationLeadMinutes,
      ).join(', ');
      _snoozeMinutes.text = '${note.snoozeMinutes}';
      _scheduleType = NoteScheduleTypeStorage.parse(note.scheduleType);
      _oneTimeAt = noteReminderDate(note);
      _resetTime = note.resetTime ?? '00:00';
      _notificationTime = note.notificationTime ?? '09:00';
      _notificationEnabled = note.notificationEnabled;
      _weekday = note.resetWeekday ?? DateTime.monday;
      _weekdays = parseNoteIntList(note.resetWeekdays).toSet();
      _anchorDate = parseNoteDate(note.anchorDate) ?? DateTime.now();
      _pinned = note.pinned;
      _showOnCalendar = note.showOnCalendar;
      _alarmSettings = noteAlarmSettingsFromNote(note);
      _error = null;
      _editing = true;
    });
  }

  NoteScheduleDraft _schedule() => NoteScheduleDraft(
    type: _scheduleType,
    oneTimeAt: _oneTimeAt,
    resetTime: _resetTime,
    notificationEnabled: _notificationEnabled,
    notificationTime: _notificationTime,
    notificationDaysBefore: _scheduleType == NoteScheduleType.daily
        ? 0
        : int.tryParse(_notificationDaysBefore.text) ?? 0,
    notificationExtraDaysBefore: _scheduleType == NoteScheduleType.daily
        ? const []
        : parseNoteIntList(_notificationExtraDaysBefore.text),
    notificationLeadMinutes: parseNoteIntList(_notificationLeadMinutes.text),
    weekday: _weekday,
    weekdays: _weekdays.toList()..sort(),
    dayOfMonth: int.tryParse(_dayOfMonth.text),
    intervalDays: int.tryParse(_intervalDays.text),
    anchorDate: noteDateKey(_anchorDate),
    snoozeMinutes: int.tryParse(_snoozeMinutes.text) ?? 0,
  );

  Future<void> _save() async {
    final wasNew = _entry == null;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = '제목을 입력하세요.');
      return;
    }
    final schedule = _schedule();
    final scheduleError = validateNoteSchedule(schedule);
    if (scheduleError != null) {
      setState(() => _error = scheduleError);
      return;
    }
    if (!_alarmSettings.hasValidClip) {
      setState(() => _error = '알람 음원 구간은 1초 이상이어야 합니다.');
      return;
    }
    final service = ref.read(noteNotificationServiceProvider);
    final needsSystemNotification =
        service.isSupported &&
        ((schedule.type == NoteScheduleType.once &&
                schedule.notificationEnabled) ||
            (schedule.isRepeating && schedule.notificationEnabled));
    if (needsSystemNotification) {
      final permission = await service.requestPermissions();
      if (!permission.granted) {
        setState(() => _error = '알림과 정확한 알람 권한을 모두 허용하세요.');
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final noteId = await ref
          .read(notesDaoProvider)
          .saveNote(
            id: _note?.id,
            title: _title.text,
            content: plainTextFromDocument(_richController.document),
            richContent: encodeDocument(_richController.document),
            schedule: schedule,
            checklistItems: [
              for (final item in checklistFromDocument(
                _richController.document,
              ))
                item,
            ],
            pinned: _pinned,
            showOnCalendar: _showOnCalendar,
            alarmSettings: _alarmSettings,
          );
      refreshReminderBadge(ref);
      if (!mounted) return;
      if (wasNew) {
        unawaited(rebuildNoteNotifications(ref));
        Navigator.pop(context);
      } else {
        final updated = await ref
            .read(notesDaoProvider)
            .getNoteWithChecklist(noteId);
        if (updated != null && mounted) {
          setState(() {
            _entry = updated;
            _editing = false;
          });
        }
        unawaited(rebuildNoteNotifications(ref));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleChecklistItem(int checklistIndex, bool isChecked) async {
    final entry = _entry;
    if (entry == null ||
        checklistIndex < 0 ||
        checklistIndex >= entry.items.length) {
      return;
    }
    await ref
        .read(notesDaoProvider)
        .toggleChecklistItem(entry.items[checklistIndex].id, isChecked);
    refreshReminderBadge(ref);
    unawaited(rebuildNoteNotifications(ref));
    final updated = await ref
        .read(notesDaoProvider)
        .getNoteWithChecklist(entry.note.id);
    if (updated != null && mounted) setState(() => _entry = updated);
  }

  Future<void> _delete() async {
    final note = _note;
    if (note == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메모 삭제'),
        content: const Text('이 메모를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(notesDaoProvider).deleteNote(note.id);
    refreshReminderBadge(ref);
    await rebuildNoteNotifications(ref);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final notificationSupported = ref
        .watch(noteNotificationServiceProvider)
        .isSupported;
    if (!_editing && _entry != null) return _buildViewer(context, _entry!);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: mobileBottomPadding(context, spacing: 20),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _note == null ? '새 메모' : '메모 수정',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_note != null)
                  IconButton(
                    tooltip: '삭제',
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              autofocus: _note == null,
              maxLength: 120,
              decoration: InputDecoration(labelText: '제목', errorText: _error),
            ),
            const SizedBox(height: 8),
            RichNoteEditor(
              controller: _richController,
              focusNode: _richFocus,
              scrollController: _richScroll,
              minHeight: 220,
              maxHeight: 420,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<NoteScheduleType>(
              initialValue: _scheduleType,
              decoration: const InputDecoration(labelText: '일정 유형'),
              items: [
                for (final type in NoteScheduleType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(noteScheduleLabel(type)),
                  ),
              ],
              onChanged: (value) => setState(
                () => _scheduleType = value ?? NoteScheduleType.none,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _showOnCalendar,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _showOnCalendar = value),
              title: const Text('캘린더에 표시'),
              subtitle: const Text('꺼두면 알림이나 반복 설정이 있어도 캘린더에는 보이지 않습니다.'),
            ),
            if (_scheduleType == NoteScheduleType.once)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_outlined),
                title: Text(
                  _oneTimeAt == null
                      ? '알림 날짜와 시간 선택'
                      : formatNoteReminder(_oneTimeAt!),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickOneTime,
              ),
            if (_scheduleType == NoteScheduleType.once) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: notificationSupported && _notificationEnabled,
                onChanged: notificationSupported
                    ? (value) => setState(() => _notificationEnabled = value)
                    : null,
                title: const Text('Android 시스템 알림'),
                subtitle: Text(
                  notificationSupported
                      ? '꺼두면 날짜만 저장하고 알림은 울리지 않습니다.'
                      : 'Android 기기에서만 지원합니다.',
                ),
              ),
              if (notificationSupported && _notificationEnabled) ...[
                TextField(
                  controller: _notificationLeadMinutes,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: '추가 사전 알림',
                    helperText: '분 단위, 쉼표로 구분. 예: 10, 60, 1440',
                  ),
                ),
                TextField(
                  controller: _snoozeMinutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '스누즈',
                    suffixText: '분',
                  ),
                ),
              ],
            ],
            if (_scheduleType.isRepeating) ...[
              _MobileTimeTile(
                label: '리셋 시각',
                value: _resetTime,
                icon: Icons.restart_alt,
                onTap: () => _pickTime(notification: false),
              ),
              if (_scheduleType == NoteScheduleType.weekly)
                DropdownButtonFormField<int>(
                  initialValue: _weekday,
                  decoration: const InputDecoration(labelText: '리셋 요일'),
                  items: [
                    for (var day = 1; day <= 7; day++)
                      DropdownMenuItem(
                        value: day,
                        child: Text(noteWeekdayLabel(day)),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _weekday = value ?? DateTime.monday),
                ),
              if (_scheduleType == NoteScheduleType.weekly) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      FilterChip(
                        selected: _weekdays.contains(day),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _weekdays.add(day);
                          } else {
                            _weekdays.remove(day);
                          }
                        }),
                        label: Text(noteWeekdayLabel(day)),
                      ),
                  ],
                ),
              ],
              if (_scheduleType == NoteScheduleType.monthly)
                TextField(
                  controller: _dayOfMonth,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '매월 리셋 날짜',
                    suffixText: '일',
                  ),
                ),
              if (_scheduleType == NoteScheduleType.yearly) ...[
                TextField(
                  controller: _dayOfMonth,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '매년 리셋 날짜',
                    suffixText: '일',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('매년 기준 월'),
                  subtitle: Text('${_anchorDate.month}월'),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: _pickAnchorDate,
                ),
              ],
              if (_scheduleType == NoteScheduleType.interval) ...[
                TextField(
                  controller: _intervalDays,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '반복 간격',
                    suffixText: '일',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('반복 기준일'),
                  subtitle: Text(noteDateKey(_anchorDate)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: _pickAnchorDate,
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: notificationSupported && _notificationEnabled,
                onChanged: notificationSupported
                    ? (value) => setState(() => _notificationEnabled = value)
                    : null,
                title: const Text('Android 시스템 알림'),
                subtitle: Text(
                  notificationSupported
                      ? '정확한 알람 권한이 필요합니다.'
                      : 'Android 기기에서만 지원합니다.',
                ),
              ),
              if (notificationSupported &&
                  _notificationEnabled &&
                  _scheduleType != NoteScheduleType.daily)
                TextField(
                  controller: _notificationDaysBefore,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '리셋 며칠 전 알림',
                    suffixText: '일 전',
                  ),
                ),
              if (notificationSupported && _notificationEnabled)
                _MobileTimeTile(
                  label: '알림 시각',
                  value: _notificationTime,
                  icon: Icons.notifications_active_outlined,
                  onTap: () => _pickTime(notification: true),
                ),
              if (notificationSupported &&
                  _notificationEnabled &&
                  _scheduleType != NoteScheduleType.daily)
                TextField(
                  controller: _notificationExtraDaysBefore,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: '추가 알림일',
                    helperText: '리셋 며칠 전인지 쉼표로 구분. 예: 1, 3, 7',
                  ),
                ),
              if (notificationSupported && _notificationEnabled)
                TextField(
                  controller: _snoozeMinutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '스누즈',
                    suffixText: '분',
                  ),
                ),
            ],
            if (notificationSupported &&
                ((_scheduleType == NoteScheduleType.once &&
                        _notificationEnabled) ||
                    (_scheduleType.isRepeating && _notificationEnabled))) ...[
              const Divider(height: 28),
              Text('알람 소리', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<NoteAlarmSoundKind>(
                segments: const [
                  ButtonSegment(
                    value: NoteAlarmSoundKind.system,
                    label: Text('시스템 음원'),
                  ),
                  ButtonSegment(
                    value: NoteAlarmSoundKind.custom,
                    label: Text('내 파일'),
                  ),
                ],
                selected: {_alarmSettings.soundKind},
                onSelectionChanged: (value) => setState(() {
                  _alarmSettings = _alarmSettings.copyWith(
                    soundKind: value.first,
                  );
                }),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.music_note),
                title: Text(
                  _alarmSettings.soundName ??
                      (_alarmSettings.soundKind == NoteAlarmSoundKind.system
                          ? '기본 알람음'
                          : '음원 파일을 선택하세요'),
                ),
                trailing: TextButton(
                  onPressed:
                      _alarmSettings.soundKind == NoteAlarmSoundKind.system
                      ? _pickSystemSound
                      : _pickCustomSound,
                  child: const Text('선택'),
                ),
              ),
              if (_alarmSettings.soundKind == NoteAlarmSoundKind.custom &&
                  _audioDurationMs != null &&
                  _audioDurationMs! >= 1000) ...[
                Text(
                  '재생 구간 ${_formatDuration(_alarmSettings.clipStartMs)} – '
                  '${_formatDuration(_alarmSettings.clipEndMs ?? _audioDurationMs!)}',
                ),
                RangeSlider(
                  min: 0,
                  max: _audioDurationMs!.toDouble(),
                  divisions: (_audioDurationMs! ~/ 500).clamp(2, 1000),
                  values: RangeValues(
                    _alarmSettings.clipStartMs.toDouble().clamp(
                      0.0,
                      (_audioDurationMs! - 1000).toDouble(),
                    ),
                    (_alarmSettings.clipEndMs ?? _audioDurationMs!)
                        .toDouble()
                        .clamp(1000.0, _audioDurationMs!.toDouble()),
                  ),
                  onChanged: (values) => setState(() {
                    final start = values.start.round();
                    final end = values.end.round();
                    if (end - start >= 1000) {
                      _alarmSettings = _alarmSettings.copyWith(
                        clipStartMs: start,
                        clipEndMs: end,
                      );
                    }
                  }),
                ),
              ],
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _alarmSettings.soundKind == NoteAlarmSoundKind.system ||
                            _alarmSettings.soundUri != null
                        ? () => ref
                              .read(noteNotificationServiceProvider)
                              .preview(_alarmSettings)
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('미리듣기'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () =>
                        ref.read(noteNotificationServiceProvider).stopPreview(),
                    child: const Text('정지'),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _alarmSettings.vibrationEnabled,
                onChanged: (value) => setState(() {
                  _alarmSettings = _alarmSettings.copyWith(
                    vibrationEnabled: value,
                  );
                }),
                title: const Text('진동'),
              ),
            ],
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  selected: _pinned,
                  onSelected: (value) => setState(() => _pinned = value),
                  avatar: const Icon(Icons.push_pin_outlined, size: 16),
                  label: const Text('상단 고정'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _entry == null
                              ? Navigator.pop(context)
                              : setState(() {
                                  _editing = false;
                                  _error = null;
                                }),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('저장'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewer(BuildContext context, NoteWithChecklist entry) {
    final note = entry.note;
    final ddayDate = noteDdayDate(note);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        mobileBottomPadding(context, spacing: 24),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                color: Theme.of(context).dividerColor,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '편집',
                  onPressed: _restoreDraftAndEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RichNoteViewer(
              document: documentFromNote(note),
              onTap: _restoreDraftAndEdit,
              onChecklistToggle: _toggleChecklistItem,
              minHeight: 120,
            ),
            if (note.scheduleType != 'none') ...[
              const Divider(height: 28),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(
                  ddayDate == null
                      ? noteScheduleSummary(note)
                      : '${formatNoteDday(ddayDate)} · ${noteScheduleSummary(note)}',
                ),
                subtitle: note.notificationEnabled
                    ? Text(
                        '${noteNotificationSummary(note)} · ${note.alarmSoundName ?? '기본 알람음'} · ${note.alarmVibrationEnabled ? '진동 켜짐' : '진동 꺼짐'}',
                      )
                    : null,
              ),
            ],
            const SizedBox(height: 32),
            InkWell(
              onTap: _restoreDraftAndEdit,
              child: const SizedBox(
                height: 72,
                child: Center(child: Text('빈 영역을 탭하여 편집')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDuration(int milliseconds) {
  final totalSeconds = milliseconds ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

Widget _force24HourTimePicker(BuildContext context, Widget? child) {
  return MediaQuery(
    data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
    child: child ?? const SizedBox.shrink(),
  );
}

class _MobileTimeTile extends StatelessWidget {
  const _MobileTimeTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: TextButton(onPressed: onTap, child: Text(value)),
    );
  }
}
