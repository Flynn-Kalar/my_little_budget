import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../shared/prism_color_picker.dart';
import '../mobile_widgets.dart';

class MobileThemeScreen extends ConsumerWidget {
  const MobileThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = ref.watch(themeProvider).forBrightness(theme.brightness);
    final mode = ref.watch(themeModeProvider);

    return MobilePage(
      title: '테마 설정',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.chevron_left),
            label: const Text('설정'),
          ),
        ),
        Text(
          '화면 모드와 주요 색상을 조정합니다. 변경 사항은 바로 적용되고 저장됩니다.',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 12),
        MobileCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.brightness_6_outlined,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '화면 모드',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selected) {
                    ref
                        .read(themeModeProvider.notifier)
                        .setMode(selected.first);
                  },
                ),
              ),
            ],
          ),
        ),
        MobileCard(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '색상 토큰',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => ref
                    .read(themeProvider.notifier)
                    .reset(brightness: theme.brightness),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('전체 기본값'),
              ),
            ],
          ),
        ),
        for (final token in ThemeToken.values)
          _TokenColorCard(token: token, color: colors.of(token)),
      ],
    );
  }
}

class _TokenColorCard extends StatelessWidget {
  const _TokenColorCard({required this.token, required this.color});

  final ThemeToken token;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MobileCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.dividerColor),
          ),
          child: const SizedBox(width: 40, height: 40),
        ),
        title: Text(
          _tokenLabel(token),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          _tokenDescription(token),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _toHex(color),
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.edit_outlined,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ],
        ),
        onTap: () => _ColorEditSheet.show(context, token: token, color: color),
      ),
    );
  }
}

class _ColorEditSheet extends ConsumerStatefulWidget {
  const _ColorEditSheet({required this.token, required this.color});

  final ThemeToken token;
  final Color color;

  static Future<void> show(
    BuildContext context, {
    required ThemeToken token,
    required Color color,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ColorEditSheet(token: token, color: color),
    );
  }

  @override
  ConsumerState<_ColorEditSheet> createState() => _ColorEditSheetState();
}

class _ColorEditSheetState extends ConsumerState<_ColorEditSheet> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: mobileBottomPadding(context, spacing: 16),
      ),
      child: PrismColorPicker(
        title: '${_tokenLabel(widget.token)} 색상 변경',
        initialColor: widget.color,
        onCancel: () => Navigator.pop(context),
        onApply: (picked) async {
          final brightness = Theme.of(context).brightness;
          final navigator = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          final label = _tokenLabel(widget.token);
          await ref
              .read(themeProvider.notifier)
              .setColor(widget.token, picked, brightness: brightness);
          if (!mounted) return;
          navigator.pop();
          messenger.showSnackBar(SnackBar(content: Text('$label 색상을 적용했습니다.')));
        },
      ),
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
  ThemeToken.income => '수입 금액과 긍정 표시',
  ThemeToken.expense => '지출 금액과 위험 표시',
  ThemeToken.transfer => '이체 거래 표시',
  ThemeToken.background => '전체 화면 배경',
  ThemeToken.surface => '카드와 패널 배경',
  ThemeToken.accent => '버튼, 선택 상태, 배지',
  ThemeToken.warning => '경고와 주의 표시',
};

String _toHex(Color color) => hexFromColor(color);
