ZenexPay - Daily Features Update

Base project:
Fixed v2 + Withdrawal merged project.

This update adds database integration for:
1. Daily Goal
2. Daily Check-in
3. Daily Missions
4. Rewards / Promotions / Announcements
5. Profile Edit + Save

IMPORTANT:
Run SUPABASE_DAILY_FEATURES_V2.sql in Supabase SQL Editor AFTER the previous Daily Activity SQL that was already run.

Daily Check-in reward is now controlled by the daily_feature_settings table.
Default reward remains 20 BDT.

Admin/service-role examples:
  update public.daily_feature_settings set checkin_reward = 50, updated_at = now() where id = true;
  update public.daily_feature_settings set daily_goal_target = 5, updated_at = now() where id = true;

Daily missions are managed through public.daily_missions.
Promotions/announcements are managed through public.promotions.
Profile phone column is added automatically if missing.

The Flutter app reads/writes these database features through Supabase RPC/table calls.
