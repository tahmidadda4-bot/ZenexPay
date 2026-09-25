-- ZenexPay withdrawal implementation
-- Run this once in the Supabase SQL Editor.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------
-- Saved withdrawal methods
-- ---------------------------------------------------------
create table if not exists public.withdrawal_methods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  method_type text not null check (method_type in ('bkash', 'nagad', 'bank')),
  account_number text not null,
  phone_number text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, method_type),
  check (
    (method_type in ('bkash', 'nagad') and phone_number is not null)
    or (method_type = 'bank' and phone_number is null)
  )
);

create unique index if not exists withdrawal_methods_phone_unique
  on public.withdrawal_methods(phone_number)
  where phone_number is not null;

alter table public.withdrawal_methods enable row level security;

drop policy if exists "withdrawal_methods_select_own" on public.withdrawal_methods;
create policy "withdrawal_methods_select_own"
  on public.withdrawal_methods for select
  using (auth.uid() = user_id);

drop policy if exists "withdrawal_methods_insert_own" on public.withdrawal_methods;
create policy "withdrawal_methods_insert_own"
  on public.withdrawal_methods for insert
  with check (auth.uid() = user_id);

drop policy if exists "withdrawal_methods_update_own" on public.withdrawal_methods;
create policy "withdrawal_methods_update_own"
  on public.withdrawal_methods for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Normalize Bangladesh mobile numbers so 01..., 8801... and +8801...
-- cannot bypass the global uniqueness rule.
create or replace function public.normalize_bd_mobile(p_value text)
returns text
language plpgsql
immutable
as $$
declare
  v text := regexp_replace(coalesce(p_value, ''), '[^0-9]', '', 'g');
begin
  if v like '008801%' then
    v := substring(v from 5);
  elsif v like '8801%' then
    v := substring(v from 3);
  elsif v like '1%' and length(v) = 10 then
    v := '0' || v;
  end if;

  if v !~ '^01[3-9][0-9]{8}$' then
    raise exception using message = 'Invalid Bangladesh mobile number';
  end if;

  return v;
end;
$$;

create or replace function public.prepare_withdrawal_method()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();

  if new.method_type in ('bkash', 'nagad') then
    new.phone_number := public.normalize_bd_mobile(new.account_number);
    new.account_number := new.phone_number;
  else
    new.phone_number := null;
    new.account_number := regexp_replace(trim(new.account_number), '\s+', '', 'g');
    if new.account_number = '' then
      raise exception using message = 'Invalid bank account number';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_prepare_withdrawal_method on public.withdrawal_methods;
create trigger trg_prepare_withdrawal_method
before insert or update on public.withdrawal_methods
for each row execute function public.prepare_withdrawal_method();

-- ---------------------------------------------------------
-- Transaction fields used by withdrawal requests
-- ---------------------------------------------------------
alter table public.transactions
  add column if not exists status text not null default 'completed',
  add column if not exists withdrawal_method text,
  add column if not exists withdrawal_account text;

-- One pending withdrawal at a time per user prevents accidental
-- double requests while the first request is being reviewed.
create unique index if not exists transactions_one_pending_withdrawal_per_user
  on public.transactions(user_id)
  where type = 'withdrawal' and status = 'pending';

-- ---------------------------------------------------------
-- Atomic withdrawal request
-- ---------------------------------------------------------
create or replace function public.create_withdrawal_request(
  p_amount numeric,
  p_method_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_method public.withdrawal_methods%rowtype;
  v_transaction_id uuid;
begin
  if v_user is null then
    raise exception using message = 'Not authenticated';
  end if;

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
$$;

revoke all on function public.create_withdrawal_request(numeric, uuid) from public;
grant execute on function public.create_withdrawal_request(numeric, uuid) to authenticated;
