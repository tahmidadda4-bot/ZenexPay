import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late Future<UserAnalytics> future;

  @override
  void initState() {
    super.initState();
    future = SupabaseService.analytics();
  }

  Future<void> _refresh() async {
    setState(() => future = SupabaseService.analytics());
    await future;
  }

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
        if (s.hasError) return Center(child: Text('${s.error}'));
        final a = s.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF111827), Color(0xFF5B5AF7)]),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your performance', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 5),
                    Text('৳${money(a.totalEarned)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    const Text('earned overall', style: TextStyle(color: Colors.white60)),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: _HeroStat('This month', '৳${money(a.monthEarned)}')),
                      Expanded(child: _HeroStat('Streak', '${a.streak} days')),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.45,
                children: [
                  _Metric('Approved', '${a.approved}', Icons.check_circle_rounded),
                  _Metric('Pending', '${a.pending}', Icons.hourglass_top_rounded),
                  _Metric('Rejected', '${a.rejected}', Icons.cancel_rounded),
                  _Metric('Proof sent', '${a.screenshotSubmitted}', Icons.photo_camera_outlined),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Last 7 days', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Container(
                height: 220,
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
                decoration: BoxDecoration(
                  color: Theme.of(c).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Theme.of(c).dividerColor.withOpacity(.5)),
                ),
                child: _Chart(points: a.last7Days),
              ),
              const SizedBox(height: 20),
              const Text('Money flow', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              _Rows(children: [
                _Row('Earned', '৳${money(a.totalEarned)}', Icons.add_circle_outline),
                _Row('Withdrawn', '৳${money(a.totalWithdrawn)}', Icons.remove_circle_outline),
                _Row('Current balance', '৳${money(a.balance)}', Icons.account_balance_wallet_outlined),
              ]),
            ],
          ),
        );
      },
    ),
  );
}

class _HeroStat extends StatelessWidget {
  final String t, v;
  const _HeroStat(this.t, this.v);
  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(t, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      const SizedBox(height: 4),
      Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
    ],
  );
}

class _Metric extends StatelessWidget {
  final String t, v;
  final IconData i;
  const _Metric(this.t, this.v, this.i);
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Theme.of(c).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(c).dividerColor.withOpacity(.5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(i, color: Theme.of(c).colorScheme.primary),
        const Spacer(),
        Text(v, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        Text(t, style: TextStyle(fontSize: 12, color: Theme.of(c).colorScheme.onSurface.withOpacity(.6))),
      ],
    ),
  );
}

class _Rows extends StatelessWidget {
  final List<Widget> children;
  const _Rows({required this.children});
  @override
  Widget build(BuildContext c) => Container(
    decoration: BoxDecoration(
      color: Theme.of(c).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Theme.of(c).dividerColor.withOpacity(.5)),
    ),
    child: Column(children: children),
  );
}

class _Row extends StatelessWidget {
  final String t, v;
  final IconData i;
  const _Row(this.t, this.v, this.i);
  @override
  Widget build(BuildContext c) => ListTile(
    leading: Icon(i, color: Theme.of(c).colorScheme.primary),
    title: Text(t),
    trailing: Text(v, style: const TextStyle(fontWeight: FontWeight.w900)),
  );
}

class _Chart extends StatelessWidget {
  final List<DailyPoint> points;
  const _Chart({required this.points});
  @override
  Widget build(BuildContext c) {
    final max = points.fold<double>(0, (m, p) => math.max(m, p.amount));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: points.map((p) {
        final h = max <= 0 ? 5.0 : math.max(5, 125 * p.amount / max);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(p.amount <= 0 ? '0' : '৳${money(p.amount)}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Container(
                  height: h.toDouble()
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 7),
                Text(p.label, style: const TextStyle(fontSize: 9)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
