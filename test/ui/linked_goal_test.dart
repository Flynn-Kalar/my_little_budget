import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/core/money.dart';
import 'package:my_little_budget/data/daos/accounts_dao.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/notes/note_goal_block.dart';
import 'package:my_little_budget/features/settings/statement_period.dart';
import 'package:my_little_budget/ui/desktop/accounts/widgets/account_form_dialog.dart';
import 'package:my_little_budget/ui/mobile/accounts/mobile_accounts_screen.dart';
import 'package:my_little_budget/ui/shared/fund_purpose.dart';
import 'package:my_little_budget/ui/shared/note_amount_goal.dart';
import 'package:my_little_budget/ui/shared/note_goal_embed.dart';

void main() {
  final today = DateTime(2026, 11, 18);
  late AppDatabase db;
  late Account bank;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    bank = (await db.accountsDao.getActiveAccounts()).firstWhere(
      (a) => a.kind == 'bank',
    );
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget body, bool mobile) async {
    tester.view.physicalSize = mobile
        ? const Size(320, 900)
        : const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          statementTodayProvider.overrideWithValue(today),
        ],
        child: MaterialApp(home: Scaffold(body: body)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  Future<void> select(WidgetTester tester, String key, String label) async {
    final field = find.byKey(ValueKey(key));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  for (final mobile in [false, true]) {
    testWidgets(
      '${mobile ? 'mobile' : 'desktop'} creates and reopens connected goal and updates live',
      (tester) async {
        final controller = QuillController.basic();
        final tagId = await db.tagsDao.createTag('보험료', '#123456');
        final tag = (await db.select(db.tags).get()).singleWhere(
          (t) => t.id == tagId,
        );
        try {
          await pump(
            tester,
            Builder(
              builder: (context) => TextButton(
                onPressed: () => editNoteGoalBlock(context, controller),
                child: const Text('목표 만들기'),
              ),
            ),
            mobile,
          );
          await tester.tap(find.text('목표 만들기'));
          await tester.pumpAndSettle();
          await select(tester, 'goal-source', '연결 계좌 거래 자동 집계');
          await select(tester, 'goal-account', '${bank.name} · 생활비');
          await select(tester, 'goal-tag', '#보험료');
          final draft = tester
              .widget<NoteGoalForm>(find.byType(NoteGoalForm))
              .draft;
          draft.target.text = '1,200,000';
          draft.current.text = '300000';
          draft.start = DateTime(2026, 10);
          draft.due = DateTime(2027, 1, 31);
          draft.refresh();
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, '삽입'));
          await tester.pumpAndSettle();
          final data =
              controller.document
                      .toDelta()
                      .toList()
                      .firstWhere((op) => op.data is Map)
                      .data
                  as Map;
          final block = NoteGoalBlock.decode(data[noteGoalBlockType])!;
          expect(block.goal.accountUuid, bank.uuid);
          expect(block.goal.tagUuid, tag.uuid);
          expect(block.goal.source, 'transactions');
          await pump(
            tester,
            Builder(
              builder: (context) => SingleChildScrollView(
                child: Column(
                  children: [
                    NoteGoalSummary(goal: block.goal),
                    TextButton(
                      onPressed: () =>
                          editNoteGoalBlock(context, controller, block: block),
                      child: const Text('목표 수정'),
                    ),
                  ],
                ),
              ),
            ),
            mobile,
          );
          expect(find.text('이번 달 필요한 적립액 300,000원'), findsOneWidget);
          final category = (await db.categoriesDao.getActiveCategories(
            'income',
          )).first;
          final transactionId = await db
              .into(db.transactions)
              .insert(
                TransactionsCompanion.insert(
                  type: 'income',
                  amount: 100000,
                  occurredOn: '2026-11-18',
                  accountId: Value(bank.id),
                  categoryId: Value(category.id),
                ),
              );
          await db.tagsDao.setTransactionTags(transactionId, [tagId]);
          await tester.pumpAndSettle();
          expect(find.text('400,000 / 1,200,000원'), findsOneWidget);
          expect(find.text('이번 달 필요한 적립액 200,000원'), findsOneWidget);
          await tester.tap(find.text('목표 수정'));
          await tester.pumpAndSettle();
          final reopened = tester
              .widget<NoteGoalForm>(find.byType(NoteGoalForm))
              .draft;
          expect(
            reopened.goal,
            block.goal,
          ); // Live progress must not overwrite the baseline.
          await select(tester, 'goal-source', '계좌 잔액 자동 집계');
          expect(find.byKey(const ValueKey('goal-tag')), findsNothing);
          expect(reopened.goal!.tagUuid, isNull);
          expect(tester.takeException(), isNull);
        } finally {
          await close(tester);
          controller.dispose();
        }
      },
    );

    testWidgets(
      '${mobile ? 'mobile' : 'desktop'} saves reserve purpose without changing balance',
      (tester) async {
        try {
          if (mobile) {
            for (final account in await db.accountsDao.getActiveAccounts()) {
              if (account.id != bank.id) {
                await db.accountsDao.archiveAccount(account.id);
              }
            }
            await pump(tester, const MobileAccountsScreen(), mobile);
            final edit = find.byTooltip('자산 메뉴').first;
            await tester.ensureVisible(edit);
            await tester.tap(edit);
            await tester.pumpAndSettle();
            await tester.tap(find.text('수정').last);
          } else {
            final account = (await db.accountsDao.getAccountBalance(
              bank.id,
              asOf: today,
            ))!;
            await pump(
              tester,
              Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      AccountFormDialog.show(context, account: account),
                  child: const Text('편집'),
                ),
              ),
              mobile,
            );
            await tester.tap(find.text('편집'));
          }
          await tester.pumpAndSettle();
          await select(tester, 'account-fund-purpose', '연간 지출 준비금');
          final save = find.widgetWithText(FilledButton, '저장');
          await tester.ensureVisible(save);
          await tester.tap(save);
          await tester.pumpAndSettle();
          final result = (await db.accountsDao.getAccountBalance(
            bank.id,
            asOf: today,
          ))!;
          expect(result.fundPurpose, 'annual');
          expect(result.balance, 0);
          expect(await db.select(db.transactions).get(), isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          await close(tester);
        }
      },
    );
  }

  testWidgets(
    'purpose totals separate funds and omit excluded, card and investment assets',
    (tester) async {
      AccountBalance account(
        int id,
        int amount, {
        String purpose = 'living',
        String kind = 'bank',
        bool exclude = false,
        bool investment = false,
      }) => AccountBalance(
        accountId: id,
        name: '$id',
        kind: kind,
        color: '#123456',
        initialBalance: 0,
        cardLimit: null,
        excludeFromTotal: exclude,
        isInvestment: investment,
        balance: amount,
        fundPurpose: purpose,
      );
      try {
        await pump(
          tester,
          FundPurposeSummary(
            accounts: [
              account(1, 100000),
              account(2, 200000, purpose: 'emergency'),
              account(3, 300000, purpose: 'annual'),
              account(4, 900000, exclude: true),
              account(5, -10000, kind: 'card'),
              account(6, 700000, investment: true),
            ],
          ),
          true,
        );
        for (final amount in [100000, 200000, 300000]) {
          expect(find.text(formatKRW(amount)), findsOneWidget);
        }
        for (final amount in [900000, -10000, 700000]) {
          expect(find.text(formatKRW(amount)), findsNothing);
        }
        expect(tester.takeException(), isNull);
      } finally {
        await close(tester);
      }
    },
  );
}
