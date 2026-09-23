import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'firebase_options.dart';
import 'screens/auth_page.dart';
import 'screens/tasks_page.dart';
import 'screens/submissions_page.dart';
import 'screens/wallet_page.dart';
import 'screens/profile_page.dart';
import 'screens/chat_page.dart';
import 'screens/notifications_page.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';
import 'theme_controller.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.init();

  runApp(const ZenexPayApp());
}

class ZenexPayApp extends StatelessWidget {
  const ZenexPayApp({super.key});

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B5AF7),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF070B14) : const Color(0xFFF5F7FB),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: dark ? const Color(0xFF111827) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF111827) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(.35))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.primary, width: 1.4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        backgroundColor: dark ? const Color(0xFF0B1020) : Colors.white,
        indicatorColor: scheme.primary.withOpacity(.16),
        labelTextStyle: WidgetStatePropertyAll(const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (_, mode, __) => MaterialApp(
        navigatorKey: rootNavigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'ZenexPay',
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: mode,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool recovery = false;

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      setState(() => recovery = data.event == AuthChangeEvent.passwordRecovery);
      if (data.event != AuthChangeEvent.passwordRecovery &&
          data.session != null) {
        NotificationService.registerCurrentDevice();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (recovery) {
      return const _RecoveryGate();
    }
    return Supabase.instance.client.auth.currentSession == null
        ? const AuthPage()
        : const HomePage();
  }
}

class _RecoveryGate extends StatelessWidget {
  const _RecoveryGate();

  @override
  Widget build(BuildContext context) {
    return UpdatePasswordPage();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  final pages = const [_Dashboard(), TasksPage(), SubmissionsPage(), WalletPage(), ProfilePage()];
  void goTo(int value) { if (mounted) setState(() => index = value); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: goTo,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt_rounded), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: 'Proofs'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

class _Dashboard extends StatefulWidget {
  const _Dashboard();
  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  late Future<Map<String, dynamic>?> wallet;
  @override
  void initState() { super.initState(); wallet = SupabaseService.wallet(); NotificationService.registerCurrentDevice(); }
  void _goToTab(int tab) => context.findAncestorStateOfType<_HomePageState>()?.goTo(tab);
  void _openSupport() => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatPage()));
  void _openNotifications() => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = (user?.userMetadata?['full_name'] as String?)?.trim();
    return RefreshIndicator(
      onRefresh: () async { setState(() => wallet = SupabaseService.wallet()); await wallet; },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Row(
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hello${name == null || name.isEmpty ? '' : ', $name'} 👋', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Your work, earnings and tasks — all in one place.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ])),
              IconButton.filledTonal(onPressed: _openNotifications, icon: const Icon(Icons.notifications_none_rounded)),
            ],
          ),
          const SizedBox(height: 18),
          FutureBuilder<Map<String, dynamic>?>(
            future: wallet,
            builder: (_, s) {
              final b = s.data?['balance'] ?? 0;
              final e = s.data?['total_earned'] ?? 0;
              return Container(
                padding: const EdgeInsets.all(23),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF126DFF), Color(0xFF6B35F4)]),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: const Color(0xFF4D5DFF).withOpacity(.25), blurRadius: 28, offset: const Offset(0, 12))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 20), SizedBox(width: 8), Text('AVAILABLE BALANCE', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.1))]),
                  const SizedBox(height: 8),
                  Text('৳ ${_money(b)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 15),
                  Row(children: [Expanded(child: Text('Total earned  ৳ ${_money(e)}', style: const TextStyle(color: Colors.white70))), FilledButton.tonal(onPressed: () => _goToTab(3), child: const Text('Wallet'))]),
                ]),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(children: [
            _quick(Icons.task_alt_rounded, 'Tasks', () => _goToTab(1)),
            const SizedBox(width: 10),
            _quick(Icons.assignment_rounded, 'Proofs', () => _goToTab(2)),
            const SizedBox(width: 10),
            _quick(Icons.support_agent_rounded, 'Support', _openSupport),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _quick(Icons.account_balance_wallet_rounded, 'Wallet', () => _goToTab(3)),
            const SizedBox(width: 10),
            _quick(Icons.person_rounded, 'Profile', () => _goToTab(4)),
            const SizedBox(width: 10),
            _quick(Icons.refresh_rounded, 'Refresh', () => setState(() => wallet = SupabaseService.wallet())),
          ]),
          const SizedBox(height: 18),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('How ZenexPay works', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            SizedBox(height: 14),
            _Step(icon: Icons.search_rounded, title: 'Choose a task', text: 'Read the task rules before starting.'),
            _Step(icon: Icons.upload_file_rounded, title: 'Submit proof', text: 'Send the requested proof honestly.'),
            _Step(icon: Icons.verified_rounded, title: 'Get reviewed', text: 'Approved rewards are added securely.'),
            _Step(icon: Icons.support_agent_rounded, title: 'Need help?', text: 'Contact ZenexPay Admin from Support.'),
          ]))),
        ],
      ),
    );
  }

  Widget _quick(IconData icon, String label, VoidCallback onTap) => Expanded(child: Card(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Column(children: [Icon(icon), const SizedBox(height: 7), Text(label, style: const TextStyle(fontWeight: FontWeight.w800))])))));
}

class _Step extends StatelessWidget {
  final IconData icon; final String title; final String text;
  const _Step({required this.icon, required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 13), child: Row(children: [CircleAvatar(radius: 17, child: Icon(icon, size: 18)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), Text(text)]))]));
}

String _money(dynamic value) => (double.tryParse('$value') ?? 0).toStringAsFixed(2);
