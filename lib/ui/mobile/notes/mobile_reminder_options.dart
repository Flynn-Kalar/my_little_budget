import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import '../../../features/notes/reminder_device_zone.dart';

import '../../../features/notes/reminder_calendar.dart';
import '../../../features/notes/reminder_store.dart';
import '../../../features/notes/note_schedule.dart';

class MobileReminderOptions extends StatefulWidget {
  const MobileReminderOptions({
    super.key,
    required this.load,
    required this.schedule,
    required this.onChanged,
  });
  final Future<ReminderOptions> Function() load;
  final NoteScheduleDraft schedule;
  final ValueChanged<ReminderOptions> onChanged;
  @override
  State<MobileReminderOptions> createState() => _MobileReminderOptionsState();
}

class _MobileReminderOptionsState extends State<MobileReminderOptions> {
  ReminderOptions? value;
  late final zone = TextEditingController();
  @override
  void initState() {
    super.initState();
    tzdata.initializeTimeZones();
    widget.load().then((loaded) async {
      var v = loaded;
      if (v.timeZone == null) {
        try {
          final name = await reminderDeviceZone();
          v = ReminderOptions(
            dueDate: v.dueDate,
            every: v.every,
            until: v.until,
            timeZone: name,
            alarmMode: v.alarmMode,
            anchorDate: v.anchorDate,
          );
        } catch (_) {
          /* Tests and unsupported platforms use the adapter fallback. */
        }
      }
      if (!mounted) return;
      zone.text = v.timeZone ?? '';
      setState(() => value = v);
      widget.onChanged(v);
    });
  }

  @override
  void dispose() {
    zone.dispose();
    super.dispose();
  }

  void change({
    String? due,
    bool clearDue = false,
    int? every,
    String? until,
    bool clearUntil = false,
    bool? alarm,
  }) {
    final v = value!;
    final next = ReminderOptions(
      dueDate: clearDue ? null : due ?? v.dueDate,
      every: every ?? v.every,
      until: clearUntil ? null : until ?? v.until,
      timeZone: zone.text.trim().isEmpty ? null : zone.text.trim(),
      alarmMode: alarm ?? v.alarmMode,
      anchorDate: v.anchorDate,
    );
    setState(() => value = next);
    widget.onChanged(next);
  }

  Future<void> pick(bool due) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
    );
    if (date == null || !mounted) return;
    if (due) {
      change(due: noteDateKey(date));
    } else {
      change(until: noteDateKey(date));
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null) return const Text('알림 설정 불러오는 중');
    List<DateTime> preview = [];
    String? error;
    if (widget.schedule.isRepeating) {
      try {
        final location = v.timeZone == null || v.timeZone == 'UTC'
            ? tz.UTC
            : tz.getLocation(v.timeZone!);
        preview = reminderResets(
          widget.schedule,
          location,
          DateTime.now(),
          anchor:
              parseNoteDate(
                (widget.schedule.type == NoteScheduleType.yearly ||
                        widget.schedule.type == NoteScheduleType.interval)
                    ? widget.schedule.anchorDate
                    : v.anchorDate ?? widget.schedule.anchorDate,
              ) ??
              DateTime.now(),
          every: v.every,
          until: parseNoteDate(v.until),
          count: 3,
        ).where((d) => d.isAfter(DateTime.now())).take(3).toList();
      } catch (_) {
        error = '반복 간격 또는 시간대를 확인하세요.';
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('마감일 (알림과 별도)'),
          subtitle: Text(v.dueDate ?? '없음'),
          onTap: () => pick(true),
          trailing: v.dueDate == null
              ? const Icon(Icons.event_outlined)
              : IconButton(
                  tooltip: '마감일 지우기',
                  icon: const Icon(Icons.clear),
                  onPressed: () => change(clearDue: true),
                ),
        ),
        if (widget.schedule.isRepeating) ...[
          if (widget.schedule.type != NoteScheduleType.interval)
            TextFormField(
              initialValue: '${v.every}',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '반복 간격',
                helperText: '선택한 일·주·월·년 단위의 간격 (1~365)',
              ),
              onChanged: (s) => change(every: int.tryParse(s) ?? 0),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('반복 종료일 (해당 날짜 포함)'),
            subtitle: Text(v.until ?? '종료 없음'),
            onTap: () => pick(false),
            trailing: v.until == null
                ? null
                : IconButton(
                    tooltip: '종료일 지우기',
                    icon: const Icon(Icons.clear),
                    onPressed: () => change(clearUntil: true),
                  ),
          ),
          TextField(
            controller: zone,
            decoration: const InputDecoration(
              labelText: '시간대',
              hintText: 'Asia/Seoul',
              helperText: '저장한 시간대를 유지합니다. 기기 시간대 변경과 별개입니다.',
            ),
            onChanged: (_) => change(),
          ),
          Text(
            error ??
                (preview.isEmpty
                    ? '반복 날짜 없음'
                    : '다음 3회: ${preview.map((d) => noteDateKey(d)).join(', ')}'),
          ),
        ],
        if (widget.schedule.notificationEnabled)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('알람으로 울리기'),
            subtitle: const Text('켜면 최대 60초간 소리·진동, 끄면 일반 알림'),
            value: v.alarmMode,
            onChanged: (b) => change(alarm: b),
          ),
      ],
    );
  }
}
