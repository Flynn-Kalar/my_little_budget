import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup.dart';
import '../../data/supabase_backup_settings.dart';
import '../../data/supabase_operation_status.dart';
import '../../data/sync_models.dart';
import '../../features/settings/data_management_controller.dart';
import 'local_backup_panel.dart';

enum DataSyncMode { local, auto, windows }

/// Shared form lifecycle and user interactions; each platform owns its layout.
mixin DataManagementActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  bool dataBusy = false;
  SyncProgress? syncProgress;
  DataSyncMode selectedSyncMode = DataSyncMode.local;
  final supabaseUrlController = TextEditingController();
  final supabaseAnonKeyController = TextEditingController();
  final supabaseEmailController = TextEditingController();
  final supabasePasswordController = TextEditingController();
  final supabaseBucketController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadSupabaseSettings);
  }

  @override
  void dispose() {
    supabaseUrlController.dispose();
    supabaseAnonKeyController.dispose();
    supabaseEmailController.dispose();
    supabasePasswordController.dispose();
    supabaseBucketController.dispose();
    super.dispose();
  }

  Future<void> _loadSupabaseSettings() async {
    if (!mounted) return;
    await ref.read(supabaseBackupSettingsProvider.notifier).whenReady;
    if (!mounted) return;
    final settings = ref.read(supabaseBackupSettingsProvider);
    _fillSupabaseControllers(settings);
    setState(() {
      selectedSyncMode = settings.isConfigured || settings.isTableSyncConfigured
          ? DataSyncMode.auto
          : DataSyncMode.local;
    });
  }

  void _fillSupabaseControllers(SupabaseBackupSettings settings) {
    supabaseUrlController.text = settings.url;
    supabaseAnonKeyController.text = settings.anonKey;
    supabaseEmailController.text = settings.authEmail;
    supabasePasswordController.clear();
    supabaseBucketController.text = settings.bucket;
  }

  SupabaseBackupSettings _supabaseDraft() => SupabaseBackupSettings(
    url: supabaseUrlController.text,
    anonKey: supabaseAnonKeyController.text,
    bucket: supabaseBucketController.text,
    authEmail: supabaseEmailController.text,
    pathPrefix: SupabaseBackupSettings.defaultPathPrefix,
  );

  Future<void> _run(
    String failure,
    Future<void> Function(DataManagementController) action, {
    SyncProgress? progress,
  }) async {
    if (!mounted || dataBusy) return;
    final controller = ref.read(dataManagementControllerProvider);
    setState(() {
      dataBusy = true;
      syncProgress = progress;
    });
    try {
      await action(controller);
    } on DataManagementException catch (error) {
      _showSnack(error.message);
    } catch (error) {
      _showSnack('$failure: ${sanitizeSupabaseError('$error')}');
    } finally {
      if (mounted) {
        setState(() {
          dataBusy = false;
          syncProgress = null;
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _updateSyncProgress(SyncProgress progress) {
    if (mounted) setState(() => syncProgress = progress);
  }

  Future<void> exportBackup() => _run('백업 파일 생성에 실패했습니다', (controller) async {
    final backup = await controller.exportBackup();
    if (!mounted) return;
    final filename = buildBackupFilename();
    final path = await FilePicker.saveFile(
      dialogTitle: '백업 파일 저장',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: utf8.encode(backup.toJsonString()),
    );
    if (path != null) _showSnack('백업 파일을 만들었습니다: $filename');
  });

  Future<void> importBackup() => _run('복원에 실패했습니다', (controller) async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: '복원할 백업 파일 선택',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
    );
    if (picked == null || picked.files.single.path == null || !mounted) return;
    final content = await File(picked.files.single.path!).readAsString();
    final backup = controller.parseBackupContent(content);
    if (!mounted) return;
    final confirmed = await showBackupRestorePreview(context, backup);
    if (confirmed != true || !mounted) return;
    await controller.restoreBackup(backup);
    _showSnack('백업 데이터를 복원했습니다.');
  });

  Future<void> resetAllData() => _run('초기화에 실패했습니다', (controller) async {
    final confirmed = await showResetConfirmationDialog(context);
    if (confirmed != true || !mounted) return;
    await controller.resetAllData();
    _showSnack('데이터를 초기화했습니다.');
  });

  Future<void> saveSupabaseSettings() => _run(
    'Supabase 설정 저장에 실패했습니다',
    (controller) async {
      final result = await controller.saveSupabaseSettings(
        _supabaseDraft(),
        password: supabasePasswordController.text,
        onProgress: _updateSyncProgress,
        onSaved: () {
          if (mounted) supabasePasswordController.clear();
        },
      );
      if (!mounted) return;
      _fillSupabaseControllers(ref.read(supabaseBackupSettingsProvider));
      setState(() => selectedSyncMode = DataSyncMode.auto);
      _showSnack(
        result.isOk
            ? 'Supabase 연결 설정을 저장하고 동기화했습니다.'
            : '설정은 저장했지만 동기화하지 못했습니다: ${sanitizeSupabaseError(result.error)}',
      );
    },
    progress: const SyncProgress(percent: 0, label: 'Supabase에 로그인하고 있습니다.'),
  );

  Future<void> syncNow() => _run('동기화하지 못했습니다', (controller) async {
    final result = await controller.synchronize(
      _supabaseDraft(),
      onProgress: _updateSyncProgress,
    );
    _showSnack(
      result.isOk
          ? '동기화했습니다. 업로드 ${result.uploaded}건, 다운로드 ${result.downloaded}건'
          : '동기화하지 못했습니다: ${sanitizeSupabaseError(result.error)}',
    );
  }, progress: const SyncProgress(percent: 0, label: '동기화를 준비하고 있습니다.'));

  Future<void> refreshSupabaseRemoteStatus() => _run(
    'Supabase 백업 상태를 확인하지 못했습니다',
    (controller) => controller.refreshRemoteStatus(_supabaseDraft()),
  );

  Future<void> testSupabaseSettings() =>
      _run('Supabase Storage 연결 확인에 실패했습니다', (controller) async {
        await controller.testStorage(_supabaseDraft());
        _showSnack('Supabase Storage 연결을 확인했습니다.');
      });

  Future<void> testSupabaseTables() =>
      _run('Supabase DB 테이블 확인에 실패했습니다', (controller) async {
        final count = await controller.testTables(_supabaseDraft());
        _showSnack('Supabase DB 엔티티 테이블 $count개를 확인했습니다.');
      });

  Future<void> clearSupabaseSettings() =>
      _run('Supabase 설정 삭제에 실패했습니다', (controller) async {
        await controller.clearSupabaseSettings();
        if (!mounted) return;
        _fillSupabaseControllers(SupabaseBackupSettings.empty);
        setState(() => selectedSyncMode = DataSyncMode.local);
        _showSnack('Supabase 연결 설정을 삭제했습니다.');
      });

  Future<void> uploadSupabaseBackup() =>
      _run('Supabase 백업에 실패했습니다', (controller) async {
        final result = await controller.uploadBackup(_supabaseDraft());
        _showSnack('Supabase에 백업했습니다: ${result.latestPath}');
      });

  Future<void> restoreSupabaseBackup() =>
      _run('Supabase 복원에 실패했습니다', (controller) async {
        final settings = _supabaseDraft();
        final backup = await controller.downloadBackup(settings);
        if (!mounted) return;
        final confirmed = await showBackupRestorePreview(context, backup);
        if (confirmed != true || !mounted) return;
        await controller.restoreRemoteBackup(backup, settings);
        _showSnack('Supabase 백업을 복원했습니다.');
      });
}

Future<bool?> showResetConfirmationDialog(BuildContext context) =>
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('데이터 초기화'),
        content: const Text('현재 데이터를 모두 삭제하고 기본 자산과 카테고리를 복구합니다. 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
