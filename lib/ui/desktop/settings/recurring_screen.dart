import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'package:my_little_budget/features/settings/providers.dart';
import 'widgets/recurring_list.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recurringItemsProvider);
    final accounts =
        ref.watch(settingsAccountsProvider).asData?.value ?? const [];
    final categories =
        ref.watch(settingsActiveCategoriesProvider).asData?.value ?? const [];
    final tags = ref.watch(settingsTagsProvider).asData?.value ?? const [];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => context.go('/settings'),
              icon: Icon(Icons.chevron_left, size: 18),
              label: Text('설정'),
              style: TextButton.styleFrom(
                foregroundColor: context.desktopMuted,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '반복 거래',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '월세·구독·급여처럼 주기적으로 발생하는 거래를 자동으로 추가합니다.',
              style: TextStyle(fontSize: 13, color: context.desktopMuted),
            ),
            SizedBox(height: 24),
            items.when(
              loading: () => Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text('불러오기 오류: $e'),
              ),
              data: (rows) => RecurringList(
                items: rows,
                accounts: accounts,
                categories: categories,
                tags: tags,
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
