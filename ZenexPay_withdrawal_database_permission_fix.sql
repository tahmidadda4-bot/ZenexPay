-- ZenexPay Withdrawal: database permission fix
-- Run this file ONCE in Supabase SQL Editor.
-- This fixes the "Could not save this withdrawal method" error
-- without changing the Fixed v2 project files.

begin;

-- Allow logged-in users to access the withdrawal_methods table.
-- RLS policies already limit them to their own rows.
grant usage on schema public to authenticated;

grant select, insert, update, delete
on table public.withdrawal_methods
to authenticated;

-- The withdrawal RPC is already designed to run as SECURITY DEFINER.
-- Make sure authenticated users can call it.
grant execute
on function public.create_withdrawal_request(numeric, uuid)
to authenticated;

-- Refresh PostgREST's schema cache after the permission change.
notify pgrst, 'reload schema';

commit;
