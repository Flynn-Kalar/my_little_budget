import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../features/settings/app_info.dart';
import '../mobile_widgets.dart';

class MobileAboutScreen extends StatelessWidget {
  const MobileAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.75);

    return MobilePage(
      title: '앱 정보',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.chevron_left),
            label: const Text('설정'),
          ),
        ),
        _InfoTile(
          icon: Icons.info_outline,
          title: '버전',
          subtitle: appVersionLabel,
          muted: muted,
        ),
        _InfoTile(
          icon: Icons.code_outlined,
          title: 'GitHub 저장소',
          subtitle: appRepositoryUrl,
          muted: muted,
          copyValue: appRepositoryUrl,
        ),
        MobileCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(Icons.article_outlined, color: muted),
            title: const Text(
              '오픈소스 라이선스',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text('사용 중인 패키지 라이선스', style: TextStyle(color: muted)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: appDisplayName,
              applicationVersion: appVersionLabel,
            ),
          ),
        ),
        _InfoTile(
          icon: Icons.privacy_tip_outlined,
          title: '개인정보처리방침',
          subtitle: appPrivacyPolicyUrl,
          muted: muted,
          copyValue: appPrivacyPolicyUrl,
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.muted,
    this.copyValue,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color muted;
  final String? copyValue;

  @override
  Widget build(BuildContext context) {
    return MobileCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: muted),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: muted),
        ),
        trailing: copyValue == null
            ? null
            : IconButton(
                tooltip: '복사',
                onPressed: () => _copyToClipboard(context, copyValue!),
                icon: const Icon(Icons.copy_outlined),
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
