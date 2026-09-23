import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});
  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  late Future<UserAnalytics> future;
  @override
  void initState() { super.initState(); future = SupabaseService.analytics(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Level & Achievements', style: TextStyle(fontWeight: FontWeight.w900))),
    body: FutureBuilder<UserAnalytics>(
      future: future,
      builder: (_, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text('${s.error}'));
        final a = s.data!;
        final level = a.approved >= 100 ? 5 : a.approved >= 50 ? 4 : a.approved >= 25 ? 3 : a.approved >= 10 ? 2 : 1;
        final next = level == 1 ? 10 : level == 2 ? 25 : level == 3 ? 50 : level == 4 ? 100 : 100;
        final progress = level == 5 ? 1.0 : (a.approved / next).clamp(0.0, 1.0);
        final badges = <_Badge>[
          _Badge('First Step', 'Complete your first approved task.', a.approved >= 1, Icons.flag_rounded),
          _Badge('Task Hunter', 'Reach 10 approved tasks.', a.approved >= 10, Icons.search_rounded),
          _Badge('Rising Star', 'Reach 25 approved tasks.', a.approved >= 25, Icons.auto_awesome_rounded),
          _Badge('Pro Worker', 'Reach 50 approved tasks.', a.approved >= 50, Icons.workspace_premium_rounded),
          _Badge('Elite', 'Reach 100 approved tasks.', a.approved >= 100, Icons.military_tech_rounded),
          _Badge('7-Day Fire', 'Maintain a 7-day activity streak.', a.streak >= 7, Icons.local_fire_department_rounded),
        ];
        return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.workspace_premium_rounded, size: 34), const SizedBox(width: 12), Text('Level $level', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900))]),
            const SizedBox(height: 10),
            Text(level == 5 ? 'Maximum milestone reached' : '${a.approved} approved • next milestone $next'),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress, minHeight: 9, borderRadius: BorderRadius.circular(20)),
          ]))),
          const SizedBox(height: 18),
          const Text('Achievements', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...badges.map((b) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
            leading: CircleAvatar(child: Icon(b.icon)), title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(b.description), trailing: Icon(b.unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded),
          ))),
        ]);
      },
    ),
  );
}

class _Badge { final String title, description; final bool unlocked; final IconData icon; const _Badge(this.title, this.description, this.unlocked, this.icon); }
