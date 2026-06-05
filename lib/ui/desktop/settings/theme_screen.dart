import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colors.dart';
import '../../../core/theme/theme_notifier.dart';

class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeProvider);
    final mode = ref.watch(themeModeProvider);

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
              '테마 설정',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '화면 모드와 주요 색상을 조정합니다. 변경사항은 즉시 적용되고 저장됩니다.',
              style: TextStyle(fontSize: 13, color: AppTokens.muted),
            ),
            const SizedBox(height: 24),
            _ThemeCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.brightness_6_outlined,
                    color: AppTokens.muted,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
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
            const SizedBox(height: 12),
            _ThemeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '색상 토큰',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(themeProvider.notifier).reset(),
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: const Text('기본값'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final token in ThemeToken.values) ...[
                    _TokenColorRow(token: token, color: colors.of(token)),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _TokenColorRow extends ConsumerWidget {
  const _TokenColorRow({required this.token, required this.color});

  final ThemeToken token;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        _ColorDot(color: color),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(
            _tokenLabel(token),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final swatch in _swatches)
                Tooltip(
                  message: _toHex(swatch),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => ref
                        .read(themeProvider.notifier)
                        .setColor(token, swatch),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: swatch,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: swatch.toARGB32() == color.toARGB32()
                              ? Colors.black87
                              : AppTokens.sidebarBorder,
                          width: swatch.toARGB32() == color.toARGB32() ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppTokens.sidebarBorder),
      ),
      child: const SizedBox(width: 22, height: 22),
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
  ThemeToken.surface => '표면',
  ThemeToken.accent => '강조',
  ThemeToken.warning => '경고',
};

String _toHex(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

const _swatches = [
  Color(0xFF2563EB),
  Color(0xFF16A34A),
  Color(0xFFDC2626),
  Color(0xFFF59E0B),
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
  Color(0xFF64748B),
  Color(0xFF111827),
  Color(0xFFECFEEF),
  Color(0xFFF5FFF7),
  Color(0xFFFFFFFF),
];
