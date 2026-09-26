import 'dart:convert';
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
  final List<Map<String, dynamic>> referrals;
  final int totalReferrals;
  final int successfulReferrals;
  final int pendingReferrals;
  final double reward;

  const ReferralInfo({
    required this.code,
    required this.referrals,
    required this.totalReferrals,
    required this.successfulReferrals,
    required this.pendingReferrals,
    required this.reward,
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

  // =========================================================
  // SUBMIT TASK
  // =========================================================

  static Future<Map<String, dynamic>?> submissionForTask(String taskId) async {
    return await client
        .from('task_submissions')
        .select('id,task_id,status,proof_text,admin_note,rejection_reason,screenshot_reason,created_at,updated_at')
        .eq('user_id', uid)
        .eq('task_id', taskId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
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
    await logActivity(action: 'task_submit', entityType: 'task', entityId: taskId);
  }

  // =========================================================
  // WITHDRAW
  // =========================================================

  // =========================================================
  // WITHDRAWAL METHODS
  // =========================================================

  static Future<List<Map<String, dynamic>>> withdrawalMethods() async {
    final data = await client
        .from('withdrawal_methods')
        .select('id,method_type,account_number,created_at,updated_at')
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
        .select('id,method_type,account_number,created_at,updated_at')
        .single();

    final result = Map<String, dynamic>.from(row);
    await logActivity(action: 'withdrawal_method_save', entityType: 'withdrawal_method', entityId: '${result['id']}');
    return result;
  }

  static Future<Map<String, dynamic>?> transactionById(String id) async {
    final data = await client
        .from('transactions')
        .select('id,type,amount,description,status,withdrawal_method,withdrawal_account,created_at')
        .eq('id', id)
        .eq('user_id', uid)
        .maybeSingle();

    return data;
  }

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
    await logActivity(action: 'withdrawal_request', entityType: 'transaction', entityId: '${transaction['id']}', metadata: {'amount': amount, 'method_id': methodId});
    return transaction;
  }

  // =========================================================
  // DAILY FEATURES
  // =========================================================

  static Future<Map<String, dynamic>> dailyGoal() async {
    final result = await client.rpc('get_daily_goal');
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<Map<String, dynamic>> dailyCheckInStatus() async {
    final today = DateTime.now().toUtc().add(const Duration(hours: 6));
    final date = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final settings = await client.from('daily_feature_settings').select('checkin_reward,daily_goal_target').eq('id', true).maybeSingle();
    final checkin = await client.from('daily_checkins').select('streak,reward,checkin_date').eq('user_id', uid).eq('checkin_date', date).maybeSingle();
    final latest = await client.from('daily_checkins').select('streak,checkin_date').eq('user_id', uid).order('checkin_date', ascending: false).limit(1).maybeSingle();
    return {
      'reward': settings?['checkin_reward'] ?? 20,
      'claimed': checkin != null,
      'today': checkin,
      'streak': latest?['streak'] ?? 0,
    };
  }

  static Future<void> claimDailyCheckIn() async {
    await client.rpc('claim_daily_checkin');
    await logActivity(action: 'daily_checkin_claim', entityType: 'daily_checkin');
  }

  static Future<List<Map<String, dynamic>>> dailyMissions() async {
    final data = await client.from('daily_missions').select('id,title,description,reward,target_tasks,starts_at,ends_at').eq('is_active', true).order('created_at', ascending: false);
    final rows = List<Map<String, dynamic>>.from(data);
    final today = DateTime.now().toUtc().add(const Duration(hours: 6));
    final date = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final claims = await client.from('daily_mission_claims').select('mission_id,reward').eq('user_id', uid).eq('claim_date', date);
    final claimIds = {for (final r in List<Map<String, dynamic>>.from(claims)) '${r['mission_id']}'};
    final goal = await dailyGoal();
    final completed = int.tryParse('${goal['completed'] ?? 0}') ?? 0;
    return rows.map((r) => {...r, 'claimed': claimIds.contains('${r['id']}'), 'completed': completed}).toList();
  }

  static Future<void> claimDailyMission(String missionId) async {
    await client.rpc('claim_daily_mission', params: {'p_mission_id': missionId});
    await logActivity(action: 'daily_mission_claim', entityType: 'daily_mission', entityId: missionId);
  }

  static Future<List<Map<String, dynamic>>> promotions() async {
    final data = await client.from('promotions').select('id,kind,title,description,reward,action_label,starts_at,ends_at').eq('is_active', true).order('created_at', ascending: false);
    final rows = List<Map<String, dynamic>>.from(data);
    final today = DateTime.now().toUtc().add(const Duration(hours: 6));
    final date = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final claims = await client.from('promotion_claims').select('promotion_id,reward').eq('user_id', uid).eq('claim_date', date);
    final claimIds = {for (final r in List<Map<String, dynamic>>.from(claims)) '${r['promotion_id']}'};
    return rows.map((r) => {...r, 'claimed': claimIds.contains('${r['id']}')}).toList();
  }

  static Future<void> claimPromotion(String promotionId) async {
    await client.rpc('claim_promotion', params: {'p_promotion_id': promotionId});
    await logActivity(action: 'promotion_claim', entityType: 'promotion', entityId: promotionId);
  }

  static Future<Map<String, dynamic>?> profile() async {
    return await client.from('profiles').select('id,full_name,phone,referral_code,user_numeric_id').eq('id', uid).maybeSingle();
  }

  static Future<void> updateProfile({required String fullName, String? phone}) async {
    await client.from('profiles').update({
      'full_name': fullName.trim(),
      'phone': (phone ?? '').trim().isEmpty ? null : phone!.trim(),
    }).eq('id', uid);
    await logActivity(action: 'profile_update', entityType: 'profile', entityId: uid);
    await client.auth.updateUser(UserAttributes(data: {'full_name': fullName.trim()}));
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
    await logActivity(action: 'screenshot_submit', entityType: 'task_submission', entityId: submissionId);
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
    final result = await client.rpc('get_my_referral_info');
    final data = Map<String, dynamic>.from(result as Map);
    return ReferralInfo(
      code: '${data['code'] ?? ''}'.trim(),
      referrals: List<Map<String, dynamic>>.from((data['referrals'] as List?) ?? const []),
      totalReferrals: int.tryParse('${data['total_referrals'] ?? 0}') ?? 0,
      successfulReferrals: int.tryParse('${data['successful_referrals'] ?? 0}') ?? 0,
      pendingReferrals: int.tryParse('${data['pending_referrals'] ?? 0}') ?? 0,
      reward: double.tryParse('${data['reward'] ?? 0}') ?? 0,
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
    await logActivity(action: 'referral_code_apply', entityType: 'referral', metadata: {'code': value});
  }

  static Future<List<Map<String, dynamic>>> myActivity() async {
    final data = await client
        .from('user_activity_audit')
        .select('id,action,entity_type,entity_id,metadata,created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(data);
  }

  // =========================================================
  // USER ACTIVITY / AUDIT
  // =========================================================

  static Future<void> logActivity({
    required String action,
    String entityType = 'app',
    String? entityId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await client.rpc('log_user_activity', params: {
        'p_action': action,
        'p_entity_type': entityType,
        'p_entity_id': entityId,
        'p_metadata': metadata ?? <String, dynamic>{},
      });
    } catch (_) {
      // Audit logging must never block the user's primary action.
    }
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


  static Future<Map<String, dynamic>?> taskById(String taskId) async {
    final data = await client.from('tasks').select('*').eq('id', taskId).maybeSingle();
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>?> submissionById(String submissionId) async {
    final data = await client.from('task_submissions').select('*,tasks(*)').eq('id', submissionId).maybeSingle();
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>?> supportAiState(String conversationId) async {
    final data = await client.from('support_ai_sessions').select('conversation_id,user_id,status,handoff_reason,updated_at').eq('conversation_id', conversationId).maybeSingle();
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> aiSupportTurn({
    required String conversationId,
    required String message,
  }) async {
    try {
      final result = await client.functions.invoke(
        'ai-support',
        body: {
          'conversation_id': conversationId,
          'message': message,
        },
      );

      final raw = result.data;
      if (raw is Map) return Map<String, dynamic>.from(raw);
      throw Exception('AI support returned an invalid response.');
    } on FunctionException catch (e) {
      // Supabase throws FunctionException for non-2xx responses. The Edge
      // Function intentionally returns structured JSON for temporary AI
      // failures, so preserve that response for ChatPage instead of treating
      // it as a reason to hand the user to Admin.
      final details = e.details;
      if (details is Map) {
        return Map<String, dynamic>.from(details);
      }
      if (details is String && details.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(details);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
      rethrow;
    }
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
