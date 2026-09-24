import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme_controller.dart';
import 'analytics_page.dart';
import 'achievements_page.dart';
import 'referral_page.dart';
import 'chat_page.dart';
import 'security_page.dart';

const _blue = Color(0xFF4F8CFF);
const _purple = Color(0xFF8B5CF6);
const _navy = Color(0xFF070B18);

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _push(BuildContext c, Widget page) => Navigator.push(
        c,
        MaterialPageRoute(builder: (_) => page),
      );

  @override
  Widget build(BuildContext c) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = (user?.userMetadata?['full_name'] as String?)?.trim() ?? '';
    final email = user?.email ?? '';
    final initial = name.isEmpty ? (email.isEmpty ? 'Z' : email[0].toUpperCase()) : name[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Security',
            onPressed: () => _push(c, const SecurityPage()),
            icon: const Icon(Icons.shield_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _ProfileHero(name: name.isEmpty ? 'ZenexPay User' : name, email: email, initial: initial),
          const SizedBox(height: 16),
          const _SectionTitle('Your ZenexPay'),
          const SizedBox(height: 10),
          _ActionCard(
            icon: Icons.insights_rounded,
            title: 'Earnings analytics',
            subtitle: 'Track earnings, approvals and activity',
            onTap: () => _push(c, const AnalyticsPage()),
          ),
          const SizedBox(height: 10),
          _ActionCard(
            icon: Icons.workspace_premium_rounded,
            title: 'Level & achievements',
            subtitle: 'Milestones, badges and your progress',
            onTap: () => _push(c, const AchievementsPage()),
          ),
          const SizedBox(height: 10),
          _ActionCard(
            icon: Icons.groups_rounded,
            title: 'Referral center',
            subtitle: 'Invite friends and manage referral codes',
            onTap: () => _push(c, const ReferralPage()),
          ),
          const SizedBox(height: 18),
          const _SectionTitle('Preferences & support'),
          const SizedBox(height: 10),
          _SettingsCard(children: [
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeModeNotifier,
              builder: (_, mode, __) => SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                secondary: const _IconBox(icon: Icons.dark_mode_outlined),
                title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Use the premium dark interface'),
                value: mode == ThemeMode.dark,
                onChanged: (v) => themeModeNotifier.value = v ? ThemeMode.dark : ThemeMode.light,
              ),
            ),
            const Divider(height: 1),
            _SettingTile(
              icon: Icons.support_agent_rounded,
              title: 'Chat with Admin',
              subtitle: 'Tasks, proof, wallet or withdrawals',
              onTap: () => _push(c, const ChatPage()),
            ),
            const Divider(height: 1),
            _SettingTile(
              icon: Icons.security_rounded,
              title: 'Account security',
              subtitle: 'Password and account security',
              onTap: () => _push(c, const SecurityPage()),
            ),
          ]),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: Theme.of(c).colorScheme.error,
              side: BorderSide(color: Theme.of(c).colorScheme.error.withOpacity(.35)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
            onPressed: () async => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final String name, email, initial;
  const _ProfileHero({required this.name, required this.email, required this.initial});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_navy, Color(0xFF162A64), _purple],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: _purple.withOpacity(.20), blurRadius: 28, offset: const Offset(0, 12))],
        ),
        child: Row(children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.13),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(.16)),
            ),
            alignment: Alignment.center,
            child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(email.isEmpty ? 'Account' : email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified_rounded, color: Colors.white, size: 14), SizedBox(width: 5), Text('ZenexPay member', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))]),
            ),
          ])),
        ]),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900));
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(21),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(21), border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.45))),
            child: Row(children: [
              _IconBox(icon: icon),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey))])),
              const Icon(Icons.chevron_right_rounded),
            ]),
          ),
        ),
      );
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.45))), child: Column(children: children));
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _SettingTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), leading: _IconBox(icon: icon), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right_rounded), onTap: onTap);
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  const _IconBox({required this.icon});
  @override
  Widget build(BuildContext context) => Container(width: 44, height: 44, decoration: BoxDecoration(color: _blue.withOpacity(.11), borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Icon(icon, color: _blue, size: 21));
}
