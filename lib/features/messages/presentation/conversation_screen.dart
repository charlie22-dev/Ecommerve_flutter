import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/store_message.dart';
import '../../../core/theme/app_color_tokens.dart';
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
                  ),
                  loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
                  error: (err, _) =>
                      Center(child: Text('Could not load this conversation.', style: TextStyle(color: colors.error))),
                ),
              ),
              ChatComposer(
                hint: 'Type a message…',
                onSend: (text) => ref.read(messageActionsProvider).send(text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
