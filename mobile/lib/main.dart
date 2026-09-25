import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'firebase_options.dart';
import 'screens/auth_page.dart';
import 'screens/tasks_page.dart';
import 'screens/submissions_page.dart';
import 'screens/wallet_page.dart';
import 'screens/profile_page.dart';
import 'screens/referral_page.dart';
import 'services/notification_service.dart';
import 'services/internet_connection_gate.dart';
import 'theme_controller.dart';
import 'screens/reset_password_page.dart';
import 'screens/dashboard_page.dart';
import 'screens/onboarding_page.dart';
import 'zenex_ui.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.init();
  runApp(const ZenexPayApp());
}

class ZenexPayApp extends StatelessWidget {
  const ZenexPayApp({super.key});

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: kPurple, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme.copyWith(primary: kPurple, secondary: kBlue, surface: dark ? const Color(0xFF0D1730) : Colors.white),
      scaffoldBackgroundColor: dark ? kNavy : const Color(0xFFF4F7FC),
      dividerColor: dark ? const Color(0xFF23457F) : const Color(0xFFE3E8F1),
      appBarTheme: AppBarTheme(elevation: 0, centerTitle: false, backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent, foregroundColor: dark ? Colors.white : scheme.onSurface, titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: dark ? Colors.white : scheme.onSurface)),
      cardTheme: CardThemeData(elevation: 0, margin: EdgeInsets.zero, color: dark ? const Color(0xFF0D1730) : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: dark ? const Color(0xFF0C1730) : Colors.white, labelStyle: TextStyle(color: dark ? Colors.white60 : Colors.black54), hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: dark ? const Color(0xFF244C96) : Colors.transparent)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: dark ? const Color(0xFF244C96) : scheme.outlineVariant.withOpacity(.35))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kBlue, width: 1.4)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: kPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), textStyle: const TextStyle(fontWeight: FontWeight.w900))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: dark ? Colors.white : scheme.primary, side: BorderSide(color: dark ? const Color(0xFF315B9D) : scheme.primary.withOpacity(.35)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), textStyle: const TextStyle(fontWeight: FontWeight.w800))),
      navigationBarTheme: NavigationBarThemeData(height: 72, backgroundColor: dark ? const Color(0xFF070C1B) : Colors.white, surfaceTintColor: Colors.transparent, indicatorColor: kPurple.withOpacity(.24), labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 10, fontWeight: FontWeight.w800)), iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(color: states.contains(WidgetState.selected) ? Colors.white : Colors.white54)),),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: dark ? const Color(0xFF172342) : const Color(0xFF111827), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(valueListenable: themeModeNotifier, builder: (_, mode, __) => MaterialApp(navigatorKey: rootNavigatorKey, debugShowCheckedModeBanner: false, title: 'ZenexPay', theme: _theme(Brightness.light), darkTheme: _theme(Brightness.dark), themeMode: mode, home: const InternetConnectionGate(child: AuthGate())));
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool recovery = false, loading = true, onboardingSeen = false;
  static const _onboardingKey = 'zenexpay_onboarding_seen_v3';

  @override
  void initState() {
    super.initState();
    _loadStartupState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      setState(() => recovery = data.event == AuthChangeEvent.passwordRecovery);
      if (data.event != AuthChangeEvent.passwordRecovery && data.session != null) NotificationService.registerCurrentDevice();
    });
  }

  Future<void> _loadStartupState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() { onboardingSeen = prefs.getBool(_onboardingKey) ?? false; loading = false; });
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    if (mounted) setState(() => onboardingSeen = true);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const _StartupSplash();
    if (!onboardingSeen) return OnboardingPage(onFinished: _finishOnboarding);
    if (recovery) return const UpdatePasswordPage();
    return Supabase.instance.client.auth.currentSession == null ? const AuthPage() : const HomePage();
  }
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash();
  @override
  Widget build(BuildContext context) => Scaffold(body: ZenexGlowBackground(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: const [ZenexLogo(size: 76), SizedBox(height: 18), Text('ZenexPay', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)), SizedBox(height: 6), Text('WORK  •  EARN  •  GROW', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1.5)), SizedBox(height: 30), SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2))]))));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  late final List<Widget> pages = [DashboardPage(onTabSelected: goTo), const TasksPage(), const WalletPage(), const ReferralPage(), const ProfilePage()];
  void goTo(int value) { if (mounted) setState(() => index = value); }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(top: false, child: IndexedStack(index: index, children: pages)),
    bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: goTo, destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt_rounded), label: 'Tasks'),
      NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Wallet'),
      NavigationDestination(icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt_rounded), label: 'Referral'),
      NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
    ]),
  );
}
