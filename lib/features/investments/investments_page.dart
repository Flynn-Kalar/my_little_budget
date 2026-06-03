import 'package:flutter/material.dart';

import '../../shell/placeholder_scaffold.dart';

class InvestmentsPage extends StatelessWidget {
  const InvestmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(
      title: '투자',
      description:
          '종목 매수/매도/배당 + 평단가 기반 실현손익 계산. 단일 투자 자산에 매핑.',
    );
  }
}
