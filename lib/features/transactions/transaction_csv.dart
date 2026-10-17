import 'dart:convert';

import '../../data/backup.dart';
import '../../data/database.dart';
import 'validation.dart';

const transactionCsvColumns = [
  '날짜',
  '시간',
  '유형',
  '금액',
  '계좌',
  '카테고리',
  '출금계좌',
  '입금계좌',
  '메모',
  '태그',
];

const transactionCsvTypeLabels = {
  'income': '수입',
  'expense': '지출',
  'transfer': '이체',
  'adjustment': '조정',
};

/// RFC 4180 quoting, including embedded newlines and doubled quotes.
List<List<String>> parseTransactionCsv(String source) {
  source = source.replaceFirst(RegExp('^\uFEFF'), '');
  final rows = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  var quoted = false;
  var closedQuote = false;
  for (var i = 0; i < source.length; i++) {
    final c = source[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < source.length && source[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
          closedQuote = true;
        }
      } else {
        field.write(c);
      }
    } else if (c == ',') {
      row.add(field.toString());
      field = StringBuffer();
      closedQuote = false;
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < source.length && source[i + 1] == '\n') i++;
      row.add(field.toString());
      if (row.any((v) => v.isNotEmpty)) rows.add(row);
      row = [];
      field = StringBuffer();
      closedQuote = false;
    } else if (c == '"' && field.isEmpty && !closedQuote) {
      quoted = true;
    } else {
      if (closedQuote || c == '"') {
        throw const FormatException('CSV 따옴표 형식이 올바르지 않습니다.');
      }
      field.write(c);
    }
  }
  if (quoted) throw const FormatException('CSV 따옴표가 닫히지 않았습니다.');
  row.add(field.toString());
  if (row.any((v) => v.isNotEmpty)) rows.add(row);
  if (rows.isEmpty) throw const FormatException('빈 CSV 파일입니다.');
  if (rows.first.toSet().length != rows.first.length) {
    throw const FormatException('CSV 열 이름이 중복됩니다.');
  }
  return rows;
}

String _safeText(String value) =>
    RegExp(r"^[\s]*[=+@\-']").hasMatch(value) ? "'$value" : value;
String _unescapeText(String value) =>
    value.startsWith("'") &&
        (RegExp(r"^[\s]*[=+@\-']").hasMatch(value.substring(1)))
    ? value.substring(1)
    : value;
String _quote(String value) => '"${value.replaceAll('"', '""')}"';

String exportTransactionCsv(Backup backup) {
  final accounts = {for (final a in backup.accounts) a.id: a.name};
  final categories = {for (final c in backup.categories) c.id: c.name};
  final tags = {for (final t in backup.tags) t.id: t.name};
  final links = <int, List<String>>{};
  for (final link in backup.transactionTags) {
    final name = tags[link.tagId];
    if (name != null) (links[link.transactionId] ??= []).add(name);
  }
  final rows = <List<String>>[
    transactionCsvColumns,
    for (final t in backup.transactions.where((t) => t.deletedAt == null))
      [
        t.occurredOn,
        t.occurredTime,
        transactionCsvTypeLabels[t.type] ?? t.type,
        '${t.amount}',
        _safeText(accounts[t.accountId] ?? ''),
        _safeText(categories[t.categoryId] ?? ''),
        _safeText(accounts[t.fromAccountId] ?? ''),
        _safeText(accounts[t.toAccountId] ?? ''),
        _safeText(t.memo ?? ''),
        jsonEncode(links[t.id] ?? <String>[]),
      ],
  ];
  return '\uFEFF${rows.map((row) => row.map(_quote).join(',')).join('\r\n')}\r\n';
}

class CsvImportEntry {
  const CsvImportEntry(
    this.rowNumber,
    this.draft,
    this.tags, {
    this.error,
    this.duplicate = false,
  });
  final int rowNumber;
  final TransactionDraft? draft;
  final List<String> tags;
  final String? error;
  final bool duplicate;
}

class CsvImportPreview {
  const CsvImportPreview(this.entries);
  final List<CsvImportEntry> entries;
  int get invalid => entries.where((e) => e.error != null).length;
  int get duplicates => entries.where((e) => e.duplicate).length;
  int get ready => entries.length - invalid - duplicates;
}

String _fingerprint(TransactionDraft t, List<String> tags) => jsonEncode([
  t.type,
  t.occurredOn,
  t.occurredTime,
  t.amount,
  t.accountId,
  t.categoryId,
  t.fromAccountId,
  t.toAccountId,
  t.memo?.trim() ?? '',
  tags.toSet().toList()..sort(),
]);

class TransactionCsvService {
  TransactionCsvService(this.database);
  final AppDatabase database;

  Future<CsvImportPreview> preview(
    List<List<String>> rows,
    Map<String, int?> mapping,
  ) async {
    final backup = await database.backupDao.exportBackup();
    final accounts = {
      for (final a in backup.accounts.where(
        (a) => a.archivedAt == null && a.deletedAt == null,
      ))
        a.name: a.id,
    };
    final categories = {
      for (final c in backup.categories.where(
        (c) => c.archivedAt == null && c.deletedAt == null,
      ))
        '${c.type}|${c.name}': c.id,
    };
    final tagNames = {for (final t in backup.tags) t.id: t.name};
    final links = <int, List<String>>{};
    for (final l in backup.transactionTags) {
      if (tagNames[l.tagId] != null) {
        (links[l.transactionId] ??= []).add(tagNames[l.tagId]!);
      }
    }
    final seen = <String>{
      for (final t in backup.transactions.where((t) => t.deletedAt == null))
        _fingerprint(
          TransactionDraft(
            type: t.type,
            amount: t.amount,
            occurredOn: t.occurredOn,
            occurredTime: t.occurredTime,
            accountId: t.accountId,
            categoryId: t.categoryId,
            fromAccountId: t.fromAccountId,
            toAccountId: t.toAccountId,
            memo: t.memo,
          ),
          links[t.id] ?? [],
        ),
    };
    final entries = <CsvImportEntry>[];
    for (var index = 1; index < rows.length; index++) {
      final row = rows[index];
      String cell(String name) {
        final column = mapping[name];
        return column == null || column >= row.length
            ? ''
            : _unescapeText(row[column]).trim();
      }

      try {
        if (row.length != rows.first.length) {
          throw const FormatException('열 개수가 제목 행과 다릅니다.');
        }
        final type = switch (cell('유형')) {
          '수입' => 'income',
          '지출' => 'expense',
          '이체' => 'transfer',
          '조정' => 'adjustment',
          final v => v,
        };
        final date = cell('날짜');
        final parsedDate = DateTime.tryParse(date);
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
            parsedDate == null ||
            parsedDate.toIso8601String().substring(0, 10) != date) {
          throw const FormatException('실제 날짜를 YYYY-MM-DD로 입력해주세요.');
        }
        final time = cell('시간').isEmpty ? '00:00' : cell('시간');
        if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
          throw const FormatException('시간을 HH:MM로 입력해주세요.');
        }
        final memo = cell('메모');
        final tagsCell = cell('태그');
        final List<String> tags;
        if (tagsCell.startsWith('[')) {
          final decoded = jsonDecode(tagsCell);
          if (decoded is! List || decoded.any((t) => t is! String)) {
            throw const FormatException('태그 배열을 확인해주세요.');
          }
          tags = decoded
              .cast<String>()
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toSet()
              .toList();
        } else {
          tags = tagsCell
              .split(';')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toSet()
              .toList();
        }
        if (tags.any((t) => t.length > 20)) {
          throw const FormatException('태그는 각각 20자 이하여야 합니다.');
        }
        final result = validateTransaction(
          type: type,
          amount: int.tryParse(
            cell('금액').replaceAll(',', '').replaceAll('₩', '').trim(),
          ),
          occurredOn: date,
          occurredTime: time,
          memo: memo,
          accountId: accounts[cell('계좌')],
          categoryId: categories['$type|${cell('카테고리')}'],
          fromAccountId: accounts[cell('출금계좌')],
          toAccountId: accounts[cell('입금계좌')],
        );
        if (result.isFail) {
          throw FormatException(
            '${result.errors.values.join(' / ')} (계좌·카테고리는 기존 활성 항목 이름으로 연결됩니다.)',
          );
        }
        final draft = result.value!;
        final duplicate = !seen.add(_fingerprint(draft, tags));
        entries.add(
          CsvImportEntry(index + 1, draft, tags, duplicate: duplicate),
        );
      } catch (error) {
        entries.add(CsvImportEntry(index + 1, null, const [], error: '$error'));
      }
    }
    return CsvImportPreview(entries);
  }

  Future<int> importRows(
    List<List<String>> rows,
    Map<String, int?> mapping,
  ) => database.transaction(() async {
    // Recheck against current data inside the same transaction as the writes.
    final checked = await preview(rows, mapping);
    if (checked.invalid > 0) throw StateError('오류가 있는 행을 수정한 뒤 다시 가져와주세요.');
    var count = 0;
    for (final e in checked.entries.where((e) => !e.duplicate)) {
      await database.transactionsDao.saveTransaction(
        draft: e.draft!,
        tagNames: e.tags,
      );
      count++;
    }
    return count;
  });
}
