-- ZenexPay CURRENT 3-ISSUE REPAIR
-- Run this AFTER the canonical Admin migration and any existing Admin fixes.
-- Safe to rerun: functions/policies are recreated, business data is not deleted.

begin;

-- ============================================================
-- 1. USER APP: task submission reliability
-- ============================================================
create or replace function public.submit_task(
  p_task_id uuid,
  p_proof_text text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_task public.tasks%rowtype;
  v_submission_id uuid;
  v_status text;
begin
  if v_user is null then
    raise exception using message = 'Not authenticated';
  end if;
  if not exists (select 1 from public.profiles where id=v_user and status='active') then
    raise exception using message = 'Account is blocked';
  end if;
  if coalesce((select (value)::text::boolean from public.app_settings where key='task_system_enabled'),true)=false then
    raise exception using message = 'Task system is temporarily disabled';
  end if;

  select * into v_task
  from public.tasks
  where id=p_task_id
    and status::text='published'
  for share;

  if not found then
    raise exception using message = 'Task is no longer available';
  end if;

  select lower(status::text)
    into v_status
  from public.task_submissions
  where user_id=v_user
    and task_id=p_task_id
    and lower(status::text) in ('pending','screenshot_requested','screenshot_submitted','approved')
  order by created_at desc
  limit 1;

  if v_status='approved' then
    raise exception using message = 'This task has already been completed and paid.';
  elsif v_status='screenshot_requested' then
    raise exception using message = 'A screenshot was requested for your existing submission. Please upload it from My Submissions.';
  elsif v_status='screenshot_submitted' then
    raise exception using message = 'Your screenshot is already under review. Please wait for the reviewer.';
  elsif v_status='pending' then
    raise exception using message = 'This task is already pending review. You cannot submit it again until the current review is finished.';
  end if;


  insert into public.task_submissions (
    user_id, task_id, status, proof_text, created_at, updated_at
  ) values (
    v_user, p_task_id, 'pending'::public.submission_status,
    nullif(trim(p_proof_text), ''), now(), now()
  ) returning id into v_submission_id;

  return v_submission_id;
exception
  when unique_violation then
    raise exception using message = 'This task is already pending review. Please wait for the current review to finish.';
end;
$$;
revoke all on function public.submit_task(uuid,text) from public;
grant execute on function public.submit_task(uuid,text) to authenticated;

-- ============================================================
-- 2. ADMIN: withdrawal queue must always receive pending rows
-- ============================================================
create or replace function public.admin_withdrawal_list(p_limit integer default 500)
returns table(
  id uuid,
  user_id uuid,
  full_name text,
  email text,
  user_numeric_id text,
  amount numeric,
  method text,
  account_number text,
  status text,
  note text,
  processed_by uuid,
  processed_at timestamptz,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not (
    coalesce(auth.jwt()->'app_metadata'->>'role','')='admin'
    or public.admin_role_for(auth.uid()) in ('super_admin','finance','viewer')
  ) then
    raise exception 'Finance/view access required';
  end if;

  return query
  select
    w.id,
    w.user_id,
    p.full_name,
    u.email::text,
    p.user_numeric_id::text,
    w.amount,
    w.method::text,
    case
      when public.admin_can('finance') then w.account_number
      when nullif(trim(w.account_number),'') is null then null
      else '••••' || right(w.account_number,4)
    end,
    w.status::text,
    w.note,
    w.processed_by,
    w.processed_at,
    w.created_at
  from public.withdrawals w
  left join public.profiles p on p.id=w.user_id
  left join auth.users u on u.id=w.user_id
  order by w.created_at desc
  limit least(greatest(coalesce(p_limit,500),1),2000);
end;
$$;
revoke all on function public.admin_withdrawal_list(integer) from public;
grant execute on function public.admin_withdrawal_list(integer) to authenticated;

-- Ensure the Admin/Mobile settings read path is available.
alter table public.app_settings enable row level security;
grant select on public.app_settings to authenticated;
drop policy if exists "Authenticated users view settings" on public.app_settings;
create policy "Authenticated users view settings"
on public.app_settings
for select to authenticated
using (true);

notify pgrst, 'reload schema';
commit;
