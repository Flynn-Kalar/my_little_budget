// SPEC §5.3 — 첫 실행/초기화 시 들어가는 기본 자산·카테고리.

typedef DefaultAccount = ({
  String name,
  String kind,
  String color,
  bool isInvestment,
});
typedef DefaultCategory = ({String name, String color});

const List<DefaultAccount> defaultAccounts = [
  (name: '주거래 통장', kind: 'bank', color: '#2563eb', isInvestment: false),
  (name: '신용카드', kind: 'card', color: '#dc2626', isInvestment: false),
  (name: '현금', kind: 'cash', color: '#16a34a', isInvestment: false),
  (name: '비상금', kind: 'bank', color: '#0891b2', isInvestment: false),
  (name: '투자', kind: 'other', color: '#7c3aed', isInvestment: true),
];

const List<DefaultCategory> defaultExpenseCategories = [
  (name: '식비', color: '#f97316'),
  (name: '교통', color: '#0ea5e9'),
  (name: '주거', color: '#84cc16'),
  (name: '통신', color: '#a855f7'),
  (name: '의료', color: '#ef4444'),
  (name: '문화·여가', color: '#ec4899'),
  (name: '교육', color: '#6366f1'),
  (name: '쇼핑', color: '#f59e0b'),
  (name: '경조사', color: '#14b8a6'),
  (name: '기타지출', color: '#64748b'),
];

const List<DefaultCategory> defaultIncomeCategories = [
  (name: '급여', color: '#22c55e'),
  (name: '용돈', color: '#10b981'),
  (name: '이자', color: '#06b6d4'),
  (name: '기타수입', color: '#94a3b8'),
];
