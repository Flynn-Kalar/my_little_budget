# my_little_budget — 현재 앱 사양

원본: `C:\Users\di020\my_little_budget_tauri` (Next.js 15 + better-sqlite3 + Drizzle + Tauri 2)
대상: 이 문서를 보고 Flutter 로 재구현.

이 문서는 "지금 앱이 무엇을 하는가" 를 화면·동작·데이터 수준에서 빠짐없이 적어둔 사양서다. 구현 코드의 줄 단위 매핑이 아니라, **다른 스택으로 다시 만들 때 빠뜨리면 안 되는 동작과 규칙** 을 담는다.

---

## 1. 한 줄 정의

> 로컬 SQLite 파일 하나(`budget.db`) 에 모든 데이터를 저장하는, **외부 전송 없는 한국어 가계부**. 현금흐름(수입/지출/이체) 외에 **자산 잔액 관리, 카테고리 예산, 반복 거래, 태그, 투자 종목 손익** 까지 다룬다.

- 언어: 한국어 단일.
- 통화: 원(KRW), 정수형, 소수점·환율 없음.
- 단일 사용자, 로컬 단독 동작, 로그인 없음, 동기화 없음.
- 데스크톱(현재 Tauri Windows) 배포. → Flutter 에서 모바일까지 포함하려면 SQLite 위치/접근만 플랫폼별로 다르게.

---

## 2. 전역 구조

### 2.1 네비게이션 (사이드바)

좌측 고정 사이드바, 상하 2영역:

상단:
1. **내역** (`/transactions`) — 거래 추가/편집/검색 (기본 진입 페이지, `/` 는 여기로 리디렉트)
2. **예산** (`/budget`) — 월별 예산 그룹 관리·진행률
3. **통계** (`/stats`) — 월 도넛 차트 + 12개월 추세, 하위에 `/stats/yearly` 연간 피벗
4. **자산** (`/accounts`) — 자산 목록·잔액, 상세는 `/accounts/[id]`
5. **투자** (`/investments`) — 종목 매수/매도/배당, 실현손익 탭

하단:
6. **설정** (`/settings`) — 카테고리·태그·반복거래·테마·데이터 관리

**배지**: 사이드바 "예산" 항목 옆에 **이번 달 예산 초과 그룹 수** 를 빨간 배지로 표시. 0이면 표시 없음.

### 2.2 테마

- CSS 변수 7개 (`income`, `expense`, `transfer`, `background`, `surface`, `accent`, `warning`) 로 운영.
- 기본값: 수입=#2563eb, 지출=#dc2626, 이체=#ffae00, 배경=#ecfeef, 표면=#f5fff7, 강조=#646464, 경고=#5e00d1.
- 사용자가 `/settings/theme` 에서 색상 변경 → **localStorage(`mlb-theme-v1`)** 에 JSON 저장 → 다음 진입 시 복원.
- Flutter 에서는 `SharedPreferences` 등에 동일 구조로 저장하면 됨.
- 다크모드 토글은 별도로 없음. 색상은 사용자가 직접 고른다.

### 2.3 통화·날짜 포맷

- `formatKRW(n)` = `Intl.NumberFormat("ko-KR", currency: "KRW", maximumFractionDigits: 0)` → `₩12,345`.
- `parseKRW(s)` = 숫자·마이너스 외 제거 후 `parseInt`, 빈 문자열은 0.
- 날짜키: **`YYYY-MM-DD`** (text). 월키: **`YYYY-MM`** (text). 시각: **`HH:MM`** (24h, default `"00:00"`).
- 입력 시각 파서 `parseTimeInput("20")="20:00"`, `"2030"="20:30"`, `"20:30"="20:30"`, 그 외 null.
- 요일 라벨: `["일","월","화","수","목","금","토"]`. 날짜 헤더는 `MM.DD (요일)`.

---

## 3. 데이터 모델 (SQLite, 마이그레이션 그대로 옮기면 됨)

모든 금액은 정수(원). 모든 시간/날짜는 텍스트. boolean 은 0/1 정수.

### 3.1 accounts — 자산(계좌)
| 컬럼 | 타입 | 비고 |
|---|---|---|
| id | INTEGER PK auto | |
| name | TEXT NOT NULL UNIQUE | 최대 40자 |
| kind | TEXT NOT NULL | `cash`/`bank`/`card`/`other` |
| initial_balance | INTEGER NOT NULL default 0 | 초기 잔액. **편집 시 절대 변경하지 않음** — 잔액 차이는 adjustment 거래로 기록 |
| color | TEXT NOT NULL default `#94a3b8` | hex |
| exclude_from_total | INTEGER bool default 0 | 총 순자산 합산 제외 (예: 가족 계좌, 메모용) |
| is_investment | INTEGER bool default 0 | 투자 활동이 매핑될 단일 자산. **앱 전체에서 1개만 허용** (저장 시 다른 모든 자산을 0으로 강제) |
| sort_order | INTEGER default 0 | |
| archived_at | TEXT NULL | 보관(소프트 삭제). 사용 0건이면 hard delete 가능 |
| created_at | TEXT default `datetime('now')` | |

### 3.2 categories — 카테고리
| 컬럼 | 타입 | 비고 |
|---|---|---|
| id | INTEGER PK auto | |
| name | TEXT NOT NULL | 최대 20자 |
| type | TEXT NOT NULL | `income` / `expense` |
| color | TEXT NOT NULL default `#64748b` | |
| icon | TEXT NULL | (현재 사용처 사실상 없음) |
| sort_order | INTEGER default 0 | |
| archived_at | TEXT NULL | 사용 중이면 hard delete 안 됨 |
| created_at | TEXT default now | |

UNIQUE `(name, type)`.

### 3.3 transactions — 거래 (메인 테이블)
| 컬럼 | 비고 |
|---|---|
| id | PK |
| type | `income` / `expense` / `transfer` / `adjustment` |
| occurred_on | `YYYY-MM-DD` NOT NULL |
| occurred_time | `HH:MM` NOT NULL default `"00:00"` |
| amount | INTEGER. **type=adjustment 면 signed delta(음수 허용, 0 불가)**, 그 외엔 항상 양수 |
| memo | TEXT NULL, 최대 200자 |
| account_id | type ∈ {income, expense, adjustment} 면 NOT NULL, 그 외 NULL |
| category_id | type ∈ {income, expense} 면 NOT NULL, 그 외 NULL |
| from_account_id, to_account_id | transfer 면 NOT NULL 둘 다 + 서로 달라야 함, 그 외 NULL |

타입별 형상 제약 (DB CHECK 로 강제):
- `income`/`expense`: `account_id`+`category_id` 필수, 양수 amount
- `transfer`: `from_account_id` ≠ `to_account_id`, 양수 amount
- `adjustment`: `account_id` 만, `amount <> 0` (signed)

인덱스: occurred_on, type, category_id, account_id, from_account_id, to_account_id.

### 3.4 budget_groups + budget_group_categories — 예산 그룹
- 월별 `(name, month)` 유니크.
- 한 그룹은 **카테고리 묶음** 또는 **자산 연동** 둘 중 하나.
- `amount` = 기본 예산. `adjustment` = 잔금 이월/수동 가감 (signed). 유효 예산 = `max(0, base + adjustment)`.
- `percentage` (정수, 1~1000) NOT NULL 아님: 설정되면 **고정 금액 대신 (월 예상 소득 × percentage / 100)** 를 base 로 사용. **% 모드와 자산 연동은 동시 사용 금지**.
- `carry_forward` bool: 다음 달 복사 시 (예산−사용액) 을 다음 달 adjustment 에 자동 기입 (음수 가능). **자산 연동 그룹은 강제 false.**
- `account_id` NULL 이면 카테고리 기반, NOT NULL 이면 자산 연동.
- 카테고리 매핑은 별도 테이블 `budget_group_categories(group_id, category_id)` PK 복합키. 자산 연동 그룹은 카테고리 매핑 추가 안 함.

### 3.5 monthly_income — 월별 예상 소득
| 컬럼 | 비고 |
|---|---|
| month | PK, `YYYY-MM` |
| expected_income | INTEGER ≥ 0 |
| updated_at | TEXT |

% 모드 예산의 base 산정용.

### 3.6 investments — 투자 거래
| 컬럼 | 비고 |
|---|---|
| id | PK |
| side | `buy` / `sell` / `dividend` |
| occurred_on / occurred_time | 거래 시각 |
| ticker | TEXT NOT NULL (최대 40자) |
| quantity | buy/sell 은 양수, dividend 는 항상 0 |
| total_amount | INTEGER > 0. 매수금, 매도금, 배당금 |
| account_id | 투자 자산(`accounts.is_investment=1`) 의 id. 자산이 archive/삭제되면 `ON DELETE SET NULL` |
| memo | TEXT NULL |

평단가(average-cost) 방식으로 종목별 보유수량/원가 추적. **버는 매도 시점에 실현손익을 계산.** (3.10 참조)

### 3.7 recurring_transactions — 반복 거래
| 컬럼 | 비고 |
|---|---|
| name | 표시명 |
| type | `income` / `expense` / `transfer` (adjustment 없음) |
| amount | > 0 |
| memo | NULL 가능 |
| account_id / category_id / from_account_id / to_account_id | type 에 따라 transactions 와 동일 형상 규칙. **자산/카테고리 삭제 시 set null** (그러면 사실상 자동 비활성) |
| frequency | `monthly` / `weekly` |
| day_of_month | monthly 면 1~31. **31 같은 경우 그 달 마지막 날로 폴백.** |
| day_of_week | weekly 면 0(일)~6(토) |
| occurred_time | default "00:00" |
| start_date | `YYYY-MM-DD` 필수 |
| end_date | NULL 가능 (무기한) |
| last_generated_on | 마지막으로 생성된 occurred_on. NULL 이면 start_date 이전 의미 |
| tag_names | JSON 배열 텍스트, 예 `'["여행","고정"]'`. 자동 생성된 거래에 이 태그들을 붙임. 없으면 NULL |
| active | bool, default 1 |

### 3.8 tags / transaction_tags
- `tags(id, name UNIQUE, color, created_at)`. 색상 hex.
- `transaction_tags(transaction_id, tag_id)` 복합 PK. **transfer/adjustment 에는 사실상 태그 안 붙음** (UI 가 income/expense 에만 노출).

### 3.9 잔액 계산 SQL

**한 자산의 현재 잔액** =
```
initial_balance
+ Σ(income.amount        where account_id    = acc.id)
- Σ(expense.amount       where account_id    = acc.id)
+ Σ(transfer.amount      where to_account_id  = acc.id)
- Σ(transfer.amount      where from_account_id= acc.id)
+ Σ(adjustment.amount    where account_id    = acc.id)
+ Σ(investment_balance_impact for this account)   ← 3.10
```

**총 순자산** = `exclude_from_total = 0` 인 자산들 잔액의 합.

자산 페이지에서는 자산을 4그룹으로 분류해 색띠로 비중 표시:
- `cash`: 현금성 (kind=cash or bank, balance ≥ 0, isInvestment=false)
- `investment`: isInvestment=true
- `debt`: balance < 0 또는 kind=card
- `other`: 그 외
그룹 색: cash=#22c55e, investment=#7c3aed, debt=#dc2626, other=#94a3b8.

### 3.10 투자 → 자산 잔액 영향

투자는 별도 `investments` 테이블이지만 잔액 계산에 합산됨. 규칙(매도 시점에 평단가로 실현):

전체 투자기록을 occurred_on/time 순으로 훑으면서 종목별 `(qty, basis)` 를 유지:
- `buy`: `qty += quantity`, `basis += total_amount`. **balanceImpact = 0** (현금 → 주식 자산 전환으로 본다).
- `sell`: 매도수량 `sq = min(quantity, qty)`. 평단 `avg = basis/qty`. `costBasis = round(avg * sq)`. `qty -= sq`, `basis = max(0, basis - costBasis)`. **balanceImpact = total_amount − costBasis** (실현손익).
- `dividend`: **balanceImpact = total_amount** (전액 자산 증가).

각 이벤트의 자산 영향을 그 종목이 속한 `account_id` 로 귀속시켜 자산 잔액에 합산.

투자 자산은 `is_investment=1` 인 단일 자산. 새 투자 거래 저장 시 자동으로 이 자산의 id 를 `account_id` 에 박는다. 투자 자산이 없으면 `account_id=null` 로 저장 → 잔액 영향 없음.

---

## 4. 화면별 동작

### 4.1 `/transactions` 내역

**상단**: 월 네비게이션 (`◀ YYYY년 M월 ▶`, "오늘" 버튼). URL `?month=YYYY-MM` 로 상태 보존. 미지정 시 이번 달.

**요약 카드**: 수입/지출/순수입 3셀. 색은 수입=`income`(파랑계열), 지출=`expense`(빨강계열), 순수입은 양수면 income 색 + `+` 접두, 음수면 expense 색 + `-` 접두, 0이면 기본.

**필터 바**:
- TypeFilter: 전체 / 수입 / 지출 / 이체 토글 (`?type=`)
- FilterPanel (펼침): 검색어(`q` — memo·카테고리명·자산명 LIKE), 금액 범위(min/max), 자산(`accountId`), 카테고리 다중(`categoryIds=1,2,3`), 태그 다중(`tagIds=...`), "태그 없는 거래만" 토글(`untagged=1`), 날짜 범위(`fromDate`, `toDate`)

검색 결과 범위 규칙:
- `fromDate`/`toDate` 중 하나라도 있으면 → 그 범위
- 그 외 검색/필터(q·금액·자산·카테고리·태그·미지정) 가 활성 → **전체 기간** (현재 월에 한정하지 않음)
- 아무 필터도 없으면 → 현재 월 범위
- `adjustment` 는 항상 결과에서 제외 (단, type=adjustment 로 명시 시 통과). 자산 상세에서만 보임.

**페이지 진입 시 부수효과**: `generateDueRecurringTransactions(이번달 말일)` 호출 — 활성 반복 거래 중 `last_generated_on` 이후 누락분을 transactions 에 backfill. 멱등.

**입력 행 (InlineEntry)**: 페이지 상단에 항상 떠있는 "한 줄 입력". 타입 토글(수입/지출/이체) + 날짜·시각 + 자산/카테고리 콤보 + 금액 + 메모 + 태그. Enter 로 저장 → 입력 행 리셋.

**거래 목록**: 날짜별 섹션 그룹화(헤더 `MM.DD (요일)`). 각 행 클릭 → 인라인 편집(QuickRow) 모드. 편집 모드에서 "복제" 버튼 → 동일 값으로 새 입력 모드(`duplicating`).

거래 행 표시:
- income/expense: 컬러 점(카테고리 색) + 카테고리명 + 태그 칩(`#태그명`) + meta(`HH:MM · 자산명 · 메모` 중 빈 값 제외) + 금액 (수입은 `+`/income 색, 지출은 `-`/expense 색)
- transfer: 양방향 화살표 아이콘 + "이체" + meta(`HH:MM · From → To · 메모`) + 금액 (색 없음, 굵게)
- 시각이 `"00:00"` 이면 시각 표시 생략.

**거래 저장 (action `saveTransaction`)**: 폼 데이터를 zod `transactionSchema` 로 검증.
- 신규: INSERT. id 받음.
- 편집: UPDATE.
- `tagNames` (JSON 배열 문자열) 가 함께 들어옴 → `setTransactionTagsByName(txId, names)`: 기존 매핑 전체 삭제 후, 이름별로 tags 테이블 lookup/insert(없으면 랜덤 팔레트 색)하고 매핑 다시 채움. 이름은 trim, 빈 문자열 제거, 20자 제한, 중복 제거.

**자동완성**: `listRecentMemos()` — 최근 거래의 distinct memo 300개 (가장 최근부터).

### 4.2 `/accounts` 자산

**총 순자산 카드**: `exclude_from_total=0` 자산들의 balance 합. 음수면 expense 색. 아래에 4그룹(현금성/투자/기타/부채) 색띠 비중 바 + 라벨/금액.

**자산 목록 (AccountList)**: 활성 자산. 정렬은 `sort_order, id`. 드래그로 순서 변경 가능 (`updateAccountOrder`). 각 행 클릭 → `/accounts/[id]`.

**보관됨 목록 (ArchivedAccountList)**: archived_at 있는 항목. "복구" 또는 "영구 삭제". 영구 삭제는 다른 기록(거래·투자·예산·반복거래) 에서 참조 0건이어야 가능. 카운트는 `getAccountUsageCount(id)`.

**추가/편집 (AccountForm)**:
- 필드: name, kind, color, excludeFromTotal, isInvestment, **현재 잔액** (currentBalance).
- **신규**: `currentBalance` 이 `initial_balance` 로 저장됨.
- **편집**: `initial_balance` 는 절대 건드리지 않는다. 잔액 차이 `delta = currentBalance - 현재잔액` 이 0이 아니면, 같은 타이밍으로 `transactions` 에 type=adjustment 거래 INSERT (`amount=delta`, `memo="잔액 조정"`, occurred_on=오늘, occurred_time=현재 시각).
- `isInvestment=true` 로 저장하면 **다른 모든 자산의 is_investment 를 0 으로 강제 UPDATE** (단일 투자 자산 보장).

### 4.3 `/accounts/[id]` 자산 상세

상단: 이름 + 색 점 + 현재 잔액(음수면 expense 색).

**거래 목록 (AccountTransactionList)**: 이 자산이 관련된 income/expense/transfer/adjustment + 이 자산에 귀속된 **투자 활동을 가상 행으로 합산**.

투자 가상 행 (잔액 영향 기준):
- `buy`: amount=0 (잔액 영향 없음), 카테고리명 = "매수 · TICKER", 색 = #94a3b8 (회색)
- `sell`: 잔액 영향 = 실현손익. 양수면 income, 음수면 expense, 0이면 expense 스타일로 표기. 카테고리명 = "매도 · TICKER", 색 = #22c55e
- `dividend`: income, amount = total_amount. 카테고리명 = "배당 · TICKER", 색 = #a78bfa

정렬: 일반거래 + 가상 투자 행을 occurred_on DESC, occurred_time DESC, id DESC.
adjustment 거래도 여기서는 보임 (잔액 조정 내역 확인용).

### 4.4 `/budget` 예산

**상단**: 월 네비게이션. "이전 달 복사" 버튼 (`copyPreviousMonthBudgets`):
- 직전 달의 그룹들을 현재 달에 없으면 INSERT.
- 카테고리 기반 그룹은 `carry_forward=true` 면 **adjustment = (직전달 유효예산 − 사용액)** 으로 자동 기입 (음수 가능). false 면 adjustment=0.
- % 모드 그룹은 `amount=0`, `percentage` 보존 (base 는 새 달 소득 × % 로 자동).
- 자산 연동 그룹은 단순 복사 (amount=0, adjustment=0, carry_forward=false 강제).
- 직전 달 예상 소득도 함께 복사 (타겟이 0일 때만 덮어쓰지 않음).

**월 예상 소득 입력 (MonthlyIncomeInput)**: % 모드 예산이 1개라도 있으면 강조 표시. 0 또는 양의 정수.

**예산 그룹 목록**: 카테고리 기반 / 자산 연동 그룹들이 한 리스트에 섞여 나옴.

각 그룹 행 (`BudgetGroupRow`):
- 그룹명, 진행률 막대, 사용액 / 유효예산, 사용률(%)
- 카테고리 기반: 매핑된 카테고리 컬러 점들 + 칩. + 버튼으로 카테고리 추가, x 로 제거.
- 자산 연동: 자산 이름·색 + "자산 연동" 배지. **유효예산 = max(0, 월초 잔액) + 이번 달 입금(수익+들어온이체)**, **사용액 = 이번 달 출금(지출+나간이체)**.
- 인라인 편집: amount, adjustment, percentage 토글, carry_forward 토글, 삭제.
- 사용률 100% 이상이면 progress bar 빨간색.

**진행률 표시 (BudgetProgress)**: 모든 그룹의 총 예산/총 사용액 합산 막대 + 텍스트.

**신규 그룹 폼 (CreateGroupForm)**:
- 이름 + 모드(고정금액 / % / 자산 연동) + 카테고리 다중 선택 또는 자산 선택
- "남은 카테고리"만 옵션으로 노출 (이미 그룹에 속한 카테고리 제외)
- "남은 자산"만 옵션으로 (이미 연동된 자산 제외)

### 4.5 `/stats` 통계

**도넛 1: 지출 카테고리** — `expenseByCategory(month)` 결과. 중앙에 합계 표시. 범례 항목 클릭 시 해당 카테고리 거래 패널 펼침 (CategoryDetailPanel).

**도넛 2: 수입 vs 지출** — 수입 1조각(녹색 #22c55e) + 지출 카테고리 세그먼트들. 중앙에 순수입 표시. 같은 인터랙션.

**12개월 추세 (TrendChart)**: `monthlyTrend(12, anchorMonth)` — 마지막 12개월 income/expense/net 막대+선 그래프. 거래 없는 달은 0.

화면 우상단 "연간 요약 →" 링크.

### 4.6 `/stats/yearly?year=YYYY` 연간 요약

연도 네비게이션(이전/다음). 거래 있는 연도 목록 칩(`availableTransactionYears`).

**지출 / 수입 피벗** (`yearlyCategoryPivot(year, type)`): 카테고리 × 12개월 그리드. 사용 내역 없는 카테고리 자동 제외. 총액 내림차순 정렬. 셀 값은 KRW.

**순수입 테이블** (`NetIncomeTable`): 월별 (수입 − 지출). 음수면 빨강.

### 4.7 `/investments` 투자

**상단**: 탭 토글 (목록 / 손익). 연동 자산명 표시.

**목록 탭**:
- 월 네비게이션. 요약 4셀: 매수(빨강 -), 매도(파랑 +), 배당(파랑 +), 순현금(매도+배당-매수, 부호 표시).
- `listInvestmentsByMonth(month)` 표 형태. 인라인 추가/편집 (InvestmentQuickRow): side, occurredOn/time, ticker, quantity(매도/매수만), totalAmount, memo.
- 매도/배당 시 ticker 검증: 현재 보유 종목(`listHeldTickers()` — 매수합−매도합>0) 에만 가능. 단, 같은 id 의 기존 행을 수정 중이고 ticker 가 같으면 통과 (이미 청산된 종목의 행 편집 허용).
- 저장 시 `accountId` 는 현재 `isInvestment=1` 인 자산 id (없으면 null).

**손익 탭**:
- 기간 선택 (`from`, `to` 날짜, default 이번 달).
- 요약: 실현 손익(부호 색), 이익/손해 건수, 평균 수익률(매도 건만 평균).
- `listRealizedPnL(from, to)`: 전체 투자기록을 시간순 훑어 평단 계산 → 기간 안의 매도/배당 만 결과. 매도는 `pnl = sellAmount - costBasis`, `returnRate = pnl/costBasis`. 배당은 `pnl = totalAmount`, returnRate=0.

### 4.8 `/settings`

서브 페이지 리스트 + 데이터 관리.

#### 4.8.1 `/settings/categories`
- 지출 / 수입 / 보관됨 3섹션.
- 항목별: 이름, 색, 정렬 핸들.
- 추가 폼: name + color.
- 사용 중인 카테고리는 삭제 대신 **보관** (archived_at = now). 사용 없으면 hard delete 가능.

#### 4.8.2 `/settings/recurring` 반복 거래
- 카드 리스트: 이름, 다음 발생일, 빈도(매월 N일 / 매주 요일), 금액, 자산/카테고리, 태그, 활성 토글.
- 폼 (RecurringForm): type, frequency 토글(monthly/weekly), dayOfMonth(1~31) 또는 dayOfWeek(0~6), occurredTime, amount, memo, account/category 또는 from/to (transfer), startDate, endDate(옵션), tags(이름 배열, JSON 으로 저장).
- 비활성화하면 자동 backfill 안 됨.
- backfill 알고리즘은 §5.1.

#### 4.8.3 `/settings/tags`
- 태그 CRUD. 이름 UNIQUE, 색상 hex.

#### 4.8.4 `/settings/theme`
- §2.2.

#### 4.8.5 데이터 관리 (settings 메인 페이지 하단, `DataManagement` 컴포넌트)
- **내보내기**: `GET /api/data/export` → 모든 테이블 덤프를 `BackupSchema` (§5.2) JSON 으로. 파일명 `mlb-backup-YYYYMMDD-HHMMSS.json`.
- **가져오기**: 파일 업로드. zod `BackupSchema.safeParse`. 한 트랜잭션 안에서 모든 테이블 비우고 그대로 다시 INSERT (id 포함). 실패 시 롤백.
- **전체 초기화**: 확인 문구 `"삭제"` 입력 강제. 거래·태그·투자·예산을 전부 비우고, 카테고리는 기본 시드로 리셋, **기본 자산 5개(주거래 통장/신용카드/현금/비상금/투자) 는 유지하되 initial_balance=0 으로 리셋, 사용자 추가 자산은 삭제.**

---

## 5. 부수 로직

### 5.1 반복 거래 자동 생성 (`generateDueRecurringTransactions(horizon)`)

`/transactions` 진입 시 매번 호출. horizon = 이번 달 마지막 날.

```
for each active recurring r:
  anchor = r.last_generated_on   // NULL 이면 첫 발생
  loop (최대 120회 — 무한루프 방지):
    next = nextOccurrence(r, anchor)
    if next == null: break
    if next > horizon: break
    if r.end_date != null and next > r.end_date: break

    INSERT into transactions (...)   // type/account/category 등 r 의 값으로
    if r.tag_names != null:
      각 이름에 대해 tags lookup-or-create, transaction_tags 매핑

    anchor = next
  if anchor != r.last_generated_on:
    UPDATE recurring_transactions SET last_generated_on = anchor
```

`nextOccurrence(r, anchor)`:
- `monthly`:
  - anchor null → start_date 의 (year, month) 에서 `min(dayOfMonth, 그달 마지막일)` 로 후보. 후보 ≥ start_date 면 채택, 아니면 다음 달로.
  - anchor 있으면 anchor 의 **다음 달**, `min(dayOfMonth, 다음달 마지막일)`.
- `weekly`:
  - anchor null → start_date 부터 가장 가까운 dayOfWeek (`(dayOfWeek - sd.dayOfWeek + 7) % 7` 일 더함).
  - anchor 있으면 anchor + 7일.

전 과정 단일 트랜잭션. 새 거래 한 건당 anchor 갱신. 멱등(같은 horizon 으로 재호출 시 추가 INSERT 없음).

### 5.2 Backup 스키마 (`BackupSchema`)

```jsonc
{
  "version": 1,
  "appName": "my_little_budget",
  "exportedAt": "<ISO timestamp>",
  "data": {
    "accounts": [...],
    "categories": [...],
    "budgetGroups": [...],
    "budgetGroupCategories": [...],
    "transactions": [...],
    "investments": [...],            // 옵션 (구버전 호환)
    "tags": [...],                   // 옵션
    "transactionTags": [...],        // 옵션
    "monthlyIncome": [...],          // 옵션
    "recurringTransactions": [...]   // 옵션
  }
}
```

`boolish` 필드(예: `excludeFromTotal`, `isInvestment`, `carryForward`, `active`) 는 boolean 또는 0/1 정수 둘 다 허용 (SQLite 라운드트립 호환).

### 5.3 기본 시드 (앱 첫 실행 또는 초기화 시)

기본 자산 5개:
```
주거래 통장 (bank, #2563eb)
신용카드   (card, #dc2626)
현금       (cash, #16a34a)
비상금     (bank, #0891b2)
투자       (other, #7c3aed)
```

기본 지출 카테고리 10개:
```
식비 #f97316, 교통 #0ea5e9, 주거 #84cc16, 통신 #a855f7, 의료 #ef4444,
문화·여가 #ec4899, 교육 #6366f1, 쇼핑 #f59e0b, 경조사 #14b8a6, 기타지출 #64748b
```

기본 수입 카테고리 4개:
```
급여 #22c55e, 용돈 #10b981, 이자 #06b6d4, 기타수입 #94a3b8
```

### 5.4 검증 규칙 (zod, Flutter 에서 동등하게 구현 필요)

- 거래: type 에 따라 discriminated union. amount > 0 (adjustment 만 signed, ≠ 0). 날짜 `YYYY-MM-DD`, 시각 `HH:MM`. memo 최대 200. transfer 의 from ≠ to.
- 자산: name 1~40자, kind enum, color hex `^#[0-9a-fA-F]{6}$`.
- 카테고리: name 1~20, type enum, color hex.
- 예산 그룹: percentage 1~1000 정수, amount ≥ 0. 자산 연동과 % 동시 불가.
- 투자: ticker 1~40, buy/sell 은 quantity ≥ 1, dividend 는 quantity=0, totalAmount ≥ 1.
- 태그 이름: 1~20자, trim, 중복 제거.

---

## 6. Flutter 포팅 시 매핑 가이드

### 6.1 데이터 계층
- **SQLite 드라이버**: `sqflite` (모바일) 또는 `drift` (sqflite + ORM, 더 권장 — 컴파일타임 쿼리 + 마이그레이션 관리). 또는 `sqlite3` + 수동 SQL.
- **DB 위치**: 모바일은 `getApplicationDocumentsDirectory()/budget.db`. 데스크톱(Windows) 은 `%APPDATA%\com.dijung.mylittlebudget\budget.db` 유지하면 기존 Tauri 빌드에서 이전 가능.
- **마이그레이션**: 현재 Drizzle SQL 스냅샷을 그대로 schema_v1 로 옮기고, 이후 Flutter 쪽 마이그레이션은 drift의 schema versioning 사용.
- **트랜잭션**: import / reset / recurring backfill / 태그 재매핑 등은 반드시 트랜잭션.

### 6.2 상태 관리
- 현재 Next.js 의 서버 컴포넌트가 매 진입마다 DB 직접 조회 → Flutter 에서는 **모든 화면이 진입/갱신 시 쿼리 재실행** 하면 동등. `Riverpod` 의 `Provider`/`StreamProvider` 또는 `bloc` 어느 쪽이든.
- "save 후 refresh" 패턴이 도처에 있음 → Flutter 에서는 mutation 후 관련 provider invalidate.

### 6.3 라우팅
6개 탭 라우트 + 하위 페이지. `go_router` 권장. URL 쿼리(`?month=`, `?type=`, `?categoryIds=` 등) 도 그대로 유지하면 딥링크 친화적.

### 6.4 UI
- Tailwind 디자인 → Flutter 의 `ThemeData` + 사용자 정의 토큰(현재 7개) 을 InheritedWidget 으로.
- 차트: Recharts 대신 `fl_chart` (도넛/막대/라인 모두 지원).
- 드래그 정렬: `ReorderableListView`.
- 인라인 편집 행: `Form` + `TextEditingController`.

### 6.5 플랫폼 차이
- 키보드/포커스: 데스크톱 키보드 단축키(Enter 저장, Esc 취소) 가 현재 일부 적용 → Flutter 에서도 `Focus`/`Shortcuts`/`Actions` 로 동등.
- 파일 입출력(백업): `file_picker` + `path_provider`.

---

## 7. 빠뜨리면 안 되는 미묘한 규칙 체크리스트

- [ ] 거래의 type 별 형상 제약을 DB CHECK 로 강제 (앱 코드에서만 검증하면 안 됨).
- [ ] adjustment 는 transactions 리스트에 보이지 않음 (자산 상세에서만).
- [ ] 자산 편집 시 잔액 변경분은 반드시 adjustment 거래로 기록 (initial_balance 직접 수정 금지).
- [ ] is_investment 자산은 전 앱에서 1개만.
- [ ] 반복 거래 backfill 은 한 진입 당 호출 1회 + 멱등.
- [ ] 반복 거래의 dayOfMonth 가 그 달에 없으면 마지막 날로 폴백.
- [ ] 예산 그룹: 자산 연동과 % 모드 동시 사용 금지, 자산 연동은 carry_forward 강제 false.
- [ ] 자산 연동 예산의 "사용가능총액" 산정에서 월초 잔액이 음수면 0으로 clamp.
- [ ] 검색·필터가 활성이면 월 범위를 벗어나 전체 기간을 본다 (직관성).
- [ ] 투자 매도/배당은 현재 보유 종목에만 허용 (기존 행 수정은 예외).
- [ ] 매도 시 평단가 계산은 SQL 이 아니라 코드에서 전체 시간순 훑기로.
- [ ] 백업 import 시 boolean 컬럼은 0/1 정수와 true/false 양쪽 허용.
- [ ] 자산/카테고리 hard delete 는 사용 0건일 때만 (참조 카운트 함수 필요).
- [ ] 자산 archive 후에도 그 자산이 붙은 거래는 그대로 조회됨 (account_id 는 정수 그대로).
- [ ] 태그 자동 생성 시 색은 정해진 팔레트에서 랜덤.
- [ ] 사이드바 "예산" 배지는 매 layout 렌더마다 현재 월 기준 초과 그룹 수를 재계산.
- [ ] 전체 초기화는 기본 자산 5개 보존 + initial_balance=0, 사용자 추가 자산은 삭제.

---

## 8. 아직 미구현/명시되지 않은 영역

이 앱에 **없는 것**:
- 다중 사용자, 인증
- 다중 통화, 환율
- 클라우드 동기화/공유
- 영수증 사진 첨부
- 푸시 알림/리마인더
- 보안 잠금(앱 PIN/생체)
- 통계의 카테고리·자산 필터(현재 통계는 전체만)
- 거래 일괄 가져오기(CSV/은행 API)

Flutter 버전에서 이 중 일부를 추가할 거라면 별도 설계 필요.
