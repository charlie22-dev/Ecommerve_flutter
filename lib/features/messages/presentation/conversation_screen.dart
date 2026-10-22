import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/store_message.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../data/typing_service.dart';
import 'message_providers.dart';
import 'widgets/chat_thread.dart';

/// The customer's chat — either with BookVerse Store (storeId == null)
/// or with a specific approved seller store (storeId != null).
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, this.storeId, this.storeName});

  /// Null → BookVerse Official support. Non-null → buyer ↔ seller chat.
  final String? storeId;

  /// Display name of the seller store (used in AppBar title).
  final String? storeName;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  bool _welcomeChecked = false;
  TypingService? _typingService;
  bool _otherIsTyping = false;

  bool get _isSeller => widget.storeId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initTyping());
  }

  void _initTyping() {
    final uid = ref.read(authUidProvider);
    if (uid == null || !mounted) return;
    _typingService = TypingService(userId: uid, senderRole: 'user');
    _typingService!.onOtherTyping.listen((isTyping) {
      if (mounted) setState(() => _otherIsTyping = isTyping);
    });
  }

  void _onTypingChanged(bool isTyping) {
    _typingService?.sendTyping(isTyping);
  }

  @override
  void dispose() {
    _typingService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Choose the right provider based on whether this is a seller chat.
    final threadAsync = _isSeller
        ? ref.watch(sellerThreadProvider(widget.storeId!))
        : ref.watch(storeThreadProvider);

    if (!_isSeller) {
      ref.listen(storeThreadProvider, (previous, next) {
        final thread = next.value;
        if (thread != null && !_welcomeChecked) {
          _welcomeChecked = true;
          ref.read(messageActionsProvider).sendStoreWelcomeIfEmpty(thread);
        }
      });
    }

    final title = _isSeller
        ? (widget.storeName ?? 'Seller')
        : 'BookVerse Store';
    final subtitle = _isSeller
        ? 'Approved seller · reply within a day'
        : 'Official store · usually replies within a day';

    Widget avatar = _isSeller
        ? CircleAvatar(
            radius: 18,
            backgroundColor: colors.accentBlue,
            child: Text(
              title.isNotEmpty ? title[0].toUpperCase() : 'S',
              style: TextStyle(color: colors.onInk, fontWeight: FontWeight.w700),
            ),
          )
        : const StoreAvatar(radius: 18);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: ChatHeader(
          avatar: avatar,
          name: title,
          subtitle: subtitle,
          verified: !_isSeller,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Expanded(
                child: threadAsync.when(
                  data: (thread) => ChatThread(
                    messages: thread,
                    isMine: (m) => m.sender == MessageSender.user,
                    otherAvatar: _isSeller
                        ? CircleAvatar(
                            radius: 16,
                            backgroundColor: colors.accentBlue,
                            child: Text(
                              title.isNotEmpty ? title[0].toUpperCase() : 'S',
                              style: TextStyle(
                                color: colors.onInk,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : const StoreAvatar(),
                    showTypingIndicator: _otherIsTyping,
                  ),
                  loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
                  error: (err, _) =>
                      Center(child: Text('Could not load this conversation.', style: TextStyle(color: colors.error))),
                ),
              ),
              ChatComposer(
                hint: 'Type a message…',
                onSend: (text) async {
                  if (_isSeller) {
                    await ref.read(sellerMessageActionsProvider).send(text, widget.storeId!);
                  } else {
                    await ref.read(messageActionsProvider).send(text);
                  }
                },
                onTypingChanged: _onTypingChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
