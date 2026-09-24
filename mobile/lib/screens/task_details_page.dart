import 'package:flutter/material.dart';

import 'submit_proof_page.dart';

class TaskDetailsPage extends StatelessWidget {
  final Map<String, dynamic> task;
  const TaskDetailsPage({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final reward = double.tryParse('${task['reward'] ?? 0}') ?? 0;
    final proofRequired = task['proof_required'] == true;
    final title = '${task['title'] ?? 'Task'}';
    final description = '${task['description'] ?? 'Complete the task according to the instructions.'}';
    final instructions = '${task['instructions'] ?? 'Follow the task requirements carefully, then submit your proof.'}';

    return Scaffold(
      backgroundColor: const Color(0xFF050814),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Task Details', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF142F77), Color(0xFF5320A5)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF6D79FF).withOpacity(.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(17)),
                  child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text('Earn ৳ ${reward.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF72F0B1), fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Requirements',
            icon: Icons.checklist_rounded,
            children: [
              _Bullet(text: proofRequired ? 'Proof may be required for review.' : 'Complete the task and submit the required details.'),
              const _Bullet(text: 'Do not submit false or unrelated information.'),
              const _Bullet(text: 'Rewards are credited after review when approved.'),
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Description',
            icon: Icons.description_outlined,
            children: [Text(description, style: const TextStyle(color: Colors.white70, height: 1.5))],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Instructions',
            icon: Icons.menu_book_rounded,
            children: [Text(instructions, style: const TextStyle(color: Colors.white70, height: 1.5))],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SubmitProofPage(task: task)),
              ),
              icon: const Icon(Icons.send_rounded),
              label: Text('Start Task  •  ৳ ${reward.toStringAsFixed(2)}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1222),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: Colors.white.withOpacity(.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: const Color(0xFF8C73FF), size: 19), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))]),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.circle, size: 6, color: Color(0xFF4F8CFF))),
            const SizedBox(width: 9),
            Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, height: 1.4))),
          ],
        ),
      );
}
