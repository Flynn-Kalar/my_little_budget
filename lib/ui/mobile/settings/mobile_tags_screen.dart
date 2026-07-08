import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../features/tags/validation.dart';
import 'package:my_little_budget/features/settings/providers.dart';
import '../mobile_widgets.dart';

class MobileTagsScreen extends ConsumerWidget {
  const MobileTagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(settingsTagsProvider);
    return MobilePageScaffold(
      title: '태그 관리',
      onAdd: () => _showTagSheet(context),
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
              children: [
                for (var i = 0; i < items.length; i++)
                  _TagCard(tag: items[i], tags: items, index: i),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _showTagSheet(BuildContext context, {Tag? tag}) async {
    final action = await _TagSheet.show(context, tag: tag);
    if (!context.mounted || action == null) return;
    final message = switch (action) {
      _TagAction.created => '태그를 추가했습니다.',
      _TagAction.updated => '태그를 수정했습니다.',
      _TagAction.deleted => '태그를 삭제했습니다.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TagCard extends ConsumerWidget {
  const _TagCard({required this.tag, required this.tags, required this.index});

  final Tag tag;
  final List<Tag> tags;
  final int index;

  Future<void> _move(WidgetRef ref, int direction) async {
    final target = index + direction;
    if (target < 0 || target >= tags.length) return;
    final ordered = [...tags];
    final moving = ordered.removeAt(index);
    ordered.insert(target, moving);
    await ref
        .read(tagsDaoProvider)
        .updateTagOrder(ordered.map((tag) => tag.id).toList());
    refreshTags(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MobileCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(backgroundColor: _parseColor(tag.color)),
        title: Text('#${tag.name}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () async {
                await ref
                    .read(tagsDaoProvider)
                    .setTagPinned(tag.id, !tag.isPinned);
                refreshTags(ref);
              },
              icon: Icon(
                tag.isPinned ? Icons.star_rounded : Icons.star_border_rounded,
              ),
              tooltip: tag.isPinned ? '고정 해제' : '태그 고정',
            ),
            PopupMenuButton<String>(
              tooltip: '태그 메뉴',
              onSelected: (value) async {
                if (value == 'edit') {
                  final action = await _TagSheet.show(context, tag: tag);
                  if (!context.mounted || action == null) return;
                  final message = action == _TagAction.deleted
                      ? '태그를 삭제했습니다.'
                      : '태그를 수정했습니다.';
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                } else if (value == 'up') {
                  _move(ref, -1);
                } else if (value == 'down') {
                  _move(ref, 1);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('수정'),
                  ),
                ),
                PopupMenuItem(
                  value: 'up',
                  enabled: index > 0,
                  child: const ListTile(
                    leading: Icon(Icons.arrow_upward),
                    title: Text('위로 이동'),
                  ),
                ),
                PopupMenuItem(
                  value: 'down',
                  enabled: index < tags.length - 1,
                  child: const ListTile(
                    leading: Icon(Icons.arrow_downward),
                    title: Text('아래로 이동'),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () async {
          final action = await _TagSheet.show(context, tag: tag);
          if (!context.mounted || action == null) return;
          final message = action == _TagAction.deleted
              ? '태그를 삭제했습니다.'
              : '태그를 수정했습니다.';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },
      ),
    );
  }
}

class _TagSheet extends ConsumerStatefulWidget {
  const _TagSheet({this.tag});

  final Tag? tag;

  static Future<_TagAction?> show(BuildContext context, {Tag? tag}) {
    return showModalBottomSheet<_TagAction>(
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
  String? _error;

  bool get _isEdit => widget.tag != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = validateTag(name: _name.text);
    if (result.isFail) {
      setState(() => _error = '태그 이름을 입력해주세요.');
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
      Navigator.pop(context, _isEdit ? _TagAction.updated : _TagAction.created);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().contains('UNIQUE')
              ? '이미 사용 중인 태그 이름입니다.'
              : '태그를 저장하지 못했습니다.',
        );
      }
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
    Navigator.pop(context, _TagAction.deleted);
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
            decoration: InputDecoration(
              labelText: '이름',
              prefixText: '#',
              border: const OutlineInputBorder(),
              errorText: _error,
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
                    foregroundColor: context.appExpense,
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

enum _TagAction { created, updated, deleted }

Color _parseColor(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return Color(0xFF000000 | (value ?? 0x64748B));
}
