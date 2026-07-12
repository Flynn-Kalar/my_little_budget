import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
import 'package:my_little_budget/features/settings/providers.dart'
    as settings_providers;
import 'package:my_little_budget/features/budget/badges_providers.dart'
    as badges_providers;
import 'package:my_little_budget/features/stats/providers.dart'
    as stats_providers;
import 'package:my_little_budget/features/transactions/providers.dart'
    as transactions_providers;
import '../mobile_widgets.dart';

enum _SyncMode { local, auto, windows }

class MobileDataManagementScreen extends ConsumerStatefulWidget {
  const MobileDataManagementScreen({super.key});

  @override
  ConsumerState<MobileDataManagementScreen> createState() =>
      _MobileDataManagementScreenState();
}

class _MobileDataManagementScreenState
    extends ConsumerState<MobileDataManagementScreen> {
  bool _busy = false;
  _SyncMode _selectedMode = _SyncMode.local;
  SupabaseBackupRemoteStatus? _remoteStatus;
  String? _remoteStatusError;
  late final _supabaseUrlCtrl = TextEditingController();
  late final _supabaseAnonKeyCtrl = TextEditingController();
  late final _supabaseBucketCtrl = TextEditingController();

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
      final path = await FilePicker.saveFile(
        dialogTitle: '백업 파일 저장',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: utf8.encode(backup.toJsonString()),
      );
      if (path == null || !mounted) return;
      _showSnack('백업 파일을 만들었습니다.');
    } catch (e) {
      debugPrint('exportBackup failed: $e');
      if (mounted) _showSnack('백업에 실패했습니다.');
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

      final content = await File(picked.files.single.path!).readAsString();
      final parsed = parseBackup(content);
      if (!parsed.isOk) {
        _showSnack(parsed.error ?? '백업 파일 형식이 올바르지 않습니다.');
        return;
      }

      if (!mounted) return;
      final confirmed = await _confirmRestore(context);
      if (confirmed != true) return;

      await ref.read(backupDaoProvider).importBackup(parsed.backup!);
      _invalidateAfterImport(ref);
      await rebuildNoteNotifications(ref);
      if (!mounted) return;
      _showSnack('백업을 복원했습니다.');
    } catch (e) {
      debugPrint('importBackup failed: $e');
      if (mounted) _showSnack('복원에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetAllData() async {
    final confirmed = await _confirmReset(context);
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(backupDaoProvider).resetAllData();
      _invalidateAfterImport(ref);
      await rebuildNoteNotifications(ref);
      if (!mounted) return;
      _showSnack('초기화했습니다.');
    } catch (e) {
      debugPrint('resetAllData failed: $e');
      if (mounted) _showSnack('초기화에 실패했습니다. 데이터를 다시 확인해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  SupabaseBackupSettings _supabaseDraft() {
    return SupabaseBackupSettings(
      url: _supabaseUrlCtrl.text,
      anonKey: _supabaseAnonKeyCtrl.text,
      bucket: _supabaseBucketCtrl.text,
      pathPrefix: SupabaseBackupSettings.defaultPathPrefix,
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
      debugPrint('saveSupabaseSettings failed: $e');
      if (mounted) _showSnack('Supabase 설정 저장에 실패했습니다.');
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
    } catch (error) {
      debugPrint('testSupabaseTables failed: $error');
      if (mounted) _showSnack('Supabase DB 테이블 확인에 실패했습니다.');
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
      setState(() {
        _selectedMode = _SyncMode.local;
        _remoteStatus = null;
        _remoteStatusError = null;
      });
      _showSnack('Supabase 연결 설정을 삭제했습니다.');
    } catch (e) {
      debugPrint('clearSupabaseSettings failed: $e');
      if (mounted) _showSnack('Supabase 설정 삭제에 실패했습니다.');
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
      _showSnack('Supabase에 백업했습니다.');
    } catch (e) {
      debugPrint('uploadSupabaseBackup failed: $e');
      if (mounted) _showSnack('Supabase 백업에 실패했습니다.');
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
      final confirmed = await _confirmRestore(context);
      if (confirmed != true) return;

      await ref.read(backupDaoProvider).importBackup(parsed.backup!);
      _invalidateAfterImport(ref);
      await rebuildNoteNotifications(ref);
      await ref.read(supabaseBackupSettingsProvider.notifier).markRestoreNow();
      if (!mounted) return;
      await _refreshSupabaseRemoteStatus();
      _showSnack('Supabase 백업을 복원했습니다.');
    } catch (e) {
      debugPrint('restoreSupabaseBackup failed: $e');
      if (mounted) _showSnack('Supabase 복원에 실패했습니다.');
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

    return MobilePage(
      title: '데이터 관리',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _busy ? null : () => context.go('/settings'),
            icon: const Icon(Icons.chevron_left),
            label: const Text('설정'),
          ),
        ),
        Text(
          '현재 데이터를 JSON 백업 파일로 저장하거나, 선택한 백업 파일로 데이터를 복원할 수 있습니다.',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 12),
        _SyncModeSelector(
          selected: _selectedMode,
          onChanged: (mode) => setState(() => _selectedMode = mode),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: switch (_selectedMode) {
            _SyncMode.local => _LocalBackupPanel(
              key: const ValueKey('mobile-settings-local-sync-panel'),
              busy: _busy,
              onExport: _exportBackup,
              onImport: _importBackup,
            ),
            _SyncMode.auto => _SupabaseSettingsCard(
              key: const ValueKey('mobile-settings-auto-sync-panel'),
              urlController: _supabaseUrlCtrl,
              anonKeyController: _supabaseAnonKeyCtrl,
              bucketController: _supabaseBucketCtrl,
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
              key: ValueKey('mobile-settings-windows-download-panel'),
            ),
          },
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 3),
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.5),
        _ResetDeviceButton(
          key: const ValueKey('mobile-settings-data-reset-button'),
          busy: _busy,
          onPressed: _resetAllData,
        ),
      ],
    );
  }
}

class _SyncModeSelector extends StatelessWidget {
  const _SyncModeSelector({required this.selected, required this.onChanged});

  final _SyncMode selected;
  final ValueChanged<_SyncMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return MobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SyncModeRow(
            mode: _SyncMode.local,
            selected: selected,
            label: '로컬',
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          _SyncModeRow(
            mode: _SyncMode.auto,
            selected: selected,
            label: '자동 동기화',
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          _SyncModeRow(
            mode: _SyncMode.windows,
            selected: selected,
            label: 'Windows 버전 설치',
            onChanged: onChanged,
          ),
        ],
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
    final theme = Theme.of(context);
    final isSelected = selected == mode;
    final color = context.appIncome;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? color
                    : theme.colorScheme.onSurface.withValues(alpha: 0.38),
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
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
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
          icon: Icons.file_upload_outlined,
          title: 'JSON 백업 내보내기',
          description: '현재 데이터를 하나의 JSON 파일로 저장합니다.',
          buttonLabel: '백업 파일 만들기',
          onPressed: busy ? null : onExport,
        ),
        _ActionCard(
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
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.75);

    return MobileCard(
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.desktop_windows_outlined, color: context.appIncome),
              const SizedBox(width: 12),
              Text(
                '다운로드',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Windows PC 버전은 GitHub Releases에서 받을 수 있습니다.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 12),
          SelectableText(
            'Windows 버전 다운로드\n$_releasesUrl',
            style: TextStyle(
              color: context.appIncome,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Android 버전은 현재 내부 테스트/직접 설치용으로 제공됩니다.',
            style: TextStyle(color: muted),
          ),
        ],
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
          foregroundColor: context.appExpense,
          backgroundColor: context.appExpense.withValues(alpha: 0.10),
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
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.75);

    return MobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_sync_outlined, color: context.appIncome),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Supabase 백업 연결',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
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
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 12),
          _SupabaseStatusPanel(
            settings: settings,
            remoteStatus: remoteStatus,
            remoteStatusError: remoteStatusError,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('mobile-settings-supabase-url-field'),
            controller: urlController,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Supabase URL',
              hintText: 'https://project-ref.supabase.co',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('mobile-settings-supabase-anon-key-field'),
            controller: anonKeyController,
            enabled: !busy,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'anon / publishable key',
              prefixIcon: Icon(Icons.key_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('mobile-settings-supabase-bucket-field'),
            controller: bucketController,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Storage bucket',
              hintText: 'my-little-budget',
              prefixIcon: Icon(Icons.inventory_2_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const ValueKey('mobile-settings-supabase-save-button'),
                onPressed: busy ? null : onSave,
                icon: const Icon(Icons.save_outlined),
                label: const Text('설정 저장'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('mobile-settings-supabase-test-button'),
                onPressed: busy ? null : onTest,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('연결 테스트'),
              ),
              OutlinedButton.icon(
                key: const ValueKey(
                  'mobile-settings-supabase-table-test-button',
                ),
                onPressed: busy ? null : onTestTables,
                icon: const Icon(Icons.storage_outlined),
                label: const Text('DB 테이블 테스트'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('mobile-settings-supabase-refresh-button'),
                onPressed: busy ? null : onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('상태 새로고침'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('mobile-settings-supabase-clear-button'),
                onPressed: busy || !configured ? null : onClear,
                icon: const Icon(Icons.delete_outline),
                label: const Text('설정 삭제'),
              ),
              FilledButton.icon(
                key: const ValueKey('mobile-settings-supabase-upload-button'),
                onPressed: busy ? null : onUpload,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Supabase 백업'),
              ),
              FilledButton.icon(
                key: const ValueKey('mobile-settings-supabase-restore-button'),
                onPressed: busy ? null : onRestore,
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Supabase 복원'),
              ),
            ],
          ),
        ],
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
    final theme = Theme.of(context);

    return Container(
      key: const ValueKey('mobile-settings-auto-sync-setup-guide'),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        onExpansionChanged: (value) => setState(() => _expanded = value),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Icon(Icons.help_outline, color: context.appIncome),
        title: const Text(
          '자동동기화 설정방법',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        children: const [_AutoSyncSetupSteps()],
      ),
    );
  }
}

class _AutoSyncSetupSteps extends StatelessWidget {
  const _AutoSyncSetupSteps();

  static const _supabaseUrl = 'https://supabase.com/';
  static const _tableSyncSql = '''
-- My Little Budget table-sync v2 preparation.
-- This stage grants SELECT only. Row upload/update/delete is intentionally not enabled.
-- The anon key is a public client credential, so do not add write policies without auth.

do \$\$
declare
  table_name text;
begin
  foreach table_name in array array[
    'mlb_accounts',
    'mlb_categories',
    'mlb_transactions',
    'mlb_budget_groups',
    'mlb_monthly_income',
    'mlb_investments',
    'mlb_recurring_transactions',
    'mlb_tags',
    'mlb_calendar_events'
  ]
  loop
    execute format(
      'create table if not exists public.%I (
        uuid text primary key,
        payload jsonb not null default ''{}''::jsonb,
        updated_at timestamptz not null default now(),
        deleted_at timestamptz,
        sync_status text not null default ''pending''
      )',
      table_name
    );
    execute format('alter table public.%I enable row level security', table_name);
    execute format(
      'drop policy if exists mlb_sync_read_anon on public.%I',
      table_name
    );
    execute format(
      'create policy mlb_sync_read_anon on public.%I for select to anon using (true)',
      table_name
    );
    execute format('grant select on table public.%I to anon', table_name);
  end loop;
end
\$\$;
''';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = TextStyle(
      color: theme.colorScheme.onSurface,
      height: 1.45,
      fontSize: 18,
      fontWeight: FontWeight.w800,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('1. ', style: style),
            InkWell(
              onTap: () => _openSupabase(context),
              child: Text(
                _supabaseUrl,
                style: style.copyWith(
                  color: context.appIncome,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(
              '에서 GitHub 아이디가 있으면 GitHub 연동으로 로그인합니다. GitHub 아이디가 없으면 계정을 생성합니다.',
              style: style,
            ),
          ],
        ),
        const SizedBox(height: 10),
        const _GuideImage(assetName: 'assets/help/supabase-sign-up.png'),
        const SizedBox(height: 10),
        Text(
          '2. 조직 생성 화면에서 Type은 Personal, Plan은 Free 플랜으로 시작하면 됩니다.',
          style: style,
        ),
        const SizedBox(height: 10),
        const _GuideImage(
          assetName: 'assets/help/supabase-create-organization.png',
        ),
        const SizedBox(height: 10),
        Text('3. Supabase 프로젝트를 만듭니다.', style: style),
        const SizedBox(height: 10),
        const _GuideImage(assetName: 'assets/help/supabase-create-project.png'),
        const SizedBox(height: 10),
        Text(
          '지역은 Asia-Pacific처럼 아시아 지역으로 지정하는 것이 좋습니다. 비밀번호를 설정해야 Storage bucket 생성이 가능합니다.',
          style: style,
        ),
        const SizedBox(height: 10),
        Text('4. Storage bucket을 생성합니다.', style: style),
        const SizedBox(height: 10),
        const _GuideImage(
          assetName: 'assets/help/supabase-create-storage-bucket.png',
        ),
        const SizedBox(height: 10),
        Text(
          '5. 왼쪽 메뉴에서 SQL Editor를 클릭합니다. 화면 중앙의 SQL 입력창에 아래 SQL 명령어를 그대로 붙여넣은 뒤, Run 버튼을 눌러 실행합니다.',
          style: style,
        ),
        const SizedBox(height: 10),
        const _GuideImage(assetName: 'assets/help/supabase-sql-editor.png'),
        const SizedBox(height: 10),
        _SqlCommandBlock(sql: _tableSyncSql),
        const SizedBox(height: 10),
        Text('6. 프로젝트 메인페이지에서 프로젝트 URL을 복사 후 동기화 설정창에 입력합니다.', style: style),
        const SizedBox(height: 10),
        const _GuideImage(
          assetName: 'assets/help/supabase-project-url-copy.png',
        ),
        const SizedBox(height: 10),
        Text(
          '7. Settings - API Keys - Legacy anon, service_role API keys에서 anon public을 복사 후 동기화 설정창에 입력합니다.',
          style: style,
        ),
        const SizedBox(height: 10),
        const _GuideImage(assetName: 'assets/help/supabase-anon-key-copy.png'),
        const SizedBox(height: 10),
        Text(
          '8. 좌측 메뉴 Storage로 이동해서 bucket 생성 후 bucket name을 동기화 설정창에 입력합니다.',
          style: style,
        ),
        const SizedBox(height: 10),
        const _GuideImage(
          assetName: 'assets/help/supabase-storage-bucket-create.png',
        ),
        const SizedBox(height: 10),
        const _GuideImage(
          assetName: 'assets/help/supabase-storage-bucket-name.png',
        ),
        const SizedBox(height: 10),
        Text('9. 설정 저장 후 연결 테스트와 DB 테이블 테스트를 실행합니다.', style: style),
        Text(
          '10. Supabase 백업으로 현재 데이터를 올리고, 필요하면 Supabase 복원으로 내려받습니다.',
          style: style,
        ),
      ],
    );
  }

  Future<void> _openSupabase(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse(_supabaseUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Supabase 링크를 열 수 없습니다.')));
    }
  }
}

class _GuideImage extends StatelessWidget {
  const _GuideImage({required this.assetName});

  final String assetName;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showImagePreview(context),
          child: Image.asset(assetName, fit: BoxFit.contain),
        ),
      ),
    );
  }

  void _showImagePreview(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    boundaryMargin: const EdgeInsets.all(1000),
                    minScale: 0.8,
                    maxScale: 8,
                    child: Center(
                      child: Image.asset(assetName, fit: BoxFit.contain),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SqlCommandBlock extends StatefulWidget {
  const _SqlCommandBlock({required this.sql});

  final String sql;

  @override
  State<_SqlCommandBlock> createState() => _SqlCommandBlockState();
}

class _SqlCommandBlockState extends State<_SqlCommandBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codeStyle = TextStyle(
      color: theme.colorScheme.onSurface,
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.35,
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: _expanded ? '접기' : '펼치기',
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _expanded ? 'SQL 명령어 접기' : 'SQL 명령어 펼쳐보기',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.75,
                          ),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: widget.sql));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('SQL 명령어를 복사했습니다.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('복사'),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: SelectableText(widget.sql, style: codeStyle),
            ),
          ],
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
      key: const ValueKey('mobile-settings-supabase-status-panel'),
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
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.75),
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
    final color = configured
        ? context.appIncome
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75);
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

Future<bool?> _confirmReset(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('데이터 초기화'),
      content: const Text('현재 데이터를 초기 상태로 되돌립니다. 이 작업은 되돌릴 수 없습니다.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('초기화'),
        ),
      ],
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = danger ? context.appExpense : context.appIncome;

    return MobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(danger ? Icons.restore_outlined : Icons.save_alt),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

Future<bool?> _confirmRestore(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('백업 데이터 복원'),
      content: const Text('현재 데이터를 모두 지우고 백업 데이터를 복원합니다. 이 작업은 되돌릴 수 없습니다.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('복원'),
        ),
      ],
    ),
  );
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
