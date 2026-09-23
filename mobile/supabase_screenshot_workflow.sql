-- ============================================================
-- ZenexPay: screenshot-request workflow + user notifications
-- Run this in Supabase SQL Editor AFTER your existing functions.
-- ============================================================

-- 1) Extra submission fields.
alter table public.task_submissions
  add column if not exists screenshot_reason text,
  add column if not exists screenshot_path text,
  add column if not exists screenshot_submitted_at timestamptz;

-- 2) Notifications.
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  message text not null,
  type text not null default 'general',
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_created_idx
  on public.notifications(user_id, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists "Users can read own notifications" on public.notifications;
create policy "Users can read own notifications"
on public.notifications
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Users can mark own notifications read" on public.notifications;
create policy "Users can mark own notifications read"
on public.notifications
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- 3) Private Storage bucket for requested screenshots.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'task-submissions',
  'task-submissions',
  false,
  5242880,
  array['image/jpeg','image/png','image/webp']
)
on conflict (id) do update
set public = false,
    file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg','image/png','image/webp'];

-- Users can upload only inside their own UID folder.
drop policy if exists "Users upload own task screenshots" on storage.objects;
create policy "Users upload own task screenshots"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'task-submissions'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can delete only their own uploaded screenshot if needed.
drop policy if exists "Users delete own task screenshots" on storage.objects;
create policy "Users delete own task screenshots"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'task-submissions'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- 4) Admin requests screenshot.
-- Assumes your existing is_admin() function is already present.
create or replace function public.request_submission_screenshot(
  p_submission_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_title text;
begin
  if not public.is_admin() then
    raise exception 'Not authorized';
  end if;

  if nullif(trim(p_reason), '') is null then
    raise exception 'Screenshot reason is required';
  end if;

  select ts.user_id, t.title
  into v_user_id, v_title
  from public.task_submissions ts
  join public.tasks t on t.id = ts.task_id
  where ts.id = p_submission_id
    and ts.status = 'pending'
  for update;

  if v_user_id is null then
    raise exception 'Pending submission not found';
  end if;

  update public.task_submissions
  set status = 'screenshot_requested',
      screenshot_reason = trim(p_reason),
      screenshot_path = null,
      screenshot_submitted_at = null,
      reviewed_by = auth.uid(),
      reviewed_at = now()
  where id = p_submission_id;

  insert into public.notifications (
    user_id,
    title,
    message,
    type
  )
  values (
    v_user_id,
    'Screenshot required',
    'A reviewer requested a screenshot for "' ||
      coalesce(v_title, 'your task') ||
      '". Reason: ' || trim(p_reason),
    'screenshot_request'
  );
end;
$$;

-- 5) User submits the requested screenshot.
create or replace function public.submit_screenshot(
  p_submission_id uuid,
  p_storage_path text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_title text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select ts.user_id, t.title
  into v_user_id, v_title
  from public.task_submissions ts
  join public.tasks t on t.id = ts.task_id
  where ts.id = p_submission_id
  for update;

  if v_user_id is null then
    raise exception 'Submission not found';
  end if;

  if v_user_id <> auth.uid() then
    raise exception 'Not authorized';
  end if;

  if not exists (
    select 1
    from public.task_submissions
    where id = p_submission_id
      and status = 'screenshot_requested'
  ) then
    raise exception 'Screenshot is not currently requested';
  end if;

  if nullif(trim(p_storage_path), '') is null then
    raise exception 'Screenshot path is required';
  end if;

  if split_part(p_storage_path, '/', 1) <> auth.uid()::text then
    raise exception 'Invalid screenshot path';
  end if;

  update public.task_submissions
  set status = 'screenshot_submitted',
      screenshot_path = trim(p_storage_path),
      screenshot_submitted_at = now()
  where id = p_submission_id;

  insert into public.notifications (
    user_id,
    title,
    message,
    type
  )
  values (
    v_user_id,
    'Screenshot submitted',
    'Your screenshot for "' ||
      coalesce(v_title, 'your task') ||
      '" was submitted and is waiting for review.',
    'screenshot_submitted'
  );
end;
$$;

-- 6) Important: after a screenshot is submitted, your ADMIN APPROVE
-- function should allow status = 'screenshot_submitted' as well as
-- 'pending'. Replace the existing approve function with this version.
--
-- It keeps your existing reward logic: task reward -> wallet + transaction.

create or replace function public.approve_submission(
  p_submission_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_reward numeric;
  v_title text;
begin
  if not public.is_admin() then
    raise exception 'Not authorized';
  end if;

  select ts.user_id, t.reward, t.title
  into v_user_id, v_reward, v_title
  from public.task_submissions ts
  join public.tasks t on t.id = ts.task_id
  where ts.id = p_submission_id
    and ts.status in ('pending', 'screenshot_submitted')
  for update;

  if v_user_id is null then
    raise exception 'Submission is not pending or screenshot-submitted';
  end if;

  update public.task_submissions
  set status = 'approved',
      reviewed_by = auth.uid(),
      reviewed_at = now()
  where id = p_submission_id;

  update public.wallets
  set balance = coalesce(balance, 0) + coalesce(v_reward, 0),
      total_earned = coalesce(total_earned, 0) + coalesce(v_reward, 0)
  where user_id = v_user_id;

  insert into public.transactions (
    user_id,
    type,
    amount,
    description
  )
  values (
    v_user_id,
    'task_reward',
    v_reward,
    'Reward for approved task: ' || coalesce(v_title, 'Task')
  );

  insert into public.notifications (
    user_id,
    title,
    message,
    type
  )
  values (
    v_user_id,
    'Task approved',
    'Your task "' ||
      coalesce(v_title, 'Task') ||
      '" was approved. ৳' ||
      to_char(coalesce(v_reward, 0), 'FM999999990.00') ||
      ' has been added to your wallet.',
    'task_approved'
  );
end;
$$;

-- 7) Optional: make existing reject flow notify the user.
-- If your admin panel already has direct UPDATE rejection logic,
-- replace that logic with this RPC.

create or replace function public.reject_submission(
  p_submission_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_title text;
begin
  if not public.is_admin() then
    raise exception 'Not authorized';
  end if;

  if nullif(trim(p_reason), '') is null then
    raise exception 'Rejection reason is required';
  end if;

  select ts.user_id, t.title
  into v_user_id, v_title
  from public.task_submissions ts
  join public.tasks t on t.id = ts.task_id
  where ts.id = p_submission_id
    and ts.status in ('pending', 'screenshot_submitted')
  for update;

  if v_user_id is null then
    raise exception 'Submission not found';
  end if;

  update public.task_submissions
  set status = 'rejected',
      rejection_reason = trim(p_reason),
      reviewed_by = auth.uid(),
      reviewed_at = now()
  where id = p_submission_id;

  insert into public.notifications (
    user_id,
    title,
    message,
    type
  )
  values (
    v_user_id,
    'Task needs attention',
    'Your task "' ||
      coalesce(v_title, 'Task') ||
      '" was rejected. Reason: ' || trim(p_reason),
    'task_rejected'
  );
end;
$$;
