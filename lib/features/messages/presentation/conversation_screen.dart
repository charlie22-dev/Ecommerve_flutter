import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/store_message.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../data/typing_service.dart';
import 'message_providers.dart';
import 'widgets/chat_thread.dart';

/// The customer's chat with BookVerse Store.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  bool _welcomeChecked = false;
  TypingService? _typingService;
  bool _storeIsTyping = false;

  @override
  void initState() {
    super.initState();
    // TypingService needs the user's UID — we initialise it after the first
    // frame so that authStateProvider is already available.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initTyping());
  }

  void _initTyping() {
    final uid = ref.read(authUidProvider);
    if (uid == null || !mounted) return;
    _typingService = TypingService(userId: uid, senderRole: 'user');
    _typingService!.onOtherTyping.listen((isTyping) {
      if (mounted) setState(() => _storeIsTyping = isTyping);
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
    final threadAsync = ref.watch(storeThreadProvider);

    ref.listen(storeThreadProvider, (previous, next) {
      final thread = next.value;
      if (thread != null && !_welcomeChecked) {
        _welcomeChecked = true;
        ref.read(messageActionsProvider).sendStoreWelcomeIfEmpty(thread);
      }
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const ChatHeader(
          avatar: StoreAvatar(radius: 18),
          name: 'BookVerse Store',
          subtitle: 'Official store · usually replies within a day',
          verified: true,
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
                    otherAvatar: const StoreAvatar(),
                    showTypingIndicator: _storeIsTyping,
                  ),
                  loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
                  error: (err, _) =>
                      Center(child: Text('Could not load this conversation.', style: TextStyle(color: colors.error))),
                ),
              ),
              ChatComposer(
                hint: 'Type a message…',
                onSend: (text) => ref.read(messageActionsProvider).send(text),
                onTypingChanged: _onTypingChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
