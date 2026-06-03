import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// 라우트가 살아있는지만 확인하는 임시 페이지. 각 feature 구현 시 교체.
class PlaceholderScaffold extends StatelessWidget {
  const PlaceholderScaffold({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: const TextStyle(fontSize: 14, color: AppTokens.muted),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTokens.surface,
            border: Border.all(color: AppTokens.sidebarBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '구현 예정 — 자세한 동작은 /SPEC.md 참고',
            style: TextStyle(fontSize: 13, color: AppTokens.muted),
          ),
        ),
      ],
    );
  }
}
