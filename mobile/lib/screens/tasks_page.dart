import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class TasksPage extends StatefulWidget { const TasksPage({super.key}); @override State<TasksPage> createState()=>_TasksPageState(); }
class _TasksPageState extends State<TasksPage> {
  late Future<List<Map<String,dynamic>>> future;
  @override void initState(){super.initState(); future=SupabaseService.tasks();}
  Future<void> openTask(Map<String,dynamic> task) async {
    final proof=TextEditingController();
    final sent=await showModalBottomSheet<bool>(context:context,isScrollControlled:true,builder:(_) => Padding(padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(context).bottom),child:SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[const Expanded(child:Text('Task details',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800))),IconButton(onPressed:()=>Navigator.pop(context,false),icon:const Icon(Icons.close))]),
      const SizedBox(height:8), Text(task['title']??'',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w700)), const SizedBox(height:8), Text(task['description']??''), const SizedBox(height:16),
      const Text('Instructions',style:TextStyle(fontWeight:FontWeight.w800)), const SizedBox(height:6), Text(task['instructions']??''), const SizedBox(height:16),
      TextField(controller:proof,maxLines:5,decoration:const InputDecoration(labelText:'Proof / details',alignLabelWithHint:true)), const SizedBox(height:14),
      SizedBox(height:50,child:FilledButton(onPressed:()=>Navigator.pop(context,true),child:Text('Submit • ৳ ${task['reward']}'))),
    ]))));
    if(sent==true){try{await SupabaseService.submitTask(taskId:task['id'] as String,proofText:proof.text.trim());if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Task submitted for review.')));setState(()=>future=SupabaseService.tasks());}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Available Tasks'),actions:[IconButton(onPressed:()=>setState(()=>future=SupabaseService.tasks()),icon:const Icon(Icons.refresh))]),body:FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(_,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.hasError)return Center(child:Padding(padding:const EdgeInsets.all(20),child:Text('${s.error}')));final items=s.data??[];if(items.isEmpty)return const Center(child:Text('No published tasks available right now.'));return ListView.separated(padding:const EdgeInsets.all(16),itemCount:items.length,separatorBuilder:(_,__)=>const SizedBox(height:10),itemBuilder:(_,i){final t=items[i];return Card(child:ListTile(contentPadding:const EdgeInsets.all(14),leading:CircleAvatar(child:const Icon(Icons.task_alt)),title:Text(t['title']??'',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Padding(padding:const EdgeInsets.only(top:5),child:Text(t['description']??'',maxLines:2,overflow:TextOverflow.ellipsis)),trailing:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text('৳ ${t['reward']}',style:TextStyle(fontWeight:FontWeight.w900,color:Theme.of(context).colorScheme.primary)),const Text('Start')]),onTap:()=>openTask(t)));});}));
}
