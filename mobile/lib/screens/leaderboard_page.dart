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
      final rows = await client.rpc(
        'get_global_leaderboard',
        params: {'p_limit': 100},
      );
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
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
                final rank = int.tryParse('${row['rank'] ?? i + 1}') ?? i + 1;
                final earned = row['total_earned'] ?? 0;
                final balance = row['balance'] ?? 0;
                final completed = int.tryParse('${row['completed_tasks'] ?? 0}') ?? 0;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: rank <= 3
                          ? cs.primary.withOpacity(.14)
                          : cs.surfaceContainerHighest,
                      child: Text(
                        '$rank',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      'Balance: ${_money(balance)}  •  Tasks: $completed',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
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
