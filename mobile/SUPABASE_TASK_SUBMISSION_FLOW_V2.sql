-- ZenexPay Task Submission Flow V2
-- Run this AFTER the existing task/wallet/transaction migrations.
-- This migration makes task submission single-active-at-a-time and adds
-- automatic wallet + transaction credit when an admin approves a submission.
-- Rejected submissions can be submitted again. Screenshot-requested
-- submissions remain locked until the reviewer finishes the review.

begin;

-- ---------------------------------------------------------
-- 1. Submission audit / review fields
-- ---------------------------------------------------------
alter table public.task_submissions
  add column if not exists rejection_reason text,
  add column if not exists screenshot_reason text,
  add column if not exists screenshot_url text,
  add column if not exists admin_note text,
  add column if not exists rewarded_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

-- Keep timestamps current whenever a submission changes.
create or replace function public.touch_task_submission_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_task_submission_updated_at on public.task_submissions;
create trigger trg_task_submission_updated_at
before update on public.task_submissions
for each row execute function public.touch_task_submission_updated_at();

-- ---------------------------------------------------------
-- 2. Only one active submission per user/task
--    Rejected submissions are intentionally excluded so the user
--    can submit again after rejection.
-- ---------------------------------------------------------

-- If old data contains multiple active submissions for the same task,
-- keep the newest one active and archive the older duplicates as rejected.
with ranked as (
  select id,
         row_number() over (
           partition by user_id, task_id
           order by created_at desc, id desc
         ) as rn
  from public.task_submissions
  where lower(coalesce(status, 'pending')) in
        ('pending','screenshot_requested','screenshot_submitted')
)
update public.task_submissions s
set status = 'rejected',
    rejection_reason = coalesce(s.rejection_reason, 'Duplicate active submission archived.'),
    admin_note = coalesce(s.admin_note, 'Older duplicate submission archived during task-flow migration.'),
    updated_at = now()
from ranked r
where s.id = r.id
  and r.rn > 1;

create unique index if not exists task_submissions_one_active_per_user_task
  on public.task_submissions(user_id, task_id)
  where lower(coalesce(status, 'pending')) in
        ('pending','screenshot_requested','screenshot_submitted');

create index if not exists task_submissions_user_task_created_idx
  on public.task_submissions(user_id, task_id, created_at desc);

-- ---------------------------------------------------------
-- 3. Task reward transaction links
-- ---------------------------------------------------------
alter table public.transactions
  add column if not exists task_id uuid references public.tasks(id) on delete set null,
  add column if not exists task_submission_id uuid references public.task_submissions(id) on delete set null;

create unique index if not exists transactions_one_task_reward_per_submission
  on public.transactions(task_submission_id)
  where type = 'task_reward' and task_submission_id is not null;

-- ---------------------------------------------------------
-- 4. Secure submission RPC
--    A user may submit only when there is no active submission.
--    Rejected/previous submissions do not block a new attempt.
-- ---------------------------------------------------------
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

  select * into v_task
  from public.tasks
  where id = p_task_id
    and lower(coalesce(status, '')) = 'published'
  for share;

  if not found then
    raise exception using message = 'Task is no longer available';
  end if;

  select lower(coalesce(status, 'pending'))
  into v_status
  from public.task_submissions
  where user_id = v_user
    and task_id = p_task_id
    and lower(coalesce(status, 'pending')) in
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
$$;

grant execute on function public.submit_task(uuid, text) to authenticated;

-- ---------------------------------------------------------
-- 5. Automatic wallet credit after ADMIN approval
--    The approval itself happens wherever the reviewer/admin updates
--    task_submissions.status to approved. The trigger performs the
--    wallet credit and transaction insert atomically.
-- ---------------------------------------------------------
create or replace function public.reward_approved_task_submission()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet_exists boolean;
  v_reward numeric(12,2);
  v_task_title text;
  v_tx_id uuid;
begin
  if lower(coalesce(new.status, '')) <> 'approved' then
    return new;
  end if;

  -- Only the transition into approved should pay.
  if tg_op = 'UPDATE' and lower(coalesce(old.status, '')) = 'approved' then
    return new;
  end if;

  -- Never pay the same submission twice.
  if new.rewarded_at is not null
     or exists (
       select 1
       from public.transactions t
       where t.type = 'task_reward'
         and t.task_submission_id = new.id
     ) then
    return new;
  end if;

  select coalesce(t.reward, 0)::numeric(12,2), coalesce(t.title, 'Task')
  into v_reward, v_task_title
  from public.tasks t
  where t.id = new.task_id;

  if v_reward is null or v_reward <= 0 then
    raise exception using message = 'Task reward is invalid';
  end if;

  select exists(
    select 1 from public.wallets where user_id = new.user_id
  ) into v_wallet_exists;

  if not v_wallet_exists then
    raise exception using message = 'User wallet not found';
  end if;

  -- Lock wallet and credit balance + lifetime earnings together.
  perform 1
  from public.wallets
  where user_id = new.user_id
  for update;

  update public.wallets
  set balance = coalesce(balance, 0) + v_reward,
      total_earned = coalesce(total_earned, 0) + v_reward,
      updated_at = now()
  where user_id = new.user_id;

  insert into public.transactions (
    user_id,
    type,
    amount,
    description,
    status,
    task_id,
    task_submission_id,
    created_at
  ) values (
    new.user_id,
    'task_reward',
    v_reward,
    'Task reward: ' || v_task_title,
    'completed',
    new.task_id,
    new.id,
    now()
  )
  returning id into v_tx_id;

  update public.task_submissions
  set rewarded_at = now(),
      updated_at = now()
  where id = new.id;

  return new;
end;
$$;

drop trigger if exists trg_reward_approved_task_submission on public.task_submissions;
create trigger trg_reward_approved_task_submission
after insert or update of status on public.task_submissions
for each row execute function public.reward_approved_task_submission();

-- ---------------------------------------------------------
-- 6. Helpful status index for the User App / review screens
-- ---------------------------------------------------------
create index if not exists task_submissions_user_status_idx
  on public.task_submissions(user_id, status, created_at desc);

notify pgrst, 'reload schema';

commit;
