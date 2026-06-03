import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
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
            '반복 거래',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTokens.surface,
              border: Border.all(color: AppTokens.sidebarBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '반복 거래 화면은 다음 단계에서 구현합니다.',
              style: TextStyle(color: AppTokens.muted),
            ),
          ),
        ],
      ),
    );
  }
}
