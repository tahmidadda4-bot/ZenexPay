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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings Analytics', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: FutureBuilder<UserAnalytics>(
        future: future,
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('${snapshot.error}', textAlign: TextAlign.center)));
          }
          final a = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
              children: [
                Row(children: [
                  Expanded(child: _MetricCard(title: 'Total earned', value: '৳${money(a.totalEarned)}', icon: Icons.trending_up_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _MetricCard(title: 'This month', value: '৳${money(a.monthEarned)}', icon: Icons.calendar_month_rounded)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _MetricCard(title: 'Approved', value: '${a.approved}', icon: Icons.check_circle_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _MetricCard(title: 'Streak', value: '${a.streak} days', icon: Icons.local_fire_department_rounded)),
                ]),
                const SizedBox(height: 18),
                const _SectionTitle('Last 7 days'),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
                    child: SizedBox(height: 190, child: _BarChart(points: a.last7Days)),
                  ),
                ),
                const SizedBox(height: 18),
                const _SectionTitle('Task performance'),
                const SizedBox(height: 10),
                Card(
                  child: Column(children: [
                    _StatRow('Approved', a.approved, Icons.check_circle_outline, const Color(0xFF087443)),
                    const Divider(height: 1),
                    _StatRow('Pending', a.pending, Icons.hourglass_top_rounded, const Color(0xFF8A5A00)),
                    const Divider(height: 1),
                    _StatRow('Rejected', a.rejected, Icons.cancel_outlined, const Color(0xFFB42318)),
                    const Divider(height: 1),
                    _StatRow('Screenshot submitted', a.screenshotSubmitted, Icons.photo_camera_outlined, const Color(0xFF175CD3)),
                  ]),
                ),
                const SizedBox(height: 18),
                const _SectionTitle('Money flow'),
                const SizedBox(height: 10),
                Card(
                  child: Column(children: [
                    _MoneyRow('Earned', a.totalEarned, Icons.add_circle_outline),
                    const Divider(height: 1),
                    _MoneyRow('Withdrawn', a.totalWithdrawn, Icons.remove_circle_outline),
                    const Divider(height: 1),
                    _MoneyRow('Current balance', a.balance, Icons.account_balance_wallet_outlined),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  const _MetricCard({required this.title, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 24),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(title, style: TextStyle(color: Colors.grey.shade700)),
      ]),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900));
}

class _StatRow extends StatelessWidget {
  final String title; final int value; final IconData icon; final Color color;
  const _StatRow(this.title, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => ListTile(leading: CircleAvatar(child: Icon(icon, color: color)), title: Text(title), trailing: Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)));
}

class _MoneyRow extends StatelessWidget {
  final String title; final double value; final IconData icon;
  const _MoneyRow(this.title, this.value, this.icon);
  @override
  Widget build(BuildContext context) => ListTile(leading: Icon(icon), title: Text(title), trailing: Text('৳${money(value)}', style: const TextStyle(fontWeight: FontWeight.w900)));
}

class _BarChart extends StatelessWidget {
  final List<DailyPoint> points;
  const _BarChart({required this.points});
  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<double>(0, (m, p) => math.max(m, p.amount));
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: points.map((p) {
      final h = maxValue <= 0 ? 4.0 : math.max(4.0, 125 * p.amount / maxValue);
      return Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(p.amount <= 0 ? '0' : '৳${money(p.amount)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Container(height: h, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 7),
          Text(p.label, style: const TextStyle(fontSize: 10)),
        ]),
      ));
    }).toList());
  }
}
