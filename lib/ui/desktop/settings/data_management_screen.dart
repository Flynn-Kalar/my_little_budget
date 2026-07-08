import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/backup.dart';
import '../../../data/providers.dart';
import '../../../data/supabase_backup_service.dart';
import '../../../data/supabase_backup_settings.dart';
import '../../../data/supabase_table_sync_service.dart';
import 'package:my_little_budget/features/notes/providers.dart';
import 'package:my_little_budget/features/accounts/providers.dart'
    as accounts_providers;
import 'package:my_little_budget/features/budget/providers.dart'
    as budget_providers;
import 'package:my_little_budget/features/investments/providers.dart'
    as investments_providers;
import 'package:my_little_budget/features/budget/badges_providers.dart'
    as badges_providers;
import 'package:my_little_budget/features/stats/providers.dart'
    as stats_providers;
import 'package:my_little_budget/features/transactions/providers.dart'
    as transactions_providers;
import 'package:my_little_budget/features/settings/providers.dart'
    as settings_providers;

enum _SyncMode { local, auto, windows }

class DataManagementScreen extends ConsumerStatefulWidget {
  const DataManagementScreen({super.key});

  @override
  ConsumerState<DataManagementScreen> createState() =>
      _DataManagementScreenState();
}

class _DataManagementScreenState extends ConsumerState<DataManagementScreen> {
  bool _busy = false;
  _SyncMode _selectedMode = _SyncMode.local;
  SupabaseBackupRemoteStatus? _remoteStatus;
  String? _remoteStatusError;
  late final _supabaseUrlCtrl = TextEditingController();
  late final _supabaseAnonKeyCtrl = TextEditingController();
  late final _supabaseBucketCtrl = TextEditingController();
  late final _supabasePathPrefixCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadSupabaseSettings);
  }

  @override
  void dispose() {
    _supabaseUrlCtrl.dispose();
    _supabaseAnonKeyCtrl.dispose();
    _supabaseBucketCtrl.dispose();
    _supabasePathPrefixCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSupabaseSettings() async {
    final notifier = ref.read(supabaseBackupSettingsProvider.notifier);
    await notifier.whenReady;
    if (!mounted) return;
    final settings = ref.read(supabaseBackupSettingsProvider);
    _fillSupabaseControllers(settings);
    setState(() {
      _selectedMode = settings.isConfigured ? _SyncMode.auto : _SyncMode.local;
    });
  }

  void _fillSupabaseControllers(SupabaseBackupSettings settings) {
    _supabaseUrlCtrl.text = settings.url;
    _supabaseAnonKeyCtrl.text = settings.anonKey;
    _supabaseBucketCtrl.text = settings.bucket;
    _supabasePathPrefixCtrl.text = settings.pathPrefix;
  }

  Future<void> _refreshSupabaseRemoteStatus() async {
    final draft = _supabaseDraft();
    final error = validateSupabaseBackupSettings(draft);
    if (error != null) {
      setState(() {
        _remoteStatus = null;
        _remoteStatusError = error;
      });
      return;
    }

    final result = await ref
        .read(supabaseBackupServiceProvider)
        .getRemoteStatus(draft);
    if (!mounted) return;
    setState(() {
      _remoteStatus = result.value;
      _remoteStatusError = result.error;
    });
  }

  Future<void> _exportBackup() async {
    setState(() => _busy = true);
    try {
      final backup = await ref.read(backupDaoProvider).exportBackup();
      final filename = buildBackupFilename();
      final json = backup.toJsonString();
      final path = await FilePicker.saveFile(
        dialogTitle: '백업 파일 저장',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: utf8.encode(json),
      );
      if (path == null) return;
      if (!mounted) return;
      _showSnack('백업 파일을 만들었습니다: $filename');
    } catch (e) {
      if (mounted) _showSnack('백업 파일 생성에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importBackup() async {
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.pickFiles(
        dialogTitle: '복원할 백업 파일 선택',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        allowMultiple: false,
      );
      if (picked == null || picked.files.single.path == null) return;

      final file = File(picked.files.single.path!);
      final content = await file.readAsString();
      final parsed = parseBackup(content);
      if (!parsed.isOk) {
        _showSnack(parsed.error ?? '백업 파일 형식이 올바르지 않습니다.');
        return;
      }

      if (!mounted) return;
      final confirmed = await showImportConfirmationDialog(context);
      if (confirmed != true) return;

      await ref.read(backupDaoProvider).importBackup(parsed.backup!);
      _invalidateAfterImport(ref);
      await rebuildNoteNotifications(ref);
      if (!mounted) return;
      _showSnack('백업 데이터를 복원했습니다.');
    } catch (e) {
      if (mounted) {
        _showSnack('복원에 실패했습니다. 기존 데이터는 유지됩니다. $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetAllData() async {
    final confirmed = await showResetConfirmationDialog(context);
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(backupDaoProvider).resetAllData();
      _invalidateAfterImport(ref);
      await rebuildNoteNotifications(ref);
      if (!mounted) return;
      _showSnack('데이터를 초기화했습니다.');
    } catch (e) {
      if (mounted) _showSnack('초기화에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  SupabaseBackupSettings _supabaseDraft() {
    return SupabaseBackupSettings(
      url: _supabaseUrlCtrl.text,
      anonKey: _supabaseAnonKeyCtrl.text,
      bucket: _supabaseBucketCtrl.text,
      pathPrefix: _supabasePathPrefixCtrl.text,
    );
  }

  Future<void> _saveSupabaseSettings() async {
    final draft = _supabaseDraft();
    final error = validateSupabaseBackupSettings(draft);
    if (error != null) {
      _showSnack(error);
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(supabaseBackupSettingsProvider.notifier).save(draft);
      if (!mounted) return;
      _fillSupabaseControllers(ref.read(supabaseBackupSettingsProvider));
      setState(() => _selectedMode = _SyncMode.auto);
      _showSnack('Supabase 연결 설정을 저장했습니다.');
    } catch (e) {
      if (mounted) _showSnack('Supabase 설정 저장에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testSupabaseSettings() async {
    final draft = _supabaseDraft();
    final error = validateSupabaseBackupSettings(draft);
    if (error != null) {
      _showSnack(error);
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(supabaseBackupServiceProvider)
          .testConnection(draft);
      if (!mounted) return;
      _showSnack(result.isOk ? 'Supabase Storage 연결을 확인했습니다.' : result.error!);
      if (result.isOk) await _refreshSupabaseRemoteStatus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testSupabaseTables() async {
    final draft = _supabaseDraft();
    final error = validateSupabaseProjectSettings(draft);
    if (error != null) {
      _showSnack(error);
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(supabaseTableSyncServiceProvider)
          .testConnection(draft);
      if (!mounted) return;
      _showSnack(
        result.isOk ? 'Supabase DB 엔티티 테이블 9개를 확인했습니다.' : result.error!,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearSupabaseSettings() async {
    setState(() => _busy = true);
    try {
      await ref.read(supabaseBackupSettingsProvider.notifier).clear();
      if (!mounted) return;
      _fillSupabaseControllers(SupabaseBackupSettings.empty);
      _showSnack('Supabase 연결 설정을 삭제했습니다.');
      setState(() {
        _selectedMode = _SyncMode.local;
        _remoteStatus = null;
        _remoteStatusError = null;
      });
    } catch (e) {
      if (mounted) _showSnack('Supabase 설정 삭제에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadSupabaseBackup() async {
    final draft = _supabaseDraft();
    final error = validateSupabaseBackupSettings(draft);
    if (error != null) {
      _showSnack(error);
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(supabaseBackupSettingsProvider.notifier).save(draft);
      final backup = await ref.read(backupDaoProvider).exportBackup();
      final result = await ref
          .read(supabaseBackupServiceProvider)
          .uploadBackup(settings: draft, backup: backup);
      if (!mounted) return;
      if (!result.isOk) {
        _showSnack(result.error!);
        return;
      }
      await ref.read(supabaseBackupSettingsProvider.notifier).markBackupNow();
      await _refreshSupabaseRemoteStatus();
      _showSnack('Supabase에 백업했습니다: ${result.value!.latestPath}');
    } catch (e) {
      if (mounted) _showSnack('Supabase 백업에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreSupabaseBackup() async {
    final draft = _supabaseDraft();
    final error = validateSupabaseBackupSettings(draft);
    if (error != null) {
      _showSnack(error);
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(supabaseBackupServiceProvider)
          .downloadLatestBackup(draft);
      if (!result.isOk) {
        if (mounted) _showSnack(result.error!);
        return;
      }

      final parsed = parseBackup(result.value!);
      if (!parsed.isOk) {
        if (mounted) _showSnack(parsed.error ?? '백업 파일 형식이 올바르지 않습니다.');
        return;
      }

      if (!mounted) return;
      final confirmed = await showImportConfirmationDialog(context);
      if (confirmed != true) return;

      await ref.read(backupDaoProvider).importBackup(parsed.backup!);
      _invalidateAfterImport(ref);
      await rebuildNoteNotifications(ref);
      await ref.read(supabaseBackupSettingsProvider.notifier).markRestoreNow();
      if (!mounted) return;
      await _refreshSupabaseRemoteStatus();
      _showSnack('Supabase 백업을 복원했습니다.');
    } catch (e) {
      if (mounted) _showSnack('Supabase 복원에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final supabaseSettings = ref.watch(supabaseBackupSettingsProvider);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: _busy ? null : () => context.go('/settings'),
              icon: Icon(Icons.chevron_left),
              label: Text('설정'),
            ),
            SizedBox(height: 8),
            Text(
              '데이터 백업 / 복원',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '앱 데이터를 JSON으로 저장하거나, 백업 파일로 현재 데이터를 전체 교체할 수 있습니다.',
              style: TextStyle(fontSize: 13, color: context.desktopMuted),
            ),
            SizedBox(height: 24),
            _SyncModeSelector(
              selected: _selectedMode,
              onChanged: (mode) => setState(() => _selectedMode = mode),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: switch (_selectedMode) {
                _SyncMode.local => _LocalBackupPanel(
                  key: const ValueKey('settings-local-sync-panel'),
                  busy: _busy,
                  onExport: _exportBackup,
                  onImport: _importBackup,
                ),
                _SyncMode.auto => _SupabaseSettingsCard(
                  key: const ValueKey('settings-auto-sync-panel'),
                  urlController: _supabaseUrlCtrl,
                  anonKeyController: _supabaseAnonKeyCtrl,
                  bucketController: _supabaseBucketCtrl,
                  pathPrefixController: _supabasePathPrefixCtrl,
                  configured: supabaseSettings.isConfigured,
                  settings: supabaseSettings,
                  remoteStatus: _remoteStatus,
                  remoteStatusError: _remoteStatusError,
                  busy: _busy,
                  onSave: _saveSupabaseSettings,
                  onTest: _testSupabaseSettings,
                  onTestTables: _testSupabaseTables,
                  onClear: _clearSupabaseSettings,
                  onUpload: _uploadSupabaseBackup,
                  onRestore: _restoreSupabaseBackup,
                  onRefresh: _refreshSupabaseRemoteStatus,
                ),
                _SyncMode.windows => const _WindowsDownloadPanel(
                  key: ValueKey('settings-windows-download-panel'),
                ),
              },
            ),
            if (_busy) ...[
              SizedBox(height: 16),
              const LinearProgressIndicator(minHeight: 3),
            ],
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.5),
            _ResetDeviceButton(
              key: const ValueKey('settings-data-reset-button'),
              busy: _busy,
              onPressed: _resetAllData,
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SyncModeSelector extends StatelessWidget {
  const _SyncModeSelector({required this.selected, required this.onChanged});

  final _SyncMode selected;
  final ValueChanged<_SyncMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SyncModeRow(
              mode: _SyncMode.local,
              selected: selected,
              label: '로컬',
              onChanged: onChanged,
            ),
            const SizedBox(height: 10),
            _SyncModeRow(
              mode: _SyncMode.auto,
              selected: selected,
              label: '자동 동기화',
              onChanged: onChanged,
            ),
            const SizedBox(height: 10),
            _SyncModeRow(
              mode: _SyncMode.windows,
              selected: selected,
              label: 'Windows 버전 설치',
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncModeRow extends StatelessWidget {
  const _SyncModeRow({
    required this.mode,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final _SyncMode mode;
  final _SyncMode selected;
  final String label;
  final ValueChanged<_SyncMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == mode;
    final color = context.desktopAccent;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : context.desktopMuted,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalBackupPanel extends StatelessWidget {
  const _LocalBackupPanel({
    super.key,
    required this.busy,
    required this.onExport,
    required this.onImport,
  });

  final bool busy;
  final VoidCallback onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      children: [
        _ActionCard(
          buttonKey: const ValueKey('settings-backup-export-button'),
          icon: Icons.file_upload_outlined,
          title: 'JSON 백업 내보내기',
          description: '현재 앱 데이터를 하나의 JSON 파일로 저장합니다.',
          buttonLabel: '백업 파일 만들기',
          onPressed: busy ? null : onExport,
        ),
        const SizedBox(height: 12),
        _ActionCard(
          buttonKey: const ValueKey('settings-backup-import-button'),
          icon: Icons.file_download_outlined,
          title: 'JSON 백업 불러오기',
          description: '백업 JSON 파일을 확인한 뒤 현재 데이터를 백업 데이터로 교체합니다.',
          buttonLabel: '백업 파일 선택',
          danger: true,
          onPressed: busy ? null : onImport,
        ),
      ],
    );
  }
}

class _WindowsDownloadPanel extends StatelessWidget {
  const _WindowsDownloadPanel({super.key});

  static const _releasesUrl =
      'https://github.com/Flynn-Kalar/my_little_budget/releases';

  @override
  Widget build(BuildContext context) {
    return Card(
      key: key,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.desktop_windows_outlined,
                  color: context.desktopAccent,
                ),
                const SizedBox(width: 12),
                const Text(
                  '다운로드',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Windows PC 버전은 GitHub Releases에서 받을 수 있습니다.',
              style: TextStyle(color: context.desktopMuted),
            ),
            const SizedBox(height: 12),
            SelectableText(
              'Windows 버전 다운로드\n$_releasesUrl',
              style: TextStyle(
                color: context.desktopAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Android 버전은 현재 내부 테스트/직접 설치용으로 제공됩니다.',
              style: TextStyle(color: context.desktopMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetDeviceButton extends StatelessWidget {
  const _ResetDeviceButton({
    super.key,
    required this.busy,
    required this.onPressed,
  });

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          foregroundColor: context.desktopExpense,
          backgroundColor: context.desktopExpense.withValues(alpha: 0.10),
        ),
        icon: const Icon(Icons.delete_forever_outlined),
        label: const Text('기기 초기화'),
      ),
    );
  }
}

class _SupabaseSettingsCard extends StatelessWidget {
  const _SupabaseSettingsCard({
    super.key,
    required this.urlController,
    required this.anonKeyController,
    required this.bucketController,
    required this.pathPrefixController,
    required this.configured,
    required this.settings,
    required this.remoteStatus,
    required this.remoteStatusError,
    required this.busy,
    required this.onSave,
    required this.onTest,
    required this.onTestTables,
    required this.onClear,
    required this.onUpload,
    required this.onRestore,
    required this.onRefresh,
  });

  final TextEditingController urlController;
  final TextEditingController anonKeyController;
  final TextEditingController bucketController;
  final TextEditingController pathPrefixController;
  final bool configured;
  final SupabaseBackupSettings settings;
  final SupabaseBackupRemoteStatus? remoteStatus;
  final String? remoteStatusError;
  final bool busy;
  final VoidCallback onSave;
  final VoidCallback onTest;
  final VoidCallback onTestTables;
  final VoidCallback onClear;
  final VoidCallback onUpload;
  final VoidCallback onRestore;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_sync_outlined, color: context.desktopAccent),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Supabase 백업 연결',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                _StatusChip(configured: configured),
              ],
            ),
            const SizedBox(height: 14),
            const _AutoSyncSetupGuide(),
            const SizedBox(height: 12),
            Text(
              '본인 Supabase 프로젝트의 URL, anon/publishable key, Storage bucket을 저장합니다. service_role key는 입력하지 마세요.',
              style: TextStyle(fontSize: 13, color: context.desktopMuted),
            ),
            SizedBox(height: 16),
            _SupabaseStatusPanel(
              settings: settings,
              remoteStatus: remoteStatus,
              remoteStatusError: remoteStatusError,
            ),
            SizedBox(height: 16),
            TextField(
              key: const ValueKey('settings-supabase-url-field'),
              controller: urlController,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Supabase URL',
                hintText: 'https://project-ref.supabase.co',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              key: const ValueKey('settings-supabase-anon-key-field'),
              controller: anonKeyController,
              enabled: !busy,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'anon / publishable key',
                prefixIcon: Icon(Icons.key_outlined),
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('settings-supabase-bucket-field'),
                    controller: bucketController,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: 'Storage bucket',
                      hintText: 'my-little-budget',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const ValueKey('settings-supabase-path-prefix-field'),
                    controller: pathPrefixController,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: 'Path prefix',
                      hintText: 'my_little_budget',
                      prefixIcon: Icon(Icons.folder_outlined),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const ValueKey('settings-supabase-save-button'),
                  onPressed: busy ? null : onSave,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('설정 저장'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('settings-supabase-test-button'),
                  onPressed: busy ? null : onTest,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('연결 테스트'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('settings-supabase-table-test-button'),
                  onPressed: busy ? null : onTestTables,
                  icon: const Icon(Icons.storage_outlined),
                  label: const Text('DB 테이블 테스트'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('settings-supabase-refresh-button'),
                  onPressed: busy ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('상태 새로고침'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('settings-supabase-clear-button'),
                  onPressed: busy || !configured ? null : onClear,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('설정 삭제'),
                ),
                FilledButton.icon(
                  key: const ValueKey('settings-supabase-upload-button'),
                  onPressed: busy ? null : onUpload,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Supabase 백업'),
                ),
                FilledButton.icon(
                  key: const ValueKey('settings-supabase-restore-button'),
                  onPressed: busy ? null : onRestore,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('Supabase 복원'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoSyncSetupGuide extends StatefulWidget {
  const _AutoSyncSetupGuide();

  @override
  State<_AutoSyncSetupGuide> createState() => _AutoSyncSetupGuideState();
}

class _AutoSyncSetupGuideState extends State<_AutoSyncSetupGuide> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('settings-auto-sync-setup-guide'),
      decoration: BoxDecoration(
        border: Border.all(color: context.desktopBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        onExpansionChanged: (value) => setState(() => _expanded = value),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Icon(Icons.help_outline, color: context.desktopAccent),
        title: const Text(
          '자동동기화 설정방법',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        children: [
          Text(
            [
              '1. Supabase 프로젝트를 만들고 Storage bucket을 생성합니다.',
              '2. Project URL과 anon/publishable key를 복사해 입력합니다.',
              '3. Storage bucket 이름과 백업 경로 prefix를 입력합니다.',
              '4. 설정 저장 후 연결 테스트와 DB 테이블 테스트를 실행합니다.',
              '5. Supabase 백업으로 현재 데이터를 올리고, 필요하면 Supabase 복원으로 내려받습니다.',
            ].join('\n'),
            style: TextStyle(
              color: context.desktopMuted,
              height: 1.45,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupabaseStatusPanel extends StatelessWidget {
  const _SupabaseStatusPanel({
    required this.settings,
    required this.remoteStatus,
    required this.remoteStatusError,
  });

  final SupabaseBackupSettings settings;
  final SupabaseBackupRemoteStatus? remoteStatus;
  final String? remoteStatusError;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      'latest 경로: ${settings.normalized().pathPrefix}/latest.json',
      '마지막 앱 백업: ${_formatIso(settings.lastBackupAt)}',
      '마지막 앱 복원: ${_formatIso(settings.lastRestoreAt)}',
    ];
    if (remoteStatusError != null) {
      lines.add('원격 상태: $remoteStatusError');
    } else if (remoteStatus == null) {
      lines.add('원격 상태: 아직 확인하지 않았습니다.');
    } else if (!remoteStatus!.exists) {
      lines.add('원격 상태: latest.json 없음');
    } else {
      lines.add(
        '원격 상태: latest.json 있음 ${_formatDate(remoteStatus!.updatedAt)}',
      );
    }

    return Container(
      key: const ValueKey('settings-supabase-status-panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        lines.join('\n'),
        style: TextStyle(
          fontSize: 13,
          color: context.desktopMuted,
          height: 1.4,
        ),
      ),
    );
  }
}

String _formatIso(String? value) {
  if (value == null || value.isEmpty) return '없음';
  return _formatDate(DateTime.tryParse(value));
}

String _formatDate(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.configured});

  final bool configured;

  @override
  Widget build(BuildContext context) {
    final color = configured ? context.desktopIncome : context.desktopMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        configured ? '설정됨' : '미설정',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

Future<bool?> showResetConfirmationDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('데이터 초기화'),
      content: Text('현재 데이터를 모두 삭제하고 기본 자산과 카테고리를 복구합니다. 되돌릴 수 없습니다.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('초기화'),
        ),
      ],
    ),
  );
}

Future<bool?> showImportConfirmationDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('\uBC31\uC5C5 \uB370\uC774\uD130 \uBCF5\uC6D0'),
      content: Text(
        '\uD604\uC7AC \uB370\uC774\uD130\uB97C \uBAA8\uB450 '
        '\uB36E\uC5B4\uC4F0\uACE0 \uBC31\uC5C5 \uB370\uC774\uD130\uB97C '
        '\uBCF5\uC6D0\uD569\uB2C8\uB2E4. \uB418\uB3CC\uB9B4 \uC218 '
        '\uC5C6\uC2B5\uB2C8\uB2E4.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('\uCDE8\uC18C'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('\uBCF5\uC6D0'),
        ),
      ],
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.buttonKey,
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    this.danger = false,
  });

  final Key buttonKey;
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.desktopExpense : context.desktopAccent;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: context.desktopMuted),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            FilledButton.icon(
              key: buttonKey,
              onPressed: onPressed,
              icon: Icon(danger ? Icons.restore_outlined : Icons.save_alt),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

void _invalidateAfterImport(WidgetRef ref) {
  ref.invalidate(notesProvider);
  ref.invalidate(pendingReminderCountProvider);
  ref.invalidate(accounts_providers.accountBalancesProvider);
  ref.invalidate(accounts_providers.archivedAccountsProvider);

  ref.invalidate(budget_providers.monthlyExpectedIncomeProvider);
  ref.invalidate(budget_providers.budgetRowsProvider);
  ref.invalidate(budget_providers.budgetExpenseCategoriesProvider);
  ref.invalidate(budget_providers.budgetActiveAccountsProvider);
  ref.invalidate(badges_providers.overBudgetCountProvider);

  ref.invalidate(transactions_providers.transactionsListProvider);
  ref.invalidate(transactions_providers.monthlySummaryProvider);
  ref.invalidate(transactions_providers.activeAccountsProvider);
  ref.invalidate(transactions_providers.activeCategoriesProvider);
  ref.invalidate(transactions_providers.allTagsProvider);
  ref.invalidate(transactions_providers.recentMemosProvider);

  ref.invalidate(investments_providers.investmentRowsProvider);
  ref.invalidate(investments_providers.investmentMonthlySummaryProvider);
  ref.invalidate(investments_providers.investmentAccountProvider);
  ref.invalidate(investments_providers.currentHoldingsProvider);
  ref.invalidate(investments_providers.realizedPnlProvider);

  ref.invalidate(stats_providers.statsExpenseBreakdownProvider);
  ref.invalidate(stats_providers.statsMonthlyTrendProvider);

  ref.invalidate(settings_providers.allCategoriesProvider);
  ref.invalidate(settings_providers.settingsActiveCategoriesProvider);
  ref.invalidate(settings_providers.settingsAccountsProvider);
  ref.invalidate(settings_providers.settingsTagsProvider);
  ref.invalidate(settings_providers.recurringItemsProvider);
}
