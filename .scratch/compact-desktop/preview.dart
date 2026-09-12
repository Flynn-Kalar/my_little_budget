import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_little_budget/core/theme/app_theme.dart';
import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final account = (await db.accountsDao.getActiveAccounts()).first;
  for (final type in ['income', 'expense']) {
    final category = (await db.categoriesDao.getActiveCategories(type)).first;
    await db.transactionsDao.saveTransaction(draft: TransactionDraft(
      type: type, amount: type == 'income' ? 3500000 : 125000,
      occurredOn: currentDateKey(), occurredTime: '12:30',
      accountId: account.id, categoryId: category.id, memo: '레이아웃 확인용 샘플 거래',
    ));
  }
  await db.notesDao.saveNote(title: '좁은 데스크톱 화면 확인', content: '사이드바와 데스크톱 화면을 유지합니다.');
  runApp(ProviderScope(overrides: [appDatabaseProvider.overrideWithValue(db)], child: const Preview()));
}
class Preview extends ConsumerWidget {
  const Preview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Compact desktop preview', debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    localizationsDelegates: const [FlutterQuillLocalizations.delegate,
      GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate],
    supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
    routerConfig: ref.watch(appRouterProvider),
  );
}
