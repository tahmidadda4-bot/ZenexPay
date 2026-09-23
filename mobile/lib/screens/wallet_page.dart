import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  late Future<Map<String, dynamic>?> future;
  late Future<List<Map<String, dynamic>>> transactionsFuture;
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
    transactionsFuture = SupabaseService.transactions();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await Future.wait([future, transactionsFuture]);
  }

  Future<void> withdraw() async {
    final a = double.tryParse(amount.text.trim());
    if (a == null || a <= 0 || account.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid amount and account number.'),
        ),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wallet',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            FutureBuilder<Map<String, dynamic>?>(
              future: future,
              builder: (_, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    snapshot.data == null) {
                  return const SizedBox(
                    height: 170,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final wallet = snapshot.data;
                return Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF101828), Color(0xFF344054)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available balance',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '৳ ${money(wallet?['balance'] ?? 0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _Stat(
                              title: 'Earned',
                              value: '৳ ${money(wallet?['total_earned'] ?? 0)}',
                            ),
                          ),
                          Expanded(
                            child: _Stat(
                              title: 'Withdrawn',
                              value:
                                  '৳ ${money(wallet?['total_withdrawn'] ?? 0)}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Request withdrawal',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: method,
                      decoration:
                          const InputDecoration(labelText: 'Payment method'),
                      items: const [
                        DropdownMenuItem(
                          value: 'bkash',
                          child: Text('bKash'),
                        ),
                        DropdownMenuItem(
                          value: 'nagad',
                          child: Text('Nagad'),
                        ),
                        DropdownMenuItem(
                          value: 'bank',
                          child: Text('Bank'),
                        ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => method = value);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(labelText: 'Amount (৳)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: account,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: method == 'bank'
                            ? 'Bank account number'
                            : 'Mobile account number',
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: busy ? null : withdraw,
                        child:
                            Text(busy ? 'Processing...' : 'Request withdrawal'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Minimum withdrawal is controlled by ZenexPay settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Recent transactions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: transactionsFuture,
              builder: (_, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(22),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                final rows = snapshot.data ?? [];
                if (rows.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(22),
                      child: Center(child: Text('No transactions yet.')),
                    ),
                  );
                }

                return Card(
                  child: Column(
                    children: rows.take(12).map((row) {
                      final amountValue =
                          double.tryParse('${row['amount']}') ?? 0;
                      final positive =
                          '${row['type']}'.toLowerCase() == 'task_reward';
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            positive
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                          ),
                        ),
                        title: Text(
                          '${row['description'] ?? row['type'] ?? 'Transaction'}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(formatDate(row['created_at'])),
                        trailing: Text(
                          '${positive ? '+' : '-'}৳ ${amountValue.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: positive
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
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
}

class _Stat extends StatelessWidget {
  final String title;
  final String value;

  const _Stat({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

String money(dynamic value) =>
    (double.tryParse('$value') ?? 0).toStringAsFixed(2);

String formatDate(dynamic value) {
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return '$value';
  final local = parsed.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
