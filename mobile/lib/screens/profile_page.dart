import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme_controller.dart';
import '../zenex_ui.dart';
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
    final initial = name.isEmpty ? 'Z' : name.substring(0, 1).toUpperCase();
    final muted = Colors.white60;

    return ZenexPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              onPressed: () => _push(c, const SecurityPage()),
              tooltip: 'Security',
              icon: const Icon(Icons.shield_outlined),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
          children: [
            _ProfileHero(name: name, email: email, initial: initial),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _MiniStat(icon: Icons.verified_rounded, label: 'Status', value: 'Active', accent: kCyan)),
                const SizedBox(width: 10),
                Expanded(child: _MiniStat(icon: Icons.bolt_rounded, label: 'Mode', value: 'Earning', accent: kPurple)),
              ],
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Earning center', subtitle: 'Track your progress and rewards'),
            const SizedBox(height: 10),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _MenuRow(
                    icon: Icons.insights_rounded,
                    title: 'Earnings analytics',
                    subtitle: 'Charts, earnings and performance',
                    accent: kCyan,
                    onTap: () => _push(c, const AnalyticsPage()),
                  ),
                  _Divider(),
                  _MenuRow(
                    icon: Icons.workspace_premium_rounded,
                    title: 'Level & achievements',
                    subtitle: 'Milestones from approved work',
                    accent: kPink,
                    onTap: () => _push(c, const AchievementsPage()),
                  ),
                  _Divider(),
                  _MenuRow(
                    icon: Icons.people_alt_rounded,
                    title: 'Referral center',
                    subtitle: 'Share and track referrals',
                    accent: kPurple,
                    onTap: () => _push(c, const ReferralPage()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Account & support', subtitle: 'Preferences, help and security'),
            const SizedBox(height: 10),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeModeNotifier,
                    builder: (_, mode, __) => SwitchListTile.adaptive(
                      secondary: Icon(Icons.dark_mode_outlined, color: kPurple),
                      title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text('Use the premium dark interface', style: TextStyle(color: muted, fontSize: 12)),
                      value: mode == ThemeMode.dark,
                      onChanged: (v) => themeModeNotifier.value = v ? ThemeMode.dark : ThemeMode.light,
                    ),
                  ),
                  _Divider(),
                  _MenuRow(
                    icon: Icons.support_agent_rounded,
                    title: 'Chat with Admin',
                    subtitle: 'Tasks, proof, wallet or withdrawals',
                    accent: kCyan,
                    onTap: () => _push(c, const ChatPage()),
                  ),
                  _Divider(),
                  _MenuRow(
                    icon: Icons.security_rounded,
                    title: 'Account security',
                    subtitle: 'Password and account security',
                    accent: kPink,
                    onTap: () => _push(c, const SecurityPage()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kSurface.withOpacity(.75),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(.07)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: kCyan.withOpacity(.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.lock_rounded, color: kCyan, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Your account is protected by server-controlled authentication and wallet records.',
                      style: TextStyle(color: Colors.white70, height: 1.35, fontSize: 12),
                    ),
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
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: Colors.white,
                side: BorderSide(color: kPink.withOpacity(.45)),
                backgroundColor: kPink.withOpacity(.04),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text('ZenexPay • Work • Earn • Grow', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final String name;
  final String email;
  final String initial;
  const _ProfileHero({required this.name, required this.email, required this.initial});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF171A3C), Color(0xFF34206B), Color(0xFF111A3A)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: kPurple.withOpacity(.30)),
          boxShadow: [BoxShadow(color: kPurple.withOpacity(.14), blurRadius: 28, offset: const Offset(0, 12))],
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kCyan, kBlue, kPurple]),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: kCyan.withOpacity(.18), blurRadius: 18)],
              ),
              child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900))),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('YOUR ZENEXPAY PROFILE', style: TextStyle(color: kCyan, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 5),
                  Text(name.isEmpty ? 'ZenexPay User' : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(email.isEmpty ? 'Account email' : email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  const _MiniStat({required this.icon, required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kSurface.withOpacity(.80),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: Colors.white.withOpacity(.07)),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 20),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white45, fontSize: 10)), const SizedBox(height: 2), Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))])),
          ],
        ),
      );
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  const _MenuRow({required this.icon, required this.title, required this.subtitle, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: accent.withOpacity(.10), borderRadius: BorderRadius.circular(15), border: Border.all(color: accent.withOpacity(.14))),
          child: Icon(icon, color: accent),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
        onTap: onTap,
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(height: 1, color: Colors.white.withOpacity(.07));
}
