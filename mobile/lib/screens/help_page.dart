import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const faqs = <Map<String, String>>[
    {'q': 'How do I complete a task?', 'a': 'Open Tasks, choose a published task, read its instructions and submit the requested proof.'},
    {'q': 'When is a reward added?', 'a': 'A reward is reflected after your submission is reviewed and approved according to the task workflow.'},
    {'q': 'How do I withdraw?', 'a': 'Open Wallet, choose Withdraw, enter an eligible amount and select the available payout method.'},
    {'q': 'What if my submission is rejected?', 'a': 'Open your proof/submission history to review the rejection information, then contact support if you need clarification.'},
    {'q': 'How do I contact Admin?', 'a': 'Use Chat with Admin from your Profile or Dashboard. Your conversation is linked to your account.'},
    {'q': 'I forgot my password. What should I do?', 'a': 'Use the password reset option on the sign-in screen and follow the secure email link.'},
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Help & FAQ', style: TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF111827), Color(0xFF5B5AF7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Row(children: [
                Icon(Icons.support_agent_rounded, color: Colors.white, size: 32),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Need a hand?', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  Text('Find quick answers below or chat with Admin for account-specific help.', style: TextStyle(color: Colors.white70, height: 1.35)),
                ])),
              ]),
            ),
            const SizedBox(height: 16),
            ...faqs.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.45))),
                    child: ExpansionTile(
                      shape: const RoundedRectangleBorder(),
                      collapsedShape: const RoundedRectangleBorder(),
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      leading: const Icon(Icons.help_outline_rounded),
                      title: Text(f['q']!, style: const TextStyle(fontWeight: FontWeight.w800)),
                      children: [Align(alignment: Alignment.centerLeft, child: Text(f['a']!, style: const TextStyle(height: 1.5)))],
                    ),
                  ),
                )),
          ],
        ),
      );
}
