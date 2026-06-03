import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../color_hex.dart';
import 'providers.dart';
import 'widgets/account_tx_list.dart';

/// SPEC §4.3 — 자산 상세 (PC).
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});
  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(accountByIdProvider(accountId));
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 뒤로
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextButton.icon(
                onPressed: () => context.go('/accounts'),
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('자산'),
                style: TextButton.styleFrom(foregroundColor: AppTokens.muted),
              ),
            ),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text('불러오기 오류: $e'),
              ),
              data: (account) {
                if (account == null) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('자산을 찾을 수 없습니다')),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorFromHex(account.color),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(account.name,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatKRW(account.balance),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: account.balance < 0 ? AppTokens.expense : null,
                      ),
                    ),
                    const SizedBox(height: 32),
                    AccountTxList(
                      accountId: accountId,
                      initialBalance: account.initialBalance,
                    ),
                    const SizedBox(height: 40),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
