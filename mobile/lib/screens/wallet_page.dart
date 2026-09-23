import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

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
      await SupabaseService.withdraw(amount: a, method: method, account: account.text.trim());
      amount.clear();
      account.clear();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Withdrawal request submitted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: const Text('Wallet', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            children: [
              FutureBuilder<Map<String, dynamic>?>(
                future: future,
                builder: (_, s) {
                  final w = s.data;
                  return Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF111827), Color(0xFF5B5AF7)]),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available balance', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 5),
                        Text(
                          'เงณ ${_money(w?['balance'])}',
                          style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: _Mini('Total earned', 'เงณ ${_money(w?['total_earned'])}')),
                            Expanded(child: _Mini('Withdrawn', 'เงณ ${_money(w?['total_withdrawn'])}')),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              _SectionCard(
                title: 'Request withdrawal',
                icon: Icons.payments_outlined,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: method,
                      decoration: const InputDecoration(labelText: 'Payment method'),
                      items: const [
                        DropdownMenuItem(value: 'bkash', child: Text('bKash')),
                        DropdownMenuItem(value: 'nagad', child: Text('Nagad')),
                        DropdownMenuItem(value: 'bank', child: Text('Bank')),
                      ],
                      onChanged: busy
                          ? null
                          : (v) {
                              if (v != null) setState(() => method = v);
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount (เงณ)',
                        prefixIcon: Icon(Icons.currency_exchange_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: account,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: method == 'bank' ? 'Bank account number' : 'Mobile account number',
                        prefixIcon: const Icon(Icons.account_balance_rounded),
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: busy ? null : withdraw,
                        icon: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.arrow_upward_rounded),
                        label: Text(busy ? 'Processing...' : 'Request withdrawal'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Recent transactions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: tx,
                builder: (_, s) {
                  if (s.connectionState != ConnectionState.done) {
                    return const Card(
                      child: Padding(padding: EdgeInsets.all(22), child: Center(child: CircularProgressIndicator())),
                    );
                  }
                  final rows = s.data ?? [];
                  if (rows.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: Center(child: Text('No transactions yet.')),
                      ),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Theme.of(c).dividerColor.withOpacity(.5)),
                    ),
                    child: Column(
                      children: rows.take(12).map((r) {
                        final val = double.tryParse('${r['amount']}') ?? 0;
                        final positive = '${r['type']}'.toLowerCase() == 'task_reward';
                        return ListTile(
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: (positive ? Colors.green : Colors.red).withOpacity(.1),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              positive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              color: positive ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(
                            '${r['description'] ?? r['type'] ?? 'Transaction'}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(_date(r['created_at'])),
                          trailing: Text(
                            '${positive ? '+' : '-'}เงณ ${val.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.w900, color: positive ? Colors.green : Colors.red),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
}

class _Mini extends StatelessWidget {
  final String t, v;
  const _Mini(this.t, this.v);

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

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(c).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(c).dividerColor.withOpacity(.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(c).colorScheme.primary),
                const SizedBox(width: 9),
                Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 15),
            child,
          ],
        ),
      );
}

String _money(dynamic v) => (double.tryParse('$v') ?? 0).toStringAsFixed(2);
String _date(dynamic v) {
  final d = DateTime.tryParse('$v')?.toLocal();
  return d == null ? '$v' : '${d.day}/${d.month}/${d.year}';
}
