# ZenexPay Security Checklist

- [x] Wallet balance cannot be directly updated by normal users.
- [x] Withdrawal uses a server-side RPC and locks the wallet row.
- [x] Task submission checks published status, duplicate submissions and max submissions server-side.
- [x] Task approval awards the reward exactly once per submission.
- [x] Withdrawal rejection/cancellation returns the reserved amount.
- [x] RLS is enabled on user, wallet, task, submission, transaction and withdrawal tables.
- [ ] Configure storage bucket policies before accepting proof screenshots/files.
- [ ] Never expose Supabase service-role key in the app or admin browser.
- [ ] Add rate limits / abuse detection before public launch.
- [ ] Add audit logs for sensitive admin actions.
- [ ] Configure backups and monitoring for production.
- [ ] Add legal/privacy/terms pages and support process.
