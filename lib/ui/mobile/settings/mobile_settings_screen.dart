import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../mobile_widgets.dart';

class MobileSettingsScreen extends StatelessWidget {
  const MobileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MobilePage(
      title: '설정',
      children: const [
        _SettingsTile(
          icon: Icons.category_outlined,
          title: '카테고리 관리',
          path: '/settings/categories',
        ),
        _SettingsTile(
          icon: Icons.sell_outlined,
          title: '태그 관리',
          path: '/settings/tags',
        ),
        _SettingsTile(
          icon: Icons.repeat_outlined,
          title: '반복 거래',
          path: '/settings/recurring',
        ),
        _SettingsTile(
          icon: Icons.palette_outlined,
          title: '테마 설정',
          path: '/settings/theme',
        ),
        _SettingsTile(
          icon: Icons.import_export_outlined,
          title: '데이터 백업/복원',
          path: '/settings/backup',
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.path,
  });

  final IconData icon;
  final String title;
  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MobileCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          icon,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
        ),
        title: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(path),
      ),
    );
  }
}
