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
      final path = await FilePicker.saveFile(
        dialogTitle: '백업 파일 저장',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (path == null) return;

      await File(path).writeAsString(backup.toJsonString());
      if (!mounted) return;
      _showSnack('백업 파일을 생성했습니다: $filename');
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
        _showSnack(parsed.error ?? '백업 파일 구조가 올바르지 않습니다.');
        return;
      }

      if (!mounted) return;
      final confirmed = await _confirmImport();
      if (confirmed != true) return;

      await ref.read(backupDaoProvider).importBackup(parsed.backup!);
      _invalidateAfterImport(ref);
      if (!mounted) return;
      _showSnack('백업 데이터를 복원했습니다.');
    } catch (e) {
      if (mounted) _showSnack('백업 복원에 실패했습니다. 기존 데이터는 유지됩니다: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmImport() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('백업 데이터 복원'),
        content: const Text('현재 데이터를 모두 덮어쓰고 백업 데이터를 복원합니다. 되돌릴 수 없습니다.'),
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
              '데이터 백업/복원',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '현재 앱 데이터를 JSON 파일로 내보내거나, 백업 파일로 전체 데이터를 복원합니다.',
              style: TextStyle(fontSize: 13, color: AppTokens.muted),
            ),
            const SizedBox(height: 24),
            _ActionCard(
              icon: Icons.file_upload_outlined,
              title: '데이터 내보내기',
              description:
                  '현재 앱 데이터를 단일 JSON 파일로 저장합니다. 저장 위치는 파일 선택 창에서 지정합니다.',
              buttonLabel: '백업 파일 만들기',
              onPressed: _busy ? null : _exportBackup,
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.file_download_outlined,
              title: '데이터 가져오기',
              description: '백업 JSON 파일을 검증한 뒤 현재 데이터를 백업 상태로 완전히 교체합니다.',
              buttonLabel: '백업 파일 선택',
              danger: true,
              onPressed: _busy ? null : _importBackup,
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
                '가져오기는 merge가 아니라 전체 교체입니다. 가져오기 전 백업 파일 구조를 검증하고, 복원 직전 확인 dialog를 표시합니다.',
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
