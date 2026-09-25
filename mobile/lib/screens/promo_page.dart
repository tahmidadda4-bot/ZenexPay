import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/network_error.dart';

class PromoPage extends StatefulWidget {
  const PromoPage({super.key});
  @override State<PromoPage> createState() => _PromoPageState();
}

class _PromoPageState extends State<PromoPage> {
  late Future<List<Map<String,dynamic>>> future;
  final Set<String> busy={};
  @override void initState(){super.initState();_reload();}
  void _reload()=>future=SupabaseService.promotions();
  Future<void> _claim(String id) async { setState(()=>busy.add(id)); try{await SupabaseService.claimPromotion(id);if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Reward added to your wallet.')));setState(_reload);}catch(e){if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(friendlyError(e))));}finally{if(mounted)setState(()=>busy.remove(id));} }

  @override Widget build(BuildContext context){final cs=Theme.of(context).colorScheme;return Scaffold(appBar:AppBar(title:const Text('Rewards & Announcements')),body:FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(_,s){
    if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
    if(s.hasError)return Center(child:Padding(padding:const EdgeInsets.all(24),child:Text('Could not load rewards.\n${friendlyError(s.error!)}',textAlign:TextAlign.center)));
    final rows=s.data??[];return ListView(padding:const EdgeInsets.all(16),children:[
      Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF7A35F4),Color(0xFF146BFF)]),borderRadius:BorderRadius.circular(26)),child:const Row(children:[Icon(Icons.card_giftcard_rounded,color:Colors.white,size:40),SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Rewards & Announcements',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),SizedBox(height:4),Text('Live content from ZenexPay.',style:TextStyle(color:Colors.white70))]))])),const SizedBox(height:16),
      if(rows.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(22),child:Text('No announcements right now.'))),
      for(final r in rows)...[_item(cs,r),const SizedBox(height:10)],
    ]);
  }));}

  Widget _item(ColorScheme cs,Map<String,dynamic> r){final id='${r['id']}';final reward=double.tryParse('${r['reward']??0}')??0;final claimable=reward>0;final claimed=r['claimed']==true;return Card(child:Padding(padding:const EdgeInsets.all(14),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:46,height:46,decoration:BoxDecoration(color:cs.primary.withOpacity(.10),borderRadius:BorderRadius.circular(14)),child:Icon(Icons.campaign_rounded,color:cs.primary)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${r['title']??''}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:15)),const SizedBox(height:4),Text('${r['description']??''}'),if(reward>0)Padding(padding:const EdgeInsets.only(top:7),child:Text('Reward: ৳ ${reward.toStringAsFixed(2)}',style:TextStyle(color:cs.primary,fontWeight:FontWeight.w900))),const SizedBox(height:8),Align(alignment:Alignment.centerRight,child:claimable?FilledButton(onPressed:claimed||busy.contains(id)?null:()=>_claim(id),child:Text(claimed?'Claimed Today':busy.contains(id)?'Processing…':(r['action_label']??'Claim'))):Text('${r['action_label']??'View'}',style:TextStyle(color:cs.primary,fontWeight:FontWeight.w900))) ]))])));}
}
