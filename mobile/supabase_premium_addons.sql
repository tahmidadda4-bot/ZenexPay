-- ============================================================
-- ZenexPay Premium Add-ons
-- Adds referral tracking. Analytics, streak and achievements
-- are calculated from existing wallet/submission/transaction data.
-- Run AFTER your existing ZenexPay screenshot workflow SQL.
-- ============================================================

create table if not exists public.referral_codes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  code text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.referral_claims (
  id uuid primary key default gen_random_uuid(),
  referrer_id uuid not null references auth.users(id) on delete cascade,
  referred_id uuid not null unique references auth.users(id) on delete cascade,
  code text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  approved_at timestamptz
);

create index if not exists referral_claims_referrer_idx
  on public.referral_claims(referrer_id, created_at desc);

alter table public.referral_codes enable row level security;
alter table public.referral_claims enable row level security;

drop policy if exists "Users read own referral code" on public.referral_codes;
create policy "Users read own referral code"
on public.referral_codes for select to authenticated
using (user_id = auth.uid());

drop policy if exists "Users read own referral claims" on public.referral_claims;
create policy "Users read own referral claims"
on public.referral_claims for select to authenticated
using (referrer_id = auth.uid() or referred_id = auth.uid());

create or replace function public.get_or_create_referral_code()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_count integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select code into v_code
  from public.referral_codes
  where user_id = auth.uid();

  if v_code is null then
    v_code := 'ZP' || upper(substr(replace(auth.uid()::text, '-', ''), 1, 8));
    insert into public.referral_codes(user_id, code)
    values (auth.uid(), v_code)
    on conflict (user_id) do nothing;

    select code into v_code
    from public.referral_codes
    where user_id = auth.uid();
  end if;

  select count(*)::integer into v_count
  from public.referral_claims
  where referrer_id = auth.uid()
    and status <> 'rejected';

  return jsonb_build_object(
    'code', v_code,
    'successful_referrals', coalesce(v_count, 0)
  );
end;
$$;

grant execute on function public.get_or_create_referral_code() to authenticated;

create or replace function public.claim_referral_code(p_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_referrer uuid;
  v_code text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  v_code := upper(trim(p_code));
  if v_code is null or v_code = '' then
    raise exception 'Referral code is required';
  end if;

  select user_id into v_referrer
  from public.referral_codes
  where code = v_code;

  if v_referrer is null then
    raise exception 'Referral code not found';
  end if;

  if v_referrer = auth.uid() then
    raise exception 'You cannot use your own referral code';
  end if;

  if exists (select 1 from public.referral_claims where referred_id = auth.uid()) then
    raise exception 'You have already used a referral code';
  end if;

  insert into public.referral_claims(referrer_id, referred_id, code, status)
  values (v_referrer, auth.uid(), v_code, 'pending');

  insert into public.notifications(user_id, title, message, type)
  values (
    v_referrer,
    'New referral',
    'A new user joined using your referral code. The referral is pending review.',
    'referral'
  );
end;
$$;

grant execute on function public.claim_referral_code(text) to authenticated;
