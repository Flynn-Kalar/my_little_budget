import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../features/notes/rich_note.dart';
import 'note_goal_embed.dart';

class RichNoteEditor extends StatefulWidget {
  const RichNoteEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    this.readOnly = false,
    this.minHeight = 160,
    this.maxHeight,
    this.compactToolbar = false,
    this.editorKey,
    this.bordered = true,
    this.scrollable = true,
    this.contentPadding = const EdgeInsets.all(12),
    this.lineHeight,
    this.onReadOnlyTap,
  });

  final QuillController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final bool readOnly;
  final double minHeight;
  final double? maxHeight;
  final bool compactToolbar;
  final GlobalKey<EditorState>? editorKey;
  final bool bordered;
  final bool scrollable;
  final EdgeInsetsGeometry contentPadding;
  final double? lineHeight;
  final VoidCallback? onReadOnlyTap;

  static const _fontSizeItems = <String, String>{
    '8 pt': '8',
    '9 pt': '9',
    '10 pt': '10',
    '11 pt': '11',
    '12 pt': '12',
    '14 pt': '14',
    '16 pt': '16',
    '18 pt': '18',
    '20 pt': '20',
    '24 pt': '24',
    '28 pt': '28',
    '32 pt': '32',
    '36 pt': '36',
    '기본': '0',
  };

  @override
  State<RichNoteEditor> createState() => _RichNoteEditorState();
}

class _RichNoteEditorState extends State<RichNoteEditor> {
  bool _formattingBullet = false;
  bool _bulletPending = false;
  late String _previousText;

  QuillController get controller => widget.controller;
  bool get readOnly => widget.readOnly;
  double get minHeight => widget.minHeight;
  double? get maxHeight => widget.maxHeight;

  @override
  void initState() {
    super.initState();
    _previousText = controller.document.toPlainText();
    controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(covariant RichNoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      oldWidget.controller.removeListener(_onChange);
      _previousText = controller.document.toPlainText();
      controller.addListener(_onChange);
    }
  }

  void _onChange() {
    if (_formattingBullet || readOnly) return;
    final text = controller.document.toPlainText();
    final inserted = text.length > _previousText.length;
    _previousText = text;
    // History replay must not turn a restored '- ' back into a bullet.
    if (!inserted ||
        _bulletPending ||
        controller.document.history.lastRecorded == 0) {
      return;
    }
    _bulletPending = true;
    // Quill can notify while composing an edit. Mutate only after it finishes,
    // with the final cursor position supplied by the software keyboard.
    scheduleMicrotask(() {
      _bulletPending = false;
      if (!mounted || readOnly) return;
      _formattingBullet = true;
      try {
        convertNoteBulletShortcut(controller);
        _previousText = controller.document.toPlainText();
      } finally {
        _formattingBullet = false;
      }
    });
  }

  @override
  void dispose() {
    controller.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = DefaultStyles.getInstance(context);
    final editor = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: !widget.bordered
          ? null
          : BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
      child: QuillEditor.basic(
        controller: controller,
        focusNode: widget.focusNode,
        scrollController: widget.scrollController,
        config: QuillEditorConfig(
          onTapUp: readOnly && widget.onReadOnlyTap != null
              ? (details, positionForOffset) {
                  final position = positionForOffset(details.globalPosition);
                  final leaf = controller.document
                      .querySegmentLeafNode(position.offset)
                      .leaf;
                  if (leaf?.style.attributes[Attribute.link.key]?.value !=
                      null) {
                    return false;
                  }
                  widget.onReadOnlyTap!();
                  return true;
                }
              : null,
          embedBuilders: const [NoteGoalEmbedBuilder()],
          editorKey: widget.editorKey,
          scrollable: widget.scrollable,
          customStyles: DefaultStyles(
            paragraph: styles.paragraph!.copyWith(
              style: styles.paragraph!.style.copyWith(
                fontSize: 18,
                height: widget.lineHeight,
              ),
            ),
            lists: styles.lists!.copyWith(
              style: styles.lists!.style.copyWith(
                fontSize: 18,
                height: widget.lineHeight,
              ),
            ),
          ),
          readOnlyMouseCursor: SystemMouseCursors.text,
          placeholder: readOnly ? null : '메모를 입력하세요.',
          minHeight: minHeight,
          maxHeight: maxHeight,
          padding: widget.contentPadding,
          checkBoxReadOnly: false,
          enableInteractiveSelection: !readOnly,
          showCursor: !readOnly,
        ),
      ),
    );

    if (readOnly) return editor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _RichNoteToolbar(
            controller: controller,
            compact: widget.compactToolbar,
          ),
        ),
        const SizedBox(height: 8),
        editor,
      ],
    );
  }
}

class _RichNoteToolbar extends StatelessWidget {
  const _RichNoteToolbar({required this.controller, required this.compact});

  final QuillController controller;
  final bool compact;

  static const _fontSizeOptions = QuillToolbarFontSizeButtonOptions(
    items: RichNoteEditor._fontSizeItems,
    initialValue: '18 pt',
    defaultDisplayText: '18 pt',
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttons = <Widget>[
      ListenableBuilder(
        listenable: controller,
        builder: (context, _) => IconButton(
          tooltip: '실행 취소',
          onPressed: controller.hasUndo ? controller.undo : null,
          icon: const Icon(Icons.undo),
        ),
      ),
      ListenableBuilder(
        listenable: controller,
        builder: (context, _) => IconButton(
          tooltip: '다시 실행',
          onPressed: controller.hasRedo ? controller.redo : null,
          icon: const Icon(Icons.redo),
        ),
      ),
      if (!compact)
        QuillToolbarFontSizeButton(
          controller: controller,
          options: _fontSizeOptions,
        ),
      QuillToolbarToggleCheckListButton(controller: controller),
      IconButton(
        tooltip: '금액 목표 삽입',
        icon: const Icon(Icons.savings_outlined),
        onPressed: () => editNoteGoalBlock(context, controller),
      ),
      QuillToolbarToggleStyleButton(
        controller: controller,
        attribute: Attribute.ul,
      ),
      if (!compact)
        QuillToolbarToggleStyleButton(
          controller: controller,
          attribute: Attribute.bold,
        ),
      if (!compact)
        QuillToolbarToggleStyleButton(
          controller: controller,
          attribute: Attribute.underline,
        ),
      if (!compact)
        QuillToolbarToggleStyleButton(
          controller: controller,
          attribute: Attribute.strikeThrough,
        ),
      if (!compact)
        QuillToolbarColorButton(controller: controller, isBackground: false),
      QuillToolbarColorButton(controller: controller, isBackground: true),
      if (compact)
        IconButton(
          tooltip: '글자·서식 더보기',
          icon: const Icon(Icons.more_horiz),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('글자·서식'),
              content: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  QuillToolbarFontSizeButton(
                    controller: controller,
                    options: _fontSizeOptions,
                  ),
                  for (final attribute in [
                    Attribute.bold,
                    Attribute.underline,
                    Attribute.strikeThrough,
                  ])
                    QuillToolbarToggleStyleButton(
                      controller: controller,
                      attribute: attribute,
                    ),
                  QuillToolbarColorButton(
                    controller: controller,
                    isBackground: false,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
              ],
            ),
          ),
        ),
    ];

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          height: kDefaultToolbarSize * 1.4,
          child: Row(children: buttons),
        ),
      ),
    );
  }
}

class RichNoteViewer extends StatefulWidget {
  const RichNoteViewer({
    super.key,
    required this.document,
    this.minHeight = 120,
    this.maxHeight,
    this.onTap,
    this.onChecklistToggle,
    this.bordered = true,
    this.scrollable = true,
    this.contentPadding = const EdgeInsets.all(12),
    this.lineHeight,
  });

  final Document document;
  final double minHeight;
  final double? maxHeight;
  final VoidCallback? onTap;
  final bool bordered;
  final bool scrollable;
  final EdgeInsetsGeometry contentPadding;
  final double? lineHeight;
  final FutureOr<void> Function(int checklistIndex, bool isChecked)?
  onChecklistToggle;

  @override
  State<RichNoteViewer> createState() => _RichNoteViewerState();
}

class _RichNoteViewerState extends State<RichNoteViewer> {
  late final _controller = QuillController(
    document: widget.document,
    selection: const TextSelection.collapsed(offset: 0),
    readOnly: true,
  );
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  StreamSubscription<dynamic>? _documentChanges;
  late List<bool> _checklistStates;

  @override
  void initState() {
    super.initState();
    // Capture the baseline before the first checkbox mutation is delivered.
    _checklistStates = _checklistStatesFromDocument(widget.document);
    _listenToDocumentChanges();
  }

  void _listenToDocumentChanges() {
    unawaited(_documentChanges?.cancel());
    _documentChanges = _controller.document.changes.listen((_) {
      if (!mounted || widget.onChecklistToggle == null) return;
      final next = _checklistStatesFromDocument(_controller.document);
      final changedIndex = _firstChangedChecklistIndex(_checklistStates, next);
      _checklistStates = next;
      if (changedIndex == null) return;
      final result = widget.onChecklistToggle!(
        changedIndex,
        next[changedIndex],
      );
      if (result is Future<void>) unawaited(result);
    });
  }

  @override
  void didUpdateWidget(covariant RichNoteViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _controller.document = widget.document;
      _checklistStates = _checklistStatesFromDocument(widget.document);
      _listenToDocumentChanges();
    }
  }

  @override
  void dispose() {
    unawaited(_documentChanges?.cancel());
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewer = RichNoteEditor(
      controller: _controller,
      focusNode: _focusNode,
      scrollController: _scrollController,
      readOnly: true,
      minHeight: widget.minHeight,
      maxHeight: widget.maxHeight,
      bordered: widget.bordered,
      scrollable: widget.scrollable,
      contentPadding: widget.contentPadding,
      lineHeight: widget.lineHeight,
      onReadOnlyTap: widget.onTap,
    );

    if (widget.onTap == null) return viewer;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: widget.onTap,
      child: viewer,
    );
  }
}

List<bool> _checklistStatesFromDocument(Document document) {
  final result = <bool>[];
  for (final op in document.toDelta().toList()) {
    final attrs = op.attributes ?? const <String, dynamic>{};
    final list = attrs['list'];
    if (list == 'checked') {
      result.add(true);
    } else if (list == 'unchecked') {
      result.add(false);
    }
  }
  return result;
}

int? _firstChangedChecklistIndex(List<bool> previous, List<bool> next) {
  if (previous.length != next.length) return null;
  for (var i = 0; i < next.length; i++) {
    if (previous[i] != next[i]) return i;
  }
  return null;
}
