import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/network_error.dart';

class DailyMissionsPage extends StatefulWidget {
  const DailyMissionsPage({super.key});
  @override State<DailyMissionsPage> createState() => _DailyMissionsPageState();
}

class _DailyMissionsPageState extends State<DailyMissionsPage> {
  late Future<List<Map<String, dynamic>>> future;
  final Set<String> busy = {};
  @override void initState() { super.initState(); _reload(); }
  void _reload() => future = SupabaseService.dailyMissions();

  Future<void> _claim(String id) async {
    setState(() => busy.add(id));
    try {
      await SupabaseService.claimDailyMission(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mission reward added to your wallet.')));
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally { if (mounted) setState(() => busy.remove(id)); }
  }

  @override Widget build(BuildContext context) {
    final cs=Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('Daily Missions')), body: FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(_,s){
      if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
      if(s.hasError)return Center(child:Padding(padding:const EdgeInsets.all(24),child:Text('Could not load missions.\n${friendlyError(s.error!)}',textAlign:TextAlign.center)));
      final missions=s.data??[];
      return ListView(padding:const EdgeInsets.all(16),children:[
        Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF126DFF),Color(0xFF7A35F4)]),borderRadius:BorderRadius.circular(26)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Complete more, earn more',style:TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),SizedBox(height:6),Text('Missions are loaded from the database and can be managed by Admin.',style:TextStyle(color:Colors.white70))])),
        const SizedBox(height:16), if(missions.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(22),child:Text('No missions available right now.'))),
        for(final m in missions) ...[_missionCard(cs,m),const SizedBox(height:10)],
      ]);
    }));
  }

  Widget _missionCard(ColorScheme cs,Map<String,dynamic> m){
    final id='${m['id']}'; final target=int.tryParse('${m['target_tasks']??1}')??1; final completed=int.tryParse('${m['completed']??0}')??0; final claimed=m['claimed']==true; final ready=completed>=target;
    return Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Container(width:46,height:46,decoration:BoxDecoration(color:cs.primary.withOpacity(.10),borderRadius:BorderRadius.circular(14)),child:Icon(Icons.flag_rounded,color:cs.primary)),const SizedBox(width:12),Expanded(child:Text('${m['title']??'Mission'}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16))),Text('৳ ${double.tryParse('${m['reward']??0}')?.toStringAsFixed(2)??'0.00'}',style:TextStyle(color:cs.primary,fontWeight:FontWeight.w900))]),
      const SizedBox(height:8), Text('${m['description']??''}'), const SizedBox(height:12),
      LinearProgressIndicator(value:(completed/target).clamp(0,1).toDouble(),minHeight:7), const SizedBox(height:7), Text('$completed / $target approved tasks today',style:TextStyle(color:cs.onSurfaceVariant,fontSize:12)),
      const SizedBox(height:10), Align(alignment:Alignment.centerRight,child:FilledButton(onPressed:claimed||!ready||busy.contains(id)?null:()=>_claim(id),child:Text(claimed?'Claimed Today':busy.contains(id)?'Processing…':ready?'Claim Reward':'Complete Tasks'))),
    ])));
  }
}
