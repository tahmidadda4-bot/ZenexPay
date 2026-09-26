import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;

    try {
      final rows = await client
          .from('wallets')
          .select('user_id,balance,total_earned')
          .order('total_earned', ascending: false)
          .limit(50);

      final data = List<Map<String, dynamic>>.from(rows);

      // Resolve names individually only when a profiles table is available.
      // If it is not, the leaderboard still works with a safe fallback label.
      for (final row in data) {
        row['display_name'] = 'User ${_shortId('${row['user_id'] ?? ''}')}';
        try {
          final profile = await client
              .from('profiles')
              .select('full_name')
              .eq('id', row['user_id'])
              .maybeSingle();
          final name = '${profile?['full_name'] ?? ''}'.trim();
          if (name.isNotEmpty) row['display_name'] = name;
        } catch (_) {
          // Optional profile lookup; keep the wallet ranking usable.
        }
      }

      return data;
    } catch (_) {
      // If the project has no leaderboard-ready wallet data, return an empty
      // state rather than leaving the screen broken.
      return <Map<String, dynamic>>[];
    }
  }

  String _shortId(String id) {
    if (id.isEmpty) return '—';
    return id.length <= 6 ? id : id.substring(0, 6);
  }

  String _money(dynamic value) {
    final n = double.tryParse('$value') ?? 0;
    return '৳ ${n.toStringAsFixed(2)}';
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rows = snapshot.data ?? const <Map<String, dynamic>>[];

          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events_outlined, size: 64, color: cs.primary),
                    const SizedBox(height: 14),
                    const Text(
                      'Leaderboard is not available yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Complete tasks and the ranking will appear here when wallet data is available.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (_, i) {
                final row = rows[i];
                final name = '${row['display_name'] ?? 'User'}';
                final earned = row['total_earned'] ?? row['balance'] ?? 0;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: i < 3
                          ? cs.primary.withOpacity(.14)
                          : cs.surfaceContainerHighest,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(i == 0 ? 'Top earner' : 'Rank #${i + 1}'),
                    trailing: Text(
                      _money(earned),
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w900,
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
