-- ZenexPay Referral Fix V1
-- Run AFTER the existing ZenexPay migrations.
-- Fixes:
-- 1) every user gets a unique referral code
-- 2) registration with another user's code is recorded automatically
-- 3) "Have a referral code?" can apply a code after registration
-- 4) referral count is calculated from real referral records
-- 5) duplicate/self referrals are blocked
-- 6) existing users with missing/duplicate codes are repaired

begin;

create extension if not exists pgcrypto;

-- ---------------------------------------------------------
-- 1. Referral records
-- ---------------------------------------------------------
create table if not exists public.referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_id uuid not null references auth.users(id) on delete cascade,
  referred_id uuid not null references auth.users(id) on delete cascade,
  referral_code text not null,
  created_at timestamptz not null default now(),
  constraint referrals_not_self check (referrer_id <> referred_id),
  constraint referrals_one_referrer_per_user unique (referred_id),
  constraint referrals_no_duplicate_pair unique (referrer_id, referred_id)
);

create index if not exists referrals_referrer_id_idx
  on public.referrals(referrer_id);

alter table public.referrals enable row level security;

drop policy if exists "referrals_select_own" on public.referrals;
create policy "referrals_select_own"
  on public.referrals for select
  to authenticated
  using (auth.uid() = referrer_id or auth.uid() = referred_id);

grant select on public.referrals to authenticated;
revoke insert, update, delete on public.referrals from anon, authenticated;

-- ---------------------------------------------------------
-- 2. Make profile referral codes unique and repair old data
-- ---------------------------------------------------------
alter table public.profiles
  add column if not exists referral_code text;

create or replace function public.generate_referral_code(p_user_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
begin
  loop
    v_code := 'ZP' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
    exit when not exists (
      select 1
      from public.profiles
      where upper(trim(coalesce(referral_code, ''))) = upper(v_code)
        and id <> p_user_id
    );
  end loop;
  return v_code;
end;
$$;

-- Create profiles for any old auth users that somehow do not have one.
insert into public.profiles (id, full_name, referral_code)
select
  u.id,
  coalesce(nullif(trim(u.raw_user_meta_data->>'full_name'), ''), 'Zenex User'),
  public.generate_referral_code(u.id)
from auth.users u
where not exists (
  select 1 from public.profiles p where p.id = u.id
);

-- Fill missing/blank codes.
do $$
declare
  r record;
begin
  for r in
    select id
    from public.profiles
    where referral_code is null or trim(referral_code) = ''
  loop
    update public.profiles
    set referral_code = public.generate_referral_code(r.id)
    where id = r.id;
  end loop;
end $$;

-- Repair duplicate codes, keeping the first row and generating new codes for the rest.
do $$
declare
  r record;
begin
  for r in
    select id
    from (
      select id,
             row_number() over (
               partition by upper(trim(referral_code))
               order by id
             ) as rn
      from public.profiles
      where referral_code is not null and trim(referral_code) <> ''
    ) x
    where x.rn > 1
  loop
    update public.profiles
    set referral_code = public.generate_referral_code(r.id)
    where id = r.id;
  end loop;
end $$;

create unique index if not exists profiles_referral_code_unique_idx
  on public.profiles (upper(trim(referral_code)))
  where referral_code is not null and trim(referral_code) <> '';

-- ---------------------------------------------------------
-- 3. Validate a referral code before registration
-- ---------------------------------------------------------
create or replace function public.validate_referral_code(p_referral_code text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text := upper(trim(coalesce(p_referral_code, '')));
begin
  if v_code = '' then
    return false;
  end if;

  return exists (
    select 1
    from public.profiles
    where upper(trim(referral_code)) = v_code
  );
end;
$$;

revoke all on function public.validate_referral_code(text) from public;
grant execute on function public.validate_referral_code(text) to anon, authenticated;

-- ---------------------------------------------------------
-- 4. Get current user's referral code + real count
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
begin
  if v_user is null then
    raise exception using message = 'Not authenticated';
  end if;

  select referral_code into v_code
  from public.profiles
  where id = v_user;

  if v_code is null or trim(v_code) = '' then
    v_code := public.generate_referral_code(v_user);
    update public.profiles
    set referral_code = v_code
    where id = v_user;
  end if;

  select count(*)::integer into v_count
  from public.referrals
  where referrer_id = v_user;

  return jsonb_build_object(
    'code', v_code,
    'successful_referrals', coalesce(v_count, 0)
  );
end;
$$;

revoke all on function public.get_my_referral_info() from public;
grant execute on function public.get_my_referral_info() to authenticated;

-- ---------------------------------------------------------
-- 5. Apply a referral code after registration
-- ---------------------------------------------------------
create or replace function public.claim_referral(p_referral_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_code text := upper(trim(coalesce(p_referral_code, '')));
  v_referrer uuid;
  v_referral_id uuid;
begin
  if v_user is null then
    raise exception using message = 'Not authenticated';
  end if;

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
$$;

revoke all on function public.claim_referral(text) from public;
grant execute on function public.claim_referral(text) to authenticated;

-- ---------------------------------------------------------
-- 6. Automatically record referral code used during signup
-- ---------------------------------------------------------
create or replace function public.handle_zenex_referral_signup()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_input_code text;
  v_referrer uuid;
  v_profile_code text;
begin
  v_name := coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'), ''), 'Zenex User');
  v_input_code := upper(trim(coalesce(new.raw_user_meta_data->>'referral_code', '')));

  -- Ensure a profile exists and always has its own unique code.
  select referral_code into v_profile_code
  from public.profiles
  where id = new.id;

  if v_profile_code is null or trim(v_profile_code) = '' then
    v_profile_code := public.generate_referral_code(new.id);
  end if;

  insert into public.profiles (id, full_name, referral_code)
  values (new.id, v_name, v_profile_code)
  on conflict (id) do update
    set full_name = coalesce(nullif(public.profiles.full_name, ''), excluded.full_name),
        referral_code = coalesce(nullif(trim(public.profiles.referral_code), ''), excluded.referral_code);

  -- If a valid referral code was supplied during registration, record it once.
  if v_input_code <> '' then
    select id into v_referrer
    from public.profiles
    where upper(trim(referral_code)) = v_input_code
      and id <> new.id
    limit 1;

    if v_referrer is not null then
      insert into public.referrals (referrer_id, referred_id, referral_code)
      values (v_referrer, new.id, v_input_code)
      on conflict (referred_id) do nothing;
    end if;
  end if;

  return new;
end;
$$;

-- Keep the trigger separate from any existing profile trigger.
drop trigger if exists on_auth_user_created_zenex_referral on auth.users;
create trigger on_auth_user_created_zenex_referral
after insert on auth.users
for each row execute function public.handle_zenex_referral_signup();

-- ---------------------------------------------------------
-- 7. Backfill referrals for accounts that were already created
--    with a referral_code in auth metadata before this migration.
-- ---------------------------------------------------------
insert into public.referrals (referrer_id, referred_id, referral_code)
select
  p_ref.id,
  u.id,
  upper(trim(u.raw_user_meta_data->>'referral_code'))
from auth.users u
join public.profiles p_ref
  on upper(trim(p_ref.referral_code)) = upper(trim(u.raw_user_meta_data->>'referral_code'))
where coalesce(trim(u.raw_user_meta_data->>'referral_code'), '') <> ''
  and p_ref.id <> u.id
  and not exists (
    select 1 from public.referrals r where r.referred_id = u.id
  )
on conflict (referred_id) do nothing;

notify pgrst, 'reload schema';
commit;
