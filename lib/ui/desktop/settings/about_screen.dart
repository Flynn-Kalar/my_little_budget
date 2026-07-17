import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/settings/app_info.dart';
import '../../../features/settings/update_check.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfo = ref.watch(appPackageInfoProvider);
    final versionLabel = packageInfo.when(
      data: packageVersionLabel,
      loading: () => '확인 중...',
      error: (_, _) => appVersionLabel,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.chevron_left),
              label: const Text('설정'),
            ),
            const SizedBox(height: 8),
            const Text(
              '앱 정보',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '버전, 저장소, 라이선스와 개인정보처리방침을 확인합니다.',
              style: TextStyle(fontSize: 13, color: context.desktopMuted),
            ),
            const SizedBox(height: 24),
            _InfoCard(
              icon: Icons.info_outline,
              title: '버전',
              value: versionLabel,
            ),
            _InfoCard(
              icon: Icons.code_outlined,
              title: 'GitHub 저장소',
              value: appRepositoryUrl,
              copyValue: appRepositoryUrl,
            ),
            _ActionCard(
              icon: Icons.article_outlined,
              title: '오픈소스 라이선스',
              subtitle: '앱에서 사용하는 Flutter 및 패키지 라이선스',
              onTap: () => showLicensePage(
                context: context,
                applicationName: appDisplayName,
                applicationVersion: versionLabel,
              ),
            ),
            _InfoCard(
              icon: Icons.privacy_tip_outlined,
              title: '개인정보처리방침',
              value: appPrivacyPolicyUrl,
              copyValue: appPrivacyPolicyUrl,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    this.copyValue,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? copyValue;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      icon: icon,
      title: title,
      trailing: copyValue == null
          ? null
          : IconButton(
              tooltip: '복사',
              onPressed: () => _copyToClipboard(context, copyValue!),
              icon: const Icon(Icons.copy_outlined, size: 18),
            ),
      child: SelectableText(
        value,
        style: TextStyle(fontSize: 13, color: context.desktopMuted),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      icon: icon,
      title: title,
      onTap: onTap,
      trailing: Icon(
        Icons.chevron_right,
        size: 18,
        color: context.desktopMuted,
      ),
      child: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: context.desktopMuted),
      ),
    );
  }
}

class _BaseCard extends StatelessWidget {
  const _BaseCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.desktopSurface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: context.desktopBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: context.desktopMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      child,
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _copyToClipboard(BuildContext context, String value) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('복사했습니다.')));
}
