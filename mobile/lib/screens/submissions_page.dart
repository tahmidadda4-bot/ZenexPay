import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/supabase_service.dart';

class SubmissionsPage extends StatefulWidget {
  const SubmissionsPage({super.key});

  @override
  State<SubmissionsPage> createState() => _SubmissionsPageState();
}

class _SubmissionsPageState extends State<SubmissionsPage> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = SupabaseService.submissions();
  }

  Future<void> _reload() async {
    setState(() => future = SupabaseService.submissions());
    await future;
  }

  Future<void> _openSubmission(Map<String, dynamic> row) async {
    final status = '${row['status'] ?? 'pending'}';
    if (status == 'screenshot_requested') {
      await _uploadScreenshot(row);
      return;
    }

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        final task = row['tasks'];
        final title =
            task is Map ? '${task['title'] ?? 'Task'}' : 'Task submission';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _StatusBadge(status: status),
                const SizedBox(height: 15),
                if ('${row['proof_text'] ?? ''}'.trim().isNotEmpty) ...[
                  const Text(
                    'Your submission',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text('${row['proof_text']}'),
                  const SizedBox(height: 14),
                ],
                if ('${row['rejection_reason'] ?? ''}'.trim().isNotEmpty) ...[
                  const Text(
                    'Reviewer note',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text('${row['rejection_reason']}'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _uploadScreenshot(Map<String, dynamic> row) async {
    final reason = '${row['screenshot_reason'] ?? ''}'.trim();
    final approved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Screenshot required'),
        content: Text(
          reason.isEmpty
              ? 'The reviewer requested a screenshot as additional proof.'
              : reason,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Choose screenshot'),
          ),
        ],
      ),
    );

    if (approved != true) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (image == null) return;

    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await SupabaseService.uploadScreenshot(
        submissionId: '${row['id']}',
        file: File(image.path),
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Screenshot submitted for review.'),
          ),
        );
        await _reload();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Submissions',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }

          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  'No submissions yet.\nComplete a task and it will appear here.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final row = rows[i];
                final task = row['tasks'];
                final title = task is Map
                    ? '${task['title'] ?? 'Task'}'
                    : 'Task submission';
                final status = '${row['status'] ?? 'pending'}';

                return Card(
                  child: InkWell(
                    onTap: () => _openSubmission(row),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                child: Icon(statusVisual(status).icon),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              _StatusBadge(status: status),
                            ],
                          ),
                          if (status == 'screenshot_requested') ...[
                            const SizedBox(height: 13),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => _uploadScreenshot(row),
                                icon: const Icon(Icons.photo_camera_outlined),
                                label: const Text('Upload requested screenshot'),
                              ),
                            ),
                          ],
                          if (status == 'screenshot_submitted') ...[
                            const SizedBox(height: 9),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Screenshot submitted. Waiting for review.',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final data = statusVisual(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: data.background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        data.label,
        style: TextStyle(
          color: data.foreground,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
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
