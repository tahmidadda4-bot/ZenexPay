import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

const _gBlue = Color(0xFF4F8CFF);
const _gPurple = Color(0xFF8B5CF6);

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});
  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  late Future<UserAnalytics> future;
  @override
  void initState() { super.initState(); future = SupabaseService.analytics(); }
  Future<void> _refresh() async { setState(() => future = SupabaseService.analytics()); await future; }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Level & Achievements', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))]),
        body: FutureBuilder<UserAnalytics>(
          future: future,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (s.hasError) return Center(child: Text('${s.error}'));
            final a = s.data!;
            final level = a.approved >= 100 ? 5 : a.approved >= 50 ? 4 : a.approved >= 25 ? 3 : a.approved >= 10 ? 2 : 1;
            final currentFloor = level == 1 ? 0 : level == 2 ? 10 : level == 3 ? 25 : level == 4 ? 50 : 100;
            final next = level == 1 ? 10 : level == 2 ? 25 : level == 3 ? 50 : level == 4 ? 100 : 100;
            final progress = level == 5 ? 1.0 : ((a.approved - currentFloor) / (next - currentFloor)).clamp(0.0, 1.0);
            final badges = [
              _Badge('First Step', 'Complete your first approved task.', a.approved >= 1, Icons.flag_rounded),
              _Badge('Task Hunter', 'Reach 10 approved tasks.', a.approved >= 10, Icons.search_rounded),
              _Badge('Rising Star', 'Reach 25 approved tasks.', a.approved >= 25, Icons.auto_awesome_rounded),
              _Badge('Pro Worker', 'Reach 50 approved tasks.', a.approved >= 50, Icons.workspace_premium_rounded),
              _Badge('Elite', 'Reach 100 approved tasks.', a.approved >= 100, Icons.military_tech_rounded),
              _Badge('7-Day Fire', 'Maintain a 7-day activity streak.', a.streak >= 7, Icons.local_fire_department_rounded),
            ];
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(21),
                    decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF071127), Color(0xFF243B86), _gPurple]), borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: _gPurple.withOpacity(.18), blurRadius: 28, offset: const Offset(0, 12))]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 27)), const SizedBox(width: 12), Text('Level $level', style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900))]),
                      const SizedBox(height: 10),
                      Text(level == 5 ? 'Maximum milestone reached' : '${a.approved} approved • next milestone $next', style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 15),
                      ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: progress, minHeight: 9, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation<Color>(Colors.white))),
                      const SizedBox(height: 8),
                      Text(level == 5 ? '100% complete' : '${(progress * 100).round()}% to Level ${level + 1}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [const Expanded(child: Text('Achievements', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))), Text('${badges.where((b) => b.unlocked).length}/${badges.length} unlocked', style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w700))]),
                  const SizedBox(height: 10),
                  ...badges.map((b) => _BadgeCard(b)).toList(),
                ],
              ),
            );
          },
        ),
      );
}

class _Badge { final String title, description; final bool unlocked; final IconData icon; const _Badge(this.title, this.description, this.unlocked, this.icon); }
class _BadgeCard extends StatelessWidget {
  final _Badge badge;
  const _BadgeCard(this.badge);
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(21), border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.45))), child: Row(children: [
    Container(width: 48, height: 48, decoration: BoxDecoration(gradient: badge.unlocked ? const LinearGradient(colors: [_gBlue, _gPurple]) : null, color: badge.unlocked ? null : Colors.grey.withOpacity(.10), borderRadius: BorderRadius.circular(15)), child: Icon(badge.icon, color: badge.unlocked ? Colors.white : Colors.grey, size: 22)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(badge.title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(badge.description, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.3))])),
    const SizedBox(width: 8),
    Icon(badge.unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded, color: badge.unlocked ? Colors.green : Colors.grey),
  ]));
}
