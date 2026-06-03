import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'providers.dart';
import 'widgets/tag_manager.dart';

class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(settingsTagsProvider);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.chevron_left, size: 18),
              label: const Text('설정'),
              style: TextButton.styleFrom(foregroundColor: AppTokens.muted),
            ),
            const SizedBox(height: 8),
            const Text(
              '태그 관리',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '카테고리와 독립적인 자유 라벨입니다. 한 거래에 여러 태그를 붙일 수 있습니다.',
              style: TextStyle(fontSize: 13, color: AppTokens.muted),
            ),
            const SizedBox(height: 24),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text('불러오기 오류: $e'),
              ),
              data: (tags) => TagManager(tags: tags),
            ),
          ],
        ),
      ),
    );
  }
}
