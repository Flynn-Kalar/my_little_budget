import 'package:flutter/material.dart';

import '../../shell/placeholder_scaffold.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(
      title: '통계',
      description:
          '월 도넛 차트(지출 카테고리·수입 vs 지출) + 최근 12개월 추세. 하위에 연간 피벗.',
    );
  }
}
