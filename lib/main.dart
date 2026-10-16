import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'reminder_background.dart';

@pragma('vm:entry-point')
Future<void> reminderBackgroundEntry() => reminderBackgroundMain();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyLittleBudgetApp()));
}
