import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/network_error.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final controller = TextEditingController();
  final scroll = ScrollController();
  List<Map<String, dynamic>> messages = [];
  String? conversationId;
  bool loading = true, sending = false, aiActive = true, transferred = false, aiUnavailable = false, showAdminOption = false;
  RealtimeChannel? channel;

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    try {
      conversationId = await SupabaseService.getOrCreateSupportChat();
      final aiState = await SupabaseService.supportAiState(conversationId!);
      if (aiState?['status'] == 'admin_handoff' &&
          (aiState?['handoff_reason'] == 'AI requested Admin handoff.' || aiState?['handoff_reason'] == 'User requested human support.') &&
          mounted) {
        aiActive = false;
        transferred = true;
      }
      await _load();
      await SupabaseService.markSupportMessagesRead(conversationId!);
      channel = SupabaseService.supportChatChannel(conversationId!, onMessage: () async {
        await _load();
        if (mounted) await SupabaseService.markSupportMessagesRead(conversationId!);
      });
    } catch (e) { if (mounted) _msg(friendlyError(e)); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> _load() async {
    if (conversationId == null) return;
    final data = await SupabaseService.supportMessages(conversationId!);
    if (!mounted) return;
    setState(() => messages = data);
    _bottom();
  }

  void _bottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _send() async {
    final text = controller.text.trim();
    if (text.isEmpty || conversationId == null || sending) return;

    setState(() => sending = true);
    try {
      if (aiActive && !transferred) {
        try {
          final result = await SupabaseService.aiSupportTurn(
            conversationId: conversationId!,
            message: text,
          );

          controller.clear();

          final unavailable = result['ai_unavailable'] == true;
          final handoff = result['handoff'] == true;
          final quota = result['quota_exhausted'] == true;
          final adminOption = result['show_admin_button'] == true;
          final reply = '${result['reply'] ?? ''}'.trim();

          if (mounted) {
            setState(() {
              aiUnavailable = unavailable;
              showAdminOption = adminOption;
            });
          }

          if (handoff) {
            if (mounted) {
              setState(() {
                aiActive = false;
                transferred = true;
              });
            }
          }

          if (unavailable) {
            // Infrastructure/AI problems must NEVER transfer the user to Admin.
            // Keep AI active so the user can retry the same conversation.
            if (reply.isNotEmpty && mounted) _msg(reply);
            if (quota && mounted) _bottom();
          } else if (handoff && mounted) {
            _msg(reply.isNotEmpty
                ? reply
                : 'I am transferring this conversation to a ZenexPay Admin.');
          }

          await _load();
        } catch (e) {
          // IMPORTANT: never fall back to Admin just because the AI function
          // failed. The conversation remains AI-first and the user can retry.
          if (mounted) _msg(
            'AI support is temporarily unavailable. Please try again in a moment.',
          );
        }
      } else {
        await SupabaseService.sendSupportMessage(
          conversationId: conversationId!,
          message: text,
        );
        controller.clear();
        await _load();
      }
    } catch (e) {
      if (mounted) _msg(friendlyError(e));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _handoffToHuman() async {
    if (conversationId == null || transferred || sending) return;
    setState(() => sending = true);
    try {
      final result = await SupabaseService.aiSupportTurn(
        conversationId: conversationId!,
        message: 'I would like to speak with a human support agent.',
      );
      if (result['handoff'] != true) {
        throw Exception('Human support handoff could not be started.');
      }
      if (!mounted) return;
      setState(() {
        aiActive = false;
        transferred = true;
        aiUnavailable = false;
        showAdminOption = false;
      });
      await _load();
    } catch (e) {
      if (mounted) _msg(friendlyError(e));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _msg(String x) => mounted ? ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(x.replaceFirst('Exception: ', '')), behavior: SnackBarBehavior.floating)) : null;
  bool _mine(Map<String, dynamic> m) => m['sender_id'] == Supabase.instance.client.auth.currentUser?.id;

  String _time(dynamic v) {
    final d = DateTime.tryParse('$v')?.toLocal();
    if (d == null) return '';
    final h = d.hour == 0 ? 12 : d.hour > 12 ? d.hour - 12 : d.hour;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  void dispose() { channel?.unsubscribe(); controller.dispose(); scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: Theme.of(c).colorScheme.primary.withOpacity(.11), borderRadius: BorderRadius.circular(13)), child: Icon(Icons.support_agent_rounded, color: Theme.of(c).colorScheme.primary)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('ZenexPay Support', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), Text(transferred ? 'Human support is helping you' : 'AI Support • Human support when needed', style: const TextStyle(fontSize: 10, color: Colors.grey))]),
          ]),
          actions: [IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Container(margin: const EdgeInsets.fromLTRB(14, 8, 14, 4), padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Theme.of(c).colorScheme.primary.withOpacity(.065), borderRadius: BorderRadius.circular(18)), child: Row(children: [Icon(transferred ? Icons.support_agent_rounded : Icons.auto_awesome_rounded, size: 19), const SizedBox(width: 8), Expanded(child: Text(transferred ? 'Your conversation has been transferred to ZenexPay human support.' : 'AI Support will guide you first. If you ask for a human/agent or AI cannot continue, you can switch to human support.', style: const TextStyle(fontSize: 12.5, height: 1.35)))])),
                if (showAdminOption && !transferred)
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(c).colorScheme.errorContainer.withOpacity(.55),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'AI Support is currently unavailable. You can continue with a human support agent.',
                            style: TextStyle(fontSize: 12.5, height: 1.3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: sending ? null : _handoffToHuman,
                          icon: const Icon(Icons.support_agent_rounded, size: 18),
                          label: const Text('Human Support'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: messages.isEmpty
                      ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.forum_outlined, size: 55), SizedBox(height: 12), Text('Start a conversation', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), SizedBox(height: 4), Text('ZenexPay Support is here to help.')]))
                      : ListView.builder(
                          controller: scroll,
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                          itemCount: messages.length,
                          itemBuilder: (_, i) {
                            final m = messages[i];
                            final mine = _mine(m);
                            final bg = mine ? Theme.of(c).colorScheme.primary : Theme.of(c).colorScheme.surface;
                            return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(c).width * .80), margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.fromLTRB(14, 11, 14, 8), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(mine ? 18 : 4), bottomRight: Radius.circular(mine ? 4 : 18)), border: mine ? null : Border.all(color: Theme.of(c).dividerColor.withOpacity(.45))), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Align(alignment: Alignment.centerLeft, child: Text('${m['message'] ?? ''}', style: TextStyle(color: mine ? Colors.white : null, height: 1.35)),), const SizedBox(height: 4), Text(_time(m['created_at']), style: TextStyle(fontSize: 9, color: mine ? Colors.white60 : Colors.grey))])));
                          },
                        ),
                ),
                Container(padding: const EdgeInsets.fromLTRB(10, 8, 10, 10), decoration: BoxDecoration(color: Theme.of(c).colorScheme.surface, border: Border(top: BorderSide(color: Theme.of(c).dividerColor.withOpacity(.45)))), child: SafeArea(top: false, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: TextField(controller: controller, minLines: 1, maxLines: 5, textInputAction: TextInputAction.newline, decoration: const InputDecoration(hintText: 'Type a message...', prefixIcon: Icon(Icons.chat_bubble_outline_rounded))),), const SizedBox(width: 8), SizedBox(width: 52, height: 52, child: IconButton.filled(onPressed: sending ? null : _send, icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded)))]))),
              ]),
      );
}
