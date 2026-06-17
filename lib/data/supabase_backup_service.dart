import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase/supabase.dart';

import 'backup.dart';
import 'supabase_backup_settings.dart';

final supabaseBackupServiceProvider = Provider<SupabaseBackupService>((ref) {
  return SupabaseStorageBackupService();
});

class SupabaseBackupUpload {
  const SupabaseBackupUpload({
    required this.latestPath,
    required this.historyPath,
  });

  final String latestPath;
  final String historyPath;
}

class SupabaseBackupRemoteStatus {
  const SupabaseBackupRemoteStatus({
    required this.latestPath,
    required this.exists,
    this.updatedAt,
  });

  final String latestPath;
  final bool exists;
  final DateTime? updatedAt;
}

class SupabaseBackupResult<T> {
  const SupabaseBackupResult.ok(this.value) : error = null;
  const SupabaseBackupResult.fail(String this.error) : value = null;

  final T? value;
  final String? error;

  bool get isOk => error == null;
}

abstract class SupabaseBackupService {
  Future<SupabaseBackupResult<void>> testConnection(
    SupabaseBackupSettings settings,
  );

  Future<SupabaseBackupResult<SupabaseBackupUpload>> uploadBackup({
    required SupabaseBackupSettings settings,
    required Backup backup,
    DateTime? now,
  });

  Future<SupabaseBackupResult<String>> downloadLatestBackup(
    SupabaseBackupSettings settings,
  );

  Future<SupabaseBackupResult<SupabaseBackupRemoteStatus>> getRemoteStatus(
    SupabaseBackupSettings settings,
  );
}

class SupabaseStorageBackupService implements SupabaseBackupService {
  @override
  Future<SupabaseBackupResult<void>> testConnection(
    SupabaseBackupSettings settings,
  ) async {
    final error = validateSupabaseBackupSettings(settings);
    if (error != null) return SupabaseBackupResult.fail(error);

    try {
      await _bucket(settings).list(
        path: settings.normalized().pathPrefix,
        searchOptions: const SearchOptions(limit: 1),
      );
      return const SupabaseBackupResult.ok(null);
    } catch (e) {
      return SupabaseBackupResult.fail(_describeError(e));
    }
  }

  @override
  Future<SupabaseBackupResult<SupabaseBackupUpload>> uploadBackup({
    required SupabaseBackupSettings settings,
    required Backup backup,
    DateTime? now,
  }) async {
    final error = validateSupabaseBackupSettings(settings);
    if (error != null) return SupabaseBackupResult.fail(error);

    try {
      final normalized = settings.normalized();
      final latestPath = _latestPath(normalized);
      final historyPath = _historyPath(normalized, now ?? DateTime.now());
      final bytes = utf8.encode(backup.toJsonString());
      final bucket = _bucket(normalized);
      const options = FileOptions(
        contentType: 'application/json',
        upsert: true,
      );

      await bucket.uploadBinary(latestPath, bytes, fileOptions: options);
      await bucket.uploadBinary(historyPath, bytes, fileOptions: options);

      return SupabaseBackupResult.ok(
        SupabaseBackupUpload(latestPath: latestPath, historyPath: historyPath),
      );
    } catch (e) {
      return SupabaseBackupResult.fail(_describeError(e));
    }
  }

  @override
  Future<SupabaseBackupResult<String>> downloadLatestBackup(
    SupabaseBackupSettings settings,
  ) async {
    final error = validateSupabaseBackupSettings(settings);
    if (error != null) return SupabaseBackupResult.fail(error);

    try {
      final normalized = settings.normalized();
      final bytes = await _bucket(normalized).download(_latestPath(normalized));
      return SupabaseBackupResult.ok(utf8.decode(bytes));
    } catch (e) {
      return SupabaseBackupResult.fail(_describeError(e));
    }
  }

  @override
  Future<SupabaseBackupResult<SupabaseBackupRemoteStatus>> getRemoteStatus(
    SupabaseBackupSettings settings,
  ) async {
    final error = validateSupabaseBackupSettings(settings);
    if (error != null) return SupabaseBackupResult.fail(error);

    try {
      final normalized = settings.normalized();
      final latestPath = _latestPath(normalized);
      final list = await _bucket(normalized).list(
        path: normalized.pathPrefix,
        searchOptions: const SearchOptions(limit: 100),
      );
      final latest = list
          .where((item) => item.name == 'latest.json')
          .firstOrNull;
      return SupabaseBackupResult.ok(
        SupabaseBackupRemoteStatus(
          latestPath: latestPath,
          exists: latest != null,
          updatedAt: _readUpdatedAt(latest),
        ),
      );
    } catch (e) {
      return SupabaseBackupResult.fail(_describeError(e));
    }
  }

  StorageFileApi _bucket(SupabaseBackupSettings settings) {
    final normalized = settings.normalized();
    final client = SupabaseClient(normalized.url, normalized.anonKey);
    return client.storage.from(normalized.bucket);
  }

  static String _latestPath(SupabaseBackupSettings settings) {
    return '${settings.pathPrefix}/latest.json';
  }

  static String _historyPath(SupabaseBackupSettings settings, DateTime now) {
    return '${settings.pathPrefix}/backups/${buildBackupFilename(now: now)}';
  }

  static String _describeError(Object error) {
    if (error is StorageException) {
      final status = error.statusCode == null ? '' : ' (${error.statusCode})';
      return '${error.message}$status';
    }
    return error.toString();
  }

  static DateTime? _readUpdatedAt(FileObject? file) {
    if (file == null) return null;
    final raw = file.updatedAt ?? file.createdAt;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}
