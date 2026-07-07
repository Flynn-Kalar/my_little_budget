# Supabase table sync v2 preparation

1. Supabase Dashboard에서 대상 프로젝트를 연다.
2. SQL Editor에서 `table_sync_v2_schema.sql` 전체를 실행한다.
3. 앱의 `설정 > 데이터 관리`에서 기존 Supabase URL과 anon/publishable key를 입력한다.
4. `DB 테이블 테스트`를 누른다.

성공하면 앱이 아래 9개 테이블을 PostgREST로 조회할 수 있는 상태다.

- `mlb_accounts`
- `mlb_categories`
- `mlb_transactions`
- `mlb_budget_groups`
- `mlb_monthly_income`
- `mlb_investments`
- `mlb_recurring_transactions`
- `mlb_tags`
- `mlb_calendar_events`

현재 SQL은 anon 역할에 `SELECT`만 허용한다. 앱은 아직 이 테이블에 데이터를 업로드하거나 수정하지 않으며, 기존 Supabase Storage JSON 백업/복원도 그대로 유지된다.

anon key는 비밀 키가 아니다. 실제 행 동기화를 추가할 때는 사용자 인증과 사용자별 RLS 정책을 먼저 설계하고 `INSERT`, `UPDATE`, `DELETE` 권한을 추가해야 한다.
