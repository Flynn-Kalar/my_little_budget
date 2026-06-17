import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../shared/prism_color_picker.dart';

class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final colors = ref.watch(themeProvider).forBrightness(brightness);
    final mode = ref.watch(themeModeProvider);
    final muted = context.desktopMuted;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => context.go('/settings'),
              icon: Icon(Icons.chevron_left),
              label: Text('설정'),
            ),
            SizedBox(height: 8),
            Text(
              '테마 설정',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '화면 모드와 주요 색상을 조정합니다. 변경사항은 즉시 적용되고 저장됩니다.',
              style: TextStyle(fontSize: 13, color: muted),
            ),
            SizedBox(height: 24),
            _ThemeCard(
              child: Row(
                children: [
                  Icon(Icons.brightness_6_outlined, color: muted),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '화면 모드',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (selected) {
                      ref
                          .read(themeModeProvider.notifier)
                          .setMode(selected.first);
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            _ThemeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '색상 토큰',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => ref
                            .read(themeProvider.notifier)
                            .reset(brightness: brightness),
                        icon: Icon(Icons.restart_alt, size: 18),
                        label: Text('기본값'),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  for (final token in ThemeToken.values) ...[
                    _TokenColorCard(token: token, color: colors.of(token)),
                    SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _TokenColorCard extends ConsumerWidget {
  const _TokenColorCard({required this.token, required this.color});

  final ThemeToken token;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final border = context.desktopBorder;
    final muted = context.desktopMuted;
    final hex = _toHex(color).toLowerCase();

    return Material(
      color: context.desktopSurface,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            _ColorSquare(color: color, size: 30),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tokenLabel(token),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    _tokenDescription(token),
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            Text(
              hex,
              style: TextStyle(
                fontSize: 12,
                color: muted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(width: 14),
            InkWell(
              key: ValueKey('theme-color-picker-${token.name}'),
              borderRadius: BorderRadius.circular(4),
              onTap: () => _showColorPicker(context, ref),
              child: Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _ColorSquare(color: color, radius: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showColorPicker(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: PrismColorPicker(
          title: '${_tokenLabel(token)} 색상 변경',
          initialColor: color,
          onCancel: () => Navigator.pop(dialogContext),
          onApply: (picked) async {
            await ref
                .read(themeProvider.notifier)
                .setColor(token, picked, brightness: brightness);
            if (!dialogContext.mounted) return;
            Navigator.pop(dialogContext);
          },
        ),
      ),
    );
  }
}

class _ColorSquare extends StatelessWidget {
  const _ColorSquare({
    required this.color,
    this.size = 28,
    this.radius = 6,
  });

  final Color color;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: context.desktopBorder,
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

String _tokenLabel(ThemeToken token) => switch (token) {
  ThemeToken.income => '수입',
  ThemeToken.expense => '지출',
  ThemeToken.transfer => '이체',
  ThemeToken.background => '배경',
  ThemeToken.surface => '표면/카드',
  ThemeToken.accent => '강조',
  ThemeToken.warning => '경고',
};

String _tokenDescription(ThemeToken token) => switch (token) {
  ThemeToken.income => '수입 금액, 배지 등',
  ThemeToken.expense => '지출 금액, 배지 등',
  ThemeToken.transfer => '이체 표시 등',
  ThemeToken.background => '페이지 전체 배경',
  ThemeToken.surface => '사이드바, 카드 등 한 단계 뜬 면',
  ThemeToken.accent => '버튼, 링크, 강조 요소',
  ThemeToken.warning => '예산 초과, 경고 배너 등',
};
String _toHex(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
