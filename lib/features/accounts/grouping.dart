// SPEC §3.9 — 자산을 4그룹으로 분류 (자산 페이지 색띠/소계용). 순수 함수.

enum AccountGroup { cash, investment, debt, other }

/// 분류 규칙 (순서 중요):
///   1) isInvestment   → investment
///   2) balance < 0 또는 kind == 'card' → debt
///   3) kind == 'cash' 또는 'bank'      → cash
///   4) 그 외                            → other
AccountGroup classifyAccount({
  required String kind,
  required int balance,
  required bool isInvestment,
}) {
  if (isInvestment) return AccountGroup.investment;
  if (balance < 0 || kind == 'card') return AccountGroup.debt;
  if (kind == 'cash' || kind == 'bank') return AccountGroup.cash;
  return AccountGroup.other;
}

extension AccountGroupMeta on AccountGroup {
  String get label => switch (this) {
        AccountGroup.cash => '현금성',
        AccountGroup.investment => '투자',
        AccountGroup.debt => '부채',
        AccountGroup.other => '기타',
      };

  /// SPEC §3.9 의 그룹 색 (hex).
  String get colorHex => switch (this) {
        AccountGroup.cash => '#22c55e',
        AccountGroup.investment => '#7c3aed',
        AccountGroup.debt => '#dc2626',
        AccountGroup.other => '#94a3b8',
      };
}

/// 자산 페이지 표시 순서. SPEC §3.9.
const accountGroupOrder = <AccountGroup>[
  AccountGroup.cash,
  AccountGroup.investment,
  AccountGroup.other,
  AccountGroup.debt,
];
