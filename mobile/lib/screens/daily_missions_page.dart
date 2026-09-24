import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class DailyMissionsPage extends StatefulWidget {
  const DailyMissionsPage({super.key});
  @override State<DailyMissionsPage> createState() => _DailyMissionsPageState();
}

class _DailyMissionsPageState extends State<DailyMissionsPage> {
  late Future<List<Map<String, dynamic>>> future;
  @override void initState() { super.initState(); future = SupabaseService.tasks(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('Daily Missions')), body: FutureBuilder<List<Map<String, dynamic>>>(future: future, builder: (_, s) {
      if (s.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (s.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load missions.\n${s.error}', textAlign: TextAlign.center)));
      final tasks = (s.data ?? []).take(6).toList();
      return ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF126DFF), Color(0xFF7A35F4)]), borderRadius: BorderRadius.circular(26)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Complete more, earn more', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)), SizedBox(height: 6), Text('Your active tasks are shown as daily missions.', style: TextStyle(color: Colors.white70))])),
        const SizedBox(height: 16),
        if (tasks.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(22), child: Text('No missions available right now.'))),
        for (int i = 0; i < tasks.length; i++) ...[
          Card(child: ListTile(contentPadding: const EdgeInsets.all(14), leading: Container(width: 46, height: 46, decoration: BoxDecoration(color: cs.primary.withOpacity(.10), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.flag_rounded, color: cs.primary)), title: Text('${tasks[i]['title'] ?? 'Mission'}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Reward  ৳ ${tasks[i]['reward'] ?? 0}'), trailing: Text('${i + 1}/6', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800)))),
          const SizedBox(height: 10),
        ],
      ]);
    }));
  }
}
