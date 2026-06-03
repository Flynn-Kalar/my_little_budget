import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/recurring_dao.dart';
import '../../../../data/database.dart';
import '../../../../data/providers.dart';
import '../providers.dart';
import 'recurring_form.dart';

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

class RecurringList extends ConsumerStatefulWidget {
  const RecurringList({
    super.key,
    required this.items,
    required this.accounts,
    required this.categories,
    required this.tags,
  });

  final List<RecurringListItem> items;
  final List<Account> accounts;
  final List<Category> categories;
  final List<Tag> tags;

  @override
  ConsumerState<RecurringList> createState() => _RecurringListState();
}

class _RecurringListState extends ConsumerState<RecurringList> {
  bool _showAdd = false;
  int? _editingId;
  int? _busyId;

  Future<void> _toggle(RecurringListItem item) async {
    final r = item.recurring;
    setState(() => _busyId = r.id);
    try {
      await ref
          .read(recurringDaoProvider)
          .toggleRecurringActive(r.id, !r.active);
      refreshRecurring(ref);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(RecurringListItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('반복 거래 삭제'),
        content: const Text('이미 만들어진 거래는 그대로 남습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busyId = item.recurring.id);
    try {
      await ref.read(recurringDaoProvider).deleteRecurring(item.recurring.id);
      refreshRecurring(ref);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.items.isEmpty && !_showAdd)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '등록된 반복 거래가 없습니다.',
              style: TextStyle(fontSize: 13, color: AppTokens.muted),
            ),
          ),
        for (final item in widget.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _editingId == item.recurring.id
                ? RecurringForm(
                    item: item,
                    accounts: widget.accounts,
                    categories: widget.categories,
                    tags: widget.tags,
                    onDone: () => setState(() => _editingId = null),
                  )
                : _RecurringRow(
                    item: item,
                    busy: _busyId == item.recurring.id,
                    onToggle: () => _toggle(item),
                    onEdit: () => setState(() {
                      _showAdd = false;
                      _editingId = item.recurring.id;
                    }),
                    onDelete: () => _delete(item),
                  ),
          ),
        _showAdd
            ? RecurringForm(
                accounts: widget.accounts,
                categories: widget.categories,
                tags: widget.tags,
                onDone: () => setState(() => _showAdd = false),
              )
            : Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _editingId = null;
                    _showAdd = true;
                  }),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('반복 거래 추가'),
                  style: TextButton.styleFrom(foregroundColor: AppTokens.muted),
                ),
              ),
      ],
    );
  }
}

class _RecurringRow extends StatelessWidget {
  const _RecurringRow({
    required this.item,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final RecurringListItem item;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final r = item.recurring;
    final typeColor = switch (r.type) {
      'income' => AppTokens.income,
      'expense' => AppTokens.expense,
      _ => AppTokens.transfer,
    };
    final typeLabel = switch (r.type) {
      'income' => '수입',
      'expense' => '지출',
      _ => '이체',
    };
    final target = r.type == 'transfer'
        ? '${item.fromAccountName ?? '?'} → ${item.toAccountName ?? '?'}'
        : '${item.categoryName ?? '?'} · ${item.accountName ?? '?'}';
    final cadence = r.frequency == 'monthly'
        ? '매월 ${r.dayOfMonth}일'
        : '매주 ${_weekdays[r.dayOfWeek ?? 0]}요일';
    final tagNames = _parseTagNames(r.tagNames);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        border: Border.all(color: AppTokens.sidebarBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              typeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: typeColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: r.active ? null : AppTokens.muted,
                    decoration: r.active ? null : TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  [
                    cadence,
                    target,
                    if (r.memo != null) r.memo!,
                    if (tagNames.isNotEmpty)
                      tagNames.map((t) => '#$t').join(' '),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppTokens.muted),
                ),
              ],
            ),
          ),
          Text(
            formatKRW(r.amount),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          IconButton(
            onPressed: busy ? null : onToggle,
            icon: Icon(r.active ? Icons.pause : Icons.play_arrow, size: 18),
            tooltip: r.active ? '일시정지' : '재개',
            color: AppTokens.muted,
          ),
          IconButton(
            onPressed: busy ? null : onEdit,
            icon: const Icon(Icons.edit_outlined, size: 16),
            tooltip: '편집',
            color: AppTokens.muted,
          ),
          IconButton(
            onPressed: busy ? null : onDelete,
            icon: const Icon(Icons.delete_outline, size: 16),
            tooltip: '삭제',
            color: AppTokens.warning,
          ),
        ],
      ),
    );
  }
}

List<String> _parseTagNames(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final parsed = jsonDecode(raw);
    if (parsed is List) return parsed.whereType<String>().toList();
  } catch (_) {
    // ignore invalid stored JSON
  }
  return const [];
}
