import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../shared/rich_note_editor.dart';

/// The form and Quill each scroll. Reveal the caret, rather than the entire
/// field, inside their intersecting viewports after text and keyboard layout.
class MobileNoteEditor extends StatefulWidget {
  const MobileNoteEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.formScrollController,
    required this.formViewportKey,
  });
  final QuillController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final ScrollController formScrollController;
  final GlobalKey formViewportKey;

  @override
  State<MobileNoteEditor> createState() => MobileNoteEditorState();
}

class MobileNoteEditorState extends State<MobileNoteEditor>
    with WidgetsBindingObserver {
  final _editorKey = GlobalKey<EditorState>();
  StreamSubscription<DocChange>? _documentChanges;
  Document? _document;
  TextSelection? _selection;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_controllerChanged);
    widget.focusNode.addListener(_scheduleReveal);
    _listenToDocument();
  }

  void _listenToDocument() {
    unawaited(_documentChanges?.cancel());
    _document = widget.controller.document;
    _documentChanges = _document!.changes.listen((_) => _scheduleReveal());
  }

  @override
  void didUpdateWidget(covariant MobileNoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_controllerChanged);
      widget.controller.addListener(_controllerChanged);
      _listenToDocument();
      _scheduleReveal();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_scheduleReveal);
      widget.focusNode.addListener(_scheduleReveal);
    }
  }

  void _controllerChanged() {
    if (_document != widget.controller.document) {
      _listenToDocument();
      _scheduleReveal();
    }
    if (_selection != widget.controller.selection) {
      _selection = widget.controller.selection;
      _scheduleReveal();
    }
  }

  @override
  void didChangeMetrics() => _scheduleReveal();

  bool handleUserScroll(UserScrollNotification notification) {
    if (notification.direction != ScrollDirection.idle) _generation++;
    return false;
  }

  void _scheduleReveal() {
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Let Quill's own post-layout caret scrolling finish first. Its public
      // bringIntoView cancels a pending internal scroll before our outer fix.
      scheduleMicrotask(() {
        if (mounted && generation == _generation && widget.focusNode.hasFocus) {
          _reveal(generation);
        }
      });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Rect? _bounds(BuildContext? context) {
    final render = context?.findRenderObject();
    if (render is! RenderBox || !render.attached || !render.hasSize) {
      return null;
    }
    return render.localToGlobal(Offset.zero) & render.size;
  }

  Rect? _caret() {
    final editor = _editorKey.currentState;
    final selection = widget.controller.selection;
    if (editor == null ||
        !selection.isValid ||
        selection.extentOffset >= widget.controller.document.length) {
      return null;
    }
    final render = editor.renderEditor;
    if (!render.attached || !render.hasSize) return null;
    final local = render.getLocalRectForCaret(selection.extent);
    return Rect.fromPoints(
      render.localToGlobal(local.topLeft),
      render.localToGlobal(local.bottomRight),
    );
  }

  bool _visible(Rect caret) {
    final form = _bounds(widget.formViewportKey.currentContext);
    if (form == null || !widget.scrollController.hasClients) return false;
    final inner = _bounds(
      widget.scrollController.position.context.notificationContext,
    );
    if (inner == null) return false;
    final visible = form.intersect(inner).deflate(6);
    return caret.top >= visible.top && caret.bottom <= visible.bottom;
  }

  void _reveal(int generation) {
    final caret = _caret();
    if (caret == null || _visible(caret)) return;
    // Use the editor's caret-aware implementation for its internal viewport.
    _editorKey.currentState!.bringIntoView(widget.controller.selection.extent);
    _adjustForm();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation && widget.focusNode.hasFocus) {
        _adjustForm();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _adjustForm() {
    if (!widget.formScrollController.hasClients) return;
    final caret = _caret();
    final viewport = _bounds(
      widget.formViewportKey.currentContext,
    )?.deflate(12);
    if (caret == null || viewport == null) return;
    final delta = caret.top < viewport.top
        ? caret.top - viewport.top
        : caret.bottom > viewport.bottom
        ? caret.bottom - viewport.bottom
        : 0.0;
    if (delta.abs() < 1) return;
    final position = widget.formScrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() >= 1) {
      widget.formScrollController.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<UserScrollNotification>(
        onNotification: handleUserScroll,
        child: RichNoteEditor(
          controller: widget.controller,
          focusNode: widget.focusNode,
          scrollController: widget.scrollController,
          editorKey: _editorKey,
          minHeight: 220,
          maxHeight: 420,
          compactToolbar: true,
        ),
      );

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_controllerChanged);
    widget.focusNode.removeListener(_scheduleReveal);
    unawaited(_documentChanges?.cancel());
    super.dispose();
  }
}
