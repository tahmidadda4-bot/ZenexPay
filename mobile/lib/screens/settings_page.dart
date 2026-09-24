import 'package:flutter/material.dart';
import '../theme_controller.dart';
import 'help_page.dart';
import 'legal_page.dart';
import 'security_page.dart';
import 'notifications_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _push(BuildContext c, Widget page) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          _HeroCard(
            icon: Icons.tune_rounded,
            title: 'Personalize ZenexPay',
            subtitle: 'Control appearance, notifications and account options.',
          ),
          const SizedBox(height: 16),
          _Group(
            children: [
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeModeNotifier,
                builder: (_, mode, __) => SwitchListTile.adaptive(
                  secondary: const _TileIcon(Icons.dark_mode_rounded),
                  title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Use the premium dark interface'),
                  value: mode == ThemeMode.dark,
                  onChanged: (v) => themeModeNotifier.value = v ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
              const Divider(height: 1),
              _Row(
                icon: Icons.notifications_active_rounded,
                title: 'Notifications',
                subtitle: 'View your latest account updates',
                onTap: () => _push(context, const NotificationsPage()),
              ),
              const Divider(height: 1),
              _Row(
                icon: Icons.security_rounded,
                title: 'Security',
                subtitle: 'Password and account security',
                onTap: () => _push(context, const SecurityPage()),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Group(
            children: [
              _Row(
                icon: Icons.help_outline_rounded,
                title: 'Help & FAQ',
                subtitle: 'Answers to common questions',
                onTap: () => _push(context, const HelpPage()),
              ),
              const Divider(height: 1),
              _Row(
                icon: Icons.description_outlined,
                title: 'Terms & Privacy',
                subtitle: 'Read the app terms and privacy information',
                onTap: () => _push(context, const LegalPage()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _HeroCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F5CFF), Color(0xFF6B35F4)],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: const Color(0xFF4D5DFF).withOpacity(.20), blurRadius: 26, offset: const Offset(0, 12))],
        ),
        child: Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(17)), child: Icon(icon, color: Colors.white, size: 27)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(color: Colors.white70, height: 1.35)),
          ])),
        ]),
      );
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.45)),
        ),
        child: Column(children: children),
      );
}

class _TileIcon extends StatelessWidget {
  final IconData icon;
  const _TileIcon(this.icon);
  @override
  Widget build(BuildContext context) => Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(.10), borderRadius: BorderRadius.circular(13)),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Row({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: _TileIcon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}
