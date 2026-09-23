# ZenexPay User Panel Update

Replace these files in your Flutter project:

- pubspec.yaml
- lib/main.dart
- lib/screens/auth_page.dart
- lib/screens/tasks_page.dart
- lib/screens/wallet_page.dart
- lib/screens/submissions_page.dart (NEW)
- lib/screens/profile_page.dart (NEW)
- lib/services/supabase_service.dart

Before running Flutter, run `flutter pub get`.

IMPORTANT:
1. Run `supabase_screenshot_workflow.sql` in Supabase SQL Editor.
2. This creates the screenshot workflow, notifications table, private Storage bucket, and RPCs.
3. The user app does NOT ask for screenshots during normal submission.
4. Admin requests screenshot -> user receives notification -> user uploads -> admin reviews.
5. Existing task reward/withdrawal logic is preserved, but the approve RPC is updated so screenshot_submitted submissions can be approved.
6. Your Admin Panel must call:
   request_submission_screenshot(p_submission_id, p_reason)
   when the admin presses "Request Screenshot".
7. For final approval use:
   approve_submission(p_submission_id)
8. For rejection use:
   reject_submission(p_submission_id, p_reason)

The screenshot bucket is private and limited to 5 MB per image. The mobile app uploads one requested screenshot at a time.
