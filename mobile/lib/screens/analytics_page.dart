import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/network_error.dart';

const _aBlue = Color(0xFF4F8CFF);
const _aPurple = Color(0xFF8B5CF6);

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late Future<UserAnalytics> future;
  @override
  void initState() { super.initState(); future = SupabaseService.analytics(); }
  Future<void> _refresh() async { setState(() => future = SupabaseService.analytics()); await future; }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: const Text('Earnings Analytics', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))],
        ),
        body: FutureBuilder<UserAnalytics>(
          future: future,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (s.hasError) return _ErrorState(message: friendlyError(s.error!), onRetry: _refresh);
            final a = s.data!;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _AnalyticsHero(total: '৳${money(a.totalEarned)}', month: '৳${money(a.monthEarned)}', streak: '${a.streak} days'),
                  const SizedBox(height: 16),
                  const _Title('Performance overview'),
                  const SizedBox(height: 10),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.5,
                    children: [
                      _Metric('Approved', '${a.approved}', Icons.check_circle_rounded, Colors.green),
                      _Metric('Pending', '${a.pending}', Icons.hourglass_top_rounded, Colors.orange),
                      _Metric('Rejected', '${a.rejected}', Icons.cancel_rounded, Colors.redAccent),
                      _Metric('Proof sent', '${a.screenshotSubmitted}', Icons.photo_camera_outlined, _aBlue),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _Title('Last 7 days'),
                  const SizedBox(height: 10),
                  Container(
                    height: 235,
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                    decoration: BoxDecoration(color: Theme.of(c).colorScheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: Theme.of(c).dividerColor.withOpacity(.45))),
                    child: _Chart(points: a.last7Days),
                  ),
                  const SizedBox(height: 20),
                  const _Title('Money flow'),
                  const SizedBox(height: 10),
                  _FlowCard(children: [
                    _FlowRow('Total earned', '৳${money(a.totalEarned)}', Icons.add_circle_outline, Colors.green),
                    _FlowRow('Total withdrawn', '৳${money(a.totalWithdrawn)}', Icons.remove_circle_outline, Colors.orange),
                    _FlowRow('Current balance', '৳${money(a.balance)}', Icons.account_balance_wallet_outlined, _aBlue),
                  ]),
                ],
              ),
            );
          },
        ),
      );
}

class _AnalyticsHero extends StatelessWidget {
  final String total, month, streak;
  const _AnalyticsHero({required this.total, required this.month, required this.streak});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(21),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF08122D), Color(0xFF1A2F70), _aPurple]),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: _aPurple.withOpacity(.18), blurRadius: 26, offset: const Offset(0, 12))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.insights_rounded, color: Colors.white, size: 20), SizedBox(width: 8), Text('EARNINGS OVERVIEW', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1))]),
          const SizedBox(height: 8),
          Text(total, style: const TextStyle(color: Colors.white, fontSize: 33, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('earned overall', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _HeroStat('This month', month)),
            Container(width: 1, height: 38, color: Colors.white12),
            Expanded(child: Padding(padding: const EdgeInsets.only(left: 18), child: _HeroStat('Activity streak', streak))),
          ]),
        ]),
      );
}

class _HeroStat extends StatelessWidget { final String title, value; const _HeroStat(this.title, this.value); @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white60, fontSize: 11)), const SizedBox(height: 4), Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900))]); }
class _Title extends StatelessWidget { final String text; const _Title(this.text); @override Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)); }

class _Metric extends StatelessWidget {
  final String title, value; final IconData icon; final Color color;
  const _Metric(this.title, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.45))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withOpacity(.11), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
          const Spacer(), Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      );
}

class _FlowCard extends StatelessWidget { final List<Widget> children; const _FlowCard({required this.children}); @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.45))), child: Column(children: children)); }
class _FlowRow extends StatelessWidget { final String title, value; final IconData icon; final Color color; const _FlowRow(this.title, this.value, this.icon, this.color); @override Widget build(BuildContext context) => ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3), leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w900))); }

class _Chart extends StatelessWidget {
  final List<DailyPoint> points;
  const _Chart({required this.points});
  @override
  Widget build(BuildContext c) {
    final max = points.fold<double>(0, (m, p) => math.max(m, p.amount));
    if (points.isEmpty) return const Center(child: Text('No activity data yet', style: TextStyle(color: Colors.grey)));
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: points.map((p) {
      final h = max <= 0 ? 6.0 : math.max(6, 132 * p.amount / max);
      return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text(p.amount <= 0 ? '0' : '৳${money(p.amount)}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Container(height: h.toDouble(), decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [_aBlue, _aPurple]), borderRadius: BorderRadius.circular(8))),
        const SizedBox(height: 7), Text(p.label, style: const TextStyle(fontSize: 9)),
      ])));
    }).toList());
  }
}

class _ErrorState extends StatelessWidget { final String message; final Future<void> Function() onRetry; const _ErrorState({required this.message, required this.onRetry}); @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey), const SizedBox(height: 12), const Text('Could not load analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)), const SizedBox(height: 16), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again'))]))); }
