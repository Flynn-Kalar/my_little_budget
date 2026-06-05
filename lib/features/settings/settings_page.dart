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
          children: const [
            Text(
              '설정',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '거래 입력과 앱 관리에 필요한 기준 데이터를 정리합니다.',
              style: TextStyle(fontSize: 13, color: AppTokens.muted),
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
              subtitle: '색상 저장 로직은 준비되어 있습니다. 화면 연결 예정입니다.',
              disabledLabel: 'TODO',
            ),
            _SettingsCard(
              icon: Icons.import_export_outlined,
              title: '데이터 백업/복원',
              subtitle: 'JSON 백업 파일 내보내기와 전체 교체 방식 복원',
              path: '/settings/data',
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
    this.disabledLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? path;
  final String? disabledLabel;

  bool get _enabled => path != null;

  @override
  Widget build(BuildContext context) {
    final foreground = _enabled ? Colors.black87 : AppTokens.muted;
    final borderColor = _enabled
        ? AppTokens.sidebarBorder
        : AppTokens.sidebarBorder.withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTokens.surface,
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
                  color: _enabled ? AppTokens.muted : foreground,
                ),
                const SizedBox(width: 12),
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
                          if (disabledLabel != null) ...[
                            const SizedBox(width: 8),
                            _StatusPill(label: disabledLabel!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTokens.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _enabled ? Icons.chevron_right : Icons.lock_outline,
                  size: 18,
                  color: AppTokens.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTokens.sidebarActive,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppTokens.muted,
        ),
      ),
    );
  }
}
