import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/database.dart';
import '../../../../data/providers.dart';
import '../../../../features/categories/validation.dart';
import '../../../desktop/color_hex.dart';
import '../providers.dart';

class CategoryForm extends ConsumerStatefulWidget {
  const CategoryForm({
    super.key,
    this.category,
    this.type,
    required this.onDone,
  });

  final Category? category;
  final String? type;
  final VoidCallback onDone;

  @override
  ConsumerState<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<CategoryForm> {
  late final _nameCtrl =
      TextEditingController(text: widget.category?.name ?? '');
  late String _color = widget.category?.color ?? randomColor();
  bool _busy = false;

  bool get _isEditing => widget.category != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = validateCategory(
      name: _nameCtrl.text,
      type: widget.category?.type ?? widget.type ?? 'expense',
      color: _color,
    );
    if (result.isFail) {
      _show(result.errors.values.first);
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(categoriesDaoProvider).saveCategory(
            id: widget.category?.id,
            draft: result.value!,
          );
      refreshCategories(ref);
      widget.onDone();
    } on SqliteException catch (e) {
      _show(e.message.contains('UNIQUE')
          ? '같은 이름의 카테고리가 이미 존재합니다.'
          : '저장 오류: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive() async {
    final id = widget.category?.id;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(categoriesDaoProvider).archiveCategory(id);
      refreshCategories(ref);
      widget.onDone();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        border: Border.all(color: AppTokens.sidebarBorder),
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
              isDense: true,
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('색상',
                  style: TextStyle(fontSize: 12, color: AppTokens.muted)),
              const SizedBox(width: 12),
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
                              ? Colors.black87
                              : AppTokens.sidebarBorder,
                          width: _color == c ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? '저장 중...' : '저장'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _busy ? null : widget.onDone,
                child: const Text('취소'),
              ),
              const Spacer(),
              if (_isEditing)
                TextButton(
                  onPressed: _busy ? null : _archive,
                  style: TextButton.styleFrom(foregroundColor: AppTokens.muted),
                  child: const Text('보관'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
