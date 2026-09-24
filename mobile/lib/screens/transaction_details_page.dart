import 'package:flutter/material.dart';
import '../zenex_ui.dart';

class TransactionDetailsPage extends StatelessWidget {
  final Map<String, dynamic> transaction;
  const TransactionDetailsPage({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final type = '${transaction['type'] ?? ''}'.toLowerCase();
    final positive = type == 'task_reward' || type.contains('earning') || type.contains('bonus');
    final amount = double.tryParse('${transaction['amount'] ?? 0}') ?? 0;
    final title = '${transaction['description'] ?? transaction['type'] ?? 'Transaction'}';

    return Scaffold(
      backgroundColor: kNavy,
      appBar: AppBar(backgroundColor: kNavy, foregroundColor: Colors.white, title: const Text('Transaction Details', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF174EA6), Color(0xFF6338D5)]), borderRadius: BorderRadius.circular(26)),
            child: Column(children: [
              Container(width: 58, height: 58, decoration: BoxDecoration(color: Colors.white.withOpacity(.12), shape: BoxShape.circle), child: Icon(positive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: Colors.white, size: 28)),
              const SizedBox(height: 14),
              Text(positive ? 'Earning' : 'Transaction', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${positive ? '+' : '-'}৳ ${amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(children: [
              _Row('Description', title),
              _Row('Type', '${transaction['type'] ?? '—'}'),
              _Row('Transaction ID', '${transaction['id'] ?? '—'}'),
              _Row('Date', _date(transaction['created_at'])),
            ]),
          ),
          const SizedBox(height: 16),
          SizedBox(height: 50, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(label, style: const TextStyle(color: Colors.white54))), const SizedBox(width: 12), Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))]),
      );
}

String _date(dynamic value) {
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return 'Unknown date';
  return '${parsed.day.toString().padLeft(2, '0')} ${const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][parsed.month - 1]}, ${parsed.year}';
}
