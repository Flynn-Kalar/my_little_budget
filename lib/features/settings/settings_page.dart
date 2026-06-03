import 'package:flutter/material.dart';

import '../../shell/placeholder_scaffold.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(
      title: '설정',
      description:
          '카테고리·태그·반복거래·테마 색상 + 백업 내보내기/가져오기·전체 초기화.',
    );
  }
}
