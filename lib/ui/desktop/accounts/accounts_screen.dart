import 'package:flutter/material.dart';

import 'widgets/account_list.dart';
import 'widgets/archived_accounts.dart';
import 'widgets/total_assets_card.dart';

/// SPEC §4.2 — 자산 메인 화면 (PC).
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('자산',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            TotalAssetsCard(),
            SizedBox(height: 20),
            AccountList(),
            ArchivedAccounts(),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
