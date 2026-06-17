import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/backup.dart';
import '../../../data/cloud_backup.dart';
import '../../../data/providers.dart';
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
  CloudBackupAccount? _cloudAccount;
  CloudBackupFile? _latestCloudBackup;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCloudStatus);
  }

  Future<void> _loadCloudStatus() async {
    final service = ref.read(cloudBackupServiceProvider);
    if (!service.isSupported) return;

    final account = await service.currentAccount();
    CloudBackupFile? latest;
    if (account != null) {
      final list = await service.listBackups();
      if (list.isOk && list.value!.isNotEmpty) {
        latest = list.value!.first;
      }
    }
    if (!mounted) return;
    setState(() {
      _cloudAccount = account;
      _latestCloudBackup = latest;
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
      if (!mounted) return;
      _showSnack('초기화했습니다.');
    } catch (e) {
      debugPrint('resetAllData failed: $e');
      if (mounted) _showSnack('초기화에 실패했습니다. 데이터를 다시 확인해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectGoogleDrive() async {
    setState(() => _busy = true);
    try {
      final account = await ref.read(cloudBackupServiceProvider).signIn();
      if (!mounted) return;
      if (account == null) {
        _showSnack('Google 계정 연결이 취소되었습니다.');
        return;
      }
      setState(() => _cloudAccount = account);
      await _loadCloudStatus();
      if (mounted) _showSnack('Google Drive에 연결되었습니다.');
    } catch (e) {
      debugPrint('connectGoogleDrive failed: $e');
      if (mounted) _showSnack('Google Drive 연결에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnectGoogleDrive() async {
    setState(() => _busy = true);
    try {
      await ref.read(cloudBackupServiceProvider).signOut();
      if (!mounted) return;
      setState(() {
        _cloudAccount = null;
        _latestCloudBackup = null;
      });
      _showSnack('Google Drive 연결을 해제했습니다.');
    } catch (e) {
      debugPrint('disconnectGoogleDrive failed: $e');
      if (mounted) _showSnack('Google Drive 연결 해제에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadGoogleDriveBackup() async {
    setState(() => _busy = true);
    try {
      final backup = await ref.read(backupDaoProvider).exportBackup();
      final filename = buildBackupFilename();
      final result = await ref
          .read(cloudBackupServiceProvider)
          .uploadBackup(filename: filename, json: backup.toJsonString());
      if (!mounted) return;
      if (!result.isOk) {
        _showSnack(result.error ?? 'Google Drive 백업에 실패했습니다.');
        return;
      }
      setState(() => _latestCloudBackup = result.value);
      _showSnack('Google Drive에 백업했습니다.');
    } catch (e) {
      debugPrint('uploadGoogleDriveBackup failed: $e');
      if (mounted) _showSnack('Google Drive 백업에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreGoogleDriveBackup() async {
    setState(() => _busy = true);
    try {
      final list = await ref.read(cloudBackupServiceProvider).listBackups();
      if (!list.isOk) {
        if (mounted) {
          _showSnack(list.error ?? 'Google Drive 백업 목록을 불러오지 못했습니다.');
        }
        return;
      }
      if (list.value!.isEmpty) {
        if (mounted) _showSnack('Google Drive에 백업 파일이 없습니다.');
        return;
      }

      final latest = list.value!.first;
      final content = await ref
          .read(cloudBackupServiceProvider)
          .downloadBackup(latest);
      if (!content.isOk) {
        if (mounted) {
          _showSnack(content.error ?? 'Google Drive 백업 다운로드에 실패했습니다.');
        }
        return;
      }

      final parsed = parseBackup(content.value!);
      if (!parsed.isOk) {
        if (mounted) _showSnack(parsed.error ?? '백업 파일 형식이 올바르지 않습니다.');
        return;
      }

      if (!mounted) return;
      final confirmed = await _confirmRestore(context);
      if (confirmed != true) return;

      await ref.read(backupDaoProvider).importBackup(parsed.backup!);
      _invalidateAfterImport(ref);
      if (!mounted) return;
      setState(() => _latestCloudBackup = latest);
      _showSnack('Google Drive 백업을 복원했습니다.');
    } catch (e) {
      debugPrint('restoreGoogleDriveBackup failed: $e');
      if (mounted) _showSnack('Google Drive 복원에 실패했습니다.');
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
        _CloudBackupCard(
          supported: ref.watch(cloudBackupServiceProvider).isSupported,
          account: _cloudAccount,
          latest: _latestCloudBackup,
          busy: _busy,
          onConnect: _connectGoogleDrive,
          onDisconnect: _disconnectGoogleDrive,
          onUpload: _uploadGoogleDriveBackup,
          onRestore: _restoreGoogleDriveBackup,
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

class _CloudBackupCard extends StatelessWidget {
  const _CloudBackupCard({
    required this.supported,
    required this.account,
    required this.latest,
    required this.busy,
    required this.onConnect,
    required this.onDisconnect,
    required this.onUpload,
    required this.onRestore,
  });

  final bool supported;
  final CloudBackupAccount? account;
  final CloudBackupFile? latest;
  final bool busy;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onUpload;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connected = account != null;
    final latestText = latest == null
        ? '최근 Google Drive 백업이 없습니다.'
        : '최근 백업: ${latest!.name}${_formatModifiedAt(latest!.modifiedAt)}';
    final description = supported
        ? connected
              ? '${account!.email}\n$latestText'
              : 'Google 계정을 연결하면 앱 전용 Drive 저장소에 백업합니다.'
        : 'Google Drive 백업은 현재 Android에서만 사용할 수 있습니다.';

    return MobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_upload_outlined, color: context.appIncome),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Drive 백업',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      key: const ValueKey('mobile-settings-cloud-latest'),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.75,
                        ),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!connected)
                OutlinedButton.icon(
                  key: const ValueKey('mobile-settings-cloud-connect-button'),
                  onPressed: supported && !busy ? onConnect : null,
                  icon: const Icon(Icons.login),
                  label: const Text('연결'),
                )
              else
                OutlinedButton.icon(
                  key: const ValueKey(
                    'mobile-settings-cloud-disconnect-button',
                  ),
                  onPressed: busy ? null : onDisconnect,
                  icon: const Icon(Icons.logout),
                  label: const Text('해제'),
                ),
              FilledButton.icon(
                key: const ValueKey('mobile-settings-cloud-upload-button'),
                onPressed: supported && connected && !busy ? onUpload : null,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Drive 백업'),
              ),
              FilledButton.icon(
                key: const ValueKey('mobile-settings-cloud-restore-button'),
                onPressed: supported && connected && !busy ? onRestore : null,
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Drive 복원'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatModifiedAt(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return ' (${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)})';
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
