-- ZenexPay Referral Bonus + Fraud Control V2
-- Run AFTER SUPABASE_REFERRAL_FIX_V1.sql and the existing wallet/transaction migrations.
-- This migration adds:
-- 1) qualified referral status
-- 2) one-time referral bonus, atomically added to referrer's wallet
-- 3) transaction history/detail record for every paid referral
-- 4) basic fraud controls (self-referral + same-phone detection)
-- 5) successful-referral count = QUALIFIED referrals only
-- 6) Admin-ready referral bonus settings (for the future Admin Panel)
-- 7) automatic qualification when the referred user gets the first approved task

begin;

-- ---------------------------------------------------------
-- 1. Admin-ready referral settings
-- ---------------------------------------------------------
create table if not exists public.referral_settings (
  id boolean primary key default true check (id = true),
  enabled boolean not null default true,
  bonus_amount numeric(12,2) not null default 50 check (bonus_amount >= 0),
  min_approved_tasks integer not null default 1 check (min_approved_tasks >= 1),
  updated_at timestamptz not null default now()
);

insert into public.referral_settings (id, enabled, bonus_amount, min_approved_tasks)
values (true, true, 50, 1)
on conflict (id) do nothing;

alter table public.referral_settings enable row level security;
drop policy if exists "referral_settings_select_authenticated" on public.referral_settings;
create policy "referral_settings_select_authenticated"
  on public.referral_settings for select to authenticated using (true);
grant select on public.referral_settings to authenticated;
revoke insert, update, delete on public.referral_settings from anon, authenticated;

-- ---------------------------------------------------------
-- 2. Referral status / fraud / bonus audit fields
-- ---------------------------------------------------------
alter table public.referrals
  add column if not exists status text not null default 'pending',
  add column if not exists risk_score integer not null default 0,
  add column if not exists fraud_reason text,
  add column if not exists qualified_at timestamptz,
  add column if not exists bonus_amount numeric(12,2) not null default 0,
  add column if not exists updated_at timestamptz not null default now();

-- Existing referrals are pending until they meet the qualification rule.
update public.referrals
set status = 'pending'
where status is null or status not in ('pending','qualified','rejected');

-- ---------------------------------------------------------
-- 3. Link referral bonus transactions to the exact referral
-- ---------------------------------------------------------
alter table public.transactions
  add column if not exists referral_id uuid references public.referrals(id) on delete set null;

create unique index if not exists transactions_one_referral_bonus_per_referral
  on public.transactions(referral_id)
  where type = 'referral_bonus' and referral_id is not null;

create index if not exists referrals_status_referrer_idx
  on public.referrals(referrer_id, status);

-- ---------------------------------------------------------
-- 4. Fraud/qualification helper
-- ---------------------------------------------------------
create or replace function public.qualify_referral(p_referral_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ref public.referrals%rowtype;
  v_setting public.referral_settings%rowtype;
  v_referrer_phone text;
  v_referred_phone text;
  v_approved integer;
  v_risk integer := 0;
  v_reason text := null;
  v_wallet_exists boolean;
  v_tx_id uuid;
begin
  select * into v_ref
  from public.referrals
  where id = p_referral_id
  for update;

  if not found then
    return null;
  end if;

  if v_ref.status = 'qualified' then
    return p_referral_id;
  end if;

  if v_ref.status = 'rejected' then
    return null;
  end if;

  select * into v_setting
  from public.referral_settings
  where id = true;

  if not found or not v_setting.enabled or v_setting.bonus_amount <= 0 then
    return null;
  end if;

  -- Qualification requires real earning activity from the referred user.
  select count(*)::integer into v_approved
  from public.task_submissions
  where user_id = v_ref.referred_id
    and lower(coalesce(status, '')) = 'approved';

  if v_approved < v_setting.min_approved_tasks then
    return null;
  end if;

  -- Basic fraud control: the same phone cannot be used to qualify a referral.
  -- This catches a common self-referral pattern while avoiding unreliable
  -- client-side IP/device checks.
  begin
    select nullif(regexp_replace(coalesce(phone, ''), '\D', '', 'g'), '')
      into v_referrer_phone
    from public.profiles where id = v_ref.referrer_id;

    select nullif(regexp_replace(coalesce(phone, ''), '\D', '', 'g'), '')
      into v_referred_phone
    from public.profiles where id = v_ref.referred_id;
  exception when undefined_column then
    v_referrer_phone := null;
    v_referred_phone := null;
  end;

  if v_referrer_phone is not null
     and v_referred_phone is not null
     and v_referrer_phone = v_referred_phone then
    v_risk := 100;
    v_reason := 'Same phone number as referrer';
  end if;

  if v_risk >= 100 then
    update public.referrals
    set status = 'rejected',
        risk_score = v_risk,
        fraud_reason = v_reason,
        updated_at = now()
    where id = p_referral_id;
    return null;
  end if;

  -- Lock the referrer's wallet. The wallet credit and transaction are in
  -- the same PostgreSQL transaction, so they cannot partially succeed.
  select exists(
    select 1 from public.wallets where user_id = v_ref.referrer_id
  ) into v_wallet_exists;

  if not v_wallet_exists then
    raise exception using message = 'Referrer wallet not found';
  end if;

  perform 1 from public.wallets
  where user_id = v_ref.referrer_id
  for update;

  -- Update referral first; the unique transaction index prevents duplicates.
  update public.referrals
  set status = 'qualified',
      risk_score = 0,
      fraud_reason = null,
      qualified_at = now(),
      bonus_amount = v_setting.bonus_amount
  where id = p_referral_id
    and status = 'pending';

  if not found then
    return null;
  end if;

  update public.wallets
  set balance = balance + v_setting.bonus_amount,
      total_earned = coalesce(total_earned, 0) + v_setting.bonus_amount,
      updated_at = now()
  where user_id = v_ref.referrer_id;

  insert into public.transactions (
    user_id, type, amount, description, status, referral_id, created_at
  ) values (
    v_ref.referrer_id,
    'referral_bonus',
    v_setting.bonus_amount,
    'Referral bonus - successful referral',
    'completed',
    p_referral_id,
    now()
  ) returning id into v_tx_id;

  return p_referral_id;
end;
$$;

revoke all on function public.qualify_referral(uuid) from public;
grant execute on function public.qualify_referral(uuid) to authenticated;

-- ---------------------------------------------------------
-- 5. Automatic qualification after an approved task
-- ---------------------------------------------------------
create or replace function public.handle_referral_task_qualification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_referral_id uuid;
begin
  if lower(coalesce(new.status, '')) <> 'approved' then
    return new;
  end if;

  select id into v_referral_id
  from public.referrals
  where referred_id = new.user_id
    and status = 'pending'
  order by created_at asc
  limit 1;

  if v_referral_id is not null then
    perform public.qualify_referral(v_referral_id);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_referral_task_qualification on public.task_submissions;
create trigger trg_referral_task_qualification
after insert or update of status on public.task_submissions
for each row execute function public.handle_referral_task_qualification();

-- ---------------------------------------------------------
-- 6. Successful count + current reward for the Referral page
-- ---------------------------------------------------------
create or replace function public.get_my_referral_info()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_code text;
  v_count integer;
  v_reward numeric(12,2);
begin
  if v_user is null then
    raise exception using message = 'Not authenticated';
  end if;

  select referral_code into v_code
  from public.profiles
  where id = v_user;

  if v_code is null or trim(v_code) = '' then
    v_code := public.generate_referral_code(v_user);
    update public.profiles set referral_code = v_code where id = v_user;
  end if;

  select count(*)::integer into v_count
  from public.referrals
  where referrer_id = v_user
    and status = 'qualified';

  select bonus_amount into v_reward
  from public.referral_settings
  where id = true;

  return jsonb_build_object(
    'code', v_code,
    'successful_referrals', coalesce(v_count, 0),
    'reward', coalesce(v_reward, 0)
  );
end;
$$;

revoke all on function public.get_my_referral_info() from public;
grant execute on function public.get_my_referral_info() to authenticated;

-- ---------------------------------------------------------
-- 7. One-time backfill for already-created referrals that
--    already have enough approved tasks.
--    Fraud checks still apply; no duplicate bonus is possible.
-- ---------------------------------------------------------
do $$
declare
  r record;
begin
  for r in
    select id
    from public.referrals
    where status = 'pending'
  loop
    perform public.qualify_referral(r.id);
  end loop;
end $$;

notify pgrst, 'reload schema';
commit;
