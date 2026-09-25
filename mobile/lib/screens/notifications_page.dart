import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<Map<String, dynamic>>> future;
  RealtimeChannel? channel;

  @override
  void initState() {
    super.initState();
    future = _load();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      channel = Supabase.instance.client.channel('zenexpay-notifications-$uid')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
          callback: (_) { if (mounted) setState(() => future = _load()); },
        )
        ..subscribe();
    }
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await Supabase.instance.client.from('notifications').select('id,title,body,type,is_read,created_at,data').eq('user_id', uid).order('created_at', ascending: false).limit(100);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _markRead(String id) async {
    await Supabase.instance.client.from('notifications').update({'is_read': true}).eq('id', id);
    if (mounted) setState(() => future = _load());
  }

  Future<void> _markAllRead() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    await Supabase.instance.client.from('notifications').update({'is_read': true}).eq('user_id', uid).eq('is_read', false);
    if (mounted) setState(() => future = _load());
  }

  @override
  void dispose() {
    final c = channel;
    if (c != null) Supabase.instance.client.removeChannel(c);
    super.dispose();
  }

  IconData _icon(String type) {
    switch (type) {
      case 'task_approved': return Icons.verified_rounded;
      case 'task_rejected': return Icons.cancel_rounded;
      case 'withdrawal': return Icons.payments_rounded;
      case 'chat': return Icons.support_agent_rounded;
      case 'referral': return Icons.card_giftcard_rounded;
      default: return Icons.notifications_active_rounded;
    }
  }

  String _date(dynamic value) {
    final d = DateTime.tryParse('$value')?.toLocal();
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            TextButton(onPressed: _markAllRead, child: const Text('Read all')),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return _ErrorState(onRetry: () => setState(() => future = _load()));
            final rows = snapshot.data ?? [];
            if (rows.isEmpty) return const _Empty();
            return RefreshIndicator(
              onRefresh: () async { setState(() => future = _load()); await future; },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final row = rows[i];
                  final unread = row['is_read'] != true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(21),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(21),
                        onTap: unread ? () => _markRead('${row['id']}') : null,
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(21), border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.42)), color: unread ? Theme.of(context).colorScheme.primary.withOpacity(.035) : null),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(width: 46, height: 46, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(.10), borderRadius: BorderRadius.circular(15)), child: Icon(_icon('${row['type'] ?? ''}'), color: Theme.of(context).colorScheme.primary)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [Expanded(child: Text('${row['title'] ?? 'ZenexPay'}', style: const TextStyle(fontWeight: FontWeight.w900))), if (unread) Container(width: 8, height: 8, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle))]),
                              const SizedBox(height: 5),
                              Text('${row['body'] ?? ''}', style: const TextStyle(height: 1.35)),
                              const SizedBox(height: 8),
                              Text(_date(row['created_at']), style: Theme.of(context).textTheme.bodySmall),
                            ])),
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 82, height: 82, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(.09), shape: BoxShape.circle), child: Icon(Icons.notifications_none_rounded, size: 42, color: Theme.of(context).colorScheme.primary)), const SizedBox(height: 16), const Text('You are all caught up', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 6), const Text('New task, wallet and account updates will appear here.', textAlign: TextAlign.center)])));
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_rounded, size: 45), const SizedBox(height: 10), const Text('Could not load notifications'), const SizedBox(height: 12), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'))]));
}
