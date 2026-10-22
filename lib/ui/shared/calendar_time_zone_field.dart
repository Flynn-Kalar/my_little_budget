import 'package:flutter/material.dart';
import '../../features/calendar/calendar_time_zones.dart';

class CalendarTimeZoneField extends StatefulWidget {
  const CalendarTimeZoneField({
    super.key,
    required this.controller,
    required this.date,
    required this.onChanged,
    this.enabled = true,
  });

  /// Stores the IANA identifier; the visible controller holds a readable label.
  final TextEditingController controller;
  final DateTime date;
  final VoidCallback onChanged;
  final bool enabled;
  @override
  State<CalendarTimeZoneField> createState() => _CalendarTimeZoneFieldState();
}

class _CalendarTimeZoneFieldState extends State<CalendarTimeZoneField> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _writing = false;
  @override
  void initState() {
    super.initState();
    _syncDisplay();
    widget.controller.addListener(_syncDisplay);
    _text.addListener(_input);
    _focus.addListener(_blur);
  }

  @override
  void didUpdateWidget(covariant CalendarTimeZoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncDisplay);
      widget.controller.addListener(_syncDisplay);
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.date != widget.date) {
      _syncDisplay();
    }
  }

  void _blur() {
    if (!_focus.hasFocus) _syncDisplay();
  }

  void _syncDisplay() {
    if (_writing) return;
    final id = widget.controller.text;
    final known = calendarTimeZoneIds.contains(id);
    final label = known ? calendarZoneLabel(id, widget.date) : id;
    if (_text.text == label) return;
    _writing = true;
    _text.text = label;
    _writing = false;
  }

  void _input() {
    if (_writing || !widget.enabled) return;
    _writing = true;
    widget.controller.text =
        resolveCalendarZone(_text.text, widget.date) ?? _text.text.trim();
    _writing = false;
    widget.onChanged();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncDisplay);
    _text.removeListener(_input);
    _focus.removeListener(_blur);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownMenu<String>(
        key: const ValueKey('calendar-time-zone'),
        controller: _text,
        focusNode: _focus,
        expandedInsets: EdgeInsets.zero,
        enabled: widget.enabled,
        requestFocusOnTap: true,
        enableFilter: true,
        enableSearch: true,
        menuHeight: 280,
        label: const Text('일정 시간대'),
        hintText: '지역명 또는 UTC 시간 차이 검색',
        dropdownMenuEntries: [
          for (final id in calendarTimeZoneIds)
            DropdownMenuEntry(
              value: id,
              label: calendarZoneLabel(id, widget.date),
              labelWidget: Text(
                calendarZoneLabel(id, widget.date),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        filterCallback: (entries, query) {
          final text = query.trim().toLowerCase().replaceAll('_', ' ');
          if (text.isEmpty || entries.any((e) => e.label == query)) {
            return entries;
          }
          return entries
              .where(
                (e) =>
                    calendarZoneSearchText(e.value, widget.date).contains(text),
              )
              .toList();
        },
        searchCallback: (entries, query) {
          final text = query.trim().toLowerCase().replaceAll('_', ' ');
          final index = entries.indexWhere(
            (e) => calendarZoneSearchText(e.value, widget.date).contains(text),
          );
          return index < 0 ? null : index;
        },
        onSelected: (id) {
          if (id == null) return;
          widget.controller.text = id;
          _syncDisplay();
          widget.onChanged();
        },
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: Text(
          '일정 날짜 기준의 시간 차이입니다. 반복·알림에 적용하며 종일 날짜는 이동하지 않습니다.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
}
