import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/network_error.dart';

class DailyCheckInPage extends StatefulWidget {
  const DailyCheckInPage({super.key});
  @override State<DailyCheckInPage> createState() => _DailyCheckInPageState();
}

class _DailyCheckInPageState extends State<DailyCheckInPage> {
  late Future<Map<String, dynamic>> future;
  bool busy = false;
  @override void initState() { super.initState(); _reload(); }
  void _reload() => future = SupabaseService.dailyCheckInStatus();

  Future<void> _claim() async {
    setState(() => busy = true);
    try {
      await SupabaseService.claimDailyCheckIn();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Daily check-in reward added to your wallet.')));
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('Daily Check-in')), body: FutureBuilder<Map<String, dynamic>>(
      future: future, builder: (_, s) {
        if (s.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load check-in.\n${friendlyError(s.error!)}', textAlign: TextAlign.center)));
        final d = s.data!; final streak = int.tryParse('${d['streak'] ?? 0}') ?? 0; final reward = double.tryParse('${d['reward'] ?? 20}') ?? 20; final claimed = d['claimed'] == true;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF126DFF), Color(0xFF7A35F4)]), borderRadius: BorderRadius.circular(28)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 38), const SizedBox(height: 14),
            const Text('Keep your streak alive', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6), Text('$streak day streak', style: const TextStyle(color: Colors.white70)), const SizedBox(height: 18),
            Row(children: [for (int i=1;i<=7;i++) Expanded(child: Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(vertical: 11), decoration: BoxDecoration(color: i<=streak ? Colors.white.withOpacity(.22):Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(14)), child: Column(children: [Text('$i', style: const TextStyle(color: Colors.white,fontWeight: FontWeight.w800)), const SizedBox(height:3), Icon(i<=streak?Icons.check_circle_rounded:Icons.lock_outline_rounded,size:15,color:Colors.white)])))]),
          ])), const SizedBox(height:16),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Today’s reward', style: TextStyle(fontSize:18,fontWeight:FontWeight.w900)), const SizedBox(height:8),
            Row(children:[Container(width:52,height:52,decoration:BoxDecoration(color:cs.primary.withOpacity(.10),borderRadius:BorderRadius.circular(16)),child:Icon(Icons.monetization_on_rounded,color:cs.primary)),const SizedBox(width:12),Expanded(child:Text('Daily check-in bonus\n৳ ${reward.toStringAsFixed(2)}',style:const TextStyle(fontWeight:FontWeight.w800,height:1.35)))]),
            const SizedBox(height:16), FilledButton(onPressed: claimed || busy ? null : _claim, child: Text(busy ? 'Processing…' : claimed ? 'Claimed Today' : 'Claim Reward')),
          ]))), const SizedBox(height:14), Text('Reward amount and streak rules are controlled by ZenexPay settings.',style:TextStyle(color:cs.onSurfaceVariant)),
        ]);
      }));
  }
}
