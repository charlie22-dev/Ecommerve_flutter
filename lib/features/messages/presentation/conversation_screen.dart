import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/store_message.dart';
import '../../../core/theme/app_color_tokens.dart';
import 'message_providers.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _welcomeChecked = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    ref.read(messageActionsProvider).send(text);
    _textController.clear();
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
      if (thread != null && thread.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('BookVerse Store')),
      body: Column(
        children: [
          Expanded(
            child: threadAsync.when(
              data: (thread) {
                if (thread.isEmpty) return const SizedBox.shrink();
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: thread.length,
                  itemBuilder: (context, i) => _MessageBubble(message: thread[i]),
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
              error: (err, _) => Center(child: Text('Could not load this conversation.', style: TextStyle(color: colors.error))),
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(color: colors.surface, border: Border(top: BorderSide(color: colors.border))),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: TextStyle(color: colors.textPrimary),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: 'Type a message…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.send_rounded, color: colors.ink),
                    onPressed: _send,
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final StoreMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isUser = message.sender == MessageSender.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isUser ? colors.ink : colors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.text, style: TextStyle(color: isUser ? colors.onInk : colors.textPrimary, fontSize: 13.5)),
            if (message.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat.jm().format(message.createdAt!),
                style: TextStyle(color: (isUser ? colors.onInk : colors.textTertiary).withValues(alpha: 0.6), fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
