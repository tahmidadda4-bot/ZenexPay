-- ZenexPay Admin Control FINAL
-- Canonical admin-only migration for the live 2026-09-27 Supabase schema.
--
-- IMPORTANT
-- 1) This file is written against DATABASE/ZENEXPAY_DATABASE_MAP.md.
-- 2) It does NOT recreate the whole user/business schema.
-- 3) It does NOT drop, truncate, or delete business data.
-- 4) Do not run the old V1/V2/V3 admin patches after this file.
-- 5) Existing user/business RPCs such as submit_task(), claim_daily_checkin(),
--    create_withdrawal_request(), get_my_support_chat() are intentionally not
--    replaced here unless an additive admin integration is required.
-- 6) This migration uses new admin_* RPC names for privileged admin actions so
--    existing user RPC signatures are not changed.

begin;

-- ============================================================
-- 1. Admin roles / permissions
-- ============================================================
create table if not exists public.admin_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('super_admin','finance','support','task_manager','viewer')),
  is_active boolean not null default true,
  note text not null default '',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.admin_roles add column if not exists is_active boolean not null default true;
alter table public.admin_roles enable row level security;
revoke all on public.admin_roles from anon, authenticated;
grant select on public.admin_roles to authenticated;

drop policy if exists admin_roles_select on public.admin_roles;
create policy admin_roles_select on public.admin_roles
  for select to authenticated
  using (public.is_admin());

-- Keep the existing admin identity concept, but also support the new role table.
-- Return type remains boolean, so this is safe for PostgreSQL function identity.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.status = 'active'
      and (
        coalesce(auth.jwt()->'app_metadata'->>'role','') = 'admin'
        or exists (
          select 1
          from public.admin_roles ar
          where ar.user_id = auth.uid()
            and ar.is_active = true
        )
      )
  );
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

create or replace function public.admin_role_for(p_user_id uuid default auth.uid())
returns text
language sql
stable
security definer
set search_path = public, auth
as $$
  select case
    when p_user_id = auth.uid()
      and coalesce(auth.jwt()->'app_metadata'->>'role','') = 'admin'
      then 'super_admin'
    else (select ar.role from public.admin_roles ar where ar.user_id = p_user_id)
  end;
$$;
revoke all on function public.admin_role_for(uuid) from public;
grant execute on function public.admin_role_for(uuid) to authenticated;

create or replace function public.admin_can(p_permission text)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select case
    when not public.is_admin() then false
    when coalesce(auth.jwt()->'app_metadata'->>'role','') = 'admin' then true
    when public.admin_role_for(auth.uid()) = 'super_admin' then true
    when p_permission in ('admin_roles','settings') then false
    when p_permission in ('finance') and public.admin_role_for(auth.uid()) = 'finance' then true
    when p_permission in ('support') and public.admin_role_for(auth.uid()) = 'support' then true
    when p_permission in ('tasks') and public.admin_role_for(auth.uid()) = 'task_manager' then true
    when p_permission in ('view') then true
    else false
  end;
$$;
revoke all on function public.admin_can(text) from public;
grant execute on function public.admin_can(text) to authenticated;

drop function if exists public.admin_list_roles();
create or replace function public.admin_list_roles()
returns table(
  user_id uuid,
  full_name text,
  email text,
  role text,
  is_active boolean,
  is_root boolean,
  note text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.admin_can('admin_roles') then
    raise exception 'Admin role management required';
  end if;

  return query
  select
    p.id,
    p.full_name,
    u.email::text,
    case
      when coalesce(u.raw_app_meta_data->>'role','') = 'admin' then 'super_admin'
      else ar.role
    end,
    case
      when coalesce(u.raw_app_meta_data->>'role','') = 'admin' then true
      else coalesce(ar.is_active,false)
    end,
    (coalesce(u.raw_app_meta_data->>'role','') = 'admin'),
    coalesce(ar.note,''),
    coalesce(ar.created_at,p.created_at),
    coalesce(ar.updated_at,p.updated_at)
  from public.profiles p
  join auth.users u on u.id = p.id
  left join public.admin_roles ar on ar.user_id = p.id
  where coalesce(u.raw_app_meta_data->>'role','') = 'admin'
     or ar.user_id is not null
  order by coalesce(ar.updated_at,p.created_at) desc;
end;
$$;
revoke all on function public.admin_list_roles() from public;
grant execute on function public.admin_list_roles() to authenticated;

drop function if exists public.admin_set_role(uuid,text,text);
drop function if exists public.admin_set_role(uuid,text,text,boolean);
create or replace function public.admin_set_role(
  p_user_id uuid,
  p_role text,
  p_note text default '',
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_old_role text;
  v_old_active boolean;
  v_remaining_super bigint;
begin
  if not public.admin_can('admin_roles') then
    raise exception 'Admin role management required';
  end if;

  if p_user_id is null or not exists (select 1 from public.profiles where id = p_user_id) then
    raise exception 'User not found';
  end if;

  if coalesce((select raw_app_meta_data->>'role' from auth.users where id=p_user_id),'') = 'admin' then
    raise exception 'Root admin accounts are managed through Supabase Auth';
  end if;

  select role,is_active into v_old_role,v_old_active from public.admin_roles where user_id=p_user_id;

  if p_role is null or p_role = 'none' then
    if v_old_role = 'super_admin' and coalesce(v_old_active,true) and
       (select count(*) from public.admin_roles where role='super_admin' and is_active=true) <= 1
       and not exists(select 1 from auth.users where id<>auth.uid() and coalesce(raw_app_meta_data->>'role','')='admin') then
      raise exception 'Cannot remove the last active Super Admin';
    end if;
    delete from public.admin_roles where user_id=p_user_id;
    insert into public.user_activity_audit(user_id,actor_id,action,entity_type,entity_id,metadata)
    values(p_user_id,auth.uid(),'admin_role_removed','admin_role',p_user_id::text,
           jsonb_build_object('previous_role',v_old_role,'previous_active',v_old_active));
    return;
  end if;

  if p_role not in ('super_admin','finance','support','task_manager','viewer') then
    raise exception 'Invalid admin role';
  end if;

  if p_role = 'super_admin' and public.admin_role_for(auth.uid()) <> 'super_admin'
     and coalesce(auth.jwt()->'app_metadata'->>'role','') <> 'admin' then
    raise exception 'Only a Super Admin can grant super_admin';
  end if;

  if p_user_id = auth.uid() and (not p_is_active or (v_old_role is not null and p_role <> v_old_role)) then
    raise exception 'You cannot change or deactivate your own Admin role';
  end if;

  if v_old_role = 'super_admin' and coalesce(v_old_active,true) and not p_is_active then
    select count(*) into v_remaining_super from public.admin_roles
      where role='super_admin' and is_active=true and user_id<>p_user_id;
    if v_remaining_super = 0 and not exists(select 1 from auth.users where id<>auth.uid() and coalesce(raw_app_meta_data->>'role','')='admin') then
      raise exception 'Cannot deactivate the last active Super Admin';
    end if;
  end if;

  insert into public.admin_roles(user_id,role,is_active,note,created_by,updated_at)
  values(p_user_id,p_role,coalesce(p_is_active,true),coalesce(p_note,''),auth.uid(),now())
  on conflict(user_id) do update
    set role=excluded.role,
        is_active=excluded.is_active,
        note=excluded.note,
        updated_at=now();

  insert into public.user_activity_audit(user_id,actor_id,action,entity_type,entity_id,metadata)
  values(p_user_id,auth.uid(),'admin_role_changed','admin_role',p_user_id::text,
         jsonb_build_object('role',p_role,'is_active',p_is_active,'previous_role',v_old_role,'previous_active',v_old_active));
end;
$$;
revoke all on function public.admin_set_role(uuid,text,text,boolean) from public;
grant execute on function public.admin_set_role(uuid,text,text,boolean) to authenticated;

create or replace function public.admin_set_role(
  p_user_id uuid, p_role text, p_note text default ''
)
returns void
language sql
security definer
set search_path = public
as $$
  select public.admin_set_role(p_user_id,p_role,p_note,true);
$$;
revoke all on function public.admin_set_role(uuid,text,text) from public;
grant execute on function public.admin_set_role(uuid,text,text) to authenticated;

create or replace function public.admin_find_users(p_query text default '')
returns table(user_id uuid, full_name text, email text, status text)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.admin_can('admin_roles') then raise exception 'Admin role management required'; end if;
  return query
  select p.id,p.full_name,u.email::text,p.status::text
  from public.profiles p
  join auth.users u on u.id=p.id
  where coalesce(trim(p_query),'')=''
     or lower(coalesce(p.full_name,'')) like '%'||lower(trim(p_query))||'%'
     or lower(coalesce(u.email,'')) like '%'||lower(trim(p_query))||'%'
     or p.id::text = trim(p_query)
  order by p.created_at desc
  limit 25;
end;
$$;
revoke all on function public.admin_find_users(text) from public;
grant execute on function public.admin_find_users(text) to authenticated;

-- ============================================================
-- 2. Admin configuration history
-- ============================================================
create table if not exists public.admin_config_history (
  id uuid primary key default gen_random_uuid(),
  setting_key text not null,
  old_value jsonb,
  new_value jsonb not null,
  changed_by uuid references auth.users(id) on delete set null,
  changed_at timestamptz not null default now()
);

alter table public.admin_config_history enable row level security;
revoke all on public.admin_config_history from anon, authenticated;
grant select on public.admin_config_history to authenticated;

drop policy if exists admin_config_history_select on public.admin_config_history;
create policy admin_config_history_select on public.admin_config_history
  for select to authenticated
  using (public.admin_can('settings'));

create index if not exists idx_admin_config_history_key_time
  on public.admin_config_history(setting_key, changed_at desc);

create or replace function public.admin_set_app_setting(
  p_key text,
  p_value jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text := trim(coalesce(p_key,''));
  v_old_text text;
  v_old_json jsonb;
  v_new_text text;
begin
  if not public.admin_can('settings') then
    raise exception 'Settings permission required';
  end if;
  if v_key = '' then
    raise exception 'Setting key required';
  end if;

  if jsonb_typeof(coalesce(p_value,'null'::jsonb)) = 'string' then
    v_new_text := p_value #>> '{}';
  else
    v_new_text := coalesce(p_value,'null'::jsonb)::text;
  end if;

  select value into v_old_text
  from public.app_settings
  where key=v_key
  for update;

  if v_old_text is not null then
    begin
      v_old_json := v_old_text::jsonb;
    exception when others then
      v_old_json := to_jsonb(v_old_text);
    end;
  end if;

  insert into public.admin_config_history(setting_key,old_value,new_value,changed_by)
  values(v_key,v_old_json,coalesce(p_value,'null'::jsonb),auth.uid());

  insert into public.app_settings(key,value,updated_at)
  values(v_key,v_new_text,now())
  on conflict(key) do update
    set value=excluded.value,
        updated_at=now();
end;
$$;
revoke all on function public.admin_set_app_setting(text,jsonb) from public;
grant execute on function public.admin_set_app_setting(text,jsonb) to authenticated;

create or replace function public.admin_config_history_list(
  p_key text default null,
  p_limit integer default 100
)
returns table(
  id uuid,
  setting_key text,
  old_value jsonb,
  new_value jsonb,
  changed_by uuid,
  changed_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_can('settings') then
    raise exception 'Settings permission required';
  end if;

  return query
  select h.id,h.setting_key,h.old_value,h.new_value,h.changed_by,h.changed_at
  from public.admin_config_history h
  where p_key is null or h.setting_key = p_key
  order by h.changed_at desc
  limit least(greatest(coalesce(p_limit,100),1),500);
end;
$$;
revoke all on function public.admin_config_history_list(text,integer) from public;
grant execute on function public.admin_config_history_list(text,integer) to authenticated;

-- Admin controls expected by the mobile app. Do not overwrite existing values.
insert into public.app_settings(key,value) values
  ('maintenance_mode','false'),
  ('maintenance_message','System maintenance is in progress. Please try again later.'),
  ('minimum_app_version','1.0.0'),
  ('latest_app_version','1.0.0'),
  ('force_update','false'),
  ('withdrawals_enabled','true'),
  ('minimum_withdrawal','{"amount":100}'),
  ('maximum_withdrawal','{"amount":50000}'),
  ('daily_withdrawal_limit','{"amount":100000}'),
  ('new_registrations_enabled','true'),
  ('task_system_enabled','true'),
  ('daily_checkin_enabled','true'),
  ('daily_missions_enabled','true'),
  ('referral_system_enabled','true'),
  ('support_enabled','true')
on conflict(key) do nothing;

-- ============================================================
-- 3. Admin read APIs / dashboard
-- ============================================================
create or replace function public.admin_dashboard_metrics()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare r jsonb;
begin
  if not public.admin_can('view') then raise exception 'Admin only'; end if;

  select jsonb_build_object(
    'users',(select count(*) from public.profiles),
    'active_users',(select count(*) from public.profiles where status='active'),
    'blocked_users',(select count(*) from public.profiles where status='blocked'),
    'tasks',(select count(*) from public.tasks),
    'published_tasks',(select count(*) from public.tasks where status='published'),
    'submissions',(select count(*) from public.task_submissions),
    'pending_submissions',(select count(*) from public.task_submissions where status in ('pending','screenshot_submitted')),
    'withdrawals',(select count(*) from public.withdrawals),
    'pending_withdrawals',(select count(*) from public.withdrawals where status in ('pending','processing')),
    'pending_withdrawal_amount',(select coalesce(sum(amount),0) from public.withdrawals where status in ('pending','processing')),
    'total_balance',(select coalesce(sum(balance),0) from public.wallets),
    'total_earned',(select coalesce(sum(total_earned),0) from public.wallets),
    'total_withdrawn',(select coalesce(sum(amount),0) from public.withdrawals where status='paid'),
    'today_users',(select count(*) from public.profiles where created_at>=date_trunc('day',now())),
    'today_submissions',(select count(*) from public.task_submissions where created_at>=date_trunc('day',now())),
    'today_withdrawals',(select coalesce(sum(amount),0) from public.withdrawals where created_at>=date_trunc('day',now())),
    'today_earned',(select coalesce(sum(amount),0) from public.transactions where created_at>=date_trunc('day',now()) and amount>0),
    'week_users',(select count(*) from public.profiles where created_at>=now()-interval '7 days'),
    'week_submissions',(select count(*) from public.task_submissions where created_at>=now()-interval '7 days'),
    'week_withdrawals',(select coalesce(sum(amount),0) from public.withdrawals where created_at>=now()-interval '7 days')
  ) into r;
  return r;
end;
$$;
revoke all on function public.admin_dashboard_metrics() from public;
grant execute on function public.admin_dashboard_metrics() to authenticated;

create or replace function public.admin_task_list()
returns table(
  id uuid,
  title text,
  description text,
  instructions text,
  reward numeric,
  status public.task_status,
  proof_required boolean,
  max_submissions integer,
  created_by uuid,
  created_at timestamptz,
  updated_at timestamptz,
  current_submissions bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_can('view') then raise exception 'Admin only'; end if;
  return query
  select t.id,t.title,t.description,t.instructions,t.reward,t.status,t.proof_required,
         t.max_submissions,t.created_by,t.created_at,t.updated_at,
         (select count(*) from public.task_submissions s where s.task_id=t.id) as current_submissions
  from public.tasks t
  order by t.created_at desc;
end;
$$;
revoke all on function public.admin_task_list() from public;
grant execute on function public.admin_task_list() to authenticated;

create or replace function public.admin_user_snapshot(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare r jsonb;
begin
  if not public.admin_can('view') then raise exception 'Admin only'; end if;
  if not exists(select 1 from public.profiles where id=p_user_id) then raise exception 'User not found'; end if;

  select jsonb_build_object(
    'profile',(select to_jsonb(p) from public.profiles p where p.id=p_user_id),
    'wallet',(select to_jsonb(w) from public.wallets w where w.user_id=p_user_id),
    'transactions',(select coalesce(jsonb_agg(
      case when public.admin_can('finance') then to_jsonb(t)
           else jsonb_set(to_jsonb(t), '{withdrawal_account}', to_jsonb(
             case when nullif(trim(coalesce(t.withdrawal_account,'')),'') is null then null
                  else '••••' || right(t.withdrawal_account,4) end), true)
      end order by t.created_at desc),'[]'::jsonb)
      from (select * from public.transactions where user_id=p_user_id order by created_at desc limit 100) t),
    'submissions',(select coalesce(jsonb_agg(to_jsonb(s) order by s.created_at desc),'[]'::jsonb) from (select * from public.task_submissions where user_id=p_user_id order by created_at desc limit 100) s),
    'withdrawals',(select coalesce(jsonb_agg(
      case when public.admin_can('finance') then to_jsonb(w)
           else jsonb_set(to_jsonb(w), '{account_number}', to_jsonb(
             case when nullif(trim(coalesce(w.account_number,'')),'') is null then null
                  else '••••' || right(w.account_number,4) end), true)
      end order by w.created_at desc),'[]'::jsonb)
      from (select * from public.withdrawals where user_id=p_user_id order by created_at desc limit 100) w),
    'audit',(select coalesce(jsonb_agg(to_jsonb(a) order by a.created_at desc),'[]'::jsonb) from (select * from public.user_activity_audit where user_id=p_user_id order by created_at desc limit 100) a),
    'referrals',(select count(*) from public.referrals where referrer_id=p_user_id),
    'referral_earnings',(select coalesce(sum(amount),0) from public.transactions where user_id=p_user_id and type::text='referral_bonus'),
    'total_withdrawn',(select coalesce(sum(amount),0) from public.withdrawals where user_id=p_user_id and status='paid'),
    'pending_withdrawals',(select count(*) from public.withdrawals where user_id=p_user_id and status in ('pending','processing'))
  ) into r;
  return r;
end;
$$;
revoke all on function public.admin_user_snapshot(uuid) from public;
grant execute on function public.admin_user_snapshot(uuid) to authenticated;

create or replace function public.admin_fraud_flags()
returns table(user_id uuid,flag text,severity text,detail text,detected_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_can('view') then raise exception 'Admin only'; end if;

  return query
  select w.user_id,
         'shared_withdrawal_account',
         'high',
         (select count(distinct w2.user_id)::text from public.withdrawals w2
          where w2.method=w.method and w2.account_number=w.account_number
            and w2.status in ('pending','processing','paid')) ||
         ' users share ' || w.method || ' account ending ' || right(w.account_number,4),
         now()
  from public.withdrawals w
  where w.status in ('pending','processing','paid')
    and nullif(trim(w.account_number),'') is not null
    and (select count(distinct w2.user_id) from public.withdrawals w2
         where w2.method=w.method and w2.account_number=w.account_number
           and w2.status in ('pending','processing','paid')) > 1
  group by w.user_id,w.method,w.account_number

  union all

  select p.id,'duplicate_phone','medium','Phone is used by multiple profiles',now()
  from public.profiles p
  where p.phone is not null and trim(p.phone)<>''
    and (select count(*) from public.profiles p2 where p2.phone=p.phone)>1

  union all

  select s.user_id,'high_submission_volume','medium',count(*)::text || ' submissions in the last 24 hours',now()
  from public.task_submissions s
  where s.created_at>=now()-interval '24 hours'
  group by s.user_id
  having count(*)>=20;
end;
$$;
revoke all on function public.admin_fraud_flags() from public;
grant execute on function public.admin_fraud_flags() to authenticated;

-- ============================================================
-- 4. High-impact admin actions
-- ============================================================
create or replace function public.admin_adjust_wallet(
  p_user_id uuid,
  p_amount numeric,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_old numeric;
begin
  if not public.admin_can('finance') then raise exception 'Finance permission required'; end if;
  if p_amount is null or p_amount=0 then raise exception 'Amount cannot be zero'; end if;
  if length(trim(coalesce(p_reason,'')))<3 then raise exception 'Reason is required'; end if;

  select balance into v_old from public.wallets where user_id=p_user_id for update;
  if not found then raise exception 'Wallet not found'; end if;
  if coalesce(v_old,0)+p_amount<0 then raise exception 'Adjustment would make balance negative'; end if;

  update public.wallets
  set balance=coalesce(balance,0)+p_amount,
      total_earned=case when p_amount>0 then coalesce(total_earned,0)+p_amount else total_earned end,
      updated_at=now()
  where user_id=p_user_id;

  insert into public.transactions(user_id,type,amount,description,status)
  values(p_user_id,'adjustment',p_amount,trim(p_reason),'completed');

  insert into public.user_activity_audit(user_id,actor_id,action,entity_type,entity_id,metadata)
  values(p_user_id,auth.uid(),'admin_balance_adjustment','wallet',p_user_id::text,
         jsonb_build_object('amount',p_amount,'reason',trim(p_reason),'old_balance',v_old,'new_balance',v_old+p_amount));
end;
$$;
revoke all on function public.admin_adjust_wallet(uuid,numeric,text) from public;
grant execute on function public.admin_adjust_wallet(uuid,numeric,text) to authenticated;

create or replace function public.admin_set_user_status(
  p_user_id uuid,
  p_status public.user_status
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_can('user_control') then raise exception 'User control permission required'; end if;
  if p_user_id = auth.uid() and p_status='blocked' then raise exception 'You cannot block your own admin account'; end if;
  if p_status='blocked' and exists(
    select 1 from auth.users u
    where u.id=p_user_id and coalesce(u.raw_app_meta_data->>'role','')='admin'
  ) then
    raise exception 'Root admin accounts are managed through Supabase Auth';
  end if;

  update public.profiles
  set status=p_status,updated_at=now()
  where id=p_user_id;
  if not found then raise exception 'User not found'; end if;

  insert into public.user_activity_audit(user_id,actor_id,action,entity_type,entity_id,metadata)
  values(p_user_id,auth.uid(),'admin_user_status','profile',p_user_id::text,jsonb_build_object('status',p_status::text));
end;
$$;
revoke all on function public.admin_set_user_status(uuid,public.user_status) from public;
grant execute on function public.admin_set_user_status(uuid,public.user_status) to authenticated;

create or replace function public.admin_send_notification(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_type text default 'admin',
  p_data jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare v_count integer:=0;
begin
  if not public.admin_can('support') then raise exception 'Notification permission required'; end if;
  if nullif(trim(coalesce(p_title,'')),'') is null then raise exception 'Title required'; end if;
  if nullif(trim(coalesce(p_body,'')),'') is null then raise exception 'Message required'; end if;

  if p_user_id is null then
    insert into public.notifications(user_id,title,body,message,type,data)
    select id,trim(p_title),trim(p_body),trim(p_body),coalesce(nullif(trim(p_type),''),'admin'),coalesce(p_data,'{}'::jsonb)
    from public.profiles where status='active';
    get diagnostics v_count=row_count;
  else
    if not exists(select 1 from public.profiles where id=p_user_id) then raise exception 'User not found'; end if;
    insert into public.notifications(user_id,title,body,message,type,data)
    values(p_user_id,trim(p_title),trim(p_body),trim(p_body),coalesce(nullif(trim(p_type),''),'admin'),coalesce(p_data,'{}'::jsonb));
    v_count:=1;
  end if;

  insert into public.user_activity_audit(user_id,actor_id,action,entity_type,entity_id,metadata)
  values(coalesce(p_user_id,auth.uid()),auth.uid(),'admin_notification','notification',coalesce(p_user_id,auth.uid())::text,
         jsonb_build_object('recipient_user_id',p_user_id,'count',v_count,'title',p_title));
  return v_count;
end;
$$;
revoke all on function public.admin_send_notification(uuid,text,text,text,jsonb) from public;
grant execute on function public.admin_send_notification(uuid,text,text,text,jsonb) to authenticated;

-- ============================================================
-- 5. Task / submission management
-- ============================================================
create or replace function public.admin_create_task(
  p_title text,p_description text,p_instructions text,p_reward numeric,
  p_max_submissions integer,p_proof_required boolean
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare v_id uuid;
begin
  if not public.admin_can('tasks') then raise exception 'Task management permission required'; end if;
  if nullif(trim(coalesce(p_title,'')),'') is null then raise exception 'Title required'; end if;
  if p_reward is null or p_reward<=0 then raise exception 'Reward must be positive'; end if;
  if p_max_submissions is not null and p_max_submissions<1 then raise exception 'Max submissions must be positive'; end if;

  insert into public.tasks(title,description,instructions,reward,max_submissions,proof_required,status,created_by)
  values(trim(p_title),coalesce(p_description,''),coalesce(p_instructions,''),p_reward,p_max_submissions,coalesce(p_proof_required,true),'published',auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_create_task(text,text,text,numeric,integer,boolean) from public;
grant execute on function public.admin_create_task(text,text,text,numeric,integer,boolean) to authenticated;

create or replace function public.admin_update_task(
  p_task_id uuid,p_title text,p_description text,p_instructions text,p_reward numeric,
  p_max_submissions integer,p_proof_required boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_can('tasks') then raise exception 'Task management permission required'; end if;
  if nullif(trim(coalesce(p_title,'')),'') is null then raise exception 'Title required'; end if;
  if p_reward is null or p_reward<=0 then raise exception 'Reward must be positive'; end if;
  update public.tasks
  set title=trim(p_title),description=coalesce(p_description,''),instructions=coalesce(p_instructions,''),
      reward=p_reward,max_submissions=p_max_submissions,proof_required=coalesce(p_proof_required,true),updated_at=now()
  where id=p_task_id;
  if not found then raise exception 'Task not found'; end if;
end;
$$;
revoke all on function public.admin_update_task(uuid,text,text,text,numeric,integer,boolean) from public;
grant execute on function public.admin_update_task(uuid,text,text,text,numeric,integer,boolean) to authenticated;

create or replace function public.admin_set_task_status(p_task_id uuid,p_status public.task_status)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_can('tasks') then raise exception 'Task management permission required'; end if;
  update public.tasks set status=p_status,updated_at=now() where id=p_task_id;
  if not found then raise exception 'Task not found'; end if;
end;
$$;
revoke all on function public.admin_set_task_status(uuid,public.task_status) from public;
grant execute on function public.admin_set_task_status(uuid,public.task_status) to authenticated;

create or replace function public.admin_approve_submission(p_submission_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_can('tasks') then raise exception 'Task management permission required'; end if;
  update public.task_submissions
  set status='approved',reviewed_by=auth.uid(),reviewed_at=now()
  where id=p_submission_id and status in ('pending','screenshot_submitted');
  if not found then raise exception 'Submission not found or already reviewed'; end if;
  -- The existing trg_reward_approved_task_submission trigger performs the
  -- wallet credit + transaction exactly once when status transitions to approved.
end;
$$;
revoke all on function public.admin_approve_submission(uuid) from public;
grant execute on function public.admin_approve_submission(uuid) to authenticated;

create or replace function public.admin_reject_submission(p_submission_id uuid,p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_can('tasks') then raise exception 'Task management permission required'; end if;
  if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'Rejection reason is required'; end if;

  update public.task_submissions
  set status='rejected',
      rejection_reason=trim(p_reason),
      admin_note=trim(p_reason),
      reviewed_by=auth.uid(),
      reviewed_at=now()
  where id=p_submission_id and status in ('pending','screenshot_submitted');
  if not found then raise exception 'Submission not found or already reviewed'; end if;
end;
$$;
revoke all on function public.admin_reject_submission(uuid,text) from public;
grant execute on function public.admin_reject_submission(uuid,text) to authenticated;

-- ============================================================
-- 6. Promotions / daily missions
-- ============================================================
create or replace function public.admin_create_promotion(
  p_title text,p_description text,p_reward numeric,p_kind text,p_starts_at timestamptz,p_ends_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare v_id uuid;
begin
  if not public.admin_can('tasks') then raise exception 'Promotion management permission required'; end if;
  if nullif(trim(coalesce(p_title,'')),'') is null then raise exception 'Title required'; end if;
  insert into public.promotions(title,description,reward,kind,starts_at,ends_at,is_active,action_label)
  values(trim(p_title),coalesce(p_description,''),greatest(coalesce(p_reward,0),0),coalesce(nullif(trim(p_kind),''),'announcement'),coalesce(p_starts_at,now()),p_ends_at,true,'Claim')
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_create_promotion(text,text,numeric,text,timestamptz,timestamptz) from public;
grant execute on function public.admin_create_promotion(text,text,numeric,text,timestamptz,timestamptz) to authenticated;

create or replace function public.admin_update_promotion(
  p_promotion_id uuid,p_title text,p_description text,p_reward numeric,p_kind text,
  p_starts_at timestamptz,p_ends_at timestamptz,p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_can('tasks') then raise exception 'Promotion management permission required'; end if;
  update public.promotions
  set title=trim(p_title),description=coalesce(p_description,''),reward=greatest(coalesce(p_reward,0),0),
      kind=coalesce(nullif(trim(p_kind),''),kind),starts_at=coalesce(p_starts_at,starts_at),
      ends_at=p_ends_at,is_active=coalesce(p_is_active,is_active),updated_at=now()
  where id=p_promotion_id;
  if not found then raise exception 'Promotion not found'; end if;
end;
$$;
revoke all on function public.admin_update_promotion(uuid,text,text,numeric,text,timestamptz,timestamptz,boolean) from public;
grant execute on function public.admin_update_promotion(uuid,text,text,numeric,text,timestamptz,timestamptz,boolean) to authenticated;

create or replace function public.admin_set_promotion_status(p_promotion_id uuid,p_is_active boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_can('tasks') then raise exception 'Promotion management permission required'; end if;
  update public.promotions set is_active=p_is_active,updated_at=now() where id=p_promotion_id;
  if not found then raise exception 'Promotion not found'; end if;
end;
$$;
revoke all on function public.admin_set_promotion_status(uuid,boolean) from public;
grant execute on function public.admin_set_promotion_status(uuid,boolean) to authenticated;

create or replace function public.admin_create_daily_mission(
  p_title text,p_description text,p_reward numeric,p_target_tasks integer
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare v_id uuid;
begin
  if not public.admin_can('tasks') then raise exception 'Mission management permission required'; end if;
  if nullif(trim(coalesce(p_title,'')),'') is null then raise exception 'Title required'; end if;
  insert into public.daily_missions(title,description,reward,target_tasks,is_active)
  values(trim(p_title),coalesce(p_description,''),greatest(coalesce(p_reward,0),0),greatest(coalesce(p_target_tasks,1),1),true)
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_create_daily_mission(text,text,numeric,integer) from public;
grant execute on function public.admin_create_daily_mission(text,text,numeric,integer) to authenticated;

create or replace function public.admin_update_daily_mission(
  p_mission_id uuid,p_title text,p_description text,p_reward numeric,p_target_tasks integer,p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_can('tasks') then raise exception 'Mission management permission required'; end if;
  update public.daily_missions
  set title=trim(p_title),description=coalesce(p_description,''),reward=greatest(coalesce(p_reward,0),0),
      target_tasks=greatest(coalesce(p_target_tasks,1),1),is_active=coalesce(p_is_active,is_active),updated_at=now()
  where id=p_mission_id;
  if not found then raise exception 'Mission not found'; end if;
end;
$$;
revoke all on function public.admin_update_daily_mission(uuid,text,text,numeric,integer,boolean) from public;
grant execute on function public.admin_update_daily_mission(uuid,text,text,numeric,integer,boolean) to authenticated;

create or replace function public.admin_set_daily_mission_status(p_mission_id uuid,p_is_active boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_can('tasks') then raise exception 'Mission management permission required'; end if;
  update public.daily_missions set is_active=p_is_active,updated_at=now() where id=p_mission_id;
  if not found then raise exception 'Mission not found'; end if;
end;
$$;
revoke all on function public.admin_set_daily_mission_status(uuid,boolean) from public;
grant execute on function public.admin_set_daily_mission_status(uuid,boolean) to authenticated;

-- ============================================================
-- 7. Reports / health
-- ============================================================
create or replace function public.admin_financial_report(
  p_from timestamptz default now()-interval '30 days',
  p_to timestamptz default now()
)
returns table(
  day date,
  new_users bigint,
  earned numeric,
  withdrawal_requested numeric,
  withdrawal_paid numeric,
  withdrawal_reversed numeric,
  task_rewards numeric,
  checkin_rewards numeric,
  mission_rewards numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_can('finance') and not public.admin_can('view') then
    raise exception 'Finance permission required';
  end if;
  if p_from is null or p_to is null or p_from > p_to then
    raise exception 'Invalid report range';
  end if;

  return query
  with days as (
    select generate_series(date_trunc('day',p_from),date_trunc('day',p_to),'1 day')::date as day
  ),
  u as (
    select created_at::date as day,count(*)::bigint as n
    from public.profiles
    where created_at between p_from and p_to
    group by 1
  ),
  tx as (
    select
      created_at::date as day,
      coalesce(sum(case when amount>0 then amount else 0 end),0) as earned,
      coalesce(sum(case when type::text='withdrawal' then abs(amount) else 0 end),0) as withdrawal_requested,
      coalesce(sum(case when type::text='withdrawal_reversal' then amount else 0 end),0) as withdrawal_reversed,
      coalesce(sum(case when type::text='task_reward' and amount>0 then amount else 0 end),0) as task_rewards,
      coalesce(sum(case when lower(coalesce(description,'')) like '%check-in%' and amount>0 then amount else 0 end),0) as checkin_rewards,
      coalesce(sum(case when lower(coalesce(description,'')) like '%mission%' and amount>0 then amount else 0 end),0) as mission_rewards
    from public.transactions
    where created_at between p_from and p_to
    group by 1
  ),
  wd as (
    select processed_at::date as day,
           coalesce(sum(amount) filter(where status='paid'),0) as withdrawal_paid
    from public.withdrawals
    where processed_at between p_from and p_to
    group by 1
  )
  select d.day,
         coalesce(u.n,0),
         coalesce(tx.earned,0),
         coalesce(tx.withdrawal_requested,0),
         coalesce(wd.withdrawal_paid,0),
         coalesce(tx.withdrawal_reversed,0),
         coalesce(tx.task_rewards,0),
         coalesce(tx.checkin_rewards,0),
         coalesce(tx.mission_rewards,0)
  from days d
  left join u using(day)
  left join tx using(day)
  left join wd using(day)
  order by d.day desc;
end;
$$;
revoke all on function public.admin_financial_report(timestamptz,timestamptz) from public;
grant execute on function public.admin_financial_report(timestamptz,timestamptz) to authenticated;

create or replace function public.admin_system_health()
returns table(check_name text,ok boolean,detail text,checked_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare v_count bigint;
v_realtime boolean;
begin
  if not public.admin_can('view') then raise exception 'Admin permission required'; end if;

  return query select 'database'::text,true,'Supabase query path is responding'::text,now();

  select count(*) into v_count from public.profiles;
  return query select 'profiles'::text,true,format('%s profiles accessible to Admin',v_count),now();

  select count(*) into v_count from public.wallets;
  return query select 'wallets'::text,true,format('%s wallet rows accessible to Admin',v_count),now();

  select count(*) into v_count from public.app_settings;
  return query select 'app_settings'::text,(v_count>0),format('%s settings present',v_count),now();

  select exists(
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='notifications'
  ) into v_realtime;
  return query select 'realtime_notifications'::text,v_realtime,
    case when v_realtime then 'notifications is in supabase_realtime' else 'notifications is not in supabase_realtime' end,now();
end;
$$;
revoke all on function public.admin_system_health() from public;
grant execute on function public.admin_system_health() to authenticated;

-- ============================================================
-- 8. Support / withdrawal actions
-- ============================================================
create or replace function public.admin_send_support_message(p_conversation_id uuid,p_message text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare v_id uuid;
begin
  if not public.admin_can('support') then raise exception 'Support permission required'; end if;
  if length(trim(coalesce(p_message,'')))<1 then raise exception 'Message required'; end if;
  if not exists(select 1 from public.support_conversations where id=p_conversation_id) then raise exception 'Conversation not found'; end if;
  if exists(select 1 from public.support_conversations where id=p_conversation_id and status='resolved') then raise exception 'Conversation is closed'; end if;

  insert into public.support_messages(conversation_id,sender_id,sender_type,message,is_read)
  values(p_conversation_id,auth.uid(),'admin',trim(p_message),false)
  returning id into v_id;

  update public.support_conversations
  set status='human_active',
      updated_at=now(),
      last_message=trim(p_message),
      last_message_at=now(),
      admin_unread_count=0,
      user_unread_count=coalesce(user_unread_count,0)+1
  where id=p_conversation_id;

  update public.support_ai_sessions
  set status='human_active',handoff_reason=null
  where conversation_id=p_conversation_id;

  return v_id;
end;
$$;
revoke all on function public.admin_send_support_message(uuid,text) from public;
grant execute on function public.admin_send_support_message(uuid,text) to authenticated;

-- Add the AI handoff metadata used by the Edge Function only when absent.
alter table public.support_ai_sessions add column if not exists handoff_reason text;
alter table public.support_ai_sessions add column if not exists updated_at timestamptz not null default now();

-- Existing support conversation/messages RLS was overly broad in the live snapshot.
-- Keep users on their own conversations and admins on support operations.
drop policy if exists "Enable all access for support_messages" on public.support_messages;
drop policy if exists "Users can view own support messages" on public.support_messages;
drop policy if exists support_messages_admin_select on public.support_messages;
create policy support_messages_own_select on public.support_messages
  for select to authenticated
  using (exists(select 1 from public.support_conversations c where c.id=conversation_id and c.user_id=auth.uid()) or public.admin_can('support'));
create policy support_messages_admin_manage on public.support_messages
  for all to authenticated
  using (public.admin_can('support'))
  with check (public.admin_can('support'));

-- Admins can inspect conversations and AI state; users retain their own access.
drop policy if exists support_conversations_admin_select on public.support_conversations;
create policy support_conversations_admin_select on public.support_conversations
  for select to authenticated
  using (user_id=auth.uid() or public.admin_can('support'));

drop policy if exists support_ai_sessions_admin_select on public.support_ai_sessions;
create policy support_ai_sessions_admin_select on public.support_ai_sessions
  for select to authenticated
  using (user_id=auth.uid() or public.admin_can('support'));

grant select on public.support_ai_sessions to authenticated;

create or replace function public.admin_support_conversations()
returns table(
  conversation_id uuid,
  user_id uuid,
  full_name text,
  email text,
  status text,
  ai_status text,
  admin_unread_count integer,
  user_unread_count integer,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.admin_can('support') then raise exception 'Support permission required'; end if;
  return query
  select c.id,c.user_id,p.full_name,u.email::text,c.status,coalesce(ai.status,'ai_active'),
         coalesce(c.admin_unread_count,0),coalesce(c.user_unread_count,0),c.created_at,c.updated_at
  from public.support_conversations c
  join public.profiles p on p.id=c.user_id
  join auth.users u on u.id=c.user_id
  left join public.support_ai_sessions ai on ai.conversation_id=c.id
  order by c.updated_at desc;
end;
$$;
revoke all on function public.admin_support_conversations() from public;
grant execute on function public.admin_support_conversations() to authenticated;

create or replace function public.admin_close_support_conversation(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_can('support') then raise exception 'Support permission required'; end if;
  update public.support_conversations
    set status='resolved',updated_at=now(),admin_unread_count=0
    where id=p_conversation_id;
  if not found then raise exception 'Conversation not found'; end if;
  update public.support_ai_sessions set status='resolved',updated_at=now() where conversation_id=p_conversation_id;
  insert into public.user_activity_audit(user_id,actor_id,action,entity_type,entity_id,metadata)
    select user_id,auth.uid(),'admin_support_closed','support_conversation',id,
           jsonb_build_object('status','resolved')
    from public.support_conversations where id=p_conversation_id;
end;
$$;
revoke all on function public.admin_close_support_conversation(uuid) from public;
grant execute on function public.admin_close_support_conversation(uuid) to authenticated;

create or replace function public.admin_process_withdrawal(
  p_withdrawal_id uuid,
  p_status public.withdrawal_status,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  w public.withdrawals%rowtype;
  v_tx uuid;
begin
  if not public.admin_can('finance') then raise exception 'Finance permission required'; end if;
  if p_status not in ('processing','paid','rejected','cancelled') then raise exception 'Invalid withdrawal status'; end if;

  select * into w
  from public.withdrawals
  where id=p_withdrawal_id
  for update;

  if not found then raise exception 'Withdrawal not found'; end if;
  if w.status not in ('pending','processing') then raise exception 'Withdrawal already finalized'; end if;

  update public.withdrawals
  set status=p_status,
      note=p_note,
      processed_by=auth.uid(),
      processed_at=now()
  where id=p_withdrawal_id;

  if p_status in ('rejected','cancelled') then
    update public.wallets
    set balance=coalesce(balance,0)+w.amount,
        updated_at=now()
    where user_id=w.user_id;

    insert into public.transactions(user_id,type,amount,reference_id,description,status,withdrawal_method,withdrawal_account)
    values(w.user_id,'withdrawal_reversal',w.amount,w.id,'Withdrawal returned',p_status::text,w.method,w.account_number);
  end if;

  update public.transactions
  set status = case when p_status='paid' then 'completed' else p_status::text end,
      description = coalesce(description,'Withdrawal request') ||
                    case when p_note is null or trim(p_note)='' then '' else ' · '||trim(p_note) end
  where reference_id=w.id
    and type::text='withdrawal';

  insert into public.notifications(user_id,title,message,body,type,data)
  values(
    w.user_id,
    case when p_status='paid' then 'Withdrawal paid'
         when p_status in ('rejected','cancelled') then 'Withdrawal update'
         else 'Withdrawal processing' end,
    case when p_status='paid' then 'Your withdrawal of ৳' || to_char(w.amount,'FM999999990.00') || ' has been marked as paid.'
         when p_status='rejected' then 'Your withdrawal of ৳' || to_char(w.amount,'FM999999990.00') || ' was rejected and the amount was returned to your wallet.'
         when p_status='cancelled' then 'Your withdrawal of ৳' || to_char(w.amount,'FM999999990.00') || ' was cancelled and the amount was returned to your wallet.'
         else 'Your withdrawal of ৳' || to_char(w.amount,'FM999999990.00') || ' is being processed.' end,
    case when p_status='paid' then 'Your withdrawal of ৳' || to_char(w.amount,'FM999999990.00') || ' has been marked as paid.'
         when p_status='rejected' then 'Your withdrawal of ৳' || to_char(w.amount,'FM999999990.00') || ' was rejected and the amount was returned to your wallet.'
         when p_status='cancelled' then 'Your withdrawal of ৳' || to_char(w.amount,'FM999999990.00') || ' was cancelled and the amount was returned to your wallet.'
         else 'Your withdrawal of ৳' || to_char(w.amount,'FM999999990.00') || ' is being processed.' end,
    'withdrawal',
    jsonb_build_object('withdrawal_id',w.id,'status',p_status::text,'amount',w.amount)
  );

  insert into public.user_activity_audit(user_id,actor_id,action,entity_type,entity_id,metadata)
  values(w.user_id,auth.uid(),'admin_withdrawal_status','withdrawal',w.id::text,
         jsonb_build_object('status',p_status::text,'amount',w.amount,'note',p_note));
end;
$$;
revoke all on function public.admin_process_withdrawal(uuid,public.withdrawal_status,text) from public;
grant execute on function public.admin_process_withdrawal(uuid,public.withdrawal_status,text) to authenticated;

-- ============================================================
-- 9. Audit actor support
-- ============================================================
alter table public.user_activity_audit
  add column if not exists actor_id uuid references auth.users(id) on delete set null;

create index if not exists idx_user_activity_audit_created
  on public.user_activity_audit(created_at desc);
create index if not exists idx_user_activity_audit_actor_created
  on public.user_activity_audit(actor_id,created_at desc);

-- Existing own-user audit policy plus admin read access.
drop policy if exists user_activity_audit_admin_select on public.user_activity_audit;
create policy user_activity_audit_admin_select on public.user_activity_audit
  for select to authenticated
  using (public.admin_can('view'));

grant select on public.user_activity_audit to authenticated;

-- ============================================================
-- 10. RLS alignment for Admin Panel reads/writes
-- ============================================================
-- Tasks: task managers can manage; users can still read published tasks.
drop policy if exists "Admins manage tasks" on public.tasks;
drop policy if exists "admin can manage tasks" on public.tasks;
drop policy if exists tasks_admin_insert on public.tasks;
drop policy if exists tasks_admin_update on public.tasks;
drop policy if exists tasks_admin_delete on public.tasks;
create policy tasks_admin_manage on public.tasks
  for all to authenticated
  using (public.admin_can('tasks'))
  with check (public.admin_can('tasks'));

-- Submissions: users see their own; task managers see/manage all.
drop policy if exists "Admins manage submissions" on public.task_submissions;
drop policy if exists "Allow select for all" on public.task_submissions;
drop policy if exists "Users view own submissions" on public.task_submissions;
create policy task_submissions_own_select on public.task_submissions
  for select to authenticated
  using (user_id=auth.uid() or public.admin_can('tasks'));
create policy task_submissions_admin_update on public.task_submissions
  for update to authenticated
  using (public.admin_can('tasks'))
  with check (public.admin_can('tasks'));

-- Financial data: remove public SELECT exposure; keep own-user + finance/admin reads.
drop policy if exists "Allow select for all" on public.transactions;
create policy transactions_own_or_admin_select on public.transactions
  for select to authenticated
  using (user_id=auth.uid() or public.admin_can('finance') or public.admin_can('view'));

drop policy if exists "Allow select for all" on public.withdrawals;
create policy withdrawals_own_or_admin_select on public.withdrawals
  for select to authenticated
  using (user_id=auth.uid() or public.admin_can('finance') or public.admin_can('view'));

-- Wallets already had an admin-aware SELECT policy in the live schema; add an
-- explicit role-aware policy so role admins work consistently.
drop policy if exists wallets_admin_select on public.wallets;
create policy wallets_admin_select on public.wallets
  for select to authenticated
  using (user_id=auth.uid() or public.admin_can('view'));

-- Admin reads for growth/operations tables.
drop policy if exists promotions_admin_select on public.promotions;
create policy promotions_admin_select on public.promotions
  for select to authenticated
  using (public.admin_can('view'));

drop policy if exists daily_missions_admin_select on public.daily_missions;
create policy daily_missions_admin_select on public.daily_missions
  for select to authenticated
  using (public.admin_can('view'));

drop policy if exists notifications_admin_select on public.notifications;
create policy notifications_admin_select on public.notifications
  for select to authenticated
  using (user_id=auth.uid() or public.admin_can('view'));

-- ============================================================
-- 10B. Support state model: AI -> human_requested -> human_active -> resolved
-- ============================================================
do $$
declare c record;
begin
  update public.support_conversations set status='human_requested' where status='admin_handoff';
  update public.support_ai_sessions set status='human_requested' where status='admin_handoff';
  for c in select conname from pg_constraint
           where conrelid='public.support_ai_sessions'::regclass and contype='c'
             and pg_get_constraintdef(oid) ilike '%status%' loop
    execute format('alter table public.support_ai_sessions drop constraint %I',c.conname);
  end loop;
  alter table public.support_ai_sessions add constraint support_ai_sessions_status_check
    check (status in ('ai_active','human_requested','human_active','resolved'));
exception when undefined_table then
  null;
end $$;

create or replace function public.get_or_create_support_chat()
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_enabled boolean:=true;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  select coalesce((value)::text,'true')::boolean into v_enabled from public.app_settings where key='support_enabled';
  if coalesce(v_enabled,true)=false then raise exception 'Support is temporarily disabled'; end if;
  select id into v_id from public.support_conversations where user_id=auth.uid() limit 1;
  if v_id is null then
    insert into public.support_conversations(user_id,status) values(auth.uid(),'open') returning id into v_id;
  elsif exists(select 1 from public.support_conversations where id=v_id and status='resolved') then
    update public.support_conversations set status='open',updated_at=now(),admin_unread_count=0,user_unread_count=0 where id=v_id;
    update public.support_ai_sessions set status='ai_active',handoff_reason=null,updated_at=now() where conversation_id=v_id;
  end if;
  insert into public.support_ai_sessions(conversation_id,user_id,status,updated_at) values(v_id,auth.uid(),'ai_active',now()) on conflict(conversation_id) do nothing;
  return v_id;
end; $$;
revoke all on function public.get_or_create_support_chat() from public;
grant execute on function public.get_or_create_support_chat() to authenticated;

-- ============================================================
-- 11. User feature-control backend enforcement
-- ============================================================
-- These guards complement the mobile UI while preserving the live business
-- RPC behavior captured in ZENEXPAY_DATABASE_MAP.md.
CREATE OR REPLACE FUNCTION public.submit_task(p_task_id uuid, p_proof_text text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user uuid := auth.uid();
  v_task public.tasks%rowtype;
  v_submission_id uuid;
  v_status text;
begin
  if v_user is null then
    raise exception using message = 'Not authenticated';
  end if;
  if not exists(select 1 from public.profiles where id=v_user and status='active') then
    raise exception using message = 'Account is blocked';
  end if;
  if coalesce((select (value)::text::boolean from public.app_settings where key='task_system_enabled'),true)=false then
    raise exception using message = 'Task system is temporarily disabled';
  end if;

  select * into v_task
  from public.tasks
  where id = p_task_id
    and lower(coalesce(status, '')) = 'published'
  for share;

  if not found then
    raise exception using message = 'Task is no longer available';
  end if;

  select lower(coalesce(status::text, 'pending'))
  into v_status
  from public.task_submissions
  where user_id = v_user
    and task_id = p_task_id
    and lower(coalesce(status::text, 'pending')) in
        ('pending','screenshot_requested','screenshot_submitted','approved')
  order by created_at desc
  limit 1;

  if v_status is not null then
    if v_status = 'approved' then
      raise exception using message = 'This task has already been completed and paid.';
    elsif v_status = 'screenshot_requested' then
      raise exception using message = 'A screenshot was requested for your existing submission. Please upload it from My Submissions.';
    elsif v_status = 'screenshot_submitted' then
      raise exception using message = 'Your screenshot is already under review. Please wait for the reviewer.';
    else
      raise exception using message = 'This task is already pending review. You cannot submit it again until the current review is finished.';
    end if;
  end if;

  insert into public.task_submissions (
    user_id,
    task_id,
    status,
    proof_text,
    created_at,
    updated_at
  ) values (
    v_user,
    p_task_id,
    'pending',
    nullif(trim(p_proof_text), ''),
    now(),
    now()
  )
  returning id into v_submission_id;

  return v_submission_id;
exception
  when unique_violation then
    raise exception using message = 'This task is already pending review. You cannot submit it again yet.';
end;
$function$;
revoke all on function public.submit_task(uuid,text) from public;
grant execute on function public.submit_task(uuid,text) to authenticated;

CREATE OR REPLACE FUNCTION public.claim_daily_checkin()
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user uuid;
  v_today date;
  v_yesterday date;

  v_prev_streak integer;
  v_streak integer;

  v_reward numeric(12,2);
  v_checkin_id uuid;
BEGIN

  -- Logged-in user
  v_user := auth.uid();

  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id=v_user AND status='active') THEN
    RAISE EXCEPTION 'Account is blocked';
  END IF;
  IF COALESCE((SELECT (value)::text::boolean FROM public.app_settings WHERE key='daily_checkin_enabled'),true)=false THEN
    RAISE EXCEPTION 'Daily check-in is temporarily disabled';
  END IF;

  -- Dhaka date
  v_today := (now() AT TIME ZONE 'Asia/Dhaka')::date;
  v_yesterday := v_today - 1;


  -- =======================================================
  -- REWARD
  -- =======================================================

  SELECT checkin_reward
  INTO v_reward
  FROM public.daily_feature_settings
  WHERE id = true;

  v_reward := COALESCE(v_reward, 20);


  -- =======================================================
  -- WALLET
  -- Create wallet if older account does not have one
  -- =======================================================

  INSERT INTO public.wallets(user_id)
  VALUES (v_user)
  ON CONFLICT (user_id) DO NOTHING;


  -- Lock wallet for this transaction
  PERFORM 1
  FROM public.wallets
  WHERE user_id = v_user
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wallet not found';
  END IF;


  -- =======================================================
  -- PREVENT DOUBLE CLAIM
  -- =======================================================

  IF EXISTS
  (
    SELECT 1
    FROM public.daily_checkins
    WHERE user_id = v_user
      AND checkin_date = v_today
  )
  THEN
    RAISE EXCEPTION 'Daily check-in already claimed today';
  END IF;


  -- =======================================================
  -- STREAK
  -- =======================================================

  SELECT streak
  INTO v_prev_streak
  FROM public.daily_checkins
  WHERE user_id = v_user
    AND checkin_date = v_yesterday;

  v_streak :=
    CASE
      WHEN v_prev_streak IS NULL THEN 1
      ELSE v_prev_streak + 1
    END;


  -- =======================================================
  -- WALLET CREDIT
  -- =======================================================

  UPDATE public.wallets
  SET
    balance = COALESCE(balance, 0) + v_reward,
    total_earned = COALESCE(total_earned, 0) + v_reward,
    updated_at = now()
  WHERE user_id = v_user;


  -- =======================================================
  -- TRANSACTION
  -- =======================================================

  IF EXISTS
  (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'transactions'
      AND column_name = 'status'
  )
  THEN

    INSERT INTO public.transactions
    (
      user_id,
      type,
      amount,
      description,
      status,
      created_at
    )
    VALUES
    (
      v_user,
      'daily_checkin_bonus'::public.transaction_type,
      v_reward,
      'Daily check-in bonus',
      'completed',
      now()
    );

  ELSE

    INSERT INTO public.transactions
    (
      user_id,
      type,
      amount,
      description,
      created_at
    )
    VALUES
    (
      v_user,
      'daily_checkin_bonus'::public.transaction_type,
      v_reward,
      'Daily check-in bonus',
      now()
    );

  END IF;


  -- =======================================================
  -- DAILY CHECK-IN RECORD
  -- =======================================================

  INSERT INTO public.daily_checkins
  (
    user_id,
    checkin_date,
    streak,
    reward,
    created_at
  )
  VALUES
  (
    v_user,
    v_today,
    v_streak,
    v_reward,
    now()
  )
  RETURNING id INTO v_checkin_id;


  -- =======================================================
  -- RETURN
  -- =======================================================

  RETURN v_checkin_id;


EXCEPTION

  WHEN unique_violation THEN
    RAISE EXCEPTION 'Daily check-in already claimed today';

END;
$function$;
revoke all on function public.claim_daily_checkin() from public;
grant execute on function public.claim_daily_checkin() to authenticated;

CREATE OR REPLACE FUNCTION public.claim_daily_mission(p_mission_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user uuid := auth.uid();
  v_today date := (now() at time zone 'Asia/Dhaka')::date;
  v_mission public.daily_missions%rowtype;
  v_completed integer;
  v_claim_id uuid;
begin
  if v_user is null then
    raise exception using message = 'Not authenticated';
  end if;
  if not exists(select 1 from public.profiles where id=v_user and status='active') then raise exception 'Account is blocked'; end if;
  if coalesce((select (value)::text::boolean from public.app_settings where key='daily_missions_enabled'),true)=false then raise exception 'Daily missions are temporarily disabled'; end if;

  select * into v_mission
  from public.daily_missions
  where id = p_mission_id
    and is_active = true
    and starts_at <= now()
    and (ends_at is null or ends_at >= now());

  if not found then
    raise exception using message = 'Mission is not active';
  end if;

  if exists (
    select 1 from public.daily_mission_claims
    where mission_id = p_mission_id
      and user_id = v_user
      and claim_date = v_today
  ) then
    raise exception using message = 'Mission already claimed today';
  end if;

  select count(*)::integer into v_completed
  from public.task_submissions
  where user_id = v_user
    and lower(coalesce(status::text, '')) = 'approved'
    and (created_at at time zone 'Asia/Dhaka')::date = v_today;

  if v_completed < v_mission.target_tasks then
    raise exception using message = format(
      'Complete %s approved tasks today first',
      v_mission.target_tasks
    );
  end if;

  perform 1 from public.wallets where user_id = v_user for update;
  if not found then
    raise exception using message = 'Wallet not found';
  end if;

  update public.wallets
  set balance = balance + v_mission.reward,
      total_earned = coalesce(total_earned, 0) + v_mission.reward,
      updated_at = now()
  where user_id = v_user;

  insert into public.transactions (
    user_id, type, amount, description, status, created_at
  ) values (
    v_user, 'daily_mission_reward', v_mission.reward,
    'Daily mission: ' || v_mission.title, 'completed', now()
  );

  insert into public.daily_mission_claims (
    mission_id, user_id, claim_date, reward
  ) values (
    p_mission_id, v_user, v_today, v_mission.reward
  ) returning id into v_claim_id;

  return v_claim_id;
end;
$function$;
revoke all on function public.claim_daily_mission(uuid) from public;
grant execute on function public.claim_daily_mission(uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.validate_referral_code(p_referral_code text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_code text := upper(trim(coalesce(p_referral_code, '')));
begin
  if coalesce((select (value)::text::boolean from public.app_settings where key='referral_system_enabled'),true)=false then return false; end if;
  if v_code = '' then
    return false;
  end if;

  return exists (
    select 1
    from public.profiles
    where upper(trim(referral_code)) = v_code
  );
end;
$function$;
revoke all on function public.validate_referral_code(text) from public;
grant execute on function public.validate_referral_code(text) to authenticated;

CREATE OR REPLACE FUNCTION public.claim_referral(p_referral_code text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user uuid := auth.uid();
  v_code text := upper(trim(coalesce(p_referral_code, '')));
  v_referrer uuid;
  v_referral_id uuid;
begin
  if v_user is null then
    raise exception using message = 'Not authenticated';
  end if;
  if coalesce((select (value)::text::boolean from public.app_settings where key='referral_system_enabled'),true)=false then raise exception 'Referral system is temporarily disabled'; end if;

  if v_code = '' then
    raise exception using message = 'Referral code cannot be empty.';
  end if;

  select id into v_referrer
  from public.profiles
  where upper(trim(referral_code)) = v_code
  limit 1;

  if v_referrer is null then
    raise exception using message = 'Invalid referral code.';
  end if;

  if v_referrer = v_user then
    raise exception using message = 'You cannot use your own referral code.';
  end if;

  if exists (
    select 1 from public.referrals where referred_id = v_user
  ) then
    raise exception using message = 'A referral code has already been applied to this account.';
  end if;

  insert into public.referrals (
    referrer_id, referred_id, referral_code, created_at
  ) values (
    v_referrer, v_user, v_code, now()
  ) returning id into v_referral_id;

  return v_referral_id;
exception
  when unique_violation then
    raise exception using message = 'A referral code has already been applied to this account.';
end;
$function$;
revoke all on function public.claim_referral(text) from public;
grant execute on function public.claim_referral(text) to authenticated;

CREATE OR REPLACE FUNCTION public.create_withdrawal_request(p_amount numeric, p_method_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user uuid := auth.uid();
  v_method public.withdrawal_methods%rowtype;
  v_transaction_id uuid;
begin
  if v_user is null then
    raise exception using message = 'Not authenticated';
  end if;
  if not exists(select 1 from public.profiles where id=v_user and status='active') then raise exception 'Account is blocked'; end if;
  if coalesce((select (value)::text::boolean from public.app_settings where key='withdrawals_enabled'),true)=false then raise exception 'Withdrawals are temporarily disabled'; end if;

  if p_amount is null or p_amount < 100 then
    raise exception using message = 'Minimum withdrawal is 100';
  end if;

  if p_amount > 50000 then
    raise exception using message = 'Maximum withdrawal is 50000';
  end if;

  select * into v_method
  from public.withdrawal_methods
  where id = p_method_id
    and user_id = v_user;

  if not found then
    raise exception using message = 'Withdrawal method not found';
  end if;

  if exists (
    select 1 from public.transactions
    where user_id = v_user
      and type = 'withdrawal'
      and status = 'pending'
  ) then
    raise exception using message = 'A withdrawal request is already pending';
  end if;

  -- This UPDATE locks the user's wallet row and only succeeds when
  -- enough balance exists. If the transaction INSERT later fails,
  -- PostgreSQL rolls the balance update back with the whole function.
  update public.wallets
  set balance = balance - p_amount,
      updated_at = now()
  where user_id = v_user
    and balance >= p_amount;

  if not found then
    raise exception using message = 'Insufficient balance';
  end if;

  insert into public.transactions (
    user_id,
    type,
    amount,
    description,
    status,
    withdrawal_method,
    withdrawal_account,
    created_at
  ) values (
    v_user,
    'withdrawal',
    p_amount,
    'Withdrawal request',
    'pending',
    v_method.method_type,
    v_method.account_number,
    now()
  )
  returning id into v_transaction_id;

  return v_transaction_id;
end;
$function$;
revoke all on function public.create_withdrawal_request(numeric,uuid) from public;
grant execute on function public.create_withdrawal_request(numeric,uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.send_support_message(p_conversation_id uuid, p_message text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_message_id uuid;
  v_user_id uuid;
begin

  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if coalesce((select (value)::text::boolean from public.app_settings where key='support_enabled'),true)=false then raise exception 'Support is temporarily disabled'; end if;

  if trim(coalesce(p_message, '')) = '' then
    raise exception 'Message cannot be empty';
  end if;

  select user_id
  into v_user_id
  from public.support_conversations
  where id = p_conversation_id;

  if v_user_id is null then
    raise exception 'Conversation not found';
  end if;

  if v_user_id <> auth.uid() then
    raise exception 'Access denied';
  end if;
  if exists(select 1 from public.support_conversations where id=p_conversation_id and status='resolved') then raise exception 'This support conversation is closed'; end if;

  insert into public.support_messages (
    conversation_id,
    sender_id,
    sender_type,
    message,
    is_read
  )
  values (
    p_conversation_id,
    auth.uid(),
    'user',
    trim(p_message),
    false
  )
  returning id into v_message_id;

  update public.support_conversations
  set
    last_message = trim(p_message),
    last_message_at = now(),
    admin_unread_count = admin_unread_count + 1,
    status = case when status in ('human_requested','human_active') then status else 'open' end
  where id = p_conversation_id;

  return v_message_id;

end;
$function$;
revoke all on function public.send_support_message(uuid,text) from public;
grant execute on function public.send_support_message(uuid,text) to authenticated;

-- ============================================================
-- 11. Screenshot storage: use the LIVE bucket, not the old bucket name
-- ============================================================
-- The live project has private bucket: task-submissions.
-- Add only a SELECT policy so users/admins can create signed URLs safely.
drop policy if exists "Users read own task screenshots" on storage.objects;
create policy "Users read own task screenshots"
on storage.objects for select to authenticated
using (
  bucket_id='task-submissions'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.admin_can('tasks')
  )
);

-- ============================================================
-- 12. Realtime additions required by the Admin UI
-- ============================================================
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','wallets','tasks','task_submissions','withdrawals','transactions',
    'notifications','support_messages','support_conversations','user_activity_audit','app_settings'
  ] loop
    if to_regclass('public.'||t) is not null
       and not exists(
         select 1 from pg_publication_tables
         where pubname='supabase_realtime'
           and schemaname='public'
           and tablename=t
       ) then
      begin
        execute format('alter publication supabase_realtime add table public.%I',t);
      exception when undefined_object then
        null;
      end;
    end if;
  end loop;
end $$;

notify pgrst, 'reload schema';
commit;
