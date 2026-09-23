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

  // =========================================================
  // WALLET
  // =========================================================

  static Future<Map<String, dynamic>?> wallet() async {
    return await client
        .from('wallets')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
  }

  // =========================================================
  // TASKS
  // =========================================================

  static Future<List<Map<String, dynamic>>> tasks() async {
    final data = await client
        .from('tasks')
        .select(
          'id,title,description,instructions,reward,proof_required',
        )
        .eq('status', 'published')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  // =========================================================
  // SUBMISSIONS
  // =========================================================

  static Future<List<Map<String, dynamic>>> submissions() async {
    final data = await client
        .from('task_submissions')
        .select(
          'id,task_id,status,proof_text,admin_note,created_at,tasks(title,reward)',
        )
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  // =========================================================
  // TRANSACTIONS
  // =========================================================

  static Future<List<Map<String, dynamic>>> transactions() async {
    final data = await client
        .from('transactions')
        .select(
          'id,type,amount,description,created_at',
        )
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  // =========================================================
  // SUBMIT TASK
  // =========================================================

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

  // =========================================================
  // WITHDRAW
  // =========================================================

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

    return result.toString();
  }

  // =========================================================
  // CHAT
  // =========================================================

  static Future<String> getOrCreateSupportChat() async {
    final result = await client.rpc(
      'get_or_create_support_chat',
    );

    if (result == null) {
      throw Exception('Could not create support chat.');
    }

    return result.toString();
  }

  // =========================================================
  // GET CHAT INFO
  // =========================================================

  static Future<Map<String, dynamic>?> getMySupportChat() async {
    final data = await client.rpc(
      'get_my_support_chat',
    );

    if (data == null) {
      return null;
    }

    if (data is List && data.isNotEmpty) {
      return Map<String, dynamic>.from(data.first);
    }

    return null;
  }

  // =========================================================
  // GET CHAT MESSAGES
  // =========================================================

  static Future<List<Map<String, dynamic>>> supportMessages(
    String conversationId,
  ) async {
    final data = await client
        .from('support_messages')
        .select(
          'id,conversation_id,sender_id,sender_type,message,is_read,created_at',
        )
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(data);
  }

  // =========================================================
  // SEND CHAT MESSAGE
  // =========================================================

  static Future<String> sendSupportMessage({
    required String conversationId,
    required String message,
  }) async {
    final text = message.trim();

    if (text.isEmpty) {
      throw Exception('Message cannot be empty.');
    }

    final result = await client.rpc(
      'send_support_message',
      params: {
        'p_conversation_id': conversationId,
        'p_message': text,
      },
    );

    if (result == null) {
      throw Exception('Message could not be sent.');
    }

    return result.toString();
  }

  // =========================================================
  // MARK CHAT READ
  // =========================================================

  static Future<void> markSupportMessagesRead(
    String conversationId,
  ) async {
    await client.rpc(
      'mark_support_messages_read',
      params: {
        'p_conversation_id': conversationId,
      },
    );
  }

  // =========================================================
  // REALTIME CHAT CHANNEL
  // =========================================================

  static RealtimeChannel supportChatChannel(
    String conversationId,
  ) {
    return client
        .channel('support-chat-$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'support_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {},
        )
        .subscribe();
  }
}
