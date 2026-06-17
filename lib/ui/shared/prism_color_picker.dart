import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrismColorPicker extends StatefulWidget {
  const PrismColorPicker({
    super.key,
    required this.initialColor,
    required this.title,
    required this.onApply,
    this.onCancel,
  });

  final Color initialColor;
  final String title;
  final ValueChanged<Color> onApply;
  final VoidCallback? onCancel;

  @override
  State<PrismColorPicker> createState() => _PrismColorPickerState();
}

class _PrismColorPickerState extends State<PrismColorPicker> {
  late final _r = TextEditingController();
  late final _g = TextEditingController();
  late final _b = TextEditingController();
  late final _hex = TextEditingController();
  late Color _preview = widget.initialColor;
  String? _error;

  bool get _valid => _error == null;
  bool get _changed => _preview.toARGB32() != widget.initialColor.toARGB32();

  @override
  void initState() {
    super.initState();
    _syncControllers(widget.initialColor);
  }

  @override
  void dispose() {
    _r.dispose();
    _g.dispose();
    _b.dispose();
    _hex.dispose();
    super.dispose();
  }

  void _setPreview(Color color) {
    setState(() {
      _preview = color;
      _syncControllers(color);
      _error = null;
    });
  }

  void _syncControllers(Color color) {
    final rgb = rgbFromColor(color);
    _r.text = rgb.$1.toString();
    _g.text = rgb.$2.toString();
    _b.text = rgb.$3.toString();
    _hex.text = hexFromColor(color);
  }

  void _updateFromRgb() {
    final r = int.tryParse(_r.text.trim());
    final g = int.tryParse(_g.text.trim());
    final b = int.tryParse(_b.text.trim());
    if (r == null || g == null || b == null) {
      setState(() => _error = 'RGB 값을 모두 입력하세요.');
      return;
    }
    if (![r, g, b].every(isValidRgbChannel)) {
      setState(() => _error = 'RGB 값은 0~255 사이여야 합니다.');
      return;
    }
    setState(() {
      _preview = Color.fromARGB(255, r, g, b);
      _hex.text = hexFromColor(_preview);
      _error = null;
    });
  }

  void _updateFromHex(String raw) {
    final parsed = colorFromHex(raw);
    if (parsed == null) {
      setState(() => _error = 'Hex 값은 #RRGGBB 형식이어야 합니다.');
      return;
    }
    setState(() {
      _preview = parsed;
      final rgb = rgbFromColor(parsed);
      _r.text = rgb.$1.toString();
      _g.text = rgb.$2.toString();
      _b.text = rgb.$3.toString();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _PreviewChip(color: _preview),
              ],
            ),
            const SizedBox(height: 16),
            _PrismPlane(color: _preview, onChanged: _setPreview),
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
            const SizedBox(height: 10),
            TextField(
              controller: _hex,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Hex',
                hintText: '#2563EB',
                errorText: _error,
              ),
              onChanged: _updateFromHex,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: widget.onCancel ?? () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _valid && _changed
                      ? () => widget.onApply(_preview)
                      : null,
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

class _PrismPlane extends StatelessWidget {
  const _PrismPlane({required this.color, required this.onChanged});

  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(color);
    final selected = Offset(
      (hsv.hue / 360).clamp(0.0, 1.0),
      (1 - hsv.value).clamp(0.0, 1.0),
    );

    return AspectRatio(
      aspectRatio: 2.2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          void pick(Offset local) {
            final x = (local.dx / constraints.maxWidth).clamp(0.0, 1.0);
            final y = (local.dy / constraints.maxHeight).clamp(0.0, 1.0);
            onChanged(HSVColor.fromAHSV(1, x * 360, 1, 1 - y).toColor());
          }

          return GestureDetector(
            onPanDown: (details) => pick(details.localPosition),
            onPanUpdate: (details) => pick(details.localPosition),
            child: CustomPaint(
              painter: _PrismPainter(selected: selected),
            ),
          );
        },
      ),
    );
  }
}

class _PrismPainter extends CustomPainter {
  const _PrismPainter({required this.selected});

  final Offset selected;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueShader = LinearGradient(
      colors: [
        for (var i = 0; i <= 6; i++)
          HSVColor.fromAHSV(1, i * 60, 1, 1).toColor(),
      ],
    ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()..shader = hueShader,
    );

    final valueShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black],
    ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()..shader = valueShader,
    );

    final p = Offset(selected.dx * size.width, selected.dy * size.height);
    canvas.drawCircle(p, 8, Paint()..color = Colors.white);
    canvas.drawCircle(
      p,
      8,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _PrismPainter oldDelegate) {
    return oldDelegate.selected != selected;
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: const SizedBox(width: 44, height: 36),
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
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => onChanged(),
    );
  }
}

String hexFromColor(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Color? colorFromHex(String raw) {
  final value = raw.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) return null;
  return Color(0xFF000000 | int.parse(value, radix: 16));
}

bool isValidRgbChannel(int value) => value >= 0 && value <= 255;

(int, int, int) rgbFromColor(Color color) {
  final value = color.toARGB32();
  return ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF);
}
