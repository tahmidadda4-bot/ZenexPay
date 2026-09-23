import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'screens/auth_page.dart';
import 'screens/tasks_page.dart';
import 'screens/submissions_page.dart';
import 'screens/wallet_page.dart';
import 'screens/chat_page.dart';
import 'screens/profile_page.dart';
import 'services/supabase_service.dart';
import 'theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const ZenexPayApp());
}

class ZenexPayApp extends StatelessWidget {
  const ZenexPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ZenexPay',
          themeMode: mode,
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          home: const AuthGate(),
        );
      },
    );
  }

  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0B63F6),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF6F8FC),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 72,
      ),
    );
  }

  ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0B63F6),
        brightness: Brightness.dark,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 72,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (_, __) {
        final session = Supabase.instance.client.auth.currentSession;

        if (session == null) {
          return const AuthPage();
        }

        return const HomePage();
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();

    pages = const [
      _Dashboard(),
      TasksPage(),
      SubmissionsPage(),
      WalletPage(),
      ProfilePage(),
    ];
  }

  void _goTo(int newIndex) {
    if (!mounted) return;

    setState(() {
      index = newIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: index,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Submissions',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
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
  void initState() {
    super.initState();
    wallet = SupabaseService.wallet();
  }

  Future<void> _refresh() async {
    setState(() {
      wallet = SupabaseService.wallet();
    });

    await wallet;
  }

  void _goTo(int index) {
    final state =
        context.findAncestorStateOfType<_HomePageState>();

    state?._goTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    final name =
        (user?.userMetadata?['full_name'] as String?)?.trim();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello${name == null || name.isEmpty ? '' : ', $name'} 👋',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete genuine tasks and earn approved rewards.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: () => Supabase.instance.client.auth.signOut(),
                icon: const Icon(Icons.logout_outlined),
              ),
            ],
          ),
          const SizedBox(height: 18),

          FutureBuilder<Map<String, dynamic>?>(
            future: wallet,
            builder: (_, snapshot) {
              final balance = snapshot.data?['balance'] ?? 0;
              final earned = snapshot.data?['total_earned'] ?? 0;

              return Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0B63F6),
                      Color(0xFF4A35D8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available Balance',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '৳ ${_money(balance)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total earned: ৳ ${_money(earned)}',
                            style: const TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: () => _goTo(3),
                          child: const Text('Wallet'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              _quick(
                context,
                Icons.task_alt,
                'Tasks',
                () => _goTo(1),
              ),
              const SizedBox(width: 10),
              _quick(
                context,
                Icons.assignment_outlined,
                'Submissions',
                () => _goTo(2),
              ),
              const SizedBox(width: 10),
              _quick(
                context,
                Icons.support_agent,
                'Support',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChatPage(),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 18),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'How ZenexPay works',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 12),
                  _Step(
                    icon: Icons.search,
                    title: 'Choose a task',
                    text: 'Read the task rules before starting.',
                  ),
                  _Step(
                    icon: Icons.upload_file,
                    title: 'Submit proof',
                    text: 'Send the requested proof honestly.',
                  ),
                  _Step(
                    icon: Icons.verified,
                    title: 'Get reviewed',
                    text: 'Approved rewards are added securely.',
                  ),
                  _Step(
                    icon: Icons.support_agent,
                    title: 'Need help?',
                    text: 'Contact ZenexPay Admin from Support.',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: const [
                  Icon(Icons.security, size: 30),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ZenexPay keeps wallet changes on the server. Your app cannot directly edit its balance.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quick(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(icon),
                const SizedBox(height: 7),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _Step({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _money(dynamic value) {
  return (double.tryParse('$value') ?? 0).toStringAsFixed(2);
}
