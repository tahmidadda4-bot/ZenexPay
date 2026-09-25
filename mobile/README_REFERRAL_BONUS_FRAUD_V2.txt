ZenexPay Referral Bonus + Fraud Control V2

Run SUPABASE_REFERRAL_BONUS_FRAUD_V2.sql after the existing referral fix and wallet/transaction migrations.

Referral bonus is NOT paid when a code is merely entered. A referral becomes successful after the referred user reaches the configured number of approved tasks (default 1). The referrer then receives the configured bonus atomically in the wallet and a referral_bonus transaction is created.

Basic fraud control blocks the bonus when referrer and referred user share the same phone number. The database records pending/qualified/rejected status and a fraud reason. IP/device fingerprinting is not attempted because the current app/backend does not reliably provide those signals.
