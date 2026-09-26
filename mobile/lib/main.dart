import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
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
      fontFamily: 'Roboto',
      colorScheme: scheme.copyWith(primary: kPurple, secondary: kBlue, tertiary: kCyan, surface: dark ? const Color(0xFF071633) : Colors.white),
      scaffoldBackgroundColor: dark ? kNavy : const Color(0xFFF4F7FC),
      canvasColor: dark ? kNavy : const Color(0xFFF4F7FC),
      dividerColor: dark ? const Color(0xFF16477F) : const Color(0xFFE3E8F1),
      appBarTheme: AppBarTheme(elevation: 0, centerTitle: false, backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent, foregroundColor: dark ? Colors.white : scheme.onSurface, titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: dark ? Colors.white : scheme.onSurface)),
      cardTheme: CardThemeData(elevation: 0, margin: EdgeInsets.zero, color: dark ? const Color(0xFF071633) : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF06142F) : Colors.white,
        labelStyle: TextStyle(color: dark ? Colors.white60 : Colors.black54),
        hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: dark ? const Color(0xFF1454A8) : Colors.transparent)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: dark ? const Color(0xFF1454A8) : scheme.outlineVariant.withOpacity(.35))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: kCyan, width: 1.3)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: kPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), textStyle: const TextStyle(fontWeight: FontWeight.w900))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: dark ? Colors.white : scheme.primary, side: BorderSide(color: dark ? const Color(0xFF2866B8) : scheme.primary.withOpacity(.35)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), textStyle: const TextStyle(fontWeight: FontWeight.w800))),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: dark ? const Color(0xFF030A19) : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: kPurple.withOpacity(.28),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: states.contains(WidgetState.selected)
              ? (dark ? Colors.white : scheme.onSurface)
              : (dark ? Colors.white70 : scheme.onSurfaceVariant),
        )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? (dark ? Colors.white : scheme.primary)
              : (dark ? Colors.white54 : scheme.onSurfaceVariant),
          size: 20,
        )),
      ),
      chipTheme: ChipThemeData(backgroundColor: const Color(0xFF081A3A), selectedColor: kPurple, labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11), secondaryLabelStyle: const TextStyle(color: Colors.white), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13), side: const BorderSide(color: Color(0xFF174B93)))),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF0C1B39), contentTextStyle: const TextStyle(color: Colors.white), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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
  Widget build(BuildContext context) => Scaffold(body: ZenexGlowBackground(safeArea: false, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: const [ZenexLogo(size: 86), SizedBox(height: 17), Text('ZenexPay', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)), SizedBox(height: 6), Text('SMALL TASKS  •  BIG REWARDS', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1.5)), SizedBox(height: 28), SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2))]))));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  late final List<Widget> pages = [DashboardPage(onTabSelected: goTo), const TasksPage(), const WalletPage(), const ReferralPage(), const ProfilePage()];
  void goTo(int value) { if (mounted) setState(() => index = value); }
  int _lastBackMs = 0;

  void _handleBack() {
    if (index != 0) {
      setState(() => index = 0);
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackMs < 2000) {
      SystemNavigator.pop();
      return;
    }
    _lastBackMs = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Press back again to exit ZenexPay'),
        duration: Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _handleBack();
    },
    child: Scaffold(
    body: SafeArea(top: false, child: IndexedStack(index: index, children: pages)),
    bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: goTo, destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt_rounded), label: 'Tasks'),
      NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Wallet'),
      NavigationDestination(icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt_rounded), label: 'Referral'),
      NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
    ]),
    ),
  );
}
