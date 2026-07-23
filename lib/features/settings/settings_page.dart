import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'app_info.dart';
import 'update_check.dart';
import 'windows_update_installer.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _checkingForUpdate = false;
  bool _installingUpdate = false;
  double _updateProgress = 0;

  @override
  Widget build(BuildContext context) {
    final packageInfo = ref.watch(appPackageInfoProvider);
    final versionLabel = packageInfo.when(
      data: packageVersionLabel,
      loading: () => '확인 중...',
      error: (_, _) => appVersionLabel,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '설정',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '거래 입력과 앱 관리에 필요한 기준 데이터를 정리합니다.',
            style: TextStyle(fontSize: 13, color: context.desktopMuted),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: const [
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _UpdateCheckCard(
            versionLabel: versionLabel,
            checking: _checkingForUpdate,
            installing: _installingUpdate,
            updateProgress: _updateProgress,
            onTap: _checkingForUpdate || _installingUpdate
                ? null
                : _checkForUpdate,
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    setState(() => _checkingForUpdate = true);
    UpdateCheckResult? result;
    try {
      final packageInfo = await ref.read(appPackageInfoProvider.future);
      result = await ref
          .read(updateCheckServiceProvider)
          .check(currentVersion: packageVersionLabel(packageInfo));
    } on UpdateCheckException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _checkingForUpdate = false);
    }
    if (!mounted || result == null) return;
    final approved = await _showUpdateResult(context, result);
    if (approved != true || !mounted) return;
    final installer = result.latestRelease?.windowsInstaller;
    if (installer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 릴리스에는 Windows Setup 파일이 없습니다.')),
      );
      return;
    }
    await _installUpdate(installer);
  }

  Future<void> _installUpdate(GitHubReleaseAsset installer) async {
    setState(() {
      _installingUpdate = true;
      _updateProgress = 0;
    });
    try {
      await ref
          .read(windowsUpdateInstallerProvider)
          .install(
            installer,
            onProgress: (progress) {
              if (!mounted) return;
              setState(() => _updateProgress = progress);
            },
          );
    } on WindowsUpdateException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _installingUpdate = false);
    }
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.path,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.desktopSurface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go(path),
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
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
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
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
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

class _UpdateCheckCard extends StatelessWidget {
  const _UpdateCheckCard({
    required this.versionLabel,
    required this.checking,
    required this.installing,
    required this.updateProgress,
    required this.onTap,
  });

  final String versionLabel;
  final bool checking;
  final bool installing;
  final double updateProgress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.desktopSurface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: context.desktopBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              checking || installing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.system_update_outlined,
                      size: 18,
                      color: context.desktopMuted,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '최신 버전 확인',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      checking
                          ? 'GitHub Releases를 확인하고 있습니다.'
                          : installing
                          ? '업데이트를 다운로드하고 있습니다. ${(updateProgress * 100).round()}%'
                          : '$versionLabel · 누르면 GitHub Releases에서 새 버전을 확인합니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.desktopMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool?> _showUpdateResult(
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
      '현재 ${result.currentVersion}\n'
          '최신 ${release!.tagName}${release.prerelease ? ' (시험판)' : ''}\n'
          '${_installerSizeLabel(release.windowsInstaller)}\n\n'
          '허용하면 Setup을 다운로드하고 검증한 뒤 앱을 종료하여 업데이트합니다.',
    UpdateCheckStatus.upToDate =>
      '현재 ${result.currentVersion}\nGitHub 최신 ${release!.tagName}',
    UpdateCheckStatus.noRelease => 'GitHub Releases에 아직 배포된 버전이 없습니다.',
  };
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(
            result.status == UpdateCheckStatus.updateAvailable ? '취소' : '확인',
          ),
        ),
        if (result.status == UpdateCheckStatus.updateAvailable)
          FilledButton.icon(
            onPressed: release?.windowsInstaller == null
                ? null
                : () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('다운로드 후 업데이트'),
          ),
      ],
    ),
  );
}

String _installerSizeLabel(GitHubReleaseAsset? installer) {
  if (installer == null) return 'Windows Setup 파일이 없습니다.';
  if (installer.size <= 0) return '다운로드 용량을 확인할 수 없습니다.';
  final megabytes = installer.size / (1024 * 1024);
  return '다운로드 ${megabytes.toStringAsFixed(1)}MB';
}
