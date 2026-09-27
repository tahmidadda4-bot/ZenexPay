import 'package:flutter/material.dart';
import '../zenex_ui.dart';
import '../services/supabase_service.dart';
import '../services/network_error.dart';
import 'submit_proof_page.dart';

class TaskDetailsPage extends StatefulWidget {
  final Map<String, dynamic> task;
  const TaskDetailsPage({super.key, required this.task});

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  Map<String, dynamic>? submission;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadSubmission();
  }

  Future<void> _loadSubmission() async {
    try {
      final row = await SupabaseService.submissionForTask('${widget.task['id']}');
      if (!mounted) return;
      setState(() {
        submission = row;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  String get _status => '${submission?['status'] ?? ''}'.toLowerCase();

  bool get _locked => _status == 'pending' ||
      _status == 'approved' ||
      _status == 'screenshot_requested' ||
      _status == 'screenshot_submitted';

  String get _buttonLabel {
    switch (_status) {
      case 'pending':
        return 'Pending Review';
      case 'approved':
        return 'Task Completed';
      case 'screenshot_requested':
        return 'Screenshot Requested';
      case 'screenshot_submitted':
        return 'Screenshot Under Review';
      case 'rejected':
        return 'Resubmit Task';
      default:
        return 'Start Task';
    }
  }

  String? get _statusMessage {
    switch (_status) {
      case 'pending':
        return 'You already submitted this task. You can view the submission, but you cannot submit it again until the review is completed.';
      case 'approved':
        return 'This task has already been approved and paid. It cannot be submitted again.';
      case 'screenshot_requested':
        return 'The reviewer requested a screenshot. Upload it from My Submissions to continue the review.';
      case 'screenshot_submitted':
        return 'Your requested screenshot has been submitted. Please wait for the reviewer.';
      case 'rejected':
        final reason = '${submission?['rejection_reason'] ?? submission?['admin_note'] ?? ''}'.trim();
        return reason.isEmpty ? 'Your previous submission was rejected. You may submit this task again.' : 'Rejected: $reason';
      default:
        return null;
    }
  }

  Future<void> _startOrView() async {
    if (_locked) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SubmitProofPage(task: widget.task)),
    );
    await _loadSubmission();
  }

  @override
  Widget build(BuildContext context) {
    final reward = double.tryParse('${widget.task['reward'] ?? 0}') ?? 0;
    final proofRequired = widget.task['proof_required'] == true;
    final title = '${widget.task['title'] ?? 'Task'}';
    final description = '${widget.task['description'] ?? 'Complete the task according to the instructions.'}';
    final instructions = '${widget.task['instructions'] ?? 'Follow the task requirements carefully, then submit your proof.'}';

    return Scaffold(
      backgroundColor: zenexBackground(context),
      appBar: AppBar(
        backgroundColor: zenexBackground(context),
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
          if (loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (!loading && _statusMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _status == 'rejected' ? const Color(0xFF7A1F2B).withOpacity(.18) : zenexPanel(context),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: _status == 'rejected' ? Colors.redAccent.withOpacity(.25) : zenexSubtleBorder(context)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_status == 'rejected' ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                      color: _status == 'rejected' ? Colors.redAccent : const Color(0xFF6B8CFF)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_statusMessage!, style: TextStyle(color: zenexMutedText(context), height: 1.45, fontSize: 12))),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
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
            children: [Text(description, style: TextStyle(color: zenexMutedText(context), height: 1.5))],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Instructions',
            icon: Icons.menu_book_rounded,
            children: [Text(instructions, style: TextStyle(color: zenexMutedText(context), height: 1.5))],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: loading || _locked ? null : _startOrView,
              icon: Icon(_locked ? Icons.lock_outline_rounded : Icons.send_rounded),
              label: Text(_buttonLabel),
            ),
          ),
          if (_status == 'rejected') ...[
            const SizedBox(height: 8),
            Text(
              'You may submit again because the previous submission was rejected.',
              textAlign: TextAlign.center,
              style: TextStyle(color: zenexMutedText(context), fontSize: 11),
            ),
          ],
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
          color: zenexPanel(context),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: zenexSubtleBorder(context)),
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
            Expanded(child: Text(text, style: TextStyle(color: zenexMutedText(context), height: 1.4))),
          ],
        ),
      );
}
