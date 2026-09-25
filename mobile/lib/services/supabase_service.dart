import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class UserAnalytics {
  final double totalEarned;
  final double monthEarned;
  final int approved;
  final int pending;
  final int rejected;
  final int screenshotSubmitted;
  final int streak;
  final double totalWithdrawn;
  final double balance;
  final List<DailyPoint> last7Days;

  const UserAnalytics({
    required this.totalEarned,
    required this.monthEarned,
    required this.approved,
    required this.pending,
    required this.rejected,
    required this.screenshotSubmitted,
    required this.streak,
    required this.totalWithdrawn,
    required this.balance,
    required this.last7Days,
  });
}

class DailyPoint {
  final String label;
  final double amount;

  const DailyPoint({
    required this.label,
    required this.amount,
  });
}

class ReferralInfo {
  final String code;
  final int successfulReferrals;

  const ReferralInfo({
    required this.code,
    required this.successfulReferrals,
  });
}

String money(double value) => value.toStringAsFixed(2);

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
          'id,task_id,status,proof_text,admin_note,rejection_reason,'
          'screenshot_reason,created_at,tasks(title,reward)',
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
          'id,type,amount,description,status,withdrawal_method,withdrawal_account,created_at',
        )
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  static Future<Map<String, dynamic>?> transactionById(String id) async {
    final data = await client
        .from('transactions')
        .select(
          'id,type,amount,description,status,withdrawal_method,withdrawal_account,created_at',
        )
        .eq('id', id)
        .eq('user_id', uid)
        .maybeSingle();

    return data;
  }

  // =========================================================
  // WITHDRAWAL METHODS
  // =========================================================

  static Future<List<Map<String, dynamic>>> withdrawalMethods() async {
    final data = await client
        .from('withdrawal_methods')
        .select(
          'id,method_type,account_number,created_at,updated_at',
        )
        .eq('user_id', uid)
        .order('method_type');

    return List<Map<String, dynamic>>.from(data);
  }

  static Future<Map<String, dynamic>> saveWithdrawalMethod({
    required String methodType,
    required String accountNumber,
  }) async {
    final row = await client
        .from('withdrawal_methods')
        .upsert(
          {
            'user_id': uid,
            'method_type': methodType,
            'account_number': accountNumber,
          },
          onConflict: 'user_id,method_type',
        )
        .select(
          'id,method_type,account_number,created_at,updated_at',
        )
        .single();

    return Map<String, dynamic>.from(row);
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

  static Future<Map<String, dynamic>> withdraw({
    required double amount,
    required String methodId,
  }) async {
    final result = await client.rpc(
      'create_withdrawal_request',
      params: {
        'p_amount': amount,
        'p_method_id': methodId,
      },
    );

    final id = result.toString();
    final transaction = await transactionById(id);
    if (transaction == null) {
      throw Exception('Withdrawal was created but the transaction could not be loaded.');
    }
    return transaction;
  }

  // =========================================================
  // SCREENSHOT PROOF
  // =========================================================

  static Future<void> uploadScreenshot({
    required String submissionId,
    required File file,
  }) async {
    final extension = file.path.contains('.')
        ? file.path.split('.').last.toLowerCase()
        : 'jpg';

    final path =
        '$uid/$submissionId-${DateTime.now().millisecondsSinceEpoch}.$extension';

    await client.storage
        .from('submission-screenshots')
        .upload(
          path,
          file,
          fileOptions: const FileOptions(
            upsert: false,
          ),
        );

    final publicUrl = client.storage
        .from('submission-screenshots')
        .getPublicUrl(path);

    await client
        .from('task_submissions')
        .update({
          'screenshot_url': publicUrl,
          'status': 'screenshot_submitted',
        })
        .eq('id', submissionId)
        .eq('user_id', uid);
  }

  // =========================================================
  // ANALYTICS
  // =========================================================

  static Future<UserAnalytics> analytics() async {
    final walletRow = await wallet();

    final submissionData = await client
        .from('task_submissions')
        .select('status,created_at,tasks(reward)')
        .eq('user_id', uid)
        .order('created_at', ascending: true);

    final transactionData = await client
        .from('transactions')
        .select('type,amount,created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: true);

    final submissions =
        List<Map<String, dynamic>>.from(submissionData);

    final transactions =
        List<Map<String, dynamic>>.from(transactionData);

    int approved = 0;
    int pending = 0;
    int rejected = 0;
    int screenshotSubmitted = 0;

    for (final row in submissions) {
      final status = '${row['status'] ?? ''}'.toLowerCase();

      if (status == 'approved') {
        approved++;
      } else if (status == 'rejected') {
        rejected++;
      } else {
        pending++;
      }

      if (status == 'screenshot_submitted') {
        screenshotSubmitted++;
      }
    }

    double totalEarned = 0;
    double monthEarned = 0;
    double totalWithdrawn = 0;

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    for (final row in transactions) {
      final amount =
          double.tryParse('${row['amount'] ?? 0}') ?? 0;

      final type =
          '${row['type'] ?? ''}'.toLowerCase();

      DateTime? date;

      try {
        date = DateTime.parse(
          '${row['created_at']}',
        ).toLocal();
      } catch (_) {}

      final isWithdrawal =
          type.contains('withdraw');

      final isEarn =
          type.contains('earn') ||
          type.contains('reward') ||
          type == 'credit' ||
          type == 'task_reward';

      if (isWithdrawal) {
        totalWithdrawn += amount.abs();
      } else if (isEarn) {
        totalEarned += amount.abs();

        if (date != null &&
            !date.isBefore(monthStart)) {
          monthEarned += amount.abs();
        }
      }
    }

    if (totalEarned == 0) {
      for (final row in submissions) {
        if ('${row['status'] ?? ''}'.toLowerCase() !=
            'approved') {
          continue;
        }

        final task = row['tasks'];

        if (task is Map) {
          totalEarned +=
              double.tryParse(
                    '${task['reward'] ?? 0}',
                  ) ??
                  0;
        }
      }
    }

    if (monthEarned == 0) {
      for (final row in submissions) {
        if ('${row['status'] ?? ''}'.toLowerCase() !=
            'approved') {
          continue;
        }

        DateTime? date;

        try {
          date = DateTime.parse(
            '${row['created_at']}',
          ).toLocal();
        } catch (_) {}

        if (date == null ||
            date.isBefore(monthStart)) {
          continue;
        }

        final task = row['tasks'];

        if (task is Map) {
          monthEarned +=
              double.tryParse(
                    '${task['reward'] ?? 0}',
                  ) ??
                  0;
        }
      }
    }

    final points = <DailyPoint>[];

    final start =
        DateTime(now.year, now.month, now.day)
            .subtract(
              const Duration(days: 6),
            );

    for (int i = 0; i < 7; i++) {
      final day =
          start.add(Duration(days: i));

      double amount = 0;

      for (final row in submissions) {
        if ('${row['status'] ?? ''}'.toLowerCase() !=
            'approved') {
          continue;
        }

        DateTime? date;

        try {
          date = DateTime.parse(
            '${row['created_at']}',
          ).toLocal();
        } catch (_) {}

        if (date == null ||
            date.year != day.year ||
            date.month != day.month ||
            date.day != day.day) {
          continue;
        }

        final task = row['tasks'];

        if (task is Map) {
          amount +=
              double.tryParse(
                    '${task['reward'] ?? 0}',
                  ) ??
                  0;
        }
      }

      points.add(
        DailyPoint(
          label: '${day.day}/${day.month}',
          amount: amount,
        ),
      );
    }

    final activeDays = <String>{};

    for (final row in submissions) {
      DateTime? date;

      try {
        date = DateTime.parse(
          '${row['created_at']}',
        ).toLocal();
      } catch (_) {}

      if (date != null) {
        activeDays.add(
          '${date.year}-${date.month}-${date.day}',
        );
      }
    }

    int streak = 0;

    var cursor =
        DateTime(now.year, now.month, now.day);

    while (activeDays.contains(
      '${cursor.year}-${cursor.month}-${cursor.day}',
    )) {
      streak++;

      cursor = cursor.subtract(
        const Duration(days: 1),
      );
    }

    final balance =
        double.tryParse(
              '${walletRow?['balance'] ?? 0}',
            ) ??
            0;

    return UserAnalytics(
      totalEarned: totalEarned,
      monthEarned: monthEarned,
      approved: approved,
      pending: pending,
      rejected: rejected,
      screenshotSubmitted: screenshotSubmitted,
      streak: streak,
      totalWithdrawn: totalWithdrawn,
      balance: balance,
      last7Days: points,
    );
  }

  // =========================================================
  // REFERRAL
  // =========================================================

  static Future<ReferralInfo> referralInfo() async {
    final user = client.auth.currentUser;

    final metadata = user?.userMetadata ?? {};

    String code =
        '${metadata['referral_code'] ?? ''}'.trim();

    int successful = 0;

    try {
      final rows = await client
          .from('referrals')
          .select('id')
          .eq('referrer_id', uid);

      successful = List.from(rows).length;
    } catch (_) {
      successful = 0;
    }

    if (code.isEmpty) {
      try {
        final row = await client
            .from('profiles')
            .select('referral_code')
            .eq('id', uid)
            .maybeSingle();

        code =
            '${row?['referral_code'] ?? ''}'.trim();
      } catch (_) {}
    }

    if (code.isEmpty) {
      code =
          'ZENEX-${uid.substring(0, 8).toUpperCase()}';
    }

    return ReferralInfo(
      code: code,
      successfulReferrals: successful,
    );
  }

  static Future<void> claimReferral(
    String code,
  ) async {
    final value = code.trim().toUpperCase();

    if (value.isEmpty) {
      throw Exception(
        'Referral code cannot be empty.',
      );
    }

    await client.rpc(
      'claim_referral',
      params: {
        'p_referral_code': value,
      },
    );
  }

  // =========================================================
  // CHAT
  // =========================================================

  static Future<String> getOrCreateSupportChat() async {
    final result = await client.rpc(
      'get_or_create_support_chat',
    );

    if (result == null) {
      throw Exception(
        'Could not create support chat.',
      );
    }

    return result.toString();
  }

  static Future<Map<String, dynamic>?>
      getMySupportChat() async {
    final data = await client.rpc(
      'get_my_support_chat',
    );

    if (data == null) {
      return null;
    }

    if (data is List && data.isNotEmpty) {
      return Map<String, dynamic>.from(
        data.first,
      );
    }

    return null;
  }

  static Future<List<Map<String, dynamic>>>
      supportMessages(
    String conversationId,
  ) async {
    final data = await client
        .from('support_messages')
        .select(
          'id,conversation_id,sender_id,sender_type,message,is_read,created_at',
        )
        .eq(
          'conversation_id',
          conversationId,
        )
        .order(
          'created_at',
          ascending: true,
        );

    return List<Map<String, dynamic>>.from(
      data,
    );
  }

  static Future<String> sendSupportMessage({
    required String conversationId,
    required String message,
  }) async {
    final text = message.trim();

    if (text.isEmpty) {
      throw Exception(
        'Message cannot be empty.',
      );
    }

    final result = await client.rpc(
      'send_support_message',
      params: {
        'p_conversation_id': conversationId,
        'p_message': text,
      },
    );

    if (result == null) {
      throw Exception(
        'Message could not be sent.',
      );
    }

    return result.toString();
  }

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
  // REALTIME SUPPORT CHAT
  // =========================================================

  static RealtimeChannel supportChatChannel(
    String conversationId, {
    required Future<void> Function() onMessage,
  }) {
    final channel = client.channel(
      'support-chat-$conversationId',
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'support_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (payload) async {
        try {
          await onMessage();
        } catch (_) {
          // Ignore realtime callback errors.
        }
      },
    );

    channel.subscribe();

    return channel;
  }
}
