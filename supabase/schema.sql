-- Income Platform V1
-- Run in a fresh Supabase project.
-- Designed so clients cannot directly edit wallet balances.

create extension if not exists pgcrypto;

-- ---------- ENUMS ----------
do $$ begin
  create type public.user_status as enum ('active','blocked');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.task_status as enum ('draft','published','paused','closed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.submission_status as enum ('pending','approved','rejected');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.withdrawal_status as enum ('pending','processing','paid','rejected','cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.transaction_type as enum ('task_reward','referral_reward','withdrawal','withdrawal_reversal','adjustment');
exception when duplicate_object then null; end $$;

-- ---------- PROFILES ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text,
  email text,
  referral_code text unique,
  referred_by uuid references public.profiles(id) on delete set null,
  status public.user_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Wallet is separate and protected by RLS.
create table if not exists public.wallets (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  balance numeric(14,2) not null default 0 check (balance >= 0),
  total_earned numeric(14,2) not null default 0 check (total_earned >= 0),
  total_withdrawn numeric(14,2) not null default 0 check (total_withdrawn >= 0),
  updated_at timestamptz not null default now()
);

-- ---------- TASKS ----------
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  instructions text not null default '',
  reward numeric(12,2) not null check (reward > 0),
  max_submissions integer check (max_submissions is null or max_submissions > 0),
  current_submissions integer not null default 0 check (current_submissions >= 0),
  proof_required boolean not null default true,
  status public.task_status not null default 'draft',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.task_submissions (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  proof_text text,
  proof_path text,
  status public.submission_status not null default 'pending',
  admin_note text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique(task_id, user_id)
);

-- ---------- TRANSACTIONS ----------
create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type public.transaction_type not null,
  amount numeric(14,2) not null check (amount <> 0),
  reference_id uuid,
  description text not null default '',
  created_at timestamptz not null default now()
);

-- ---------- WITHDRAWALS ----------
create table if not exists public.withdrawals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  amount numeric(14,2) not null check (amount > 0),
  method text not null check (method in ('bkash','nagad','bank')),
  account_number text not null,
  status public.withdrawal_status not null default 'pending',
  admin_note text,
  processed_by uuid references public.profiles(id) on delete set null,
  processed_at timestamptz,
  created_at timestamptz not null default now()
);

-- ---------- APP SETTINGS ----------
create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

insert into public.app_settings(key, value) values
('minimum_withdrawal', '{"amount": 100}'::jsonb),
('referral_reward', '{"amount": 0}'::jsonb)
on conflict (key) do nothing;

-- ---------- HELPER FUNCTIONS ----------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and status = 'active'
    and coalesce((auth.jwt()->'app_metadata'->>'role'),'') = 'admin'
  );
$$;

-- Generates a short unique referral code.
create or replace function public.make_referral_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  code text;
begin
  loop
    code := upper(substr(encode(gen_random_bytes(6),'hex'),1,8));
    exit when not exists(select 1 from public.profiles where referral_code = code);
  end loop;
  return code;
end;
$$;

-- New user trigger.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles(id, full_name, phone, email, referral_code)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name',''),
    new.phone,
    new.email,
    public.make_referral_code()
  )
  on conflict (id) do nothing;

  insert into public.wallets(user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- ---------- SECURE TASK SUBMISSION ----------
create or replace function public.submit_task(p_task_id uuid, p_proof_text text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  t public.tasks%rowtype;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  select * into t from public.tasks where id=p_task_id for update;
  if not found then raise exception 'Task not found'; end if;
  if t.status <> 'published' then raise exception 'Task is not available'; end if;
  if t.max_submissions is not null and t.current_submissions >= t.max_submissions then raise exception 'Task limit reached'; end if;
  if exists(select 1 from public.task_submissions where task_id=p_task_id and user_id=auth.uid()) then raise exception 'You already submitted this task'; end if;
  insert into public.task_submissions(task_id,user_id,proof_text) values(p_task_id,auth.uid(),p_proof_text) returning id into v_id;
  update public.tasks set current_submissions=current_submissions+1, updated_at=now() where id=p_task_id;
  return v_id;
end;
$$;

-- ---------- SECURE WALLET OPERATIONS ----------
create or replace function public.submit_withdrawal(
  p_amount numeric,
  p_method text,
  p_account_number text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_min numeric;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if p_amount <= 0 then raise exception 'Invalid amount'; end if;
  if p_method not in ('bkash','nagad','bank') then raise exception 'Invalid method'; end if;
  if length(trim(p_account_number)) < 5 then raise exception 'Invalid account'; end if;

  select coalesce((value->>'amount')::numeric,100)
    into v_min from public.app_settings where key='minimum_withdrawal';

  if p_amount < v_min then raise exception 'Minimum withdrawal is %', v_min; end if;

  -- Lock wallet row so two simultaneous withdrawals cannot spend the same balance.
  perform 1 from public.wallets where user_id=auth.uid() for update;

  if (select balance from public.wallets where user_id=auth.uid()) < p_amount
    then raise exception 'Insufficient balance'; end if;

  update public.wallets
  set balance = balance - p_amount,
      updated_at = now()
  where user_id=auth.uid();

  insert into public.withdrawals(user_id, amount, method, account_number)
  values(auth.uid(), p_amount, p_method, p_account_number)
  returning id into v_id;

  insert into public.transactions(user_id,type,amount,reference_id,description)
  values(auth.uid(),'withdrawal',-p_amount,v_id,'Withdrawal request');

  return v_id;
end;
$$;

-- Admin approves a task submission and awards exactly once.
create or replace function public.approve_submission(p_submission_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.task_submissions%rowtype;
  t public.tasks%rowtype;
begin
  if not public.is_admin() then raise exception 'Admin only'; end if;

  select * into s from public.task_submissions where id=p_submission_id for update;
  if not found then raise exception 'Submission not found'; end if;
  if s.status <> 'pending' then raise exception 'Submission already reviewed'; end if;

  select * into t from public.tasks where id=s.task_id for update;

  update public.task_submissions
  set status='approved', reviewed_by=auth.uid(), reviewed_at=now()
  where id=p_submission_id;

  update public.wallets
  set balance=balance+t.reward,
      total_earned=total_earned+t.reward,
      updated_at=now()
  where user_id=s.user_id;

  insert into public.transactions(user_id,type,amount,reference_id,description)
  values(s.user_id,'task_reward',t.reward,s.id,'Task reward');
end;
$$;

-- Admin processes withdrawal.
create or replace function public.process_withdrawal(
  p_withdrawal_id uuid,
  p_status public.withdrawal_status,
  p_admin_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  w public.withdrawals%rowtype;
begin
  if not public.is_admin() then raise exception 'Admin only'; end if;

  select * into w from public.withdrawals where id=p_withdrawal_id for update;
  if not found then raise exception 'Withdrawal not found'; end if;
  if w.status not in ('pending','processing') then raise exception 'Withdrawal already finalized'; end if;

  update public.withdrawals
  set status=p_status, admin_note=p_admin_note,
      processed_by=auth.uid(), processed_at=now()
  where id=p_withdrawal_id;

  if p_status='paid' then
    update public.wallets
    set total_withdrawn=total_withdrawn+w.amount, updated_at=now()
    where user_id=w.user_id;
  elsif p_status='rejected' or p_status='cancelled' then
    update public.wallets
    set balance=balance+w.amount, updated_at=now()
    where user_id=w.user_id;

    insert into public.transactions(user_id,type,amount,reference_id,description)
    values(w.user_id,'withdrawal_reversal',w.amount,w.id,'Withdrawal returned');
  end if;
end;
$$;

create or replace function public.reject_submission(p_submission_id uuid, p_admin_note text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'Admin only'; end if;
  update public.task_submissions
  set status='rejected', admin_note=p_admin_note, reviewed_by=auth.uid(), reviewed_at=now()
  where id=p_submission_id and status='pending';
  if not found then raise exception 'Submission not found or already reviewed'; end if;
end;
$$;

-- ---------- INDEXES ----------
create index if not exists idx_tasks_status on public.tasks(status);
create index if not exists idx_submissions_user on public.task_submissions(user_id, created_at desc);
create index if not exists idx_submissions_status on public.task_submissions(status, created_at desc);
create index if not exists idx_transactions_user on public.transactions(user_id, created_at desc);
create index if not exists idx_withdrawals_status on public.withdrawals(status, created_at desc);
create index if not exists idx_profiles_referrer on public.profiles(referred_by);

-- ---------- RLS ----------
alter table public.profiles enable row level security;
alter table public.wallets enable row level security;
alter table public.tasks enable row level security;
alter table public.task_submissions enable row level security;
alter table public.transactions enable row level security;
alter table public.withdrawals enable row level security;
alter table public.app_settings enable row level security;

drop policy if exists "profiles_select_self" on public.profiles;
create policy "profiles_select_self" on public.profiles
for select using (id=auth.uid() or public.is_admin());

drop policy if exists "profiles_update_self" on public.profiles;
create policy "profiles_update_self" on public.profiles
for update using (id=auth.uid()) with check (id=auth.uid());

drop policy if exists "wallet_select_self" on public.wallets;
create policy "wallet_select_self" on public.wallets
for select using (user_id=auth.uid() or public.is_admin());

drop policy if exists "tasks_read_published" on public.tasks;
create policy "tasks_read_published" on public.tasks
for select using (status='published' or public.is_admin());
drop policy if exists "tasks_admin_insert" on public.tasks;
create policy "tasks_admin_insert" on public.tasks
for insert with check (public.is_admin());
drop policy if exists "tasks_admin_update" on public.tasks;
create policy "tasks_admin_update" on public.tasks
for update using (public.is_admin()) with check (public.is_admin());
drop policy if exists "tasks_admin_delete" on public.tasks;
create policy "tasks_admin_delete" on public.tasks
for delete using (public.is_admin());

drop policy if exists "submissions_self_read" on public.task_submissions;
create policy "submissions_self_read" on public.task_submissions
for select using (user_id=auth.uid() or public.is_admin());

drop policy if exists "submissions_self_insert" on public.task_submissions;
create policy "submissions_self_insert" on public.task_submissions
for insert with check (user_id=auth.uid());

drop policy if exists "transactions_self_read" on public.transactions;
create policy "transactions_self_read" on public.transactions
for select using (user_id=auth.uid() or public.is_admin());

drop policy if exists "withdrawals_self_read" on public.withdrawals;
create policy "withdrawals_self_read" on public.withdrawals
for select using (user_id=auth.uid() or public.is_admin());

drop policy if exists "settings_read" on public.app_settings;
create policy "settings_read" on public.app_settings
for select using (true);

-- No INSERT/UPDATE/DELETE policy for wallets or transactions for normal users.
-- They must go through trusted functions.
