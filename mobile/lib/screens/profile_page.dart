import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme_controller.dart';
import 'analytics_page.dart';
import 'achievements_page.dart';
import 'referral_page.dart';
import 'chat_page.dart';
import 'security_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _push(BuildContext c, Widget p) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => p));

  @override
  Widget build(BuildContext c) {
    final u = Supabase.instance.client.auth.currentUser;
    final name = (u?.userMetadata?['full_name'] as String?)?.trim() ?? '';
    final email = u?.email ?? '';
    final initial =
        name.isEmpty ? 'Z' : name.substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF111827), Color(0xFF5B5AF7)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'ZenexPay User' : name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _MenuCard(
            items: [
              _Item(
                  Icons.insights_rounded,
                  'Earnings analytics',
                  'Charts, earnings and performance',
                  () => _push(c, const AnalyticsPage())),
              _Item(
                  Icons.workspace_premium_rounded,
                  'Level & achievements',
                  'Milestones from approved work',
                  () => _push(c, const AchievementsPage())),
              _Item(
                  Icons.people_alt_rounded,
                  'Referral center',
                  'Share and track referrals',
                  () => _push(c, const ReferralPage())),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(c).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: Theme.of(c).dividerColor.withOpacity(.5)),
            ),
            child: Column(
              children: [
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeModeNotifier,
                  builder: (_, mode, __) => SwitchListTile.adaptive(
                    secondary: const Icon(Icons.dark_mode_outlined),
                    title: const Text('Dark mode',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Use the premium dark interface'),
                    value: mode == ThemeMode.dark,
                    onChanged: (v) => themeModeNotifier.value =
                        v ? ThemeMode.dark : ThemeMode.light,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded),
                  title: const Text('Chat with Admin',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Tasks, proof, wallet or withdrawals'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(c, const ChatPage()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security_rounded),
                  title: const Text('Account security',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Password and account security'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(c, const SecurityPage()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _Item {
  final IconData i;
  final String t, s;
  final VoidCallback onTap;
  const _Item(this.i, this.t, this.s, this.onTap);
}

class _MenuCard extends StatelessWidget {
  final List<_Item> items;
  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext c) => Container(
        decoration: BoxDecoration(
          color: Theme.of(c).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(c).dividerColor.withOpacity(.5)),
        ),
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              _MenuRow(item: items[i]),
              if (i < items.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      );
}

class _MenuRow extends StatelessWidget {
  final _Item item;
  const _MenuRow({required this.item});

  @override
  Widget build(BuildContext c) => ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(c).colorScheme.primary.withOpacity(.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(item.i, color: Theme.of(c).colorScheme.primary),
        ),
        title: Text(item.t,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(item.s),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: item.onTap,
      );
}
