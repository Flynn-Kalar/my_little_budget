import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'widgets/filter_panel.dart';
import 'widgets/inline_entry.dart';
import 'widgets/month_nav.dart';
import 'widgets/summary_bar.dart';
import 'widgets/transaction_list.dart';
import 'widgets/transactions_side_panel.dart';
import 'widgets/transaction_preset_picker_dialog.dart';
import '../../../features/presets/validation.dart';

const _contentGap = 24.0;
const _compactMainColumnWidth = 720.0;
const _compactSidePanelWidth = 340.0;
const _wideMainColumnWidth = 820.0;
const _wideSidePanelWidth = 360.0;
const _wideLayoutMinWidth = 1480.0;

class _TransactionsLayoutSpec {
  const _TransactionsLayoutSpec({
    required this.mainWidth,
    required this.sideWidth,
  });

  final double mainWidth;
  final double sideWidth;
}

/// Desktop transaction screen. Data access stays inside the child widgets.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  bool _isHeaderCollapsed = false;
  bool _isFilterExpanded = false;
  final _filterPanelKey = GlobalKey();
  TransactionPresetDraft? _selectedPreset;
  int _presetRevision = 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spec = _layoutSpec(constraints.maxWidth);
          final showSidePanel =
              constraints.maxWidth >=
              spec.mainWidth + _contentGap + spec.sideWidth;
          if (!showSidePanel) return _buildMainColumn(expanded: true);
          final contentWidth = spec.mainWidth + _contentGap + spec.sideWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              key: const ValueKey('desktop-transactions-content-frame'),
              width: contentWidth,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: spec.mainWidth,
                    child: _buildMainColumn(
                      expanded: false,
                      width: spec.mainWidth,
                    ),
                  ),
                  const SizedBox(width: _contentGap),
                  SizedBox(
                    width: spec.sideWidth,
                    child: const TransactionsSidePanel(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  _TransactionsLayoutSpec _layoutSpec(double maxWidth) {
    if (maxWidth >= _wideLayoutMinWidth) {
      return const _TransactionsLayoutSpec(
        mainWidth: _wideMainColumnWidth,
        sideWidth: _wideSidePanelWidth,
      );
    }
    return const _TransactionsLayoutSpec(
      mainWidth: _compactMainColumnWidth,
      sideWidth: _compactSidePanelWidth,
    );
  }

  Widget _buildMainColumn({required bool expanded, double? width}) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isHeaderCollapsed) ...[
          const Text(
            '내역',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            const Expanded(child: MonthNav()),
            FilledButton.tonalIcon(
              key: const ValueKey('desktop-transactions-budget-button'),
              onPressed: () => context.go('/budget'),
              icon: const Icon(Icons.savings_outlined, size: 18),
              label: const Text('예산 보기'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              key: const ValueKey('desktop-transactions-investments-button'),
              onPressed: () => context.go('/investments'),
              icon: const Icon(Icons.trending_up, size: 18),
              label: const Text('투자 보기'),
            ),
            const SizedBox(width: 8),
            IconButton(
              key: const ValueKey('desktop-transactions-collapse-button'),
              tooltip: _isHeaderCollapsed ? '상단 펼치기' : '상단 접기',
              onPressed: () =>
                  setState(() => _isHeaderCollapsed = !_isHeaderCollapsed),
              icon: Icon(
                _isHeaderCollapsed
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_up,
              ),
            ),
          ],
        ),
        if (!_isHeaderCollapsed) ...[
          const SizedBox(height: 10),
          const SummaryBar(),
          const SizedBox(height: 12),
          Row(
            key: const ValueKey('desktop-transactions-filter-row'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isFilterExpanded) Flexible(child: _buildFilterPanel()),
              if (!_isFilterExpanded) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _pickPreset,
                  icon: const Icon(Icons.bookmarks_outlined, size: 18),
                  label: const Text('프리셋'),
                ),
              ],
            ],
          ),
          if (_isFilterExpanded) ...[
            const SizedBox(height: 10),
            SizedBox(
              key: const ValueKey('desktop-transactions-expanded-filter'),
              width: double.infinity,
              child: _buildFilterPanel(),
            ),
          ],
          const SizedBox(height: 10),
          InlineEntry(preset: _selectedPreset, presetRevision: _presetRevision),
        ],
        const SizedBox(height: 8),
        const Expanded(child: TransactionList()),
      ],
    );
    if (expanded) return column;
    return SizedBox(
      key: const ValueKey('desktop-transactions-main-column'),
      width: width ?? _compactMainColumnWidth,
      child: column,
    );
  }

  Widget _buildFilterPanel() {
    return FilterPanel(
      key: _filterPanelKey,
      onExpandedChanged: (expanded) {
        if (_isFilterExpanded == expanded) return;
        setState(() => _isFilterExpanded = expanded);
      },
    );
  }

  Future<void> _pickPreset() async {
    final item = await TransactionPresetPickerDialog.show(context);
    if (item == null || !mounted) return;
    setState(() {
      _selectedPreset = item.toDraft();
      _presetRevision++;
    });
  }
}
