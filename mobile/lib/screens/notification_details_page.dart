import 'package:flutter/material.dart';
import '../zenex_ui.dart';

class NotificationDetailsPage extends StatelessWidget {
  final Map<String, dynamic> notification;
  const NotificationDetailsPage({super.key, required this.notification});

  String _date(dynamic value) {
    final d = DateTime.tryParse('$value')?.toLocal();
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final data = notification['data'] is Map ? Map<String, dynamic>.from(notification['data']) : <String, dynamic>{};
    return Scaffold(
      backgroundColor: zenexBackground(context),
      appBar: AppBar(backgroundColor: zenexBackground(context), foregroundColor: zenexPrimaryText(context), title: const Text('Notification Details', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 30), children: [
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: kPurple.withOpacity(.13), borderRadius: BorderRadius.circular(16)), child: Icon(Icons.notifications_active_rounded, color: kPurple)),
          const SizedBox(height: 16),
          Text('${notification['title'] ?? 'Notification'}', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: zenexPrimaryText(context))),
          const SizedBox(height: 10),
          Text('${notification['body'] ?? ''}', style: TextStyle(fontSize: 15, height: 1.5, color: zenexPrimaryText(context))),
          const SizedBox(height: 18),
          Divider(color: Theme.of(context).dividerColor),
          const SizedBox(height: 8),
          _Row('Type', '${notification['type'] ?? 'general'}'),
          _Row('Received', _date(notification['created_at'])),
          if (data.isNotEmpty) _Row('Reference', _reference(data)),
        ])),
      ]),
    );
  }

  String _reference(Map<String, dynamic> data) {
    for (final key in ['task_id', 'submission_id', 'transaction_id', 'withdrawal_id', 'conversation_id', 'reference_id']) {
      final value = data[key];
      if (value != null && '$value'.isNotEmpty) return '$key: $value';
    }
    return 'Available in notification data';
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(label, style: TextStyle(color: zenexMutedText(context)))), const SizedBox(width: 12), Expanded(child: Text(value, textAlign: TextAlign.right, style: TextStyle(color: zenexPrimaryText(context), fontWeight: FontWeight.w800)))]));
}
