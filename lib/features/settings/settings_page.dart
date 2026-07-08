import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '설정',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '거래 입력과 앱 관리에 필요한 기준 데이터를 정리합니다.',
              style: TextStyle(fontSize: 13, color: context.desktopMuted),
            ),
            SizedBox(height: 24),
            _SettingsCard(
              icon: Icons.category_outlined,
              title: '카테고리 관리',
              subtitle: '수입·지출 카테고리, 색상, 순서, 보관 상태',
              path: '/settings/categories',
            ),
            _SettingsCard(
              icon: Icons.sell_outlined,
              title: '태그 관리',
              subtitle: '거래에 붙이는 자유 라벨',
              path: '/settings/tags',
            ),
            _SettingsCard(
              icon: Icons.repeat_outlined,
              title: '반복 거래',
              subtitle: '고정 수입·지출·이체 자동 생성 규칙',
              path: '/settings/recurring',
            ),
            _SettingsCard(
              icon: Icons.palette_outlined,
              title: '테마 설정',
              subtitle: '화면 모드와 주요 색상 토큰 설정',
              path: '/settings/theme',
            ),
            _SettingsCard(
              icon: Icons.import_export_outlined,
              title: '데이터 백업/복원',
              subtitle: 'JSON 백업 파일 내보내기와 전체 교체 방식 복원',
              path: '/settings/backup',
            ),
            _SettingsCard(
              icon: Icons.info_outline,
              title: '앱 정보',
              subtitle: '버전, 저장소, 라이선스와 개인정보처리방침',
              path: '/settings/about',
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.path,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? path;

  bool get _enabled => path != null;

  @override
  Widget build(BuildContext context) {
    final foreground = _enabled
        ? Theme.of(context).colorScheme.onSurface
        : context.desktopMuted;
    final borderColor = _enabled
        ? context.desktopBorder
        : context.desktopBorder.withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.desktopSurface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _enabled ? () => context.go(path!) : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: _enabled ? context.desktopMuted : foreground,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.desktopMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  _enabled ? Icons.chevron_right : Icons.lock_outline,
                  size: 18,
                  color: context.desktopMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
