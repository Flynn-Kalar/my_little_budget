import 'package:flutter/material.dart';

import '../../shell/placeholder_scaffold.dart';

class BudgetPage extends StatelessWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(
      title: '예산',
      description:
          '월별 예산 그룹: 카테고리 기반 / 자산 연동 / 소득의 % 모드, 잔금 이월·이전 달 복사.',
    );
  }
}
