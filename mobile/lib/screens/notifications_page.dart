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
    final data = await Supabase.instance.client
        .from('notifications')
        .select('id,title,body,type,is_read,created_at,data')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _markRead(String id) async {
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id);
    if (mounted) setState(() => future = _load());
  }

  @override
  void dispose() {
    final c = channel;
    if (c != null) { Supabase.instance.client.removeChannel(c); }
    super.dispose();
  }

  Future<void> _markAllRead() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', uid)
        .eq('is_read', false);
    if (mounted) setState(() => future = _load());
  }

  IconData _icon(String type) {
    switch (type) {
      case 'task_approved':
        return Icons.verified_rounded;
      case 'task_rejected':
        return Icons.cancel_rounded;
      case 'withdrawal':
        return Icons.payments_rounded;
      case 'chat':
        return Icons.support_agent_rounded;
      case 'referral':
        return Icons.card_giftcard_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const Center(
              child: Text('You are all caught up. 🎉'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() => future = _load()),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final row = rows[i];
                final unread = row['is_read'] != true;
                return Material(
                  color: unread
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: unread ? () => _markRead('${row['id']}') : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            child: Icon(_icon('${row['type'] ?? ''}')),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${row['title'] ?? 'ZenexPay'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text('${row['body'] ?? ''}'),
                                const SizedBox(height: 7),
                                Text(
                                  '${row['created_at'] ?? ''}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (unread)
                            Container(
                              width: 9,
                              height: 9,
                              margin: const EdgeInsets.only(top: 5),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
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
}
