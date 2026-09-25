import 'package:flutter/material.dart';
import '../zenex_ui.dart';

import '../services/supabase_service.dart';

class SubmitProofPage extends StatefulWidget {
  final Map<String, dynamic> task;
  const SubmitProofPage({super.key, required this.task});

  @override
  State<SubmitProofPage> createState() => _SubmitProofPageState();
}

class _SubmitProofPageState extends State<SubmitProofPage> {
  final proof = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    proof.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await SupabaseService.submitTask(
        taskId: '${widget.task['id']}',
        proofText: proof.text.trim().isEmpty ? null : proof.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task submitted. Waiting for admin review.')));
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reward = double.tryParse('${widget.task['reward'] ?? 0}') ?? 0;
    return Scaffold(
      backgroundColor: zenexBackground(context),
      appBar: AppBar(
        backgroundColor: zenexBackground(context),
        title: const Text('Submit Proof', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: zenexPanel(context),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: const Color(0xFF4F8CFF).withOpacity(.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.task_alt_rounded, color: Color(0xFF6B8CFF), size: 26),
                const SizedBox(width: 11),
                Expanded(child: Text('${widget.task['title'] ?? 'Task'}', style: const TextStyle(fontWeight: FontWeight.w900))),
                Text('+ ৳ ${reward.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF63E6A7), fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: zenexPanel(context),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: zenexSubtleBorder(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your submission', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('Add the requested details or proof information. Screenshot upload, when needed, remains available from Submissions.', style: TextStyle(color: zenexMutedText(context), height: 1.45, fontSize: 12)),
                const SizedBox(height: 14),
                TextField(
                  controller: proof,
                  maxLines: 7,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Describe what you completed or paste the requested proof details…',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(17)), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: busy ? null : _submit,
              icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
              label: Text(busy ? 'Submitting…' : 'Submit  •  ৳ ${reward.toStringAsFixed(2)}'),
            ),
          ),
        ],
      ),
    );
  }
}
