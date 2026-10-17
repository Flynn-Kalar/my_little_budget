import 'dart:io';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup.dart';
import '../../data/local_backup_service.dart';
import '../../data/providers.dart';
import '../../features/notes/providers.dart';
import '../../features/sync/invalidate_synced_data.dart';

Future<bool?> showBackupRestorePreview(
  BuildContext context,
  Backup backup,
) => showDialog<bool>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: const Text('백업 복원 미리보기'),
    content: SingleChildScrollView(
      child: Text(
        '백업 시각: ${DateTime.tryParse(backup.exportedAt)?.toLocal().toString().split('.').first ?? backup.exportedAt}\n\n'
        '계좌 ${backup.accounts.length}개\n카테고리 ${backup.categories.length}개\n'
        '거래 ${backup.transactions.length}건\n예산 ${backup.budgetGroups.length}개\n'
        '투자 ${backup.investments.length}건\n태그 ${backup.tags.length}개\n'
        '반복 거래 ${backup.recurringTransactions.length}개\n프리셋 ${backup.transactionPresets.length}개\n'
        '노트 ${backup.notes.length}개\n일정 ${backup.calendarEvents.length}개\n\n'
        '현재 데이터를 이 백업으로 전체 교체합니다.\n'
        '${kIsWeb ? '웹에서는 기기 내부 안전 백업을 지원하지 않습니다. 먼저 JSON을 내보내주세요.' : '복원 직전 현재 데이터의 안전 백업을 기기에 저장합니다.'}',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext, false),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(dialogContext, true),
        child: const Text('전체 교체하여 복원'),
      ),
    ],
  ),
);

class LocalBackupPanel extends ConsumerStatefulWidget {
  const LocalBackupPanel({super.key, this.enabled = true, this.onBusyChanged});
  final bool enabled;
  final ValueChanged<bool>? onBusyChanged;
  @override
  ConsumerState<LocalBackupPanel> createState() => _LocalBackupPanelState();
}

class _LocalBackupPanelState extends ConsumerState<LocalBackupPanel> {
  bool _automatic = true;
  bool _busy = false;
  bool _loaded = false;
  List<File> _files = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = ref.read(localBackupServiceProvider);
      final automatic = await service.enabled;
      final files = await service.list();
      if (mounted) {
        setState(() {
          _automatic = automatic;
          _files = files;
          _loaded = true;
          _error = service.lastError ?? _error;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.onBusyChanged?.call(true);
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = '백업 처리에 실패했습니다: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged?.call(false);
        await _load();
      }
    }
  }

  Future<void> _restore(File file) => _run(() async {
    final service = ref.read(localBackupServiceProvider);
    final backup = await service.read(file);
    if (!mounted || await showBackupRestorePreview(context, backup) != true) {
      return;
    }
    await service.captureFresh();
    await ref.read(backupDaoProvider).importBackup(backup);
    if (!mounted) return;
    invalidateSyncedData(ref);
    ref.invalidate(notesProvider);
    ref.invalidate(pendingReminderCountProvider);
    await rebuildNoteNotifications(ref);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('백업을 복원했습니다.')));
    }
  });

  Future<void> _export(File file) => _run(() async {
    final backup = await ref.read(localBackupServiceProvider).read(file);
    await FilePicker.saveFile(
      dialogTitle: '복구 지점 내보내기',
      fileName: file.uri.pathSegments.last,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: utf8.encode(backup.toJsonString()),
    );
  });

  String _timestamp(File file) {
    final name = file.uri.pathSegments.last;
    final number = int.tryParse(
      name.replaceFirst('budget-', '').replaceFirst('.json', ''),
    );
    return number == null
        ? name
        : DateTime.fromMicrosecondsSinceEpoch(
            number,
            isUtc: true,
          ).toLocal().toString().split('.').first;
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('자동 로컬 백업은 설치형 앱에서 사용할 수 있습니다. 웹에서는 JSON 내보내기를 이용해주세요.'),
        ),
      );
    }
    final enabled = widget.enabled && !_busy && _loaded;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '자동 로컬 백업',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('매일 복구 지점 보관'),
              subtitle: const Text(
                '앱 시작과 사용 중 데이터 변경 후 하루 한 번 저장합니다. 최근 7개를 기기에 보관합니다. 앱 삭제 시 함께 지워질 수 있습니다.',
              ),
              value: _automatic,
              onChanged: enabled
                  ? (value) => _run(() async {
                      await ref
                          .read(localBackupServiceProvider)
                          .setEnabled(value);
                    })
                  : null,
            ),
            OutlinedButton.icon(
              onPressed: enabled
                  ? () => _run(() async {
                      await ref.read(localBackupServiceProvider).capture();
                    })
                  : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('지금 복구 지점 만들기'),
            ),
            if (_files.isEmpty && _loaded) const Text('저장된 복구 지점이 없습니다.'),
            for (final file in _files)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_timestamp(file)),
                trailing: PopupMenuButton<String>(
                  enabled: enabled,
                  tooltip: '복구 지점 작업',
                  onSelected: (action) =>
                      action == 'restore' ? _restore(file) : _export(file),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'export', child: Text('파일로 내보내기')),
                    PopupMenuItem(value: 'restore', child: Text('미리보기 및 복원')),
                  ],
                ),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (!_loaded) const Text('복구 지점을 불러오는 중입니다.'),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
