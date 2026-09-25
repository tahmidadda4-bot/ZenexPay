import 'package:flutter/material.dart';

class DailyCheckInPage extends StatefulWidget {
  const DailyCheckInPage({super.key});
  @override State<DailyCheckInPage> createState() => _DailyCheckInPageState();
}

class _DailyCheckInPageState extends State<DailyCheckInPage> {
  bool claimed = false;
  int streak = 6;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('Daily Check-in')), body: ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF126DFF), Color(0xFF7A35F4)]), borderRadius: BorderRadius.circular(28)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 38), const SizedBox(height: 14),
        const Text('Keep your streak alive', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6), Text('$streak day streak', style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 18), Row(children: [for (int i = 1; i <= 7; i++) Expanded(child: Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(vertical: 11), decoration: BoxDecoration(color: i <= streak ? Colors.white.withOpacity(.22) : Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(14)), child: Column(children: [Text('$i', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Icon(i <= streak ? Icons.check_circle_rounded : Icons.lock_outline_rounded, size: 15, color: Colors.white)])))]),
      ])),
      const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Today’s reward', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 8),
        Row(children: [Container(width: 52, height: 52, decoration: BoxDecoration(color: cs.primary.withOpacity(.10), borderRadius: BorderRadius.circular(16)), child: Icon(Icons.monetization_on_rounded, color: cs.primary)), const SizedBox(width: 12), const Expanded(child: Text('Daily check-in bonus\n৳ 20', style: TextStyle(fontWeight: FontWeight.w800, height: 1.35)))]),
        const SizedBox(height: 16), FilledButton(onPressed: claimed ? null : () => setState(() { claimed = true; if (streak < 7) streak++; }), child: Text(claimed ? 'Claimed Today' : 'Claim Reward')),
      ]))),
      const SizedBox(height: 14),
      Text('Check in every day to continue your streak.', style: TextStyle(color: cs.onSurfaceVariant)),
    ]));
  }
}
