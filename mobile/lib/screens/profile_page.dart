import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme_controller.dart';
import 'analytics_page.dart';
import 'achievements_page.dart';
import 'referral_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = (user?.userMetadata?['full_name'] as String?)?.trim() ?? '';
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF155EEF), Color(0xFF7C3AED)]),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(children: [
              CircleAvatar(radius: 31, backgroundColor: Colors.white24, child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isEmpty ? 'ZenexPay User' : name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4), Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),
          Card(child: Column(children: [
            ListTile(leading: const CircleAvatar(child: Icon(Icons.insights_rounded)), title: const Text('Earnings analytics', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Charts, earnings and task performance'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsPage()))),
            const Divider(height: 1),
            ListTile(leading: const CircleAvatar(child: Icon(Icons.workspace_premium_rounded)), title: const Text('Level & achievements', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Unlock milestones from approved work'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsPage()))),
            const Divider(height: 1),
            ListTile(leading: const CircleAvatar(child: Icon(Icons.people_alt_rounded)), title: const Text('Referral center', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Share your code and track referrals'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReferralPage()))),
          ])),
          const SizedBox(height: 14),
          Card(child: Column(children: [
            ValueListenableBuilder<ThemeMode>(valueListenable: themeModeNotifier, builder: (_, mode, __) => SwitchListTile.adaptive(
              secondary: const CircleAvatar(child: Icon(Icons.dark_mode_outlined)),
              title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Switch the premium interface theme'),
              value: mode == ThemeMode.dark,
              onChanged: (v) => themeModeNotifier.value = v ? ThemeMode.dark : ThemeMode.light,
            )),
            const Divider(height: 1),
            ListTile(leading: const Icon(Icons.help_outline_rounded), title: const Text('Help & support'), onTap: () => showDialog(context: context, builder: (_) => const AlertDialog(title: Text('Help & support'), content: Text('For task, screenshot, wallet or withdrawal issues, contact the ZenexPay support/admin team.')))),
            const Divider(height: 1),
            const ListTile(leading: Icon(Icons.security_outlined), title: Text('Account security'), subtitle: Text('Authenticated with Supabase')),
          ])),
          const SizedBox(height: 18),
          OutlinedButton.icon(onPressed: () async => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout_rounded), label: const Text('Sign out')),
        ],
      ),
    );
  }
}
