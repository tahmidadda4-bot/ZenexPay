import 'package:flutter/material.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});
  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = const [('Rafsan', '৳ 2,450'), ('Tanjim', '৳ 2,180'), ('Sifat', '৳ 1,950'), ('Shakib', '৳ 1,720'), ('Rifat', '৳ 1,520')];
    return Scaffold(appBar: AppBar(title: const Text('Leaderboard')), body: ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF126DFF), Color(0xFF7A35F4)]), borderRadius: BorderRadius.circular(26)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Top Earners', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('Weekly ranking', style: TextStyle(color: Colors.white70))])),
      const SizedBox(height: 16),
      for (int i = 0; i < rows.length; i++) Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), leading: CircleAvatar(backgroundColor: cs.primary.withOpacity(.12), child: Text('${i + 1}', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w900))), title: Text(rows[i].$1, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(i == 0 ? 'Top earner this week' : 'Active earner'), trailing: Text(rows[i].$2, style: const TextStyle(fontWeight: FontWeight.w900))))),
    ]));
  }
}
