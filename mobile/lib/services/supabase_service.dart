import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final client = Supabase.instance.client;

  static String get uid {
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }
    return user.id;
  }

  static Future<Map<String, dynamic>?> wallet() async {
    return client
        .from('wallets')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
  }

  static Future<List<Map<String, dynamic>>> tasks() async {
    final rows = await client
        .from('tasks')
        .select(
          'id,title,description,instructions,reward,proof_required',
        )
        .eq('status', 'published')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<List<Map<String, dynamic>>> submissions() async {
    final rows = await client
        .from('task_submissions')
        .select(
          'id,task_id,status,proof_text,admin_note,rejection_reason,'
          'screenshot_reason,screenshot_path,created_at,'
          'screenshot_submitted_at,tasks(title,reward)',
        )
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<List<Map<String, dynamic>>> transactions() async {
    final rows = await client
        .from('transactions')
        .select('id,type,amount,description,created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<List<Map<String, dynamic>>> notifications({
    int limit = 30,
  }) async {
    final rows = await client
        .from('notifications')
        .select('id,title,message,type,is_read,created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> markNotificationsRead() async {
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', uid)
        .eq('is_read', false);
  }

  static Future<void> submitTask({
    required String taskId,
    String? proofText,
  }) async {
    await client.rpc(
      'submit_task',
      params: {
        'p_task_id': taskId,
        'p_proof_text': proofText,
      },
    );
  }

  static Future<void> uploadScreenshot({
    required String submissionId,
    required File file,
  }) async {
    final extension = file.path.split('.').last.toLowerCase();
    const allowed = {'jpg', 'jpeg', 'png', 'webp'};

    if (!allowed.contains(extension)) {
      throw Exception('Only JPG, PNG or WEBP screenshots are allowed.');
    }

    final bytes = await file.length();
    if (bytes > 5 * 1024 * 1024) {
      throw Exception('Screenshot must be 5 MB or smaller.');
    }

    final path =
        '$uid/$submissionId-${DateTime.now().millisecondsSinceEpoch}.$extension';

    await client.storage.from('task-submissions').upload(
      path,
      file,
      fileOptions: FileOptions(
        upsert: false,
        contentType: _contentType(extension),
      ),
    );

    try {
      await client.rpc(
        'submit_screenshot',
        params: {
          'p_submission_id': submissionId,
          'p_storage_path': path,
        },
      );
    } catch (e) {
      try {
        await client.storage.from('task-submissions').remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  static Future<String> withdraw({
    required double amount,
    required String method,
    required String account,
  }) async {
    final result = await client.rpc(
      'submit_withdrawal',
      params: {
        'p_amount': amount,
        'p_method': method,
        'p_account_number': account,
      },
    );
    return '$result';
  }

  static String _contentType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/png';
    }
  }
}
