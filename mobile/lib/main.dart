import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'screens/auth_page.dart';
import 'screens/tasks_page.dart';
import 'screens/wallet_page.dart';
import 'screens/submissions_page.dart';
import 'screens/profile_page.dart';
import 'screens/analytics_page.dart';
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
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: Brightness.light,
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (_, mode, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ZenexPay',
      themeMode: mode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF6F8FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(width: 1.2, color: scheme.primary),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F8CFF), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF0B1220),
        cardTheme: CardThemeData(elevation: 0, color: const Color(0xFF121B2B), margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Color(0xFF121B2B), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide.none)),
      ),
      home: const AuthGate(),
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
        return Supabase.instance.client.auth.currentSession == null
            ? const AuthPage()
            : const HomePage();
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

  final pages = const [
    DashboardPage(),
    TasksPage(),
    SubmissionsPage(),
    WalletPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          setState(() => index = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt_rounded),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Submissions',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
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

  static void goTo(BuildContext context, int tab) {
    context.findAncestorStateOfType<_HomePageState>()?.setState(() {});
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, dynamic>?> walletFuture;
  late Future<List<Map<String, dynamic>>> submissionsFuture;
  late Future<List<Map<String, dynamic>>> notificationsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    walletFuture = SupabaseService.wallet();
    submissionsFuture = SupabaseService.submissions();
    notificationsFuture = SupabaseService.notifications(limit: 5);
  }

  Future<void> _refresh() async {
    setState(_reload);
    await Future.wait([
      walletFuture,
      submissionsFuture,
      notificationsFuture,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = (user?.userMetadata?['full_name'] as String?)?.trim();
    final firstName =
        name == null || name.isEmpty ? 'there' : name.split(' ').first;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good to see you, $firstName 👋',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Complete tasks, build your earnings.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: notificationsFuture,
                builder: (_, snapshot) {
                  final unread = (snapshot.data ?? [])
                      .where((n) => n['is_read'] != true)
                      .length;
                  return Stack(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => _showNotifications(context),
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                      if (unread > 0)
                        Positioned(
                          right: 6,
                          top: 5,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          FutureBuilder<Map<String, dynamic>?>(
            future: walletFuture,
            builder: (_, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  snapshot.data == null) {
                return const _BalanceSkeleton();
              }

              final wallet = snapshot.data;
              final balance = wallet?['balance'] ?? 0;
              final earned = wallet?['total_earned'] ?? 0;

              return Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF155EEF), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF155EEF).withOpacity(.18),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Available balance',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '৳ ${money(balance)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total earned  ৳ ${money(earned)}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: () {
                            context
                                .findAncestorStateOfType<_HomePageState>()
                                ?.setState(() {});
                          },
                          child: const Text('Refresh'),
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
              _ActionCard(
                icon: Icons.task_alt_rounded,
                title: 'Find tasks',
                onTap: () {
                  final state =
                      context.findAncestorStateOfType<_HomePageState>();
                  state?.setState(() => state.index = 1);
                },
              ),
              const SizedBox(width: 10),
              _ActionCard(
                icon: Icons.assignment_rounded,
                title: 'My work',
                onTap: () {
                  final state =
                      context.findAncestorStateOfType<_HomePageState>();
                  state?.setState(() => state.index = 2);
                },
              ),
              const SizedBox(width: 10),
              _ActionCard(
                icon: Icons.wallet_rounded,
                title: 'Withdraw',
                onTap: () {
                  final state =
                      context.findAncestorStateOfType<_HomePageState>();
                  state?.setState(() => state.index = 3);
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsPage())),
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Row(children: [
                  CircleAvatar(child: Icon(Icons.insights_rounded)),
                  SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Earnings analytics', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('See earnings, task performance and your activity streak.'),
                  ])),
                  Icon(Icons.chevron_right_rounded),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader(
            title: 'Your activity',
            action: 'View all',
            onTap: () {
              final state =
                  context.findAncestorStateOfType<_HomePageState>();
              state?.setState(() => state.index = 2);
            },
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: submissionsFuture,
            builder: (_, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return const _EmptyCard(
                  icon: Icons.assignment_outlined,
                  title: 'No submissions yet',
                  text: 'Complete your first task to start building your history.',
                );
              }

              return Column(
                children: rows.take(3).map((row) {
                  final task = row['tasks'];
                  final title = task is Map
                      ? '${task['title'] ?? 'Task'}'
                      : 'Task submission';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SubmissionMiniCard(
                      title: title,
                      status: '${row['status'] ?? 'pending'}',
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 10),
          const _InfoCard(
            icon: Icons.shield_outlined,
            title: 'Secure by design',
            text:
                'Wallet changes are handled by Supabase server functions. The app never edits your balance directly.',
          ),
        ],
      ),
    );
  }

  Future<void> _showNotifications(BuildContext context) async {
    final rows = await SupabaseService.notifications(limit: 30);
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .78,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  const _EmptyCard(
                    icon: Icons.notifications_none_rounded,
                    title: 'You are all caught up',
                    text: 'New task and review updates will appear here.',
                  ),
                ...rows.map(
                  (n) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          n['is_read'] == true
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                        ),
                      ),
                      title: Text(
                        '${n['title'] ?? 'Notification'}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text('${n['message'] ?? ''}'),
                      trailing: n['created_at'] == null
                          ? null
                          : Text(
                              formatDate(n['created_at']),
                              style: const TextStyle(fontSize: 11),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    await SupabaseService.markNotificationsRead();
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 8),
            child: Column(
              children: [
                Icon(icon, size: 25),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    );
  }
}

class _SubmissionMiniCard extends StatelessWidget {
  final String title;
  final String status;

  const _SubmissionMiniCard({
    required this.title,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final data = statusVisual(status);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(data.icon),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: data.background,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            data.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: data.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icon, size: 42, color: Colors.grey.shade500),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _BalanceSkeleton extends StatelessWidget {
  const _BalanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 175,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

String money(dynamic value) =>
    (double.tryParse('$value') ?? 0).toStringAsFixed(2);

String formatDate(dynamic value) {
  if (value == null) return '';
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return '$value';
  final local = parsed.toLocal();
  return '${local.day}/${local.month}';
}

StatusVisual statusVisual(String status) {
  switch (status.toLowerCase()) {
    case 'approved':
      return const StatusVisual(
        label: 'Approved',
        icon: Icons.check_circle,
        background: Color(0xFFE7F8EE),
        foreground: Color(0xFF087443),
      );
    case 'rejected':
      return const StatusVisual(
        label: 'Rejected',
        icon: Icons.cancel,
        background: Color(0xFFFFE9E9),
        foreground: Color(0xFFB42318),
      );
    case 'screenshot_requested':
      return const StatusVisual(
        label: 'Proof needed',
        icon: Icons.photo_camera_outlined,
        background: Color(0xFFFFF4D6),
        foreground: Color(0xFF8A5A00),
      );
    case 'screenshot_submitted':
      return const StatusVisual(
        label: 'Proof sent',
        icon: Icons.cloud_done_outlined,
        background: Color(0xFFE8F0FF),
        foreground: Color(0xFF175CD3),
      );
    default:
      return const StatusVisual(
        label: 'Pending',
        icon: Icons.hourglass_top_rounded,
        background: Color(0xFFF2F4F7),
        foreground: Color(0xFF475467),
      );
  }
}

class StatusVisual {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  const StatusVisual({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });
}
