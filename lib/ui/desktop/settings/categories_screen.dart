import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/database.dart';
import 'package:my_little_budget/features/settings/providers.dart';
import 'widgets/category_manager.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allCategoriesProvider);
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
              '카테고리 관리',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '지출·수입 카테고리를 추가하고 색상과 순서를 바꿀 수 있습니다.',
              style: TextStyle(fontSize: 13, color: context.desktopMuted),
            ),
            SizedBox(height: 28),
            async.when(
              loading: () => Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text('불러오기 오류: $e'),
              ),
              data: (all) {
                final expense = _active(all, 'expense');
                final income = _active(all, 'income');
                final archived = all
                    .where((c) => c.archivedAt != null)
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CategoryManager(
                      type: 'expense',
                      title: '지출 카테고리',
                      items: expense,
                    ),
                    SizedBox(height: 32),
                    CategoryManager(
                      type: 'income',
                      title: '수입 카테고리',
                      items: income,
                    ),
                    if (archived.isNotEmpty) ...[
                      SizedBox(height: 32),
                      CategoryManager(
                        type: 'archived',
                        title: '보관됨',
                        items: archived,
                      ),
                    ],
                    SizedBox(height: 40),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Category> _active(List<Category> all, String type) {
    return all.where((c) => c.type == type && c.archivedAt == null).toList();
  }
}
