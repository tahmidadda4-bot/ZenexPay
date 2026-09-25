import 'package:flutter/material.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Terms & Privacy', style: TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            _Hero(),
            const SizedBox(height: 14),
            _Section(title: 'Terms of use', text: 'Use ZenexPay only with accurate account information and follow the instructions attached to each task. Rewards, submissions and withdrawals are subject to review and the rules configured by the service.'),
            _Section(title: 'Task submissions', text: 'Submit only proof that belongs to your own work. Do not submit misleading, duplicated or unrelated material. A submission may be reviewed, approved or rejected through the normal workflow.'),
            _Section(title: 'Wallet & withdrawals', text: 'Wallet balances and transaction records are displayed from the account data available to the app. Withdrawal requests may be reviewed before processing.'),
            _Section(title: 'Privacy', text: 'Account information and app activity are handled by the connected backend services to provide authentication, tasks, submissions, wallet and support features. Keep your sign-in credentials private.'),
            _Section(title: 'Security', text: 'If you notice unusual account activity, change your password and contact support. Never share passwords or authentication links with another person.'),
            _Section(title: 'Updates', text: 'These informational sections may be updated as the app and its service rules change. Check this page periodically for the latest version.'),
          ],
        ),
      );
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0F5CFF), Color(0xFF6B35F4)]),
          borderRadius: BorderRadius.circular(25),
        ),
        child: const Row(children: [
          Icon(Icons.verified_user_rounded, color: Colors.white, size: 31),
          SizedBox(width: 12),
          Expanded(child: Text('Account, service and privacy information', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900))),
        ]),
      );
}

class _Section extends StatelessWidget {
  final String title;
  final String text;
  const _Section({required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(21), border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.45))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(height: 1.55)),
        ]),
      );
}
