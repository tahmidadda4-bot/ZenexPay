# ZenexPay — Start Here

You do not need to write code for the setup steps below.

### 1. Create Supabase
Create a Supabase project. Then open **SQL Editor → New query**, paste `supabase/schema.sql`, and run it.

### 2. Create the first admin
Create a normal account from the ZenexPay app/admin login flow. Then assign `app_metadata.role = admin` to that Auth user using a secure server-side/admin method. Do not expose the service-role key in the mobile app or browser.

### 3. Configure the mobile app
Copy `mobile/lib/config/app_config.dart.example` to `mobile/lib/config/app_config.dart` and put the Supabase project URL and anon key there. Never put a Supabase service-role key in the mobile app.

### 4. Configure the admin panel
Copy `admin/.env.example` to `admin/.env` and set the Supabase URL and anon key.

### 5. GitHub
Create a private GitHub repository and upload this project. The included GitHub Action can build an Android APK after the Flutter config is supplied.

### 6. Real payouts
For live bKash/Nagad automatic payouts, obtain the appropriate official merchant/API access. Until then, withdrawals should be reviewed and paid manually by an authorized operator.

### 7. Before public launch
Add privacy policy, terms, support/dispute rules, fraud controls, rate limiting, monitoring, backups, storage policies if screenshots are uploaded, and a genuine business revenue source for task rewards.
