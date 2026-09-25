import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'notifications_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<Map<String, dynamic>?> wallet;

  @override
  void initState() {
    super.initState();
    wallet = SupabaseService.wallet();
  }

  String money(dynamic v) => (double.tryParse('$v') ?? 0).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = '${user?.userMetadata?['full_name'] ?? ''}'.trim();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() => wallet = SupabaseService.wallet());
            await wallet;
          },
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello${name.isEmpty ? '' : ', $name'} 👋',
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Start your earning journey',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FutureBuilder<Map<String, dynamic>?>(
                future: wallet,
                builder: (_, s) {
                  final b = s.data?['balance'] ?? 0;
                  final e = s.data?['total_earned'] ?? 0;
                  return Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF126DFF), Color(0xFF7A42FF)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WALLET BALANCE',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '৳ ${money(b)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total earned ৳ ${money(e)}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'Start earning',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _card(
                context,
                Icons.task_alt_rounded,
                'Browse Tasks',
                'Complete simple tasks and earn rewards',
              ),
              _card(
                context,
                Icons.account_balance_wallet_rounded,
                'Wallet',
                'View balance, withdrawals and transactions',
              ),
              _card(
                context,
                Icons.people_alt_rounded,
                'Referral Center',
                'Invite friends and track rewards',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, IconData icon, String title, String subtitle) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );
}
