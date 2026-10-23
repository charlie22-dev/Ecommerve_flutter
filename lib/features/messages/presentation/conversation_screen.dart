import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../checkout/presentation/checkout_providers.dart' show orderStreamProvider;
import 'message_providers.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    super.key,
    this.conversationId,
    this.storeId,
    this.storeName,
  });

  final String? conversationId;
  final String? storeId;
  final String? storeName;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  String? _resolvedConvId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resolvedConvId = widget.conversationId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (_resolvedConvId == null && widget.storeId != null) {
      setState(() => _isLoading = true);
      try {
        final id = await ref.read(messageActionsProvider).getOrCreateConversation(widget.storeId!);
        if (mounted) {
          setState(() {
            _resolvedConvId = id;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open chat: $e')));
        }
      }
    }

    if (_resolvedConvId != null) {
      ref.read(messageActionsProvider).markRead(_resolvedConvId!);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _resolvedConvId == null) return;
    _textController.clear();

    try {
      await ref.read(messageActionsProvider).send(
            conversationId: _resolvedConvId!,
            text: text,
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send: $e')));
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final myUid = ref.watch(authUidProvider);
    final title = widget.storeName ?? 'Chat';

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: CircularProgressIndicator(color: colors.ink)),
      );
    }

    if (_resolvedConvId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text('Conversation not found.')),
      );
    }

    final messagesAsync = ref.watch(conversationMessagesProvider(_resolvedConvId!));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('BookVerse Bookstore', style: TextStyle(color: colors.textTertiary, fontSize: 11)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Start the conversation!\nSend a message to $title.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.textTertiary, fontSize: 13.5),
                      ),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMine = msg.senderId == myUid;

                    if (msg.type == ChatMessageType.order && msg.orderId != null) {
                      return _OrderMessageBubble(
                        message: msg,
                        isMine: isMine,
                        myUid: myUid,
                      );
                    }

                    return _TextMessageBubble(
                      message: msg,
                      isMine: isMine,
                    );
                  },
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
              error: (e, _) => Center(child: Text('Could not load messages.\n$e', textAlign: TextAlign.center)),
            ),
          ),
          _ComposerBar(
            controller: _textController,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _TextMessageBubble extends StatelessWidget {
  const _TextMessageBubble({required this.message, required this.isMine});
  final ChatMessage message;
  final bool isMine;

  String _formatTime(DateTime? dt) => dt == null ? '' : DateFormat.jm().format(dt);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final timeStr = _formatTime(message.createdAt);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? colors.ink : colors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          border: isMine ? null : Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: TextStyle(
                color: isMine ? colors.onInk : colors.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                color: isMine ? colors.onInk.withValues(alpha: 0.7) : colors.textTertiary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderMessageBubble extends ConsumerWidget {
  const _OrderMessageBubble({
    required this.message,
    required this.isMine,
    required this.myUid,
  });

  final ChatMessage message;
  final bool isMine;
  final String? myUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final orderAsync = ref.watch(orderStreamProvider(message.orderId!));

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping_outlined, size: 16, color: colors.ink),
                const SizedBox(width: 6),
                Text(
                  'ORDER UPDATE',
                  style: TextStyle(color: colors.ink, fontWeight: FontWeight.w800, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message.body,
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
            const SizedBox(height: 8),
            orderAsync.when(
              data: (order) {
                if (order == null) return const SizedBox.shrink();
                final firstItem = order.items.isNotEmpty ? order.items.first : null;
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      if (firstItem?.coverUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(width: 36, height: 48, child: BookCoverImage(url: firstItem!.coverUrl)),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              firstItem?.title ?? 'Book order',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            Text(
                              'Status: ${order.status.name}',
                              style: TextStyle(color: colors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
    required this.controller,
    required this.onSend,
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: TextField(
                controller: controller,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type a message…',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onSend,
            style: IconButton.styleFrom(backgroundColor: colors.ink),
            icon: Icon(Icons.send_rounded, color: colors.onInk, size: 20),
          ),
        ],
      ),
    );
  }
}
