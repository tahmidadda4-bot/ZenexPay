import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../zenex_ui.dart';
import 'chat_page.dart';
import 'notifications_page.dart';
import 'daily_checkin_page.dart';
import 'daily_missions_page.dart';
import 'leaderboard_page.dart';
import 'promo_page.dart';
import 'analytics_page.dart';

class DashboardPage extends StatefulWidget {
  final ValueChanged<int>? onTabSelected;
  const DashboardPage({super.key, this.onTabSelected});
  @override State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, dynamic>?> wallet;
  late Future<Map<String, dynamic>?> profile;
  late Future<Map<String, dynamic>> dailyGoal;
  @override void initState() { super.initState(); wallet = SupabaseService.wallet(); profile = _loadProfile(); dailyGoal = SupabaseService.dailyGoal(); NotificationService.registerCurrentDevice(); }
  Future<Map<String, dynamic>?> _loadProfile() async {
    try {
      return await Supabase.instance.client.from('profiles').select('full_name').eq('id', Supabase.instance.client.auth.currentUser!.id).maybeSingle();
    } catch (_) {
      return null;
    }
  }
  void refresh() => setState(() { wallet = SupabaseService.wallet(); dailyGoal = SupabaseService.dailyGoal(); });
  void tab(int i) => widget.onTabSelected?.call(i);
  void push(Widget p) => Navigator.push(context, MaterialPageRoute(builder: (_) => p));

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: zenexBackground(context), body: ZenexGlowBackground(safeArea: false, child: RefreshIndicator(color: kCyan, backgroundColor: zenexPanel(context), onRefresh: () async { refresh(); await wallet; }, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 18, 16, 30), children: [
      FutureBuilder<Map<String, dynamic>?>(
        future: profile,
        builder: (_, snapshot) {
          final user = Supabase.instance.client.auth.currentUser;
          final profileName = '${snapshot.data?['full_name'] ?? ''}'.trim();
          final metadataName = '${user?.userMetadata?['full_name'] ?? ''}'.trim();
          final name = profileName.isNotEmpty ? profileName : metadataName;
          final first = name.isEmpty ? 'there' : name.split(RegExp(r'\s+')).first;
          return Row(children: [const ZenexLogo(size: 45), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Hello, $first 👋', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 2), const Text('Good to see you again!', style: TextStyle(color: Colors.white54, fontSize: 10))])), _CircleButton(Icons.notifications_none_rounded, () => push(const NotificationsPage())), const SizedBox(width: 8), _CircleButton(Icons.support_agent_rounded, () => push(const ChatPage()))]);
        },
      ),
      const SizedBox(height: 18), _balanceCard(), const SizedBox(height: 14), _quickActions(), const SizedBox(height: 22), _section('Daily Goal', "Your progress is based on today's approved tasks"), const SizedBox(height: 9), _goalCard(), const SizedBox(height: 22), _section('Featured Tasks', 'Simple tasks with clear rewards', trailing: TextButton(onPressed: () => tab(1), child: const Text('View All'))), const SizedBox(height: 9), _taskPreview(), const SizedBox(height: 22), _section('More Features', 'Everything you need in one place'), const SizedBox(height: 9), _features(), const SizedBox(height: 22), _section('How ZenexPay Works', 'Three simple steps'), const SizedBox(height: 9), _howItWorks(),
    ]))));
  }

  Widget _balanceCard() => FutureBuilder<Map<String, dynamic>?>(future: wallet, builder: (_, s) { final b=s.data?['balance']??0, e=s.data?['total_earned']??0; return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft,end: Alignment.bottomRight,colors:[Color(0xFF135CFF),Color(0xFF6C35FF),Color(0xFFB338FF)]), borderRadius: BorderRadius.circular(27), border: Border.all(color: kCyan.withOpacity(.22)), boxShadow:[BoxShadow(color:kPurple.withOpacity(.28),blurRadius:30,offset:const Offset(0,12))]), child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(width:38,height:38,decoration:BoxDecoration(color:Colors.white.withOpacity(.12),borderRadius:BorderRadius.circular(13)),child:const Icon(Icons.account_balance_wallet_rounded,color:Colors.white,size:20)),const SizedBox(width:9),const Expanded(child:Text('WALLET BALANCE',style:TextStyle(color:Colors.white70,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.1))),Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:Colors.white.withOpacity(.12),borderRadius:BorderRadius.circular(20)),child:const Text('LIVE',style:TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w900)))]),const SizedBox(height:10),Row(children:[Expanded(child:Text('৳ ${zenexMoney(b)}',style:const TextStyle(color:Colors.white,fontSize:32,fontWeight:FontWeight.w900))),TextButton(onPressed:()=>tab(2),style:TextButton.styleFrom(backgroundColor:Colors.white,foregroundColor:kPurple,padding:const EdgeInsets.symmetric(horizontal:13,vertical:8),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),child:const Text('Withdraw',style:TextStyle(fontWeight:FontWeight.w900,fontSize:10)))]),const SizedBox(height:3),Text('Total earned  ৳ ${zenexMoney(e)}',style:const TextStyle(color:Colors.white70,fontSize:11)),const SizedBox(height:16),Row(children:[_mini('Available','৳ ${zenexMoney(b)}'),Container(width:1,height:28,color:Colors.white24),_mini('Total earned','৳ ${zenexMoney(e)}')])])); });
  Widget _mini(String a,String b)=>Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:4),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:const TextStyle(color:Colors.white60,fontSize:9)),const SizedBox(height:3),Text(b,style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w900))])));

  Widget _quickActions()=>Row(children:[_action(Icons.task_alt_rounded,'Tasks','Earn more',()=>tab(1)),const SizedBox(width:7),_action(Icons.account_balance_wallet_rounded,'Withdraw','Cash out',()=>tab(2)),const SizedBox(width:7),_action(Icons.people_alt_rounded,'Referral','Invite',()=>tab(3)),const SizedBox(width:7),_action(Icons.support_agent_rounded,'Support','24/7 help',()=>push(const ChatPage()))]);
  Widget _action(IconData i,String t,String s,VoidCallback tap)=>Expanded(child:InkWell(onTap:tap,borderRadius:BorderRadius.circular(18),child:Container(padding:const EdgeInsets.symmetric(vertical:12),decoration:BoxDecoration(color:zenexPanel(context),borderRadius:BorderRadius.circular(18),border:Border.all(color:zenexSubtleBorder(context))),child:Column(children:[Container(width:38,height:38,decoration:BoxDecoration(color:kBlue.withOpacity(.11),borderRadius:BorderRadius.circular(12)),child:Icon(i,color:kBlue,size:19)),const SizedBox(height:7),Text(t,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900)),Text(s,style:const TextStyle(color:Colors.white54,fontSize:8))]))));
  Widget _section(String t,String s,{Widget? trailing})=>Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(t,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text(s,style:const TextStyle(color:Colors.white54,fontSize:10))])),if(trailing!=null)trailing!]);

  Widget _goalCard()=>FutureBuilder<Map<String,dynamic>>(future:dailyGoal,builder:(_,s){
    if(s.connectionState==ConnectionState.waiting)return const GlassCard(glow:true,padding:EdgeInsets.all(18),child:Center(child:SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2))));
    if(s.hasError)return GlassCard(glow:true,padding:const EdgeInsets.all(15),child:Text('Daily Goal unavailable',style:TextStyle(color:Colors.white54,fontSize:11)));
    final d=s.data!;final target=int.tryParse('${d['target']??3}')??3;final completed=int.tryParse('${d['completed']??0}')??0;final pct=(completed/target).clamp(0,1).toDouble();final percent=(double.tryParse('${d['percentage']??0}')??(pct*100)).round();
    return GlassCard(glow:true,padding:const EdgeInsets.all(15),child:Column(children:[Row(children:[Container(width:38,height:38,decoration:BoxDecoration(color:kBlue.withOpacity(.13),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.flag_rounded,color:kBlue)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Complete $target tasks',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:13)),const SizedBox(height:3),Text('$completed / $target completed today',style:const TextStyle(color:Colors.white54,fontSize:10))])),Text('$percent%',style:const TextStyle(color:kCyan,fontWeight:FontWeight.w900,fontSize:12))]),const SizedBox(height:12),ClipRRect(borderRadius:BorderRadius.circular(99),child:LinearProgressIndicator(value:pct,minHeight:8,backgroundColor:Colors.white10,valueColor:const AlwaysStoppedAnimation(kCyan)))]));
  });

  Widget _taskPreview()=>GlassCard(padding:EdgeInsets.zero,child:Column(children:[_taskRow(Icons.play_circle_fill_rounded,'Watch Video','Earn ৳ 5.00','Easy',const Color(0xFFB33DFF)),const Divider(height:1),_taskRow(Icons.download_rounded,'App Install','Earn ৳ 8.00','Medium',kBlue),const Divider(height:1),_taskRow(Icons.poll_rounded,'Quick Survey','Earn ৳ 10.00','Easy',kCyan)]));
  Widget _taskRow(IconData i,String title,String reward,String level,Color c)=>ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:13,vertical:5),leading:Container(width:42,height:42,decoration:BoxDecoration(color:c.withOpacity(.12),borderRadius:BorderRadius.circular(13)),child:Icon(i,color:c)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:12)),subtitle:Text(reward,style:const TextStyle(color:Colors.white54,fontSize:10)),trailing:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),decoration:BoxDecoration(color:kPurple.withOpacity(.18),borderRadius:BorderRadius.circular(12)),child:Text(level,style:const TextStyle(color:kCyan,fontSize:9,fontWeight:FontWeight.w900))));

  Widget _features()=>GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),mainAxisSpacing:9,crossAxisSpacing:9,childAspectRatio:2.25,children:[_feature(Icons.event_available_rounded,'Daily Check-in',()=>push(const DailyCheckInPage())),_feature(Icons.flag_rounded,'Daily Missions',()=>push(const DailyMissionsPage())),_feature(Icons.insights_rounded,'Analytics',()=>push(const AnalyticsPage())),_feature(Icons.leaderboard_rounded,'Leaderboard',()=>push(const LeaderboardPage())),_feature(Icons.card_giftcard_rounded,'Rewards',()=>push(const PromoPage())),_feature(Icons.support_agent_rounded,'Support',()=>push(const ChatPage()))]);
  Widget _feature(IconData i,String t,VoidCallback tap)=>InkWell(onTap:tap,borderRadius:BorderRadius.circular(16),child:Container(padding:const EdgeInsets.symmetric(horizontal:10),decoration:BoxDecoration(color:zenexPanel(context),borderRadius:BorderRadius.circular(16),border:Border.all(color:zenexSubtleBorder(context))),child:Row(children:[Icon(i,color:kPurple,size:19),const SizedBox(width:8),Expanded(child:Text(t,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800)))])));
  Widget _howItWorks()=>GlassCard(padding:const EdgeInsets.all(15),child:Column(children:[_step('01',Icons.search_rounded,'Choose a task','Read the requirements and reward.'),_step('02',Icons.upload_file_rounded,'Submit proof','Complete the work and send proof.'),_step('03',Icons.verified_rounded,'Get rewarded','Approved work adds money to your wallet.')]));
  Widget _step(String n,IconData i,String t,String s)=>Padding(padding:const EdgeInsets.only(bottom:12),child:Row(children:[Container(width:38,height:38,decoration:const BoxDecoration(shape:BoxShape.circle,gradient:LinearGradient(colors:[kBlue,kPurple])),child:Icon(i,color:Colors.white,size:18)),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('$n  $t',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text(s,style:const TextStyle(color:Colors.white54,fontSize:9))]))]));
  Widget _CircleButton(IconData i,VoidCallback tap)=>InkWell(onTap:tap,borderRadius:BorderRadius.circular(14),child:Container(width:42,height:42,decoration:BoxDecoration(color:zenexPanel(context),borderRadius:BorderRadius.circular(14),border:Border.all(color:zenexSubtleBorder(context))),child:Icon(i,color:Colors.white70,size:20)));
}
