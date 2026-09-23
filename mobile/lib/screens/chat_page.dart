import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController messageController =
      TextEditingController();

  final ScrollController scrollController =
      ScrollController();

  List<Map<String, dynamic>> messages = [];

  String? conversationId;

  bool loading = true;
  bool sending = false;

  RealtimeChannel? realtimeChannel;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      final id = await SupabaseService.getOrCreateSupportChat();

      conversationId = id;

      await _loadMessages();

      await SupabaseService.markSupportMessagesRead(id);

      _subscribeToMessages();
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _loadMessages() async {
    final id = conversationId;

    if (id == null) return;

    final data = await SupabaseService.supportMessages(id);

    if (!mounted) return;

    setState(() {
      messages = data;
    });

    _scrollToBottom();
  }

  void _subscribeToMessages() {
    final id = conversationId;

    if (id == null) return;

    realtimeChannel = SupabaseService.supportChatChannel(id);

    realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'support_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: id,
      ),
      callback: (payload) async {
        await _loadMessages();

        if (mounted) {
          await SupabaseService.markSupportMessagesRead(id);
        }
      },
    );
  }

  Future<void> _sendMessage() async {
    final text = messageController.text.trim();

    if (text.isEmpty) return;

    final id = conversationId;

    if (id == null) {
      _showError('Chat is not ready yet.');
      return;
    }

    if (sending) return;

    setState(() {
      sending = true;
    });

    try {
      await SupabaseService.sendSupportMessage(
        conversationId: id,
        message: text,
      );

      messageController.clear();

      await _loadMessages();
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;

      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message.replaceFirst('Exception: ', ''),
        ),
      ),
    );
  }

  String _time(dynamic value) {
    if (value == null) return '';

    try {
      final date = DateTime.parse(value.toString()).toLocal();

      final hour = date.hour == 0
          ? 12
          : date.hour > 12
              ? date.hour - 12
              : date.hour;

      final minute =
          date.minute.toString().padLeft(2, '0');

      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '$hour:$minute $period';
    } catch (_) {
      return '';
    }
  }

  bool _isMine(Map<String, dynamic> message) {
    return message['sender_id'] ==
        Supabase.instance.client.auth.currentUser?.id;
  }

  @override
  void dispose() {
    realtimeChannel?.unsubscribe();

    messageController.dispose();
    scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 0,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 19,
              child: Icon(
                Icons.support_agent,
                size: 23,
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ZenexPay Support',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Chat with Admin',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading
                ? null
                : () async {
                    await _loadMessages();
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(
                    12,
                    12,
                    12,
                    4,
                  ),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 21,
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Need help with a task, payment, withdrawal, or account issue? Send a message to ZenexPay Admin.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: messages.isEmpty
                      ? _emptyChat()
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(
                            14,
                            14,
                            14,
                            20,
                          ),
                          itemCount: messages.length,
                          itemBuilder: (_, index) {
                            return _messageBubble(
                              messages[index],
                            );
                          },
                        ),
                ),

                _composer(),
              ],
            ),
    );
  }

  Widget _emptyChat() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(.10),
              ),
              child: Icon(
                Icons.support_agent,
                size: 40,
                color: Theme.of(context)
                    .colorScheme
                    .primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Chat with ZenexPay Admin',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Send your question or problem below. Admin can reply directly here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageBubble(
    Map<String, dynamic> message,
  ) {
    final mine = _isMine(message);

    return Align(
      alignment: mine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.sizeOf(context).width * .78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(
          14,
          11,
          14,
          9,
        ),
        decoration: BoxDecoration(
          color: mine
              ? Theme.of(context)
                  .colorScheme
                  .primary
              : Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(
              mine ? 18 : 4,
            ),
            bottomRight: Radius.circular(
              mine ? 4 : 18,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 4,
                ),
                child: Text(
                  'ZenexPay Admin',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                  ),
                ),
              ),
            Text(
              message['message'] ?? '',
              style: TextStyle(
                color:
                    mine ? Colors.white : null,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _time(message['created_at']),
              style: TextStyle(
                fontSize: 10,
                color: mine
                    ? Colors.white70
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          10,
          8,
          10,
          8,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Colors.grey.withOpacity(.15),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: messageController,
                minLines: 1,
                maxLines: 5,
                textInputAction:
                    TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Write a message...',
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(.55),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) {
                  if (!sending) {
                    _sendMessage();
                  }
                },
              ),
            ),
            const SizedBox(width: 7),
            SizedBox(
              width: 48,
              height: 48,
              child: FilledButton(
                onPressed:
                    sending ? null : _sendMessage,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
                child: sending
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
