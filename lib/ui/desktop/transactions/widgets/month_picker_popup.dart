import 'package:flutter/material.dart';

import '../../../../core/date.dart';
import '../../../../core/theme/app_theme.dart';

/// 월 선택 팝업. 연도 ◀▶ + 1~12월 3×4 그리드.
/// 현재 선택된 (year, month) 는 검정 배경으로 강조.
class MonthPickerPopup extends StatefulWidget {
  const MonthPickerPopup({
    super.key,
    required this.currentMonth,
    required this.onPick,
  });

  final String currentMonth; // YYYY-MM
  final ValueChanged<String> onPick;

  @override
  State<MonthPickerPopup> createState() => _MonthPickerPopupState();
}

class _MonthPickerPopupState extends State<MonthPickerPopup> {
  late int _year = parseMonthKey(widget.currentMonth).year;

  @override
  Widget build(BuildContext context) {
    final selected = parseMonthKey(widget.currentMonth);

    return SizedBox(
      width: 280,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left, size: 18),
                  tooltip: '이전 연도',
                ),
                Text('$_year년',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                IconButton(
                  onPressed: () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right, size: 18),
                  tooltip: '다음 연도',
                ),
              ],
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 2.2,
              children: List.generate(12, (i) {
                final m = i + 1;
                final isSelected =
                    _year == selected.year && m == selected.month;
                return Material(
                  color: isSelected ? Colors.black87 : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      final monthKey =
                          '${_year.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}';
                      widget.onPick(monthKey);
                    },
                    child: Center(
                      child: Text(
                        '$m월',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color:
                              isSelected ? Colors.white : AppTokens.muted,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
