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
        dialogTitle: 'Save backup file',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: utf8.encode(json),
      );
      if (path == null) return;
      if (!mounted) return;
      _showSnack('Backup file created: $filename');
    } catch (e) {
      if (mounted) _showSnack('Failed to create backup file: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importBackup() async {
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.pickFiles(
        dialogTitle: 'Select backup file to restore',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        allowMultiple: false,
      );
      if (picked == null || picked.files.single.path == null) return;

      final file = File(picked.files.single.path!);
      final content = await file.readAsString();
      final parsed = parseBackup(content);
      if (!parsed.isOk) {
        _showSnack(parsed.error ?? 'Backup file structure is invalid.');
        return;
      }

      if (!mounted) return;
      final confirmed = await showImportConfirmationDialog(context);
      if (confirmed != true) return;

      await ref.read(backupDaoProvider).importBackup(parsed.backup!);
      _invalidateAfterImport(ref);
      if (!mounted) return;
      _showSnack('Backup data restored.');
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to restore backup. Existing data is unchanged. $e');
      }
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
              label: const Text('Settings'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Data Backup / Restore',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Export all app data to JSON or fully replace current data from a backup file.',
              style: TextStyle(fontSize: 13, color: AppTokens.muted),
            ),
            const SizedBox(height: 24),
            _ActionCard(
              buttonKey: const ValueKey('settings-backup-export-button'),
              icon: Icons.file_upload_outlined,
              title: 'Export data',
              description:
                  'Save current app data as one JSON file. The save location is chosen in the file dialog.',
              buttonLabel: 'Create backup file',
              onPressed: _busy ? null : _exportBackup,
            ),
            const SizedBox(height: 12),
            _ActionCard(
              buttonKey: const ValueKey('settings-backup-import-button'),
              icon: Icons.file_download_outlined,
              title: 'Import data',
              description:
                  'Validate a backup JSON file, then fully replace current data with the backup state.',
              buttonLabel: 'Choose backup file',
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
                'Import is not a merge. It validates the backup file and asks for confirmation before replacing all current app data.',
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
