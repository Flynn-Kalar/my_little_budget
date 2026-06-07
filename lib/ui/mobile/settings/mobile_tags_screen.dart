import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../features/tags/validation.dart';
import '../../desktop/settings/providers.dart';
import '../mobile_widgets.dart';

class MobileTagsScreen extends ConsumerWidget {
  const MobileTagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(settingsTagsProvider);
    return MobilePageScaffold(
      title: '태그 관리',
      onAdd: () => _TagSheet.show(context),
      addTooltip: '태그 추가',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.chevron_left),
            label: const Text('설정'),
          ),
        ),
        MobileAsync(
          value: tags,
          builder: (items) {
            if (items.isEmpty) return const EmptyMobileCard('태그가 없습니다.');
            return Column(
              children: [for (final tag in items) _TagCard(tag: tag)],
            );
          },
        ),
      ],
    );
  }
}

class _TagCard extends StatelessWidget {
  const _TagCard({required this.tag});

  final Tag tag;

  @override
  Widget build(BuildContext context) {
    return MobileCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(backgroundColor: _parseColor(tag.color)),
        title: Text('#${tag.name}'),
        onTap: () => _TagSheet.show(context, tag: tag),
      ),
    );
  }
}

class _TagSheet extends ConsumerStatefulWidget {
  const _TagSheet({this.tag});

  final Tag? tag;

  static Future<void> show(BuildContext context, {Tag? tag}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TagSheet(tag: tag),
    );
  }

  @override
  ConsumerState<_TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends ConsumerState<_TagSheet> {
  late final _name = TextEditingController(text: widget.tag?.name ?? '');
  bool _busy = false;

  bool get _isEdit => widget.tag != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = validateTag(name: _name.text);
    if (result.isFail) {
      _showSnack('태그 이름을 입력해주세요.');
      return;
    }
    setState(() => _busy = true);
    try {
      final draft = result.value!;
      if (_isEdit) {
        await ref
            .read(tagsDaoProvider)
            .updateTag(widget.tag!.id, draft.name, draft.color);
      } else {
        await ref.read(tagsDaoProvider).createTag(draft.name, draft.color);
      }
      if (!mounted) return;
      refreshTags(ref);
      Navigator.pop(context);
      _showSnack(_isEdit ? '태그를 수정했습니다.' : '태그를 추가했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final tag = widget.tag;
    if (tag == null) return;
    await ref.read(tagsDaoProvider).deleteTag(tag.id);
    if (!mounted) return;
    refreshTags(ref);
    Navigator.pop(context);
    _showSnack('태그를 삭제했습니다.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEdit ? '태그 수정' : '태그 추가',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: '이름',
              prefixText: '#',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_isEdit)
                TextButton.icon(
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('삭제'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTokens.expense,
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('저장'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _parseColor(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return Color(0xFF000000 | (value ?? 0x64748B));
}
