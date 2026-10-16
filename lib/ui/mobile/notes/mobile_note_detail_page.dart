import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../features/notes/checklist.dart';
import '../../../features/notes/note_amount_goal.dart';
import '../../../features/notes/note_format.dart';
import '../../../features/notes/providers.dart';
import '../../../features/notes/rich_note.dart';
import '../../shared/note_amount_goal.dart';
import '../../shared/rich_note_editor.dart';

class MobileNoteDetailPage extends ConsumerStatefulWidget {
  const MobileNoteDetailPage({
    super.key,
    required this.entry,
    required this.onEdit,
  });
  final NoteWithChecklist entry;
  final Future<void> Function(BuildContext context, NoteWithChecklist entry)
  onEdit;

  @override
  ConsumerState<MobileNoteDetailPage> createState() =>
      _MobileNoteDetailPageState();
}

class _MobileNoteDetailPageState extends ConsumerState<MobileNoteDetailPage> {
  late NoteWithChecklist _entry = widget.entry;
  final _scroll = ScrollController();
  bool _editing = false;
  bool _busy = false;

  Future<void> _refresh() async {
    final updated = await ref
        .read(notesDaoProvider)
        .getNoteWithChecklist(_entry.note.id);
    if (!mounted) return;
    if (updated == null) {
      Navigator.pop(context);
    } else {
      setState(() => _entry = updated);
    }
  }

  Future<void> _edit() async {
    if (_editing || _busy) return;
    setState(() => _editing = true);
    try {
      await widget.onEdit(context, _entry);
      if (mounted) await _refresh();
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  Future<void> _toggleChecklist(int index, bool checked) async {
    if (_busy || index < 0 || index >= _entry.items.length) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(notesDaoProvider)
          .toggleChecklistItem(_entry.items[index].id, checked);
      refreshReminderBadge(ref);
      unawaited(rebuildNoteNotifications(ref));
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('체크 상태를 저장하지 못했습니다. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy || _editing) return;
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
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(notesDaoProvider).deleteNote(_entry.note.id);
      refreshReminderBadge(ref);
      unawaited(rebuildNoteNotifications(ref));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메모를 삭제하지 못했습니다. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = _entry.note;
    final dday = noteDdayDate(note);
    final created = _storedTimestamp(note.createdAt);
    final updated = _storedTimestamp(note.updatedAt);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        actions: [
          IconButton(
            tooltip: '편집',
            onPressed: _busy || _editing ? null : _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: '삭제',
            onPressed: _busy || _editing ? null : _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Offstage(
          offstage: _editing,
          child: SingleChildScrollView(
            key: const ValueKey('mobile-note-detail-scroll'),
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  note.title,
                  key: const ValueKey('mobile-note-detail-title'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                if (note.goalTargetAmount != null)
                  NoteGoalSummary(goal: NoteAmountGoal.fromNote(note)!),
                RichNoteViewer(
                  document: documentFromNote(note),
                  onTap: _edit,
                  onChecklistToggle: _toggleChecklist,
                  minHeight: 0,
                  bordered: false,
                  scrollable: false,
                  contentPadding: EdgeInsets.zero,
                  lineHeight: 1.5,
                ),
                if (note.scheduleType != 'none') ...[
                  const Divider(height: 32),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: Text(
                      dday == null
                          ? noteScheduleSummary(note)
                          : '${formatNoteDday(dday)} · ${noteScheduleSummary(note)}',
                    ),
                    subtitle: note.notificationEnabled
                        ? Text(
                            '${noteNotificationSummary(note)} · ${note.alarmSoundName ?? '기본 알람음'} · ${note.alarmVibrationEnabled ? '진동 켜짐' : '진동 꺼짐'}',
                          )
                        : null,
                  ),
                ],
                if (created != null || updated != null) ...[
                  const Divider(height: 32),
                  if (created != null)
                    Text(
                      '작성 ${formatNoteReminder(created)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (updated != null)
                    Text(
                      '수정 ${formatNoteReminder(updated)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

DateTime? _storedTimestamp(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  // SQLite's datetime('now') defaults are UTC, unlike an ISO local timestamp.
  final normalized =
      RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$').hasMatch(text)
      ? '${text.replaceFirst(' ', 'T')}Z'
      : text;
  return DateTime.tryParse(normalized)?.toLocal();
}
