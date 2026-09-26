import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import '../theme_controller.dart';
import 'analytics_page.dart';
import 'achievements_page.dart';
import 'referral_page.dart';
import 'chat_page.dart';
import 'security_page.dart';
import 'settings_page.dart';
import 'help_page.dart';
import 'legal_page.dart';
import 'notifications_page.dart';
import 'leaderboard_page.dart';
import 'activity_page.dart';
import 'onboarding_page.dart';
import '../zenex_ui.dart';
import '../services/supabase_service.dart';
import '../services/network_error.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  void _push(BuildContext c, Widget p) => Navigator.push(c, MaterialPageRoute(builder: (_) => p));
  bool editing = false;
  bool saving = false;
  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  @override void dispose() { nameController.dispose(); phoneController.dispose(); super.dispose(); }

  Future<void> _edit() async {
    try {
      final row = await SupabaseService.profile();
      nameController.text = '${row?['full_name'] ?? ''}';
      phoneController.text = '${row?['phone'] ?? ''}';
    } catch (_) {}
    if (mounted) setState(() => editing = true);
  }

  Future<void> _save() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty.')));
      return;
    }
    setState(() => saving = true);
    try {
      await SupabaseService.updateProfile(fullName: nameController.text, phone: phoneController.text);
      if (!mounted) return;
      setState(() => editing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved successfully.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext c) {
    final u = Supabase.instance.client.auth.currentUser;
    final name = (u?.userMetadata?['full_name'] as String?)?.trim() ?? '';
    final email = u?.email ?? '';
    final initial = name.isEmpty ? 'Z' : name.substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: () => _push(c, const NotificationsPage()), icon: const Icon(Icons.notifications_none_rounded)), IconButton(onPressed: editing ? null : _edit, icon: const Icon(Icons.edit_rounded))],
      ),
      body: ZenexGlowBackground(safeArea: false, child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0F5CFF), Color(0xFF6B35F4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: const Color(0xFF4D5DFF).withOpacity(.20), blurRadius: 26, offset: const Offset(0, 12))],
            ),
            child: Row(children: [
              Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(20)), child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name.isEmpty ? 'ZenexPay User' : name, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70))])),
            ]),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fingerprint_rounded),
              title: const Text('User ID', style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(u?.id ?? 'Unavailable', maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                tooltip: 'Copy User ID',
                onPressed: (u?.id ?? '').isEmpty ? null : () async {
                  await Clipboard.setData(ClipboardData(text: u!.id));
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User ID copied.')));
                },
                icon: const Icon(Icons.copy_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (editing) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: OutlinedButton(onPressed: saving ? null : () => setState(() => editing = false), child: const Text('Cancel'))), const SizedBox(width: 10), Expanded(child: FilledButton(onPressed: saving ? null : _save, child: Text(saving ? 'Saving…' : 'Save')))]),
          ]))),
          const SizedBox(height: 18),
          _MenuCard(items: [
            _Item(Icons.insights_rounded, 'Earnings analytics', 'Charts, earnings and performance', () => _push(c, const AnalyticsPage())),
            _Item(Icons.workspace_premium_rounded, 'Level & achievements', 'Milestones from approved work', () => _push(c, const AchievementsPage())),
            _Item(Icons.people_alt_rounded, 'Referral center', 'Share and track referrals', () => _push(c, const ReferralPage())),
            _Item(Icons.history_rounded, 'My activity', 'See your account actions and timestamps', () => _push(c, const ActivityPage())),
            _Item(Icons.leaderboard_rounded, 'Leaderboard', 'See the current earning ranking', () => _push(c, const LeaderboardPage())),
          ]),
          const SizedBox(height: 14),
          _MenuCard(items: [
            _Item(Icons.settings_rounded, 'Settings', 'Appearance, notifications and account options', () => _push(c, const SettingsPage())),
            _Item(Icons.support_agent_rounded, 'Chat with Admin', 'Tasks, proof, wallet or withdrawals', () => _push(c, const ChatPage())),
            _Item(Icons.security_rounded, 'Account security', 'Password and account security', () => _push(c, const SecurityPage())),
            _Item(Icons.help_outline_rounded, 'Help & FAQ', 'Quick answers to common questions', () => _push(c, const HelpPage())),
            _Item(Icons.description_outlined, 'Terms & Privacy', 'Service and privacy information', () => _push(c, const LegalPage())),
            _Item(Icons.tour_rounded, 'App Tour', 'Review the ZenexPay features again', () => _push(c, const OnboardingPage(isTour: true))),
          ]),
          const SizedBox(height: 18),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (_, mode, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(color: Theme.of(c).colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(c).dividerColor.withOpacity(.45))),
              child: SwitchListTile.adaptive(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Use the premium dark interface'),
                value: mode == ThemeMode.dark,
                onChanged: (v) => themeModeNotifier.value = v ? ThemeMode.dark : ThemeMode.light,
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: () async { await SupabaseService.logActivity(action: 'logout', entityType: 'auth'); await Supabase.instance.client.auth.signOut(); }, icon: const Icon(Icons.logout_rounded), label: const Text('Sign out')),
        ],
      )),
    );
  }
}

class _Item { final IconData i; final String t, s; final VoidCallback onTap; const _Item(this.i, this.t, this.s, this.onTap); }

class _MenuCard extends StatelessWidget {
  final List<_Item> items;
  const _MenuCard({required this.items});
  @override
  Widget build(BuildContext c) => Container(
    decoration: BoxDecoration(color: Theme.of(c).colorScheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: Theme.of(c).dividerColor.withOpacity(.45))),
    child: Column(children: [for (int i = 0; i < items.length; i++) ...[_MenuRow(item: items[i]), if (i < items.length - 1) const Divider(height: 1)]]),
  );
}

class _MenuRow extends StatelessWidget {
  final _Item item;
  const _MenuRow({required this.item});
  @override
  Widget build(BuildContext c) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
    leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: Theme.of(c).colorScheme.primary.withOpacity(.10), borderRadius: BorderRadius.circular(14)), child: Icon(item.i, color: Theme.of(c).colorScheme.primary)),
    title: Text(item.t, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(item.s), trailing: const Icon(Icons.chevron_right_rounded), onTap: item.onTap,
  );
}
