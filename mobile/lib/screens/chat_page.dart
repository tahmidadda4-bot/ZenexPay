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

  bool loading = true;
  bool sending = false;

  bool aiActive = true;
  bool transferred = false;
  bool aiUnavailable = false;
  bool showAdminOption = false;

  RealtimeChannel? channel;

  @override
  void initState() {
    super.initState();
    _init();
  }

  // ---------------------------------------------------------------------------
  // INITIALIZE CHAT
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    try {
      conversationId =
          await SupabaseService.getOrCreateSupportChat();

      final aiState =
          await SupabaseService.supportAiState(conversationId!);

      if (aiState?['status'] == 'admin_handoff' &&
          (
            aiState?['handoff_reason'] ==
                'AI requested Admin handoff.' ||
            aiState?['handoff_reason'] ==
                'User requested human support.'
          ) &&
          mounted) {
        aiActive = false;
        transferred = true;
      }

      await _load();

      await SupabaseService.markSupportMessagesRead(
        conversationId!,
      );

      channel = SupabaseService.supportChatChannel(
        conversationId!,
        onMessage: () async {
          await _load();

          if (mounted) {
            await SupabaseService.markSupportMessagesRead(
              conversationId!,
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        _msg(friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // LOAD MESSAGES
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    if (conversationId == null) return;

    final data =
        await SupabaseService.supportMessages(conversationId!);

    if (!mounted) return;

    setState(() {
      messages = data;
    });

    _bottom();
  }

  // ---------------------------------------------------------------------------
  // SCROLL TO BOTTOM
  // ---------------------------------------------------------------------------

  void _bottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;

      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // SEND MESSAGE
  // ---------------------------------------------------------------------------

  Future<void> _send() async {
    final text = controller.text.trim();

    if (text.isEmpty ||
        conversationId == null ||
        sending) {
      return;
    }

    setState(() {
      sending = true;
    });

    try {
      // -----------------------------------------------------------------------
      // AI SUPPORT MODE
      // -----------------------------------------------------------------------

      if (aiActive && !transferred) {
        try {
          final result =
              await SupabaseService.aiSupportTurn(
            conversationId: conversationId!,
            message: text,
          );

          controller.clear();

          final unavailable =
              result['ai_unavailable'] == true;

          final handoff =
              result['handoff'] == true;

          final adminOption =
              result['show_admin_button'] == true;

          final reply =
              '${result['reply'] ?? ''}'.trim();

          if (mounted) {
            setState(() {
              aiUnavailable = unavailable;

              // Never keep the button after an actual handoff.
              showAdminOption =
                  adminOption && !handoff;
            });
          }

          // -------------------------------------------------------------------
          // AI REQUESTED HUMAN HANDOFF
          // -------------------------------------------------------------------

          if (handoff) {
            if (mounted) {
              setState(() {
                aiActive = false;
                transferred = true;
                aiUnavailable = false;
                showAdminOption = false;
              });
            }

            if (reply.isNotEmpty && mounted) {
              _msg(reply);
            }
          }

          // -------------------------------------------------------------------
          // AI TEMPORARILY UNAVAILABLE
          // -------------------------------------------------------------------

          else if (unavailable) {
            // IMPORTANT:
            // AI failure must NOT automatically transfer to Admin.
            // User gets Human Support button if backend requested it.
            if (reply.isNotEmpty && mounted) {
              _msg(reply);
            }
          }

          await _load();
        } catch (e) {
          // -------------------------------------------------------------------
          // NETWORK / FUNCTION ERROR
          // -------------------------------------------------------------------
          // Never automatically transfer to Admin here.

          if (mounted) {
            _msg(
              'AI support is temporarily unavailable. '
              'Please try again in a moment.',
            );
          }
        }
      }

      // -----------------------------------------------------------------------
      // HUMAN SUPPORT MODE
      // -----------------------------------------------------------------------

      else {
        await SupabaseService.sendSupportMessage(
          conversationId: conversationId!,
          message: text,
        );

        controller.clear();

        await _load();
      }
    } catch (e) {
      if (mounted) {
        _msg(friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // HUMAN SUPPORT HANDOFF
  // ---------------------------------------------------------------------------

  Future<void> _handoffToHuman() async {
    if (conversationId == null ||
        transferred ||
        sending) {
      return;
    }

    setState(() {
      sending = true;
    });

    try {
      final result =
          await SupabaseService.aiSupportTurn(
        conversationId: conversationId!,
        message:
            'I would like to speak with a human support agent.',
      );

      if (result['handoff'] != true) {
        throw Exception(
          'Human support handoff could not be started.',
        );
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
      if (mounted) {
        _msg(friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // SNACKBAR
  // ---------------------------------------------------------------------------

  void _msg(String x) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          x.replaceFirst('Exception: ', ''),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CHECK MESSAGE OWNER
  // ---------------------------------------------------------------------------

  bool _mine(Map<String, dynamic> m) {
    return m['sender_id'] ==
        Supabase.instance.client.auth.currentUser?.id;
  }

  // ---------------------------------------------------------------------------
  // TIME FORMAT
  // ---------------------------------------------------------------------------

  String _time(dynamic v) {
    final d = DateTime.tryParse('$v')?.toLocal();

    if (d == null) return '';

    final h = d.hour == 0
        ? 12
        : d.hour > 12
            ? d.hour - 12
            : d.hour;

    return '$h:${d.minute.toString().padLeft(2, '0')} '
        '${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  // ---------------------------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    channel?.unsubscribe();
    controller.dispose();
    scroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext c) {
    final theme = Theme.of(c);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(.11),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.support_agent_rounded,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 10),

            // Expanded prevents AppBar title overflow.
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ZenexPay Support',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    transferred
                        ? 'Human support is helping you'
                        : 'AI Support • Human support when needed',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: loading ? null : _load,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // BODY
      // -----------------------------------------------------------------------

      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                // -----------------------------------------------------------------
                // TOP STATUS BANNER
                // -----------------------------------------------------------------

                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(
                    14,
                    8,
                    14,
                    4,
                  ),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(.065),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        transferred
                            ? Icons.support_agent_rounded
                            : Icons.auto_awesome_rounded,
                        size: 19,
                      ),
                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          transferred
                              ? 'Your conversation has been transferred to ZenexPay human support.'
                              : 'AI Support will guide you first. If you ask for a human/agent or AI cannot continue, you can switch to human support.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // -----------------------------------------------------------------
                // HUMAN SUPPORT OPTION
                // -----------------------------------------------------------------

                if (showAdminOption && !transferred)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(
                      14,
                      6,
                      14,
                      8,
                    ),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withOpacity(.72),
                      borderRadius:
                          BorderRadius.circular(18),
                      border: Border.all(
                        color: scheme.outlineVariant
                            .withOpacity(.45),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: scheme.primary
                                    .withOpacity(.10),
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.support_agent_rounded,
                                color: scheme.primary,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 10),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Human Support Available',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'AI Support is temporarily unavailable. You can continue with a human support agent.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.35,
                                      color: scheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 11),

                        // Full width button.
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: FilledButton.icon(
                            onPressed: sending
                                ? null
                                : _handoffToHuman,
                            icon: const Icon(
                              Icons.support_agent_rounded,
                              size: 19,
                            ),
                            label: const Text(
                              'Continue with Human Support',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // -----------------------------------------------------------------
                // CHAT MESSAGE AREA
                // -----------------------------------------------------------------

                Expanded(
                  child: messages.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.forum_outlined,
                                  size: 55,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Start a conversation',
                                  style: TextStyle(
                                    fontWeight:
                                        FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'ZenexPay Support is here to help.',
                                  textAlign:
                                      TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scroll,
                          padding:
                              const EdgeInsets.fromLTRB(
                            14,
                            12,
                            14,
                            18,
                          ),
                          itemCount: messages.length,
                          itemBuilder: (_, i) {
                            final m = messages[i];
                            final mine = _mine(m);

                            final bg = mine
                                ? scheme.primary
                                : scheme.surface;

                            return Align(
                              alignment: mine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints:
                                    BoxConstraints(
                                  maxWidth:
                                      MediaQuery.sizeOf(c)
                                              .width *
                                          .80,
                                ),
                                margin:
                                    const EdgeInsets.only(
                                  bottom: 8,
                                ),
                                padding:
                                    const EdgeInsets.fromLTRB(
                                  14,
                                  11,
                                  14,
                                  8,
                                ),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius:
                                      BorderRadius.only(
                                    topLeft:
                                        const Radius.circular(
                                      18,
                                    ),
                                    topRight:
                                        const Radius.circular(
                                      18,
                                    ),
                                    bottomLeft:
                                        Radius.circular(
                                      mine ? 18 : 4,
                                    ),
                                    bottomRight:
                                        Radius.circular(
                                      mine ? 4 : 18,
                                    ),
                                  ),
                                  border: mine
                                      ? null
                                      : Border.all(
                                          color: scheme
                                              .outlineVariant
                                              .withOpacity(.45),
                                        ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Align(
                                      alignment:
                                          Alignment.centerLeft,
                                      child: Text(
                                        '${m['message'] ?? ''}',
                                        style: TextStyle(
                                          color: mine
                                              ? Colors.white
                                              : null,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _time(
                                        m['created_at'],
                                      ),
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: mine
                                            ? Colors.white60
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // -----------------------------------------------------------------
                // MESSAGE INPUT
                // -----------------------------------------------------------------

                Container(
                  padding: const EdgeInsets.fromLTRB(
                    10,
                    8,
                    10,
                    10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: scheme.outlineVariant.withOpacity(.45),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            minLines: 1,
                            maxLines: 5,
                            textInputAction:
                                TextInputAction.newline,
                            decoration:
                                const InputDecoration(
                              hintText:
                                  'Type a message...',
                              prefixIcon: Icon(
                                Icons
                                    .chat_bubble_outline_rounded,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        SizedBox(
                          width: 52,
                          height: 52,
                          child: IconButton.filled(
                            onPressed:
                                sending ? null : _send,
                            icon: sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
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
                ),
              ],
            ),
    );
  }
}
