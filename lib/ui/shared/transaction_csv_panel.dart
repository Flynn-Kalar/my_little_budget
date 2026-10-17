import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/providers.dart';
import '../../features/transactions/providers.dart';
import '../../features/transactions/transaction_csv.dart';

Future<void> showTransactionCsvImport(
  BuildContext context,
  List<List<String>> rows,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _CsvImportDialog(rows: rows),
);

class TransactionCsvPanel extends ConsumerStatefulWidget {
  const TransactionCsvPanel({
    super.key,
    this.enabled = true,
    this.onBusyChanged,
  });
  final bool enabled;
  final ValueChanged<bool>? onBusyChanged;
  @override
  ConsumerState<TransactionCsvPanel> createState() =>
      _TransactionCsvPanelState();
}

class _TransactionCsvPanelState extends ConsumerState<TransactionCsvPanel> {
  bool _busy = false;
  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    widget.onBusyChanged?.call(true);
    try {
      await action();
    } catch (error) {
      _message('CSV 처리에 실패했습니다: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  Future<void> _export() => _run(() async {
    final backup = await ref.read(backupDaoProvider).exportBackup();
    final data = exportTransactionCsv(backup);
    final path = await FilePicker.saveFile(
      dialogTitle: '거래 CSV 저장',
      fileName:
          'budget-transactions-${DateTime.now().millisecondsSinceEpoch}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: utf8.encode(data),
    );
    if (path != null) _message('거래 CSV를 내보냈습니다.');
  });

  Future<void> _import() => _run(() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (picked == null) return;
    final file = picked.files.single;
    if (file.size > 10 * 1024 * 1024) {
      throw const FormatException('10MB 이하의 파일을 선택해주세요.');
    }
    if (file.bytes == null) throw const FormatException('파일 내용을 읽을 수 없습니다.');
    final rows = parseTransactionCsv(utf8.decode(file.bytes!));
    if (rows.length > 10001) {
      throw const FormatException('한 번에 최대 10,000건을 가져올 수 있습니다.');
    }
    if (!mounted) return;
    await showTransactionCsvImport(context, rows);
  });

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !_busy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '거래 CSV',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              '전체 거래를 엑셀용 UTF-8 CSV로 내보내거나 열을 연결해 가져옵니다. 계좌·카테고리는 기존 이름을 사용하고, 태그는 세미콜론으로 구분하세요. CSV는 전체 백업을 대신하지 않습니다.',
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: enabled ? _export : null,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('전체 거래 CSV 내보내기'),
            ),
            OutlinedButton.icon(
              onPressed: enabled ? _import : null,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('CSV 가져오기 및 미리보기'),
            ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _CsvImportDialog extends ConsumerStatefulWidget {
  const _CsvImportDialog({required this.rows});
  final List<List<String>> rows;
  @override
  ConsumerState<_CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends ConsumerState<_CsvImportDialog> {
  late final Map<String, int?> _mapping = {
    for (final name in transactionCsvColumns)
      name: widget.rows.first.contains(name)
          ? widget.rows.first.indexOf(name)
          : null,
  };
  CsvImportPreview? _preview;
  bool _busy = false;
  String? _error;

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final checked = await TransactionCsvService(
        ref.read(appDatabaseProvider),
      ).preview(widget.rows, _mapping);
      if (mounted) setState(() => _preview = checked);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final count = await TransactionCsvService(
        ref.read(appDatabaseProvider),
      ).importRows(widget.rows, _mapping);
      if (!mounted) return;
      refreshTransactions(ref);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count건을 가져왔습니다. 중복 거래는 건너뛰었습니다.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(_preview == null ? 'CSV 열 연결' : 'CSV 가져오기 미리보기'),
      content: SizedBox(
        width: 600,
        height: MediaQuery.sizeOf(context).height * .6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _preview == null
                      ? [
                          const Text(
                            '첫 행은 열 이름이어야 합니다. 날짜·유형·금액을 반드시 연결하세요. 시간은 연결하지 않으면 00:00입니다. 수입·지출은 계좌와 카테고리, 이체는 출금계좌와 입금계좌가 필요합니다.',
                          ),
                          for (final name in transactionCsvColumns)
                            DropdownButtonFormField<int>(
                              initialValue: _mapping[name],
                              isExpanded: true,
                              decoration: InputDecoration(labelText: name),
                              items: [
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text('연결하지 않음'),
                                ),
                                for (
                                  var i = 0;
                                  i < widget.rows.first.length;
                                  i++
                                )
                                  DropdownMenuItem(
                                    value: i,
                                    child: Text(
                                      widget.rows.first[i],
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: _busy
                                  ? null
                                  : (v) => setState(() => _mapping[name] = v),
                            ),
                        ]
                      : [
                          Text(
                            '가져올 거래 ${_preview!.ready}건 · 중복 ${_preview!.duplicates}건 · 오류 ${_preview!.invalid}건',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            '기존 데이터와 파일 안에서 날짜·시간·유형·금액·계좌·분류·메모·태그가 같은 거래는 건너뜁니다. 오류가 있으면 파일을 수정한 뒤 다시 선택해주세요.',
                          ),
                          for (final e in _preview!.entries.take(100))
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${e.rowNumber}행 · ${e.error != null
                                    ? '오류'
                                    : e.duplicate
                                    ? '중복: 건너뜀'
                                    : '${e.draft!.occurredOn} · ${formatKRW(e.draft!.amount)}'}',
                              ),
                              subtitle: Text(
                                e.error ??
                                    '${e.draft!.memo ?? ''} · ${transactionCsvTypeLabels[e.draft!.type] ?? e.draft!.type}',
                              ),
                            ),
                          if (_preview!.entries.length > 100)
                            const Text(
                              '화면에는 처음 100행을 표시하며, 검증과 가져오기는 전체 행에 적용됩니다.',
                            ),
                        ],
                ),
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        if (_preview != null)
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _preview = null;
                    _error = null;
                  }),
            child: const Text('열 연결 수정'),
          ),
        if (_preview == null)
          FilledButton(
            onPressed:
                _busy || ['날짜', '유형', '금액'].any((n) => _mapping[n] == null)
                ? null
                : _check,
            child: const Text('검증 및 미리보기'),
          )
        else
          FilledButton(
            onPressed: _busy || _preview!.invalid > 0 || _preview!.ready == 0
                ? null
                : _save,
            child: Text('${_preview!.ready}건 가져오기'),
          ),
      ],
    ),
  );
}
