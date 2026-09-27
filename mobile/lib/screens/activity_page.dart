import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/network_error.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});
  @override State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  late Future<List<Map<String,dynamic>>> future;
  @override void initState(){super.initState(); future=SupabaseService.myActivity();}
  String _label(String a)=>a.replaceAll('_',' ').split(' ').map((x)=>x.isEmpty?'':x[0].toUpperCase()+x.substring(1)).join(' ');
  @override Widget build(BuildContext context)=>Scaffold(
    appBar: AppBar(title: const Text('My Activity', style: TextStyle(fontWeight: FontWeight.w900)), actions:[IconButton(onPressed:()=>setState(()=>future=SupabaseService.myActivity()),icon:const Icon(Icons.refresh_rounded))]),
    body: FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(c,s){
      if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
      if(s.hasError)return Center(child:Text(friendlyError(s.error!)));
      final rows=s.data??const [];
      if(rows.isEmpty)return const Center(child:Padding(padding:EdgeInsets.all(30),child:Text('No activity recorded yet.',textAlign:TextAlign.center)));
      return RefreshIndicator(onRefresh:()async{setState(()=>future=SupabaseService.myActivity());await future;},child:ListView.separated(padding:const EdgeInsets.fromLTRB(16,12,16,30),itemCount:rows.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(_,i){final r=rows[i];final d=DateTime.tryParse('${r['created_at']??''}')?.toLocal();return Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.history_rounded,size:18)),title:Text(_label('${r['action']??'activity'}'),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(d==null?'':d.toString(),style:const TextStyle(fontSize:11)),));}));
    }),
  );
}
