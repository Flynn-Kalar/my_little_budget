import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../features/settings/app_info.dart';
import '../../../features/settings/update_check.dart';
import '../mobile_widgets.dart';

class MobileSettingsScreen extends ConsumerStatefulWidget {
  const MobileSettingsScreen({super.key});

  @override
  ConsumerState<MobileSettingsScreen> createState() =>
      _MobileSettingsScreenState();
}

class _MobileSettingsScreenState extends ConsumerState<MobileSettingsScreen> {
  bool _checkingForUpdate = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.75);
    final packageInfo = ref.watch(appPackageInfoProvider);
    final versionLabel = packageInfo.when(
      data: packageVersionLabel,
      loading: () => '확인 중...',
      error: (_, _) => appVersionLabel,
    );

    return MobilePage(
      title: '설정',
      children: [
        const _SettingsTile(
          icon: Icons.category_outlined,
          title: '카테고리 관리',
          path: '/settings/categories',
        ),
        const _SettingsTile(
          icon: Icons.sell_outlined,
          title: '태그 관리',
          path: '/settings/tags',
        ),
        const _SettingsTile(
          icon: Icons.repeat_outlined,
          title: '반복 거래',
          path: '/settings/recurring',
        ),
        const _SettingsTile(
          icon: Icons.palette_outlined,
          title: '테마 설정',
          path: '/settings/theme',
        ),
        const _SettingsTile(
          icon: Icons.import_export_outlined,
          title: '데이터 백업/복원',
          path: '/settings/backup',
        ),
        const _SettingsTile(
          icon: Icons.info_outline,
          title: '앱 정보',
          path: '/settings/about',
        ),
        MobileCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: _checkingForUpdate
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.system_update_outlined, color: muted),
            title: const Text(
              '최신 버전 확인',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              _checkingForUpdate
                  ? 'GitHub Releases를 확인하고 있습니다.'
                  : '$versionLabel · 눌러서 새 버전을 확인합니다.',
              style: TextStyle(color: muted),
            ),
            trailing: _checkingForUpdate
                ? null
                : const Icon(Icons.chevron_right),
            onTap: _checkingForUpdate ? null : _checkForUpdate,
          ),
        ),
      ],
    );
  }

  Future<void> _checkForUpdate() async {
    setState(() => _checkingForUpdate = true);
    try {
      final packageInfo = await ref.read(appPackageInfoProvider.future);
      final result = await ref
          .read(updateCheckServiceProvider)
          .check(currentVersion: packageVersionLabel(packageInfo));
      if (!mounted) return;
      await _showUpdateResult(context, result);
    } on UpdateCheckException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _checkingForUpdate = false);
    }
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

Future<void> _showUpdateResult(
  BuildContext context,
  UpdateCheckResult result,
) async {
  final release = result.latestRelease;
  final title = switch (result.status) {
    UpdateCheckStatus.updateAvailable => '새 버전이 있습니다',
    UpdateCheckStatus.upToDate => '최신 버전입니다',
    UpdateCheckStatus.noRelease => '등록된 릴리스가 없습니다',
  };
  final message = switch (result.status) {
    UpdateCheckStatus.updateAvailable =>
      '현재 ${result.currentVersion}\n최신 ${release!.tagName}${release.prerelease ? ' (시험판)' : ''}',
    UpdateCheckStatus.upToDate =>
      '현재 ${result.currentVersion}\nGitHub 최신 ${release!.tagName}',
    UpdateCheckStatus.noRelease => 'GitHub Releases에 아직 배포된 버전이 없습니다.',
  };
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('확인'),
        ),
        if (release != null)
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final opened = await _openPlayStore();
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Play 스토어를 열 수 없습니다.')),
                );
              }
            },
            icon: const Icon(Icons.shop_outlined, size: 18),
            label: const Text('Play 스토어에서 보기'),
          ),
      ],
    ),
  );
}

Future<bool> _openPlayStore() async {
  try {
    final openedApp = await launchUrl(
      Uri.parse(appPlayStoreMarketUrl),
      mode: LaunchMode.externalApplication,
    );
    if (openedApp) return true;
  } catch (_) {
    // Play Store 앱이 없으면 아래 웹 주소를 사용한다.
  }
  try {
    return await launchUrl(
      Uri.parse(appPlayStoreUrl),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
