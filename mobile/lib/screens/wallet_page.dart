import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../zenex_ui.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  late Future<Map<String, dynamic>?> future;
  late Future<List<Map<String, dynamic>>> tx;
  final amount = TextEditingController();
  final account = TextEditingController();
  String method = 'bkash';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    future = SupabaseService.wallet();
    tx = SupabaseService.transactions();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await Future.wait([future, tx]);
  }

  Future<void> withdraw() async {
    final a = double.tryParse(amount.text.trim());
    if (a == null || a <= 0 || account.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount and account number.')),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await SupabaseService.withdraw(
        amount: a,
        method: method,
        account: account.text.trim(),
      );
      amount.clear();
      account.clear();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Withdrawal request submitted.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    amount.dispose();
    account.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ZenexPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Wallet'),
              Text('Manage earnings & withdrawals', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white54)),
            ],
          ),
          actions: [
            IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh'),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          color: kCyan,
          backgroundColor: kSurface,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
            children: [
              FutureBuilder<Map<String, dynamic>?>(
                future: future,
                builder: (_, s) {
                  final w = s.data;
                  final balance = w?['balance'] ?? 0;
                  final earned = w?['total_earned'] ?? 0;
                  final withdrawn = w?['total_withdrawn'] ?? 0;
                  return Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [kBlue, kPurple, kPink],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: kPurple.withOpacity(.24), blurRadius: 28, offset: const Offset(0, 12))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Expanded(child: Text('AVAILABLE BALANCE', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(20)),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.lock_rounded, size: 13, color: Colors.white), SizedBox(width: 5), Text('SECURE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900))]),
                          ),
                        ]),
                        const SizedBox(height: 7),
                        Text('৳ ${_money(balance)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -.8)),
                        const SizedBox(height: 4),
                        const Text('Ready for your next withdrawal', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 21),
                        Row(children: [
                          Expanded(child: _BalanceStat('TOTAL EARNED', '৳ ${_money(earned)}', Icons.trending_up_rounded)),
                          const SizedBox(width: 10),
                          Expanded(child: _BalanceStat('WITHDRAWN', '৳ ${_money(withdrawn)}', Icons.south_west_rounded)),
                        ]),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              const SectionHeader(title: 'Withdraw funds', subtitle: 'Choose a payment method and request a payout'),
              const SizedBox(height: 10),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Payment method', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<String>(
                    value: method,
                    decoration: InputDecoration(prefixIcon: Icon(_methodIcon(method))),
                    items: const [
                      DropdownMenuItem(value: 'bkash', child: Text('bKash')),
                      DropdownMenuItem(value: 'nagad', child: Text('Nagad')),
                      DropdownMenuItem(value: 'bank', child: Text('Bank')),
                    ],
                    onChanged: busy ? null : (v) { if (v != null) setState(() => method = v); },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Withdrawal amount', prefixIcon: Icon(Icons.payments_outlined), prefixText: '৳ '),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: account,
                    keyboardType: method == 'bank' ? TextInputType.number : TextInputType.phone,
                    decoration: InputDecoration(labelText: method == 'bank' ? 'Bank account number' : 'Mobile account number', prefixIcon: const Icon(Icons.account_balance_rounded)),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: kCyan.withOpacity(.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: kCyan.withOpacity(.12))),
                    child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline_rounded, size: 17, color: kCyan), SizedBox(width: 9), Expanded(child: Text('Withdrawal requests are reviewed before funds are released. Make sure your account number is correct.', style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4)))]),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [kBlue, kPurple, kPink]), borderRadius: BorderRadius.circular(17)),
                      child: FilledButton.icon(
                        onPressed: busy ? null : withdraw,
                        style: FilledButton.styleFrom(backgroundColor: Colors.transparent, disabledBackgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                        icon: busy ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_upward_rounded),
                        label: Text(busy ? 'Processing...' : 'Request withdrawal'),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 22),
              const SectionHeader(title: 'Recent transactions', subtitle: 'Your latest wallet activity'),
              const SizedBox(height: 10),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: tx,
                builder: (_, s) {
                  if (s.connectionState != ConnectionState.done) return const GlassCard(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                  if (s.hasError) return GlassCard(padding: const EdgeInsets.all(18), child: Text('${s.error}', style: const TextStyle(color: Colors.white70)));
                  final rows = s.data ?? [];
                  if (rows.isEmpty) return const GlassCard(padding: EdgeInsets.all(26), child: Column(children: [Icon(Icons.receipt_long_outlined, size: 34, color: Colors.white38), SizedBox(height: 9), Text('No transactions yet.', style: TextStyle(color: Colors.white60)), SizedBox(height: 3), Text('Your earnings and withdrawals will appear here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11))]));
                  return GlassCard(padding: EdgeInsets.zero, child: Column(children: rows.take(12).map((r) => _TransactionTile(row: r)).toList()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _methodIcon(String value) => value == 'bank' ? Icons.account_balance_rounded : Icons.phone_android_rounded;
}

class _BalanceStat extends StatelessWidget {
  final String title, value;
  final IconData icon;
  const _BalanceStat(this.title, this.value, this.icon);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(color: Colors.white.withOpacity(.11), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white.withOpacity(.10))),
    child: Row(children: [Icon(icon, size: 17, color: Colors.white70), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))]))]),
  );
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> row;
  const _TransactionTile({required this.row});
  @override
  Widget build(BuildContext context) {
    final value = double.tryParse('${row['amount']}') ?? 0;
    final positive = '${row['type']}'.toLowerCase() == 'task_reward';
    final color = positive ? kCyan : kPink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(.055)))),
      child: Row(children: [
        IconTile(icon: positive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: color, size: 42),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${row['description'] ?? row['type'] ?? 'Transaction'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), const SizedBox(height: 4), Text(_date(row['created_at']), style: const TextStyle(color: Colors.white38, fontSize: 10))])),
        const SizedBox(width: 8),
        Text('${positive ? '+' : '-'}৳ ${value.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 12)),
      ]),
    );
  }
}

String _money(dynamic v) => (double.tryParse('$v') ?? 0).toStringAsFixed(2);
String _date(dynamic v) {
  final d = DateTime.tryParse('$v')?.toLocal();
  return d == null ? '$v' : '${d.day}/${d.month}/${d.year}';
}
