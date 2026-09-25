import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import 'chat_page.dart';
import 'notifications_page.dart';
import 'daily_checkin_page.dart';
import 'daily_missions_page.dart';
import 'leaderboard_page.dart';
import 'promo_page.dart';
import '../zenex_ui.dart';

const _bg = Color(0xFF050814);
const _panel = Color(0xFF0C1222);
const _panel2 = Color(0xFF10182C);
const _blue = Color(0xFF3D8CFF);
const _purple = Color(0xFF7847FF);

class DashboardPage extends StatefulWidget {
  final ValueChanged<int>? onTabSelected;
  const DashboardPage({super.key, this.onTabSelected});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, dynamic>?> wallet;

  @override
  void initState() {
    super.initState();
    wallet = SupabaseService.wallet();
    NotificationService.registerCurrentDevice();
  }

  void _refresh() => setState(() => wallet = SupabaseService.wallet());


  void _openSupport() => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatPage()));
  void _openNotifications() => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = (user?.userMetadata?['full_name'] as String?)?.trim();
    final firstName = name == null || name.isEmpty ? 'there' : name.split(' ').first;

    return Scaffold(
      backgroundColor: zenexBackground(context),
      body: RefreshIndicator(
        color: _blue,
        backgroundColor: zenexPanel(context),
        onRefresh: () async { _refresh(); await wallet; },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
          children: [
            Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(colors: [_blue, _purple]),
                  boxShadow: [BoxShadow(color: _blue.withOpacity(.22), blurRadius: 20)],
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Welcome back', style: TextStyle(color: zenexMutedText(context).withOpacity(.75), fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Hi, $firstName 👋', style: TextStyle(color: zenexPrimaryText(context), fontSize: 20, fontWeight: FontWeight.w900)),
              ])),
              _roundAction(Icons.notifications_none_rounded, _openNotifications),
            ]),
            const SizedBox(height: 20),
            _balanceCard(),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _action(Icons.task_alt_rounded, 'Tasks',  'Earn more', 1)),
              const SizedBox(width: 10),
              Expanded(child: _action(Icons.account_balance_wallet_rounded, 'Wallet', 'Manage', 3)),
              const SizedBox(width: 10),
              Expanded(child: _action(Icons.support_agent_rounded, 'Support', 'Get help', null)),
            ]),
            const SizedBox(height: 20),
            const _Title(title: 'Quick overview', subtitle: 'Your earning activity'),
            const SizedBox(height: 10),
            _stats(),
            const SizedBox(height: 20),
            const _Title(title: 'More features', subtitle: 'Open all available ZenexPay pages'),
            const SizedBox(height: 10),
            _featureGrid(),
            const SizedBox(height: 20),
            const _Title(title: 'How ZenexPay works', subtitle: 'Simple steps to earn'),
            const SizedBox(height: 10),
            _howItWorks(),
          ],
        ),
      ),
    );
  }

  Widget _balanceCard() => FutureBuilder<Map<String, dynamic>?>(
    future: wallet,
    builder: (_, s) {
      final b = s.data?['balance'] ?? 0;
      final e = s.data?['total_earned'] ?? 0;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_blue, _purple]),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(.12)),
          boxShadow: [BoxShadow(color: _purple.withOpacity(.20), blurRadius: 34, offset: const Offset(0, 15))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20)),
            const SizedBox(width: 10),
            const Expanded(child: Text('AVAILABLE BALANCE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(20)), child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 13),
          Text('৳ ${_money(b)}', style: const TextStyle(color: Colors.white, fontSize: 35, fontWeight: FontWeight.w900, letterSpacing: -.7)),
          const SizedBox(height: 6),
          Text('Total earned ৳ ${_money(e)}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _mini('Available', '৳ ${_money(b)}')),
            Container(width: 1, height: 30, color: Colors.white.withOpacity(.18)),
            Expanded(child: Padding(padding: const EdgeInsets.only(left: 16), child: _mini('Total earned', '৳ ${_money(e)}'))),
          ]),
        ]),
      );
    },
  );

  Widget _action(IconData icon, String title, String sub, int? tab) => GestureDetector(
    onTap: tab != null ? () => _selectTab(tab) : _openSupport,
    child: Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 13),
      decoration: BoxDecoration(color: zenexPanel(context), borderRadius: BorderRadius.circular(20), border: Border.all(color: zenexSubtleBorder(context))),
      child: Column(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: _blue.withOpacity(.11), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: _blue, size: 21)),
        const SizedBox(height: 9),
        Text(title, style: TextStyle(color: zenexPrimaryText(context), fontSize: 12, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(color: zenexMutedText(context).withOpacity(.75), fontSize: 9)),
      ]),
    ),
  );

  Widget _stats() => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: zenexPanel(context), borderRadius: BorderRadius.circular(23), border: Border.all(color: zenexSubtleBorder(context))),
    child: Row(children: [
      _stat(Icons.bolt_rounded, 'Earning mode', 'Active'),
      _divider(),
      _stat(Icons.task_alt_rounded, 'Tasks', 'Available'),
      _divider(),
      _stat(Icons.verified_rounded, 'Account', 'Verified'),
    ]),
  );

  Widget _featureGrid() => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 1.55,
    children: [
      _feature(Icons.event_available_rounded, 'Daily Check-in', 'Claim daily reward', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyCheckInPage()))),
      _feature(Icons.flag_rounded, 'Daily Missions', 'See mission tasks', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyMissionsPage()))),
      _feature(Icons.leaderboard_rounded, 'Leaderboard', 'View top earners', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardPage()))),
      _feature(Icons.card_giftcard_rounded, 'Rewards', 'Bonuses & campaigns', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PromoPage()))),
    ],
  );

  Widget _feature(IconData icon, String title, String subtitle, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: zenexPanel(context), borderRadius: BorderRadius.circular(18), border: Border.all(color: zenexSubtleBorder(context))),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: _blue.withOpacity(.11), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: _blue, size: 20)),
        const SizedBox(width: 9),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: zenexPrimaryText(context), fontSize: 11, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: zenexMutedText(context).withOpacity(.75), fontSize: 8.5))])),
      ]),
    ),
  );

  Widget _howItWorks() => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(color: zenexPanel(context), borderRadius: BorderRadius.circular(24), border: Border.all(color: zenexSubtleBorder(context))),
    child: Column(children: const [
      _WorkStep(number: '01', icon: Icons.search_rounded, title: 'Choose a task', text: 'Pick a task and read its requirements.'),
      _WorkStep(number: '02', icon: Icons.upload_file_rounded, title: 'Submit proof', text: 'Complete it and submit the requested proof.'),
      _WorkStep(number: '03', icon: Icons.verified_rounded, title: 'Get reviewed', text: 'Approved work adds the reward to your wallet.'),
    ]),
  );

  Widget _roundAction(IconData icon, VoidCallback tap) => InkWell(onTap: tap, borderRadius: BorderRadius.circular(15), child: Container(width: 45, height: 45, decoration: BoxDecoration(color: zenexPanel(context), borderRadius: BorderRadius.circular(15), border: Border.all(color: zenexSubtleBorder(context))), child: Icon(icon, color: zenexMutedText(context), size: 21)));
  Widget _mini(String a, String b) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a, style: TextStyle(color: zenexMutedText(context), fontSize: 9)), const SizedBox(height: 3), Text(b, style: TextStyle(color: zenexPrimaryText(context), fontSize: 12, fontWeight: FontWeight.w800))]);
  Widget _stat(IconData icon, String label, String value) => Expanded(child: Column(children: [Icon(icon, color: _blue, size: 18), const SizedBox(height: 7), Text(value, style: TextStyle(color: zenexPrimaryText(context), fontSize: 10, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(label, textAlign: TextAlign.center, style: TextStyle(color: zenexMutedText(context).withOpacity(.75), fontSize: 8))]));
  Widget _divider() => Container(width: 1, height: 35, color: zenexSubtleBorder(context).withOpacity(.55));
  void _selectTab(int tab) => widget.onTabSelected?.call(tab);
  String _money(dynamic v) => (double.tryParse('$v') ?? 0).toStringAsFixed(2);
}

class _Title extends StatelessWidget {
  final String title, subtitle;
  const _Title({required this.title, required this.subtitle});
  @override Widget build(BuildContext context) => Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: zenexPrimaryText(context), fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: TextStyle(color: zenexMutedText(context).withOpacity(.75), fontSize: 11))]))]);
}

class _WorkStep extends StatelessWidget {
  final String number, title, text; final IconData icon;
  const _WorkStep({required this.number, required this.icon, required this.title, required this.text});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_blue, _purple]), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: Colors.white, size: 19)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$number  $title', style: TextStyle(color: zenexPrimaryText(context), fontSize: 12, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(text, style: TextStyle(color: zenexMutedText(context).withOpacity(.75), fontSize: 10, height: 1.3))]))]));
}
