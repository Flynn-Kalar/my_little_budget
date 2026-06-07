import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/theme/theme_notifier.dart';
import '../mobile_widgets.dart';

class MobileThemeScreen extends ConsumerWidget {
  const MobileThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = ref.watch(themeProvider);
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
                onPressed: () => ref.read(themeProvider.notifier).reset(),
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
  late final _r = TextEditingController();
  late final _g = TextEditingController();
  late final _b = TextEditingController();
  late final _hex = TextEditingController();
  late Color _preview = widget.color;
  String? _error;

  bool get _valid => _error == null;
  bool get _changed => _preview.toARGB32() != widget.color.toARGB32();

  @override
  void initState() {
    super.initState();
    _setControllers(widget.color);
  }

  @override
  void dispose() {
    _r.dispose();
    _g.dispose();
    _b.dispose();
    _hex.dispose();
    super.dispose();
  }

  void _setControllers(Color color) {
    final rgb = _rgb(color);
    _r.text = rgb.$1.toString();
    _g.text = rgb.$2.toString();
    _b.text = rgb.$3.toString();
    _hex.text = _toHex(color);
  }

  void _updateFromRgb() {
    final r = int.tryParse(_r.text.trim());
    final g = int.tryParse(_g.text.trim());
    final b = int.tryParse(_b.text.trim());
    if (r == null || g == null || b == null) {
      setState(() => _error = 'RGB 값을 모두 입력해주세요.');
      return;
    }
    if ([r, g, b].any((value) => value < 0 || value > 255)) {
      setState(() => _error = 'RGB 값은 0~255 사이여야 합니다.');
      return;
    }
    final color = Color.fromARGB(255, r, g, b);
    setState(() {
      _preview = color;
      _hex.text = _toHex(color);
      _error = null;
    });
  }

  void _updateFromHex(String raw) {
    final parsed = _parseHex(raw);
    if (parsed == null) {
      setState(() => _error = 'Hex 값은 #RRGGBB 형식이어야 합니다.');
      return;
    }
    setState(() {
      _preview = parsed;
      final rgb = _rgb(parsed);
      _r.text = rgb.$1.toString();
      _g.text = rgb.$2.toString();
      _b.text = rgb.$3.toString();
      _error = null;
    });
  }

  Future<void> _apply() async {
    if (!_valid) return;
    await ref.read(themeProvider.notifier).setColor(widget.token, _preview);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_tokenLabel(widget.token)} 색상을 적용했습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_tokenLabel(widget.token)} 색상 변경',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _preview,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.dividerColor, width: 2),
                ),
                child: const SizedBox(width: 84, height: 84),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _toHex(_preview),
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _RgbField(
                    label: 'R',
                    controller: _r,
                    onChanged: _updateFromRgb,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RgbField(
                    label: 'G',
                    controller: _g,
                    onChanged: _updateFromRgb,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RgbField(
                    label: 'B',
                    controller: _b,
                    onChanged: _updateFromRgb,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hex,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Hex',
                hintText: '#2563EB',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onChanged: _updateFromHex,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _valid && _changed ? _apply : null,
                  child: const Text('적용'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RgbField extends StatelessWidget {
  const _RgbField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => onChanged(),
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

String _toHex(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Color? _parseHex(String raw) {
  final value = raw.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) return null;
  return Color(0xFF000000 | int.parse(value, radix: 16));
}

(int, int, int) _rgb(Color color) {
  final value = color.toARGB32();
  return ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF);
}
