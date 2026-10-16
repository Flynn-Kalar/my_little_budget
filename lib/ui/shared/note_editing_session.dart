import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../features/notes/note_draft_store.dart';

/// Owns recovery and route protection, without saving a note or scheduling alarms.
class NoteEditingSession extends StatefulWidget {
  const NoteEditingSession({
    super.key,
    required this.database,
    required this.note,
    required this.editing,
    required this.busy,
    required this.changes,
    required this.snapshot,
    required this.restore,
    required this.onSave,
    required this.builder,
    this.initialize,
  });
  final AppDatabase database;
  final Note? note;
  final bool editing;
  final bool busy;
  final Listenable changes;
  final Map<String, dynamic> Function() snapshot;
  final void Function(Map<String, dynamic>) restore;
  final Future<void> Function(bool asCopy) onSave;
  final Future<void> Function()? initialize;
  final Widget Function(NoteEditingSessionState session) builder;

  @override
  State<NoteEditingSession> createState() => NoteEditingSessionState();
}

class NoteEditingSessionState extends State<NoteEditingSession> {
  late final _store = NoteDraftStore(widget.database);
  late final AppLifecycleListener _lifecycle;
  String _baseline = '';
  String _observed = '';
  String? _persisted;
  String? _baseUpdatedAt;
  String? _draftError;
  bool _ready = false;
  bool _recovering = false;
  bool _recoveryFailed = false;
  bool _dirty = false;
  bool _allowPop = false;
  bool _confirming = false;
  bool _observing = false;
  bool _paused = false;
  bool _conflict = false;
  Timer? _timer;
  Future<void> _writes = Future.value();

  @override
  void initState() {
    super.initState();
    _resetBaseline();
    widget.changes.addListener(_observeLater);
    _lifecycle = AppLifecycleListener(
      onInactive: _flushInBackground,
      onPause: _flushInBackground,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    try {
      await widget.initialize?.call();
      if (!mounted) return;
      _resetBaseline();
      setState(() => _ready = true);
      if (widget.editing) await _offerRecovery();
    } catch (_) {
      if (mounted) {
        setState(() {
          _ready = true;
          _recoveryFailed = true;
          _draftError = '임시 작성 내용을 확인하지 못했습니다. 다시 시도해 주세요.';
        });
      }
    }
  }

  void _resetBaseline() {
    _baseline = _observed = jsonEncode(widget.snapshot());
    _baseUpdatedAt = widget.note?.updatedAt;
    _dirty = false;
    _persisted = null;
    _paused = false;
    _conflict = false;
  }

  @override
  void didUpdateWidget(covariant NoteEditingSession oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.changes.removeListener(_observeLater);
    widget.changes.addListener(_observeLater);
    if (_ready && !oldWidget.editing && widget.editing) {
      _resetBaseline();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_offerRecovery());
      });
    } else {
      _observeLater();
    }
  }

  Future<void> _offerRecovery() async {
    if (!mounted || _recovering) return;
    setState(() => _recovering = true);
    try {
      final draft = await _store.load(widget.note?.id);
      _recoveryFailed = false;
      _draftError = null;
      if (!mounted || draft == null) return;
      final payload = Map<String, dynamic>.from(
        jsonDecode(draft.payload) as Map,
      );
      if (payload['version'] != 1 ||
          payload['rich'] is! List ||
          payload['title'] is! String) {
        throw const FormatException('Invalid draft');
      }
      final conflict = draft.baseUpdatedAt != widget.note?.updatedAt;
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('임시 작성 내용이 있습니다'),
          content: Text(
            conflict
                ? '원본 메모가 변경되었습니다. 초안을 복구해 확인할 수 있으며, 원본을 덮어쓰지 않고 새 메모로 저장할 수 있습니다.'
                : '이 기기에 남아 있는 작성 내용을 복구할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'close'),
              child: const Text('나중에'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: const Text('초안 버리기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'restore'),
              child: const Text('복구'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (action == 'restore') {
        widget.restore(payload);
        _baseUpdatedAt = draft.baseUpdatedAt;
        _conflict = conflict;
        _observed = jsonEncode(widget.snapshot());
        _persisted = _observed;
        setState(() => _dirty = _observed != _baseline);
      } else if (action == 'discard') {
        await _store.delete(widget.note?.id);
      } else {
        await closeRoute();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _recoveryFailed = true;
          _draftError = '임시 작성 내용을 읽지 못했습니다. 원본 초안은 보존되어 있습니다.';
        });
      }
    } finally {
      if (mounted) setState(() => _recovering = false);
    }
  }

  void _observeLater() {
    if (_observing || !_ready || _recovering || _paused || !widget.editing) {
      return;
    }
    _observing = true;
    scheduleMicrotask(() {
      _observing = false;
      if (mounted) _observe();
    });
  }

  void _observe() {
    if (!_ready || _recovering || _paused || !widget.editing) return;
    final value = jsonEncode(widget.snapshot());
    if (value == _observed) return;
    _observed = value;
    _timer?.cancel();
    setState(() => _dirty = value != _baseline);
    if (_recoveryFailed) return;
    if (_dirty) {
      _timer = Timer(const Duration(seconds: 1), () => unawaited(flushDraft()));
    } else {
      _enqueue(() => _store.delete(widget.note?.id));
      _persisted = null;
    }
  }

  void _enqueue(Future<void> Function() operation) {
    _writes = _writes.then((_) => operation()).catchError((Object _) {
      if (mounted) {
        setState(() => _draftError = '임시 저장하지 못했습니다. 입력 내용을 유지하고 있습니다.');
      }
    });
  }

  Future<void> flushDraft({bool force = false}) {
    _timer?.cancel();
    if ((!force && _paused) ||
        !_ready ||
        _recovering ||
        _recoveryFailed ||
        !widget.editing) {
      return _writes;
    }
    final snapshot = widget.snapshot();
    final value = jsonEncode(snapshot);
    if (value != _baseline && value != _persisted) {
      final noteId = widget.note?.id;
      final base = _baseUpdatedAt;
      _enqueue(() async {
        await _store.write(
          noteId: noteId,
          baseUpdatedAt: base,
          payload: snapshot,
        );
        if (mounted) {
          setState(() {
            _persisted = value;
            _draftError = null;
          });
        }
      });
    }
    return _writes;
  }

  void _flushInBackground() {
    unawaited(flushDraft());
  }

  Future<void> prepareSave() async {
    _observe();
    _paused = true;
    await flushDraft(force: true);
  }

  Future<void> checkVersion({required bool asCopy}) async {
    if (!asCopy) await _store.checkVersion(widget.note?.id, _baseUpdatedAt);
  }

  Future<void> deleteSavedDraft() => _store.delete(widget.note?.id);

  void saved() {
    _baseline = _observed = jsonEncode(widget.snapshot());
    _persisted = null;
    _draftError = null;
    _dirty = false;
    _conflict = false;
  }

  void finishSave() {
    _paused = false;
    if (mounted) setState(() {});
  }

  String saveError(Object error) {
    if (error is NoteEditConflict) {
      _conflict = true;
      return '원본 메모가 변경되었습니다. 내용을 확인한 뒤 새 메모로 저장해 주세요.';
    }
    return '저장하지 못했습니다. 작성 내용은 유지됩니다. 다시 시도해 주세요.';
  }

  Future<void> closeRoute() async {
    if (!mounted || _allowPop) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> requestExit({VoidCallback? onExit}) async {
    if (widget.busy || !_ready || _recovering || _confirming) return;
    _observe();
    if (!_dirty) {
      if (onExit != null) {
        onExit();
      } else {
        await closeRoute();
      }
      return;
    }
    _confirming = true;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('변경사항을 저장할까요?'),
        content: const Text('저장하지 않은 작성 내용이 있습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'stay'),
            child: const Text('계속 작성'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('변경사항 버리기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('저장 후 닫기'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (!mounted) return;
    if (action == 'save') {
      await widget.onSave(false);
      if (!mounted || _dirty || _allowPop) return;
    } else if (action == 'discard') {
      _timer?.cancel();
      _paused = true;
      try {
        await _writes;
        await _store.delete(widget.note?.id);
      } catch (_) {
        _paused = false;
        setState(() => _draftError = '초안을 지우지 못했습니다. 다시 시도해 주세요.');
        return;
      }
      _dirty = false;
    } else {
      return;
    }
    if (onExit != null) {
      onExit();
    } else {
      await closeRoute();
    }
  }

  Widget status({String? error}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          !_ready || _recovering
              ? '작성 내용 확인 중…'
              : widget.busy
              ? '저장 중…'
              : _dirty
              ? _observed == _persisted
                    ? '이 기기에 임시 저장됨'
                    : '작성 중'
              : '변경사항 없음',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (error != null || _draftError != null)
          Text(
            error ?? _draftError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_conflict)
          TextButton(
            onPressed: widget.busy ? null : () => widget.onSave(true),
            child: const Text('새 메모로 저장'),
          ),
        if (_recoveryFailed)
          TextButton(
            onPressed: widget.busy ? null : () => _offerRecovery(),
            child: const Text('초안 다시 확인'),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    _observeLater();
    return PopScope<Object?>(
      canPop:
          _allowPop ||
          (_ready &&
              !_recovering &&
              !widget.busy &&
              !widget.editing),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(requestExit());
      },
      child: AbsorbPointer(
        absorbing: !_ready || _recovering || widget.busy,
        child: widget.builder(this),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    widget.changes.removeListener(_observeLater);
    super.dispose();
  }
}
