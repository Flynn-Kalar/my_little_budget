-- My Little Budget table-sync v2 preparation.
-- This stage grants SELECT only. Row upload/update/delete is intentionally not enabled.
-- The anon key is a public client credential, so do not add write policies without auth.

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'mlb_accounts',
    'mlb_categories',
    'mlb_transactions',
    'mlb_budget_groups',
    'mlb_monthly_income',
    'mlb_investments',
    'mlb_recurring_transactions',
    'mlb_tags'
  ]
  loop
    execute format(
      'create table if not exists public.%I (
        uuid text primary key,
        payload jsonb not null default ''{}''::jsonb,
        updated_at timestamptz not null default now(),
        deleted_at timestamptz,
        sync_status text not null default ''pending''
      )',
      table_name
    );
    execute format('alter table public.%I enable row level security', table_name);
    execute format(
      'drop policy if exists mlb_sync_read_anon on public.%I',
      table_name
    );
    execute format(
      'create policy mlb_sync_read_anon on public.%I for select to anon using (true)',
      table_name
    );
    execute format('grant select on table public.%I to anon', table_name);
  end loop;
end
$$;
