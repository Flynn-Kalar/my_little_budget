import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/backup.dart';
import '../../../data/providers.dart';
import '../accounts/providers.dart' as accounts_providers;
import '../budget/providers.dart' as budget_providers;
import '../investments/providers.dart' as investments_providers;
import '../shell/badges_providers.dart' as badges_providers;
import '../stats/providers.dart' as stats_providers;
import '../transactions/providers.dart' as transactions_providers;
import 'providers.dart' as settings_providers;

class DataManagementScreen extends ConsumerStatefulWidget {
  const DataManagementScreen({super.key});

  @override
  ConsumerState<DataManagementScreen> createState() =>
      _DataManagementScreenState();
}

class _DataManagementScreenState extends ConsumerState<DataManagementScreen> {
  bool _busy = false;

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
      if (!mounted) return;
      _showSnack('데이터를 초기화했습니다.');
    } catch (e) {
      if (mounted) _showSnack('초기화에 실패했습니다: $e');
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: _busy ? null : () => context.go('/settings'),
              icon: const Icon(Icons.chevron_left),
              label: const Text('설정'),
            ),
            const SizedBox(height: 8),
            const Text(
              '데이터 백업 / 복원',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '앱 데이터를 JSON으로 저장하거나, 백업 파일로 현재 데이터를 전체 교체할 수 있습니다.',
              style: TextStyle(fontSize: 13, color: AppTokens.muted),
            ),
            const SizedBox(height: 24),
            _ActionCard(
              buttonKey: const ValueKey('settings-backup-export-button'),
              icon: Icons.file_upload_outlined,
              title: '백업 내보내기',
              description: '현재 앱 데이터를 하나의 JSON 파일로 저장합니다.',
              buttonLabel: '백업 파일 만들기',
              onPressed: _busy ? null : _exportBackup,
            ),
            const SizedBox(height: 12),
            _ActionCard(
              buttonKey: const ValueKey('settings-backup-import-button'),
              icon: Icons.file_download_outlined,
              title: '백업 불러오기',
              description: '백업 JSON 파일을 확인한 뒤 현재 데이터를 백업 데이터로 교체합니다.',
              buttonLabel: '백업 파일 선택',
              danger: true,
              onPressed: _busy ? null : _importBackup,
            ),
            const SizedBox(height: 12),
            _ActionCard(
              buttonKey: const ValueKey('settings-data-reset-button'),
              icon: Icons.delete_forever_outlined,
              title: '데이터 초기화',
              description: '거래, 예산, 투자, 태그 데이터를 삭제하고 기본 자산과 카테고리를 복구합니다.',
              buttonLabel: '초기화',
              danger: true,
              onPressed: _busy ? null : _resetAllData,
            ),
            const SizedBox(height: 12),
            const _WarningCard(),
            if (_busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(minHeight: 3),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

Future<bool?> showResetConfirmationDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('데이터 초기화'),
      content: const Text('현재 데이터를 모두 삭제하고 기본 자산과 카테고리를 복구합니다. 되돌릴 수 없습니다.'),
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

Future<bool?> showImportConfirmationDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('\uBC31\uC5C5 \uB370\uC774\uD130 \uBCF5\uC6D0'),
      content: const Text(
        '\uD604\uC7AC \uB370\uC774\uD130\uB97C \uBAA8\uB450 '
        '\uB36E\uC5B4\uC4F0\uACE0 \uBC31\uC5C5 \uB370\uC774\uD130\uB97C '
        '\uBCF5\uC6D0\uD569\uB2C8\uB2E4. \uB418\uB3CC\uB9B4 \uC218 '
        '\uC5C6\uC2B5\uB2C8\uB2E4.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('\uCDE8\uC18C'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('\uBCF5\uC6D0'),
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
    final color = danger ? AppTokens.expense : AppTokens.accent;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTokens.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
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

class _WarningCard extends StatelessWidget {
  const _WarningCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_outlined, color: AppTokens.expense),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '복원은 병합이 아닙니다. 백업 파일을 확인한 뒤 현재 데이터를 모두 덮어쓰기 전에 확인을 요청합니다.',
                style: TextStyle(color: AppTokens.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
