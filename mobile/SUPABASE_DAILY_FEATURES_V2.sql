-- ZenexPay Daily Features V2
-- Run this AFTER the earlier Daily Activity SQL was already run.
-- This migration makes Daily Check-in reward admin-controlled and adds
-- database-backed Daily Goal, Daily Missions, Rewards/Promotions and Profile editing.

begin;

create extension if not exists pgcrypto;

-- =========================================================
-- 1) ADMIN-CONTROLLED DAILY SETTINGS
-- =========================================================
create table if not exists public.daily_feature_settings (
  id boolean primary key default true check (id = true),
  checkin_reward numeric(12,2) not null default 20 check (checkin_reward >= 0),
  daily_goal_target integer not null default 3 check (daily_goal_target > 0),
  updated_at timestamptz not null default now()
);

insert into public.daily_feature_settings (id, checkin_reward, daily_goal_target)
values (true, 20, 3)
on conflict (id) do nothing;

-- Admin/service role can change this row. Normal users can only read it.
alter table public.daily_feature_settings enable row level security;
drop policy if exists "daily_feature_settings_select_authenticated" on public.daily_feature_settings;
create policy "daily_feature_settings_select_authenticated"
  on public.daily_feature_settings for select
  to authenticated using (true);
revoke insert, update, delete on public.daily_feature_settings from anon, authenticated;
grant select on public.daily_feature_settings to authenticated;

-- =========================================================
-- 2) DAILY CHECK-IN: replace fixed ৳20 with current setting
-- =========================================================
create or replace function public.claim_daily_checkin()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_today date := (now() at time zone 'Asia/Dhaka')::date;
  v_yesterday date := v_today - 1;
  v_prev_streak integer;
  v_streak integer;
  v_reward numeric(12,2);
  v_checkin_id uuid;
begin
  if v_user is null then
    raise exception using message = 'Not authenticated';
  end if;

  select checkin_reward into v_reward
  from public.daily_feature_settings
  where id = true;

  v_reward := coalesce(v_reward, 20);

  if exists (
    select 1 from public.daily_checkins
    where user_id = v_user and checkin_date = v_today
  ) then
    raise exception using message = 'Daily check-in already claimed today';
  end if;

  select streak into v_prev_streak
  from public.daily_checkins
  where user_id = v_user and checkin_date = v_yesterday;

  v_streak := case when v_prev_streak is null then 1 else v_prev_streak + 1 end;

  perform 1 from public.wallets where user_id = v_user for update;
  if not found then
    raise exception using message = 'Wallet not found';
  end if;

  update public.wallets
  set balance = balance + v_reward,
      total_earned = coalesce(total_earned, 0) + v_reward,
      updated_at = now()
  where user_id = v_user;

  insert into public.transactions (
    user_id, type, amount, description, status, created_at
  ) values (
    v_user, 'daily_checkin_bonus', v_reward,
    'Daily check-in bonus', 'completed', now()
  );

  insert into public.daily_checkins (
    user_id, checkin_date, streak, reward, created_at
  ) values (
    v_user, v_today, v_streak, v_reward, now()
  ) returning id into v_checkin_id;

  return v_checkin_id;
end;
$$;

revoke all on function public.claim_daily_checkin() from public;
grant execute on function public.claim_daily_checkin() to authenticated;

-- =========================================================
-- 3) DAILY MISSIONS
-- =========================================================
create table if not exists public.daily_missions (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  reward numeric(12,2) not null default 0 check (reward >= 0),
  target_tasks integer not null default 1 check (target_tasks > 0),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at)
);

create table if not exists public.daily_mission_claims (
  id uuid primary key default gen_random_uuid(),
  mission_id uuid not null references public.daily_missions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  claim_date date not null,
  reward numeric(12,2) not null check (reward >= 0),
  created_at timestamptz not null default now(),
  unique (mission_id, user_id, claim_date)
);

alter table public.daily_missions enable row level security;
alter table public.daily_mission_claims enable row level security;

drop policy if exists "daily_missions_select_authenticated" on public.daily_missions;
create policy "daily_missions_select_authenticated"
  on public.daily_missions for select to authenticated using (
    is_active = true and starts_at <= now() and (ends_at is null or ends_at >= now())
  );

drop policy if exists "daily_mission_claims_select_own" on public.daily_mission_claims;
create policy "daily_mission_claims_select_own"
  on public.daily_mission_claims for select to authenticated using (auth.uid() = user_id);

revoke insert, update, delete on public.daily_missions from anon, authenticated;
revoke insert, update, delete on public.daily_mission_claims from anon, authenticated;
grant select on public.daily_missions, public.daily_mission_claims to authenticated;

create or replace function public.claim_daily_mission(p_mission_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
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
    where mission_id = p_mission_id and user_id = v_user and claim_date = v_today
  ) then
    raise exception using message = 'Mission already claimed today';
  end if;

  select count(*)::integer into v_completed
  from public.task_submissions
  where user_id = v_user
    and lower(coalesce(status, '')) = 'approved'
    and (created_at at time zone 'Asia/Dhaka')::date = v_today;

  if v_completed < v_mission.target_tasks then
    raise exception using message = format('Complete %s approved tasks today first', v_mission.target_tasks);
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
$$;

revoke all on function public.claim_daily_mission(uuid) from public;
grant execute on function public.claim_daily_mission(uuid) to authenticated;

-- =========================================================
-- 4) REWARDS / PROMOS / ANNOUNCEMENTS
-- =========================================================
create table if not exists public.promotions (
  id uuid primary key default gen_random_uuid(),
  kind text not null default 'announcement',
  title text not null,
  description text not null default '',
  reward numeric(12,2) not null default 0 check (reward >= 0),
  action_label text not null default 'View',
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at)
);

create table if not exists public.promotion_claims (
  id uuid primary key default gen_random_uuid(),
  promotion_id uuid not null references public.promotions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  claim_date date not null,
  reward numeric(12,2) not null check (reward >= 0),
  created_at timestamptz not null default now(),
  unique (promotion_id, user_id, claim_date)
);

alter table public.promotions enable row level security;
alter table public.promotion_claims enable row level security;

drop policy if exists "promotions_select_authenticated" on public.promotions;
create policy "promotions_select_authenticated"
  on public.promotions for select to authenticated using (
    is_active = true and starts_at <= now() and (ends_at is null or ends_at >= now())
  );

drop policy if exists "promotion_claims_select_own" on public.promotion_claims;
create policy "promotion_claims_select_own"
  on public.promotion_claims for select to authenticated using (auth.uid() = user_id);

revoke insert, update, delete on public.promotions from anon, authenticated;
revoke insert, update, delete on public.promotion_claims from anon, authenticated;
grant select on public.promotions, public.promotion_claims to authenticated;



create or replace function public.claim_promotion(p_promotion_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_today date := (now() at time zone 'Asia/Dhaka')::date;
  v_promo public.promotions%rowtype;
  v_claim_id uuid;
begin
  if v_user is null then
    raise exception using message = 'Not authenticated';
  end if;

  select * into v_promo
  from public.promotions
  where id = p_promotion_id
    and is_active = true
    and starts_at <= now()
    and (ends_at is null or ends_at >= now());

  if not found then
    raise exception using message = 'Promotion is not active';
  end if;

  if v_promo.reward <= 0 then
    raise exception using message = 'This promotion has no cash reward';
  end if;

  if v_promo.kind not in ('bonus','campaign','reward') then
    raise exception using message = 'This promotion is informational';
  end if;

  if exists (
    select 1 from public.promotion_claims
    where promotion_id = p_promotion_id and user_id = v_user and claim_date = v_today
  ) then
    raise exception using message = 'Promotion already claimed today';
  end if;

  perform 1 from public.wallets where user_id = v_user for update;
  if not found then
    raise exception using message = 'Wallet not found';
  end if;

  update public.wallets
  set balance = balance + v_promo.reward,
      total_earned = coalesce(total_earned, 0) + v_promo.reward,
      updated_at = now()
  where user_id = v_user;

  insert into public.transactions (
    user_id, type, amount, description, status, created_at
  ) values (
    v_user, 'promotion_reward', v_promo.reward,
    'Promotion reward: ' || v_promo.title, 'completed', now()
  );

  insert into public.promotion_claims (
    promotion_id, user_id, claim_date, reward
  ) values (
    p_promotion_id, v_user, v_today, v_promo.reward
  ) returning id into v_claim_id;

  return v_claim_id;
end;
$$;

revoke all on function public.claim_promotion(uuid) from public;
grant execute on function public.claim_promotion(uuid) to authenticated;

-- Seed visible content only if the table is empty. Admin can later edit/remove it.
insert into public.daily_missions (title, description, reward, target_tasks, is_active)
select 'Daily Task Sprint', 'Complete 3 approved tasks today.', 20, 3, true
where not exists (select 1 from public.daily_missions);

insert into public.promotions (kind, title, description, reward, action_label, is_active)
select * from (values
  ('bonus','Daily Bonus','Complete today''s activity and claim available rewards.',20::numeric,'Claim',true),
  ('referral','Referral Bonus','Invite a new active user and earn the configured bonus.',15::numeric,'View',true),
  ('campaign','Special Campaign','Watch this space for current ZenexPay campaigns.',50::numeric,'Claim',true),
  ('announcement','New Campaign','New earning opportunities may appear here.',0::numeric,'View',true)
) as seed(kind,title,description,reward,action_label,is_active)
where not exists (select 1 from public.promotions);

-- =========================================================
-- 5) PROFILE EDIT / SAVE
-- =========================================================
alter table public.profiles
  add column if not exists phone text;

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select to authenticated using (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

grant select, update on public.profiles to authenticated;

-- =========================================================
-- 6) DAILY GOAL READ FUNCTION
-- =========================================================
create or replace function public.get_daily_goal()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_today date := (now() at time zone 'Asia/Dhaka')::date;
  v_target integer;
  v_completed integer;
begin
  if v_user is null then
    raise exception using message = 'Not authenticated';
  end if;

  select daily_goal_target into v_target
  from public.daily_feature_settings where id = true;

  select count(*)::integer into v_completed
  from public.task_submissions
  where user_id = v_user
    and lower(coalesce(status, '')) = 'approved'
    and (created_at at time zone 'Asia/Dhaka')::date = v_today;

  return jsonb_build_object(
    'target', coalesce(v_target,3),
    'completed', v_completed,
    'percentage', least(100, round((v_completed::numeric / greatest(coalesce(v_target,3),1)) * 100))
  );
end;
$$;

revoke all on function public.get_daily_goal() from public;
grant execute on function public.get_daily_goal() to authenticated;

notify pgrst, 'reload schema';
commit;
