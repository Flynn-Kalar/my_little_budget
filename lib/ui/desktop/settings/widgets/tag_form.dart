import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/database.dart';
import '../../../../data/providers.dart';
import '../../../../features/tags/validation.dart';
import '../../../desktop/color_hex.dart';
import 'package:my_little_budget/features/settings/providers.dart';

class TagForm extends ConsumerStatefulWidget {
  const TagForm({super.key, this.tag, required this.onDone});

  final Tag? tag;
  final VoidCallback onDone;

  @override
  ConsumerState<TagForm> createState() => _TagFormState();
}

class _TagFormState extends ConsumerState<TagForm> {
  late final _nameCtrl = TextEditingController(text: widget.tag?.name ?? '');
  late String _color = widget.tag?.color ?? randomColor();
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = validateTag(name: _nameCtrl.text, color: _color);
    if (result.isFail) {
      _show(result.errors.values.first);
      return;
    }
    setState(() => _busy = true);
    try {
      final draft = result.value!;
      final id = widget.tag?.id;
      if (id == null) {
        await ref.read(tagsDaoProvider).createTag(draft.name, draft.color);
      } else {
        await ref.read(tagsDaoProvider).updateTag(id, draft.name, draft.color);
      }
      refreshTags(ref);
      widget.onDone();
    } catch (e) {
      final message = e.toString();
      _show(
        message.contains('UNIQUE') ? '같은 이름의 태그가 이미 존재합니다.' : '저장 오류: $message',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.desktopSurface,
        border: Border.all(color: context.desktopBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: '이름',
              hintText: '예: 여행, 출장',
              isDense: true,
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Text(
                '색상',
                style: TextStyle(fontSize: 12, color: context.desktopMuted),
              ),
              SizedBox(width: 12),
              for (final c in colorPalette)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => setState(() => _color = c),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorFromHex(c),
                        border: Border.all(
                          color: _color == c
                              ? Theme.of(context).colorScheme.onSurface
                              : context.desktopBorder,
                          width: _color == c ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? '저장 중...' : '저장'),
              ),
              SizedBox(width: 8),
              TextButton(
                onPressed: _busy ? null : widget.onDone,
                child: Text('취소'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
