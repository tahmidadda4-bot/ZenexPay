import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'tasks_page.dart';
import 'wallet_page.dart';
import 'referral_page.dart';
import 'profile_page.dart';

/// Standalone Home shell kept for integrations that navigate to screens/home_page.dart.
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  late final List<Widget> pages = [DashboardPage(onTabSelected: (v) => setState(() => index = v)), const TasksPage(), const WalletPage(), const ReferralPage(), const ProfilePage()];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(top: false, child: IndexedStack(index: index, children: pages)),
    bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (v) => setState(() => index = v), destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt_rounded), label: 'Tasks'),
      NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Wallet'),
      NavigationDestination(icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt_rounded), label: 'Referral'),
      NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
    ]),
  );
}
