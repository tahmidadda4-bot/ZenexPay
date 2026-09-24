import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import 'task_details_page.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  late Future<List<Map<String, dynamic>>> future;
  String filter = 'All';

  static const filters = <String>['All', 'General', 'Social', 'App', 'Survey'];

  @override
  void initState() {
    super.initState();
    future = SupabaseService.tasks();
  }

  Future<void> _reload() async {
    setState(() => future = SupabaseService.tasks());
    await future;
  }

  String _typeOf(Map<String, dynamic> task) {
    final raw = '${task['type'] ?? task['category'] ?? 'General'}'.trim();
    if (raw.isEmpty) return 'General';
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF050814),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Tasks', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(message: '${snapshot.error}', onRetry: _reload);
          }

          final all = snapshot.data ?? const <Map<String, dynamic>>[];
          final visible = filter == 'All'
              ? all
              : all.where((task) => _typeOf(task) == filter).toList();

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
              children: [
                _TaskHero(total: all.length),
                const SizedBox(height: 16),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final value = filters[index];
                      final selected = value == filter;
                      return ChoiceChip(
                        label: Text(value),
                        selected: selected,
                        onSelected: (_) => setState(() => filter = value),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w800,
                        ),
                        selectedColor: const Color(0xFF6948FF),
                        backgroundColor: const Color(0xFF0D1426),
                        side: BorderSide(
                          color: selected
                              ? const Color(0xFF7B61FF)
                              : Colors.white.withOpacity(.08),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Available tasks',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      '${visible.length} found',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (visible.isEmpty)
                  const _EmptyTasks()
                else
                  ...visible.map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TaskCard(
                        task: task,
                        type: _typeOf(task),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TaskDetailsPage(task: task),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TaskHero extends StatelessWidget {
  final int total;
  const _TaskHero({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF143D91), Color(0xFF4B1FAE), Color(0xFF151A55)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF5D8BFF).withOpacity(.28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B45FF).withOpacity(.20),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Complete tasks. Earn rewards.',
                  style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  '$total published ${total == 1 ? 'task' : 'tasks'} ready to explore.',
                  style: const TextStyle(color: Colors.white70, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final String type;
  final VoidCallback onTap;
  const _TaskCard({required this.task, required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final reward = double.tryParse('${task['reward'] ?? 0}') ?? 0;
    final proof = task['proof_required'] == true;

    return Material(
      color: const Color(0xFF0B1222),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF2B63C7).withOpacity(.28)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF1677FF), Color(0xFF7A3EFF)]),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 27),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${task['title'] ?? 'Task'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          type,
                          style: const TextStyle(color: Color(0xFF8AA4FF), fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF172A5C),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      '+ ৳ ${reward.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFF63E6A7), fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${task['description'] ?? 'Complete this task according to the instructions.'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, height: 1.4, fontSize: 13),
                ),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  _Meta(icon: Icons.schedule_rounded, text: '2–5 min'),
                  const SizedBox(width: 14),
                  _Meta(
                    icon: proof ? Icons.verified_outlined : Icons.flash_on_rounded,
                    text: proof ? 'Proof required' : 'Quick task',
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_rounded, color: Color(0xFF8C73FF), size: 21),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white54),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      );
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1222),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(.07)),
        ),
        child: const Column(
          children: [
            Icon(Icons.inbox_rounded, size: 42, color: Colors.white38),
            SizedBox(height: 12),
            Text('No tasks in this category', style: TextStyle(fontWeight: FontWeight.w900)),
            SizedBox(height: 5),
            Text('Try another filter or refresh the task list.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.white38),
              const SizedBox(height: 12),
              const Text('Could not load tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
            ],
          ),
        ),
      );
}
