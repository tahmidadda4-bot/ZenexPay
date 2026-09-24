import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'zenex_ui.dart';
import 'screens/reset_password_page.dart'; 
// (যদি ফাইলটি screens ফোল্ডারে থাকে, তবে উপরের পাথটি দিন)

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
    const primary = Color(0xFF8B5CF6);
    const secondary = Color(0xFF36D7FF);
    const pink = Color(0xFFE946EF);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      secondary: secondary,
      tertiary: pink,
      surface: dark ? const Color(0xFF10162A) : Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: dark ? const Color(0xFF060914) : const Color(0xFFF5F7FF),
      splashColor: primary.withOpacity(.12),
      highlightColor: secondary.withOpacity(.06),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: dark ? Colors.white : const Color(0xFF151827)),
        titleTextStyle: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w900,
          letterSpacing: -.3,
          color: dark ? Colors.white : const Color(0xFF151827),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: dark ? const Color(0xFF10162A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF0E1426) : Colors.white,
        hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
        labelStyle: TextStyle(color: dark ? Colors.white60 : Colors.black54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: dark ? Colors.white10 : scheme.outlineVariant.withOpacity(.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: primary, width: 1.35),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: .1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: primary.withOpacity(.55)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: dark ? const Color(0xFF090E1D) : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withOpacity(.22),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: dark ? Colors.white70 : Colors.black87),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? secondary : (dark ? Colors.white54 : Colors.black54),
            size: selected ? 25 : 23,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: dark ? Colors.white10 : Colors.black12,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF171E35) : const Color(0xFF171A25),
        contentTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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

  DateTime? _lastBackPress;

  Future<void> _handleSystemBack() async {
    if (!mounted) return;

    // If the user is inside a tab other than Home, Back returns to Home
    // instead of closing the entire application.
    if (index != 0) {
      setState(() => index = 0);
      return;
    }

    // At the app root, require a second Back press before exiting.
    final now = DateTime.now();
    final last = _lastBackPress;
    if (last == null || now.difference(last) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit ZenexPay'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Second press: allow the normal Android app exit.
    await Future<void>.delayed(Duration.zero);
    if (mounted) {
      // PopScope cannot pop the root route because canPop=false.
      // This explicitly closes the Android activity only after the user
      // confirms with a second Back press.
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleSystemBack();
      },
      child: Scaffold(
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
  void initState() {
    super.initState();
    wallet = SupabaseService.wallet();
    NotificationService.registerCurrentDevice();
  }

  void _goToTab(int tab) => context.findAncestorStateOfType<_HomePageState>()?.goTo(tab);
  void _openSupport() => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatPage()));
  void _openNotifications() => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));

  Future<void> _refresh() async {
    setState(() => wallet = SupabaseService.wallet());
    await wallet;
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = (user?.userMetadata?['full_name'] as String?)?.trim();
    final firstName = (name == null || name.isEmpty) ? 'there' : name.split(' ').first;

    return ZenexPageBackground(
      child: RefreshIndicator(
        color: kCyan,
        backgroundColor: kSurface,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [kPurple, kBlue]),
                    boxShadow: [BoxShadow(color: kPurple.withOpacity(.28), blurRadius: 18)],
                  ),
                  child: const Center(child: Text('Z', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back, $firstName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text('Work • Earn • Grow', style: TextStyle(color: Colors.white.withOpacity(.48), fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _openNotifications,
                  style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(.055)),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ],
            ),
            const SizedBox(height: 22),

            FutureBuilder<Map<String, dynamic>?>(
              future: wallet,
              builder: (_, snapshot) {
                final balance = snapshot.data?['balance'] ?? 0;
                final earned = snapshot.data?['total_earned'] ?? 0;
                return ZenexGradient(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('TOTAL BALANCE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(20)),
                            child: const Row(children: [Icon(Icons.verified_rounded, size: 14, color: Colors.white), SizedBox(width: 4), Text('SECURE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900))]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('৳ ${_money(balance)}', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -.8)),
                      const SizedBox(height: 5),
                      Text('Available to use', style: TextStyle(color: Colors.white.withOpacity(.65), fontSize: 12)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _balanceMini('TOTAL EARNED', '৳ ${_money(earned)}', Icons.trending_up_rounded)),
                          const SizedBox(width: 10),
                          Expanded(child: _balanceMini('ACCOUNT', 'ACTIVE', Icons.check_circle_outline_rounded)),
                        ],
                      ),
                      const SizedBox(height: 17),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _goToTab(3),
                          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kPurple, minimumSize: const Size.fromHeight(47)),
                          icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                          label: const Text('Open Wallet'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            const SectionHeader(title: 'Quick actions', subtitle: 'Everything you need, one tap away'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _action('Tasks', Icons.task_alt_rounded, kCyan, () => _goToTab(1))),
              const SizedBox(width: 10),
              Expanded(child: _action('Submit proof', Icons.cloud_upload_rounded, kPurple, () => _goToTab(2))),
              const SizedBox(width: 10),
              Expanded(child: _action('Wallet', Icons.account_balance_wallet_rounded, kBlue, () => _goToTab(3))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _action('Support', Icons.support_agent_rounded, kPink, _openSupport)),
              const SizedBox(width: 10),
              Expanded(child: _action('Profile', Icons.person_rounded, kPurple, () => _goToTab(4))),
              const SizedBox(width: 10),
              Expanded(child: _action('Refresh', Icons.sync_rounded, kCyan, _refresh)),
            ]),
            const SizedBox(height: 22),

            const SectionHeader(title: 'Your progress', subtitle: 'Keep moving forward'),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(width: 44, height: 44, decoration: BoxDecoration(color: kPurple.withOpacity(.14), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.rocket_launch_rounded, color: kPurple)),
                      const SizedBox(width: 12),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Weekly activity', style: TextStyle(fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('Complete tasks to grow your earnings', style: TextStyle(color: Colors.white54, fontSize: 12))])),
                      const Text('65%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(borderRadius: BorderRadius.circular(10), child: const LinearProgressIndicator(value: .65, minHeight: 8, backgroundColor: Color(0xFF202943), valueColor: AlwaysStoppedAnimation(kCyan))),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Keep your streak alive', style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 11)), Text('Great progress!', style: TextStyle(color: kCyan, fontSize: 11, fontWeight: FontWeight.w800))]),
                ],
              ),
            ),
            const SizedBox(height: 22),

            const SectionHeader(title: 'How ZenexPay works', subtitle: 'Simple, transparent and secure'),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Column(children: const [
                _Step(icon: Icons.search_rounded, title: 'Choose a task', text: 'Explore available tasks and read the requirements.'),
                _Step(icon: Icons.upload_file_rounded, title: 'Submit proof', text: 'Complete the work and send the required proof.'),
                _Step(icon: Icons.verified_rounded, title: 'Get reviewed', text: 'Approved rewards are added to your wallet.'),
                _Step(icon: Icons.support_agent_rounded, title: 'Need help?', text: 'Reach ZenexPay Support whenever you need assistance.'),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceMini(String title, String value, IconData icon) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white.withOpacity(.10))),
        child: Row(children: [Icon(icon, color: Colors.white70, size: 17), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))]))]),
      );

  Widget _action(String label, IconData icon, Color color, VoidCallback onTap) => GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 7),
        onTap: onTap,
        child: Column(children: [IconTile(icon: icon, color: color, size: 46), const SizedBox(height: 8), Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800))]),
      );
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _Step({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          IconTile(icon: icon, color: kCyan, size: 38),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)), const SizedBox(height: 3), Text(text, style: TextStyle(color: Colors.white.withOpacity(.52), fontSize: 11, height: 1.35))])),
        ]),
      );

String _money(dynamic value) => (double.tryParse('$value') ?? 0).toStringAsFixed(2);
