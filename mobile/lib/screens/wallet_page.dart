import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../zenex_ui.dart';
import 'transaction_history_page.dart';
import 'withdraw_page.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  late Future<Map<String, dynamic>?> future;
  late Future<List<Map<String, dynamic>>> tx;

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

  Future<void> _openWithdraw() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WithdrawPage()),
    );
    if (mounted) await _refresh();
  }

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransactionHistoryPage()),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: zenexBackground(context),
      appBar: AppBar(
        backgroundColor: zenexBackground(context),
        foregroundColor: zenexPrimaryText(context),
        title: const Text('Wallet', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ZenexGlowBackground(safeArea: false, child: RefreshIndicator(
        onRefresh: _refresh,
        color: kBlue,
        backgroundColor: zenexPanel(context),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
          children: [
            FutureBuilder<Map<String, dynamic>?>(
              future: future,
              builder: (_, snapshot) {
                final wallet = snapshot.data;
                return _BalanceCard(
                  balance: wallet?['balance'],
                  earned: wallet?['total_earned'],
                  withdrawn: wallet?['total_withdrawn'],
                  onWithdraw: _openWithdraw,
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Deposit',
                    subtitle: 'Balance activity',
                    onTap: null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.arrow_upward_rounded,
                    title: 'Withdraw',
                    subtitle: 'Cash out earnings',
                    onTap: _openWithdraw,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.receipt_long_rounded,
                    title: 'History',
                    subtitle: 'All transactions',
                    onTap: _openHistory,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Recent Transactions',
              trailing: TextButton(
                onPressed: _openHistory,
                child: const Text('View all'),
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: tx,
              builder: (_, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const GlassCard(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return GlassCard(
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.orange, size: 34),
                        const SizedBox(height: 8),
                        const Text('Could not load transactions', style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  );
                }

                final rows = snapshot.data ?? [];
                if (rows.isEmpty) {
                  return const GlassCard(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: Text('No transactions yet.')),
                    ),
                  );
                }

                return GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: rows.take(6).map((row) => _TransactionTile(row: row)).toList(),
                  ),
                );
              },
            ),
          ],
        ))),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final dynamic balance;
  final dynamic earned;
  final dynamic withdrawn;
  final VoidCallback onWithdraw;

  const _BalanceCard({
    required this.balance,
    required this.earned,
    required this.withdrawn,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF174EA6), Color(0xFF4F35C8), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(.12)),
        boxShadow: [
          BoxShadow(color: kPurple.withOpacity(.24), blurRadius: 28, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'CURRENT BALANCE',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
              Icon(Icons.account_balance_wallet_rounded, color: Colors.white.withOpacity(.85)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '৳ ${zenexMoney(balance)}',
            style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _Metric('Total earned', '৳ ${zenexMoney(earned)}'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _Metric('Withdrawn', '৳ ${zenexMoney(withdrawn)}'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onWithdraw,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF5134C7),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: const Text('Withdraw', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
        ],
      );
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionCard({required this.icon, required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.fromLTRB(10, 13, 10, 12),
      decoration: BoxDecoration(
        color: zenexPanel(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: zenexSubtleBorder(context)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: kBlue.withOpacity(.14), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: kBlue, size: 21),
          ),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: zenexPrimaryText(context), fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 2),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: zenexMutedText(context), fontSize: 9)),
        ],
      ),
    );
    return onTap == null ? card : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: card);
  }
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> row;
  const _TransactionTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final type = '${row['type'] ?? ''}'.toLowerCase();
    final positive = type == 'task_reward' || type.contains('earning') || type.contains('bonus');
    final amount = double.tryParse('${row['amount'] ?? 0}') ?? 0;
    final title = '${row['description'] ?? row['type'] ?? 'Transaction'}';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: (positive ? const Color(0xFF27D17F) : const Color(0xFFFF4D8D)).withOpacity(.12),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          positive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
          color: positive ? const Color(0xFF27D17F) : const Color(0xFFFF4D8D),
        ),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: zenexPrimaryText(context), fontWeight: FontWeight.w800)),
      subtitle: Text(_date(row['created_at']), style: TextStyle(color: zenexMutedText(context), fontSize: 11)),
      trailing: Text(
        '${positive ? '+' : '-'}৳ ${amount.toStringAsFixed(2)}',
        style: TextStyle(color: positive ? const Color(0xFF27D17F) : const Color(0xFFFF4D8D), fontWeight: FontWeight.w900),
      ),
    );
  }
}

String _date(dynamic value) {
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return 'Unknown date';
  return '${parsed.day.toString().padLeft(2, '0')} ${_month(parsed.month)}, ${parsed.year} ${_two(parsed.hour)}:${_two(parsed.minute)}';
}

String _two(int n) => n.toString().padLeft(2, '0');
String _month(int n) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][n - 1];
