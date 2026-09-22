import 'package:supabase_flutter/supabase_flutter.dart';
class SupabaseService {
  static final client=Supabase.instance.client; static String get uid=>client.auth.currentUser!.id;
  static Future<Map<String,dynamic>?> wallet()=>client.from('wallets').select().eq('user_id',uid).maybeSingle();
  static Future<List<Map<String,dynamic>>> tasks()=>client.from('tasks').select('id,title,description,instructions,reward,proof_required').eq('status','published').order('created_at',ascending:false);
  static Future<List<Map<String,dynamic>>> submissions()=>client.from('task_submissions').select('id,task_id,status,proof_text,admin_note,created_at,tasks(title,reward)').eq('user_id',uid).order('created_at',ascending:false);
  static Future<List<Map<String,dynamic>>> transactions()=>client.from('transactions').select('id,type,amount,description,created_at').eq('user_id',uid).order('created_at',ascending:false);
  static Future<void> submitTask({required String taskId,String? proofText})async{await client.rpc('submit_task',params:{'p_task_id':taskId,'p_proof_text':proofText});}
  static Future<String> withdraw({required double amount,required String method,required String account})async=>client.rpc('submit_withdrawal',params:{'p_amount':amount,'p_method':method,'p_account_number':account}) as String;
}
