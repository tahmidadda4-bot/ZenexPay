import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/supabase_service.dart';
import '../zenex_ui.dart';

class SubmissionsPage extends StatefulWidget {
  const SubmissionsPage({super.key});

  @override
  State<SubmissionsPage> createState() => _SubmissionsPageState();
}

class _SubmissionsPageState extends State<SubmissionsPage> {
  late Future<List<Map<String, dynamic>>> future;
  String filter = 'All';

  @override
  void initState() {
    super.initState();
    future = SupabaseService.submissions();
  }

  Future<void> _reload() async {
    setState(() => future = SupabaseService.submissions());
    await future;
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final status = '${row['status'] ?? 'pending'}';
    if (status == 'screenshot_requested') {
      await _upload(row);
      return;
    }

    final task = row['tasks'];
    final title = task is Map ? '${task['title'] ?? 'Task'}' : 'Task submission';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubmissionDetails(row: row, title: title),
    );
  }

  Future<void> _upload(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Screenshot required', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          '${row['screenshot_reason'] ?? 'The reviewer requested a screenshot as additional proof.'}',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Choose screenshot'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (image == null) return;

    try {
      if (mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }
      await SupabaseService.uploadScreenshot(
        submissionId: '${row['id']}',
        file: File(image.path),
      );
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Screenshot submitted for review.')),
        );
        await _reload();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> rows) {
    if (filter == 'All') return rows;
    return rows.where((r) {
      final s = '${r['status'] ?? 'pending'}'.toLowerCase();
      if (filter == 'Pending') return s == 'pending';
      if (filter == 'Approved') return s == 'approved';
      if (filter == 'Rejected') return s == 'rejected';
      return s == 'screenshot_requested' || s == 'screenshot_submitted';
    }).toList();
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
              Text('My Submissions'),
              Text(
                'Track every task you have submitted.',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white54),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _reload,
              tooltip: 'Refresh',
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

            final rows = s.data ?? [];
            final visible = _filtered(rows);
            final pending = rows.where((r) => '${r['status'] ?? 'pending'}' == 'pending').length;
            final approved = rows.where((r) => '${r['status'] ?? ''}' == 'approved').length;
            final needsProof = rows.where((r) => '${r['status'] ?? ''}' == 'screenshot_requested').length;

            return RefreshIndicator(
              onRefresh: _reload,
              color: kCyan,
              backgroundColor: kSurface,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
                children: [
                  _SubmissionHero(total: rows.length, pending: pending, approved: approved, needsProof: needsProof),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ['All', 'Pending', 'Approved', 'Rejected', 'Proof needed'].map((f) {
                        final selected = filter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            selected: selected,
                            label: Text(f),
                            onSelected: (_) => setState(() => filter = f),
                            selectedColor: kPurple.withOpacity(.82),
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
                  const SizedBox(height: 14),
                  if (visible.isEmpty)
                    const EmptyState(
                      icon: Icons.inbox_rounded,
                      title: 'Nothing here yet',
                      message: 'Your task submissions will appear here after you submit a task.',
                    )
                  else
                    ...visible.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 11),
                          child: _SubmissionCard(row: r, onTap: () => _open(r), onUpload: () => _upload(r)),
                        )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SubmissionHero extends StatelessWidget {
  final int total;
  final int pending;
  final int approved;
  final int needsProof;

  const _SubmissionHero({required this.total, required this.pending, required this.approved, required this.needsProof});

  @override
  Widget build(BuildContext context) {
    return ZenexGradient(
      padding: const EdgeInsets.all(19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Proof Center', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Text('Keep track of your earning activity.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              Text('$total', style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _Mini(label: 'Pending', value: pending.toString(), icon: Icons.schedule_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _Mini(label: 'Approved', value: approved.toString(), icon: Icons.verified_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _Mini(label: 'Proof needed', value: needsProof.toString(), icon: Icons.photo_camera_outlined)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Mini({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(.08))),
        child: Row(
          children: [
            Icon(icon, size: 15, color: Colors.white70),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SubmissionCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  final VoidCallback onUpload;
  const _SubmissionCard({required this.row, required this.onTap, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final task = row['tasks'];
    final title = task is Map ? '${task['title'] ?? 'Task'}' : 'Task submission';
    final status = '${row['status'] ?? 'pending'}';
    final visual = statusVisual(status);

    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: visual.background, borderRadius: BorderRadius.circular(15)),
                  child: Icon(visual.icon, color: visual.foreground),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                      const SizedBox(height: 5),
                      Text('Tap to view submission details', style: TextStyle(color: Colors.white.withOpacity(.42), fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Badge(status),
              ],
            ),
          ),
          if (status == 'screenshot_requested')
            Container(
              padding: const EdgeInsets.fromLTRB(15, 12, 15, 14),
              decoration: BoxDecoration(color: kPurple.withOpacity(.07), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)), border: Border(top: BorderSide(color: Colors.white10))),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onUpload,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Upload requested screenshot'),
                ),
              ),
            ),
          if (status == 'screenshot_submitted')
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Screenshot submitted • waiting for review', style: TextStyle(color: kCyan, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubmissionDetails extends StatelessWidget {
  final Map<String, dynamic> row;
  final String title;
  const _SubmissionDetails({required this.row, required this.title});

  @override
  Widget build(BuildContext context) {
    final status = '${row['status'] ?? 'pending'}';
    return Container(
      decoration: const BoxDecoration(color: kNavy2, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18, 4, 18, 25 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(19),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [kBlue, kPurple, kPink]), borderRadius: BorderRadius.circular(24)),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900))),
                    _Badge(status),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if ('${row['proof_text'] ?? ''}'.trim().isNotEmpty) ...[
                const Text('Your submission', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 8),
                GlassCard(child: Text('${row['proof_text']}', style: const TextStyle(color: Colors.white70, height: 1.5))),
                const SizedBox(height: 16),
              ],
              if ('${row['rejection_reason'] ?? ''}'.trim().isNotEmpty) ...[
                const Text('Reviewer note', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.redAccent.withOpacity(.18))),
                  child: Text('${row['rejection_reason']}', style: const TextStyle(color: Colors.white70, height: 1.45)),
                ),
              ],
              if ('${row['admin_note'] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Admin note', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 8),
                GlassCard(child: Text('${row['admin_note']}', style: const TextStyle(color: Colors.white70, height: 1.45))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String status;
  const _Badge(this.status);

  @override
  Widget build(BuildContext context) {
    final v = statusVisual(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: v.background, borderRadius: BorderRadius.circular(30)),
      child: Text(v.label, style: TextStyle(color: v.foreground, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }
}

class StatusVisual {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  const StatusVisual(this.label, this.icon, this.background, this.foreground);
}

StatusVisual statusVisual(String s) {
  switch (s.toLowerCase()) {
    case 'approved':
      return const StatusVisual('Approved', Icons.check_circle_rounded, Color(0xFF123F2C), Color(0xFF52E3A4));
    case 'rejected':
      return const StatusVisual('Rejected', Icons.cancel_rounded, Color(0xFF4A2025), Color(0xFFFF7777));
    case 'screenshot_requested':
      return const StatusVisual('Proof needed', Icons.photo_camera_outlined, Color(0xFF4A3915), Color(0xFFFFD166));
    case 'screenshot_submitted':
      return const StatusVisual('Proof sent', Icons.cloud_done_outlined, Color(0xFF172E4A), Color(0xFF63B3FF));
    default:
      return const StatusVisual('Pending', Icons.hourglass_top_rounded, Color(0xFF242A3D), Color(0xFFB8C1D9));
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48, color: kCyan),
                const SizedBox(height: 12),
                const Text('Could not load submissions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 15),
                FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
              ],
            ),
          ),
        ),
      );
}
