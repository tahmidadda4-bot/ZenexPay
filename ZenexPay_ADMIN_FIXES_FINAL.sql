-- ZenexPay Admin Fixes FINAL
-- Additive/idempotent patch for the already-applied Admin Control migration.
-- Scope: Users detail/referral context, submissions detail, withdrawal queue,
-- fraud evidence, support status, task publishing reliability, and admin reads.
-- Do not run legacy admin SQL after this file.

begin;

-- ============================================================
-- 1. SUPPORT STATUS: canonical state model
-- ============================================================
do $$
declare c record;
begin
  for c in
    select conname
    from pg_constraint
    where conrelid='public.support_conversations'::regclass
      and contype='c'
      and pg_get_constraintdef(oid) ilike '%status%'
  loop
    execute format('alter table public.support_conversations drop constraint %I', c.conname);
  end loop;

  for c in
    select conname
    from pg_constraint
    where conrelid='public.support_ai_sessions'::regclass
      and contype='c'
      and pg_get_constraintdef(oid) ilike '%status%'
  loop
    execute format('alter table public.support_ai_sessions drop constraint %I', c.conname);
  end loop;
end $$;

update public.support_conversations
set status='human_requested'
where status='admin_handoff';

update public.support_ai_sessions
set status='human_requested'
where status='admin_handoff';

do $$
begin
  alter table public.support_conversations
    add constraint support_conversations_status_check
    check (status in ('open','human_requested','human_active','resolved'));
exception when duplicate_object then null;
end $$;

do $$
begin
  alter table public.support_ai_sessions
    add constraint support_ai_sessions_status_check
    check (status in ('ai_active','human_requested','human_active','resolved'));
exception when duplicate_object then null;
end $$;

-- ============================================================
-- 2. USER SNAPSHOT: complete admin detail view
-- ============================================================
create or replace function public.admin_user_snapshot(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare r jsonb;
begin
  if not public.admin_can('view') then raise exception 'Admin only'; end if;
  if not exists(select 1 from public.profiles where id=p_user_id) then raise exception 'User not found'; end if;

  select jsonb_build_object(
    'profile',(
      select to_jsonb(p) || jsonb_build_object('email',u.email)
      from public.profiles p
      left join auth.users u on u.id=p.id
      where p.id=p_user_id
    ),
    'referrer',(
      select to_jsonb(rp) || jsonb_build_object('email',ru.email)
      from public.profiles rp
      left join auth.users ru on ru.id=rp.id
      where rp.id=(select p.referred_by from public.profiles p where p.id=p_user_id)
    ),
    'referrals_list',(
      select coalesce(jsonb_agg(x order by x.created_at desc),'[]'::jsonb)
      from (
        select r.id,r.referrer_id,r.referred_id,r.referral_code,r.status,r.risk_score,
               r.fraud_reason,r.bonus_amount,r.created_at,r.qualified_at,
               rp.full_name as referred_full_name,ru.email as referred_email,
               rp.phone as referred_phone,rp.user_numeric_id as referred_user_numeric_id
        from public.referrals r
        left join public.profiles rp on rp.id=r.referred_id
        left join auth.users ru on ru.id=r.referred_id
        where r.referrer_id=p_user_id
        order by r.created_at desc
        limit 100
      ) x
    ),
    'transactions',(
      select coalesce(jsonb_agg(
        case when public.admin_can('finance') then to_jsonb(t)
             else jsonb_set(to_jsonb(t), '{withdrawal_account}', to_jsonb(
               case when nullif(trim(coalesce(t.withdrawal_account,'')),'') is null then null
                    else '••••' || right(t.withdrawal_account,4) end), true)
        end order by t.created_at desc),'[]'::jsonb)
      from (select * from public.transactions where user_id=p_user_id order by created_at desc limit 200) t
    ),
    'submissions',(
      select coalesce(jsonb_agg(to_jsonb(s) || jsonb_build_object('task_title',t.title,'task_reward',t.reward) order by s.created_at desc),'[]'::jsonb)
      from public.task_submissions s
      left join public.tasks t on t.id=s.task_id
      where s.user_id=p_user_id
    ),
    'withdrawals',(
      select coalesce(jsonb_agg(
        case when public.admin_can('finance') then to_jsonb(w)
             else jsonb_set(to_jsonb(w), '{account_number}', to_jsonb(
               case when nullif(trim(coalesce(w.account_number,'')),'') is null then null
                    else '••••' || right(w.account_number,4) end), true)
        end order by w.created_at desc),'[]'::jsonb)
      from public.withdrawals w where w.user_id=p_user_id
    ),
    'support',(
      select coalesce(jsonb_agg(to_jsonb(c) order by c.updated_at desc),'[]'::jsonb)
      from public.support_conversations c where c.user_id=p_user_id
    ),
    'notifications',(
      select coalesce(jsonb_agg(to_jsonb(n) order by n.created_at desc),'[]'::jsonb)
      from public.notifications n where n.user_id=p_user_id limit 100
    ),
    'audit',(
      select coalesce(jsonb_agg(to_jsonb(a) order by a.created_at desc),'[]'::jsonb)
      from (select * from public.user_activity_audit where user_id=p_user_id order by created_at desc limit 200) a
    ),
    'referrals',(select count(*) from public.referrals where referrer_id=p_user_id),
    'referral_earnings',(select coalesce(sum(amount),0) from public.transactions where user_id=p_user_id and type::text='referral_bonus'),
    'total_withdrawn',(select coalesce(sum(amount),0) from public.withdrawals where user_id=p_user_id and status='paid'),
    'pending_withdrawals',(select count(*) from public.withdrawals where user_id=p_user_id and status in ('pending','processing')),
    'risk_flags',(select coalesce(jsonb_agg(to_jsonb(f)),'[]'::jsonb) from public.admin_fraud_flags() f where f.user_id=p_user_id)
  ) into r;
  return r;
end;
$$;
revoke all on function public.admin_user_snapshot(uuid) from public;
grant execute on function public.admin_user_snapshot(uuid) to authenticated;

-- ============================================================
-- 3. SUBMISSION DETAIL RPC
-- ============================================================
create or replace function public.admin_submission_snapshot(p_submission_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare r jsonb;
begin
  if not public.admin_can('tasks') then raise exception 'Task management permission required'; end if;
  if not exists(select 1 from public.task_submissions where id=p_submission_id) then raise exception 'Submission not found'; end if;

  select jsonb_build_object(
    'submission',to_jsonb(s),
    'task',(select to_jsonb(t) from public.tasks t where t.id=s.task_id),
    'user',(select to_jsonb(p) || jsonb_build_object('email',u.email) from public.profiles p left join auth.users u on u.id=p.id where p.id=s.user_id),
    'reviewer',(select to_jsonb(p) || jsonb_build_object('email',u.email) from public.profiles p left join auth.users u on u.id=p.id where p.id=s.reviewed_by)
  ) into r
  from public.task_submissions s
  where s.id=p_submission_id;
  return r;
end;
$$;
revoke all on function public.admin_submission_snapshot(uuid) from public;
grant execute on function public.admin_submission_snapshot(uuid) to authenticated;

-- ============================================================
-- 4. WITHDRAWAL QUEUE RPC: never depend on client-side RLS joins
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
  if not (coalesce(auth.jwt()->'app_metadata'->>'role','')='admin' or public.admin_role_for(auth.uid()) in ('super_admin','finance','viewer')) then raise exception 'Finance/view access required'; end if;
  return query
  select w.id,w.user_id,p.full_name,u.email::text,p.user_numeric_id,w.amount,w.method,
         case when public.admin_can('finance') then w.account_number
              else case when nullif(trim(w.account_number),'') is null then null else '••••'||right(w.account_number,4) end end,
         w.status::text,w.note,w.processed_by,w.processed_at,w.created_at
  from public.withdrawals w
  left join public.profiles p on p.id=w.user_id
  left join auth.users u on u.id=w.user_id
  order by w.created_at desc
  limit least(greatest(coalesce(p_limit,500),1),2000);
end;
$$;
revoke all on function public.admin_withdrawal_list(integer) from public;
grant execute on function public.admin_withdrawal_list(integer) to authenticated;

-- ============================================================
-- 5. FRAUD FLAGS: full evidence instead of one-line warning
-- ============================================================
drop function if exists public.admin_fraud_flags();
create function public.admin_fraud_flags()
returns table(
  user_id uuid,
  full_name text,
  email text,
  phone text,
  flag text,
  severity text,
  detail text,
  evidence jsonb,
  detected_at timestamptz
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.admin_can('view') then raise exception 'Admin only'; end if;

  return query
  select w.user_id,p.full_name,u.email::text,p.phone,
         'shared_withdrawal_account'::text,'high'::text,
         (select count(distinct w2.user_id)::text from public.withdrawals w2
          where w2.method=w.method and w2.account_number=w.account_number
            and w2.status in ('pending','processing','paid')) ||
         ' users share ' || w.method || ' account ending ' || right(w.account_number,4),
         jsonb_build_object(
           'method',w.method,
           'account_last4',right(w.account_number,4),
           'user_ids',(select jsonb_agg(distinct w2.user_id) from public.withdrawals w2
                       where w2.method=w.method and w2.account_number=w.account_number
                         and w2.status in ('pending','processing','paid')),
           'withdrawal_ids',(select jsonb_agg(w2.id order by w2.created_at desc) from public.withdrawals w2
                             where w2.method=w.method and w2.account_number=w.account_number
                               and w2.status in ('pending','processing','paid'))
         ),now()
  from public.withdrawals w
  left join public.profiles p on p.id=w.user_id
  left join auth.users u on u.id=w.user_id
  where w.status in ('pending','processing','paid')
    and nullif(trim(w.account_number),'') is not null
    and (select count(distinct w2.user_id) from public.withdrawals w2
         where w2.method=w.method and w2.account_number=w.account_number
           and w2.status in ('pending','processing','paid')) > 1
  group by w.user_id,p.full_name,u.email,p.phone,w.method,w.account_number

  union all

  select p.id,p.full_name,u.email::text,p.phone,
         'duplicate_phone','medium',
         'Phone is used by multiple profiles',
         jsonb_build_object(
           'phone',p.phone,
           'matching_users',(select jsonb_agg(jsonb_build_object('id',p2.id,'full_name',p2.full_name,'email',u2.email,'created_at',p2.created_at) order by p2.created_at)
                             from public.profiles p2 left join auth.users u2 on u2.id=p2.id where p2.phone=p.phone)
         ),now()
  from public.profiles p
  left join auth.users u on u.id=p.id
  where p.phone is not null and trim(p.phone)<>''
    and (select count(*) from public.profiles p2 where p2.phone=p.phone)>1

  union all

  select s.user_id,p.full_name,u.email::text,p.phone,
         'high_submission_volume','medium',count(*)::text || ' submissions in the last 24 hours',
         jsonb_build_object('count',count(*),'window','24 hours','latest_submission',max(s.created_at)),now()
  from public.task_submissions s
  left join public.profiles p on p.id=s.user_id
  left join auth.users u on u.id=s.user_id
  where s.created_at>=now()-interval '24 hours'
  group by s.user_id,p.full_name,u.email,p.phone
  having count(*)>=20;
end;
$$;
revoke all on function public.admin_fraud_flags() from public;
grant execute on function public.admin_fraud_flags() to authenticated;

-- ============================================================
-- 5B. FINANCE DATA ROLE ISOLATION
-- Support/Task Manager must not gain direct SELECT access to finance data.
-- Super Admin, Finance Admin and Viewer retain the intended read access.
-- ============================================================
drop policy if exists transactions_own_or_admin_select on public.transactions;
create policy transactions_own_or_finance_view_select on public.transactions
  for select to authenticated
  using (
    user_id=auth.uid()
    or coalesce(auth.jwt()->'app_metadata'->>'role','')='admin'
    or public.admin_role_for(auth.uid()) in ('super_admin','finance','viewer')
  );

drop policy if exists withdrawals_own_or_admin_select on public.withdrawals;
create policy withdrawals_own_or_finance_view_select on public.withdrawals
  for select to authenticated
  using (
    user_id=auth.uid()
    or coalesce(auth.jwt()->'app_metadata'->>'role','')='admin'
    or public.admin_role_for(auth.uid()) in ('super_admin','finance','viewer')
  );

-- ============================================================
-- 6. TASK PUBLISH/CREATE reliability
-- Explicit aliases remove legacy trigger ambiguity. Push notification
-- failures must never roll back the actual task state change.
-- ============================================================
create or replace function public.notify_new_published_task()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'published' and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    begin
      insert into public.notifications(user_id,title,body,type,data)
      select p.id,
             'New task available',
             coalesce(new.title,'A new task is waiting for you.'),
             'new_task',
             jsonb_build_object('task_id',new.id)
      from public.profiles p
      where p.status='active';
    exception when others then
      -- Task creation/status must not fail because a notification channel failed.
      null;
    end;
  end if;
  return new;
end;
$$;

-- no-op marker for human readability

-- ============================================================
-- 7. Support reply RPC reassertion after status fix
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
  set status='human_active',updated_at=now(),last_message=trim(p_message),last_message_at=now(),admin_unread_count=0,user_unread_count=coalesce(user_unread_count,0)+1
  where id=p_conversation_id;

  update public.support_ai_sessions
  set status='human_active',updated_at=now(),handoff_reason=coalesce(handoff_reason,'Human support engaged')
  where conversation_id=p_conversation_id;

  return v_id;
end;
$$;
revoke all on function public.admin_send_support_message(uuid,text) from public;
grant execute on function public.admin_send_support_message(uuid,text) to authenticated;

notify pgrst,'reload schema';
commit;
