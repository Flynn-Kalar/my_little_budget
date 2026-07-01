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
import '../../shared/notes_providers.dart';
import '../../shared/accounts_providers.dart' as accounts_providers;
import '../../shared/budget_providers.dart' as budget_providers;
import '../../shared/investments_providers.dart' as investments_providers;
import '../../shared/settings_providers.dart' as settings_providers;
import '../../shared/badges_providers.dart' as badges_providers;
import '../../shared/stats_providers.dart' as stats_providers;
import '../../shared/transactions_providers.dart' as transactions_providers;
import '../mobile_widgets.dart';

class MobileDataManagementScreen extends ConsumerStatefulWidget {
  const MobileDataManagementScreen({super.key});

  @override
  ConsumerState<MobileDataManagementScreen> createState() =>
      _MobileDataManagementScreenState();
}

class _MobileDataManagementScreenState
    extends ConsumerState<MobileDataManagementScreen> {
  bool _busy = false;
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
    _fillSupabaseControllers(ref.read(supabaseBackupSettingsProvider));
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
        result.isOk ? 'Supabase DB 엔티티 테이블 8개를 확인했습니다.' : result.error!,
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
        _SupabaseSettingsCard(
          urlController: _supabaseUrlCtrl,
          anonKeyController: _supabaseAnonKeyCtrl,
          bucketController: _supabaseBucketCtrl,
          pathPrefixController: _supabasePathPrefixCtrl,
          configured: ref.watch(supabaseBackupSettingsProvider).isConfigured,
          settings: ref.watch(supabaseBackupSettingsProvider),
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
        _ActionCard(
          icon: Icons.file_upload_outlined,
          title: '백업 내보내기',
          description: '현재 데이터를 하나의 JSON 파일로 저장합니다.',
          buttonLabel: '백업 파일 만들기',
          onPressed: _busy ? null : _exportBackup,
        ),
        _ActionCard(
          icon: Icons.file_download_outlined,
          title: '백업 불러오기',
          description: '백업 JSON 파일을 확인한 뒤 현재 데이터를 백업 데이터로 교체합니다.',
          buttonLabel: '백업 파일 선택',
          danger: true,
          onPressed: _busy ? null : _importBackup,
        ),
        _ActionCard(
          icon: Icons.delete_forever_outlined,
          title: '데이터 초기화',
          description: '거래, 예산, 투자, 태그 데이터를 삭제하고 기본 자산과 카테고리를 복구합니다.',
          buttonLabel: '초기화',
          danger: true,
          onPressed: _busy ? null : _resetAllData,
        ),
        MobileCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_outlined, color: context.appExpense),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '복원과 초기화는 되돌릴 수 없습니다. 진행 전에 백업 파일을 만들어두세요.',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 3),
      ],
    );
  }
}

class _SupabaseSettingsCard extends StatelessWidget {
  const _SupabaseSettingsCard({
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
          const SizedBox(height: 8),
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
          TextField(
            key: const ValueKey('mobile-settings-supabase-path-prefix-field'),
            controller: pathPrefixController,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Path prefix',
              hintText: 'my_little_budget',
              prefixIcon: Icon(Icons.folder_outlined),
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
