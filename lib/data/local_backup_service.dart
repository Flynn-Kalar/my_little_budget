import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup.dart';
import 'database.dart';
import 'providers.dart';

final localBackupServiceProvider = Provider<LocalBackupService>((ref) {
  final service = LocalBackupService(ref.watch(appDatabaseProvider));
  ref.onDispose(service.dispose);
  return service;
});

class LocalBackupService {
  LocalBackupService(this.database, {this.directory, this.retention = 7});
  final AppDatabase database;
  final Directory? directory;
  final int retention;
  StreamSubscription<Set<TableUpdate>>? _subscription;
  Timer? _debounce;
  Timer? _hourly;
  Future<File?>? _pending;
  String? lastError;
  bool _disposed = false;
  static const _enabledKey = 'local_backup_enabled';

  Future<bool> get enabled async =>
      !kIsWeb &&
      ((await SharedPreferences.getInstance()).getBool(_enabledKey) ?? true);

  Future<void> setEnabled(bool value) async {
    await (await SharedPreferences.getInstance()).setBool(_enabledKey, value);
    if (value) await captureIfDue();
  }

  Future<Directory> _folder() async {
    final folder =
        directory ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}local_backups',
        );
    await folder.create(recursive: true);
    return folder;
  }

  Future<List<File>> list() async {
    if (kIsWeb) return [];
    final folder = await _folder();
    final files = await folder
        .list()
        .where(
          (f) =>
              f is File &&
              f.path.endsWith('.json') &&
              f.uri.pathSegments.last.startsWith('budget-'),
        )
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  void start() {
    if (_subscription != null || kIsWeb || _disposed) return;
    _subscription = database.tableUpdates().listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 10), captureIfDue);
    });
    _hourly = Timer.periodic(const Duration(hours: 1), (_) => captureIfDue());
    unawaited(captureIfDue());
  }

  /// Automatic failures are retained for Settings, never thrown into app startup.
  Future<void> captureIfDue() async {
    if (_disposed || kIsWeb) return;
    try {
      if (!await enabled) return;
      final files = await list();
      if (files.isNotEmpty) {
        final last = (await files.first.stat()).modified;
        final now = DateTime.now();
        if (last.year == now.year &&
            last.month == now.month &&
            last.day == now.day) {
          return;
        }
      }
      await capture();
      lastError = null;
    } catch (error) {
      lastError = '$error';
    }
  }

  /// Serialize snapshots so periodic and user-requested backups cannot race.
  Future<File?> capture() {
    if (kIsWeb) return Future.value();
    return _pending ??= _capture().whenComplete(() => _pending = null);
  }

  /// A restore must capture the current state even if an earlier automatic
  /// snapshot was already in progress when the user opened the preview.
  Future<File?> captureFresh() async {
    await _pending;
    return capture();
  }

  Future<File> _capture() async {
    final backup = await database.backupDao.exportBackup();
    final folder = await _folder();
    final file = File(
      '${folder.path}${Platform.pathSeparator}budget-${DateTime.now().toUtc().microsecondsSinceEpoch}.json',
    );
    final temporary = File('${file.path}.tmp');
    try {
      await temporary.writeAsString(backup.toJsonString(), flush: true);
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
    // A successful snapshot is in place before old recovery points are removed.
    final files = await list();
    for (final expired in files.skip(retention)) {
      await expired.delete();
    }
    lastError = null;
    return file;
  }

  Future<Backup> read(File file) async {
    final parsed = parseBackup(await file.readAsString());
    if (!parsed.isOk) {
      throw FormatException(parsed.error ?? '백업 파일을 읽을 수 없습니다.');
    }
    return parsed.backup!;
  }

  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _debounce?.cancel();
    _hourly?.cancel();
  }
}
