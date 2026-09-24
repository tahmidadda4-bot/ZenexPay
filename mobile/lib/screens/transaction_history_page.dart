import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../zenex_ui.dart';
import 'transaction_details_page.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  late Future<List<Map<String, dynamic>>> future;
  String filter = 'all';

  @override
  void initState() {
    super.initState();
    future = SupabaseService.transactions();
  }

  Future<void> _refresh() async {
    setState(() => future = SupabaseService.transactions());
    await future;
  }

  bool _matches(Map<String, dynamic> row) {
    if (filter == 'all') return true;
    final type = '${row['type'] ?? ''}'.toLowerCase();
    if (filter == 'earned') return type == 'task_reward' || type.contains('earning') || type.contains('bonus');
    return type.contains('withdraw');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNavy,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: const Text('Transaction History', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('${snapshot.error}', style: const TextStyle(color: Colors.white70)));
          final rows = (snapshot.data ?? []).where(_matches).toList();
          return RefreshIndicator(
            onRefresh: _refresh,
            color: kBlue,
            backgroundColor: kSurface,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
              children: [
                _Filters(selected: filter, onChanged: (v) => setState(() => filter = v)),
                const SizedBox(height: 14),
                if (rows.isEmpty)
                  const GlassCard(child: Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: Text('No transactions found.', style: TextStyle(color: Colors.white70)))))
                else
                  ...rows.map((row) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HistoryTile(
                          row: row,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionDetailsPage(transaction: row))),
                        ),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _Filters({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Chip('all', 'All'),
            _Chip('earned', 'Earned'),
            _Chip('withdrawn', 'Withdrawn'),
          ].map((w) => Padding(padding: const EdgeInsets.only(right: 8), child: w)).toList(),
        ),
      );

  Widget _Chip(String value, String label) => ChoiceChip(
        selected: selected == value,
        label: Text(label),
        onSelected: (_) => onChanged(value),
        selectedColor: kPurple,
        backgroundColor: kSurface,
        labelStyle: TextStyle(color: selected == value ? Colors.white : Colors.white70, fontWeight: FontWeight.w800),
        side: BorderSide(color: selected == value ? kPurple : Colors.white.withOpacity(.06)),
      );
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  const _HistoryTile({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = '${row['type'] ?? ''}'.toLowerCase();
    final positive = type == 'task_reward' || type.contains('earning') || type.contains('bonus');
    final amount = double.tryParse('${row['amount'] ?? 0}') ?? 0;
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: (positive ? Colors.greenAccent : Colors.pinkAccent).withOpacity(.12), borderRadius: BorderRadius.circular(14)), child: Icon(positive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: positive ? Colors.greenAccent : Colors.pinkAccent)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${row['description'] ?? row['type'] ?? 'Transaction'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(_date(row['created_at']), style: const TextStyle(color: Colors.white54, fontSize: 11))])),
          const SizedBox(width: 8),
          Text('${positive ? '+' : '-'}৳ ${amount.toStringAsFixed(2)}', style: TextStyle(color: positive ? Colors.greenAccent : Colors.pinkAccent, fontWeight: FontWeight.w900)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Colors.white38),
        ],
      ),
    );
  }
}

String _date(dynamic value) {
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return 'Unknown date';
  return '${parsed.day.toString().padLeft(2, '0')} ${const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][parsed.month - 1]}, ${parsed.year}';
}
