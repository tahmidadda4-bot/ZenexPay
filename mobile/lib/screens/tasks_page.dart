import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../zenex_ui.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  late Future<List<Map<String, dynamic>>> future;
  String query = '';
  String filter = 'All';

  @override
  void initState() {
    super.initState();
    future = SupabaseService.tasks();
  }

  Future<void> _reload() async {
    setState(() => future = SupabaseService.tasks());
    await future;
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> items) {
    final q = query.trim().toLowerCase();
    return items.where((t) {
      final title = '${t['title'] ?? ''}'.toLowerCase();
      final desc = '${t['description'] ?? ''}'.toLowerCase();
      final reward = num.tryParse('${t['reward'] ?? 0}') ?? 0;
      final matchesQuery = q.isEmpty || title.contains(q) || desc.contains(q);
      final matchesFilter = filter == 'All' ||
          (filter == 'Proof required' && t['proof_required'] == true) ||
          (filter == 'Quick tasks' && t['proof_required'] != true) ||
          (filter == 'High reward' && reward >= 100);
      return matchesQuery && matchesFilter;
    }).toList();
  }

  Future<void> openTask(Map<String, dynamic> task) async {
    final proof = TextEditingController();
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskDetailsSheet(task: task, proof: proof),
    );

    if (sent == true) {
      try {
        await SupabaseService.submitTask(
          taskId: '${task['id']}',
          proofText: proof.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task submitted. Waiting for admin review.')),
          );
          await _reload();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')),
          );
        }
      }
    }
    proof.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ZenexPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Task Center'),
              Text(
                'Earn more. Grow faster.',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white54),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _reload,
              tooltip: 'Refresh tasks',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.hasError) {
              return _ErrorState(message: '${s.error}', onRetry: _reload);
            }

            final items = s.data ?? [];
            final visible = _filtered(items);
            final totalReward = items.fold<num>(
              0,
              (sum, t) => sum + (num.tryParse('${t['reward'] ?? 0}') ?? 0),
            );

            return RefreshIndicator(
              onRefresh: _reload,
              color: kCyan,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
                children: [
                  _TaskHero(
                    taskCount: items.length,
                    totalReward: totalReward,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Search tasks...',
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                setState(() => query = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        'All',
                        'Quick tasks',
                        'Proof required',
                        'High reward',
                      ].map((f) {
                        final selected = filter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            selected: selected,
                            label: Text(f),
                            onSelected: (_) => setState(() => filter = f),
                            selectedColor: kPurple.withOpacity(.8),
                            backgroundColor: kSurface2,
                            side: BorderSide(color: Colors.white.withOpacity(.07)),
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : Colors.white70,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Available tasks',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        '${visible.length} found',
                        style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (visible.isEmpty)
                    const EmptyState(
                      icon: Icons.manage_search_rounded,
                      title: 'No matching tasks',
                      message: 'Try another search or filter. New tasks can appear anytime.',
                    )
                  else
                    ...visible.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TaskCard(task: t, onTap: () => openTask(t)),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TaskHero extends StatelessWidget {
  final int taskCount;
  final num totalReward;

  const _TaskHero({required this.taskCount, required this.totalReward});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF253A87), Color(0xFF632D8F), Color(0xFF201B50)],
        ),
        boxShadow: [
          BoxShadow(color: kPurple.withOpacity(.25), blurRadius: 28, offset: const Offset(0, 12)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.12),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: Colors.white.withOpacity(.14)),
            ),
            child: const Icon(Icons.bolt_rounded, color: kCyan, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your earning zone', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('$taskCount tasks live', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('Up to ৳ ${totalReward.toStringAsFixed(0)} in listed rewards', style: const TextStyle(color: Colors.white60, fontSize: 11)),
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
  final VoidCallback onTap;

  const _TaskCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final reward = num.tryParse('${task['reward'] ?? 0}') ?? 0;
    final proof = task['proof_required'] == true;

    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [kBlue, kPurple]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: kBlue.withOpacity(.20), blurRadius: 15)],
                  ),
                  child: const Icon(Icons.task_alt_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${task['title'] ?? 'Untitled task'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${task['description'] ?? 'Complete this task and submit your work.'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, height: 1.35, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '৳ ${reward.toStringAsFixed(0)}',
                  style: const TextStyle(color: kCyan, fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 14, 11),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.025),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(.06))),
            ),
            child: Row(
              children: [
                Icon(proof ? Icons.verified_user_outlined : Icons.flash_on_rounded, size: 16, color: proof ? kPurple : kCyan),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    proof ? 'Proof may be required' : 'Quick submission',
                    style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                const Text('View task', style: TextStyle(color: Colors.white80, fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(width: 5),
                const Icon(Icons.arrow_forward_rounded, size: 17, color: Colors.white70),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> task;
  final TextEditingController proof;

  const _TaskDetailsSheet({required this.task, required this.proof});

  @override
  Widget build(BuildContext context) {
    final reward = num.tryParse('${task['reward'] ?? 0}') ?? 0;
    return Container(
      decoration: const BoxDecoration(
        color: kNavy2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18, 6, 18, 24 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kBlue, kPurple, kPink]),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.task_alt_rounded, color: Colors.white, size: 29),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(.15), borderRadius: BorderRadius.circular(13)),
                          child: Text('৳ ${reward.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('${task['title'] ?? 'Task'}', style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    const Text('Complete the work carefully to protect your approval rate.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text('Description', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 7),
              Text('${task['description'] ?? ''}', style: const TextStyle(color: Colors.white70, height: 1.5)),
              const SizedBox(height: 18),
              const Text('Instructions', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 7),
              Text('${task['instructions'] ?? ''}', style: const TextStyle(color: Colors.white70, height: 1.5)),
              const SizedBox(height: 18),
              TextField(
                controller: proof,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Submission details',
                  hintText: 'Describe what you completed...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 9),
              const Text('You can add visual proof later from the Submissions section if needed.', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 17),
              SizedBox(
                height: 55,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [kBlue, kPurple, kPink]),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: kPurple.withOpacity(.22), blurRadius: 22, offset: const Offset(0, 8))],
                  ),
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                    icon: const Icon(Icons.send_rounded),
                    label: Text('Submit • ৳ ${reward.toStringAsFixed(0)}'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 50, color: Colors.white38),
            const SizedBox(height: 12),
            const Text('Could not load tasks', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 7),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
