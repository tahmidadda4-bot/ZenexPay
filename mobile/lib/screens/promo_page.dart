import 'package:flutter/material.dart';

class PromoPage extends StatelessWidget {
  const PromoPage({super.key});
  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('Rewards & Announcements')), body: ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7A35F4), Color(0xFF146BFF)]), borderRadius: BorderRadius.circular(26)), child: const Row(children: [Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 40), SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Special Bonus', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('Complete 5 tasks today and unlock a bonus.', style: TextStyle(color: Colors.white70))]))])),
      const SizedBox(height: 16),
      _item(cs, Icons.task_alt_rounded, 'Daily Mission', 'Complete 3 tasks today', '৳ 20'),
      _item(cs, Icons.people_alt_rounded, 'Referral Bonus', 'Invite a new active user', '৳ 15'),
      _item(cs, Icons.workspace_premium_rounded, 'Special Bonus', 'Reach the current campaign goal', '৳ 50'),
      _item(cs, Icons.campaign_rounded, 'New Campaign', 'New earning opportunities may appear here.', 'View'),
    ]));
  }
  Widget _item(ColorScheme cs, IconData icon, String title, String sub, String action) => Card(child: ListTile(contentPadding: const EdgeInsets.all(14), leading: Container(width: 46, height: 46, decoration: BoxDecoration(color: cs.primary.withOpacity(.10), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: cs.primary)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(sub), trailing: Text(action, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w900))));
}
