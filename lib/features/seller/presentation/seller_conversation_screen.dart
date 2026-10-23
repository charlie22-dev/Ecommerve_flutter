import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../checkout/presentation/checkout_providers.dart' show orderStreamProvider;
import '../../messages/presentation/message_providers.dart';

class SellerConversationScreen extends ConsumerStatefulWidget {
  const SellerConversationScreen({
    super.key,
    required this.conversationId,
    required this.storeId,
    this.buyerName,
  });

  final String conversationId;
  final String storeId;
  final String? buyerName;

  @override
  ConsumerState<SellerConversationScreen> createState() => _SellerConversationScreenState();
}

class _SellerConversationScreenState extends ConsumerState<SellerConversationScreen> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  void _markRead() {
    ref.read(messageActionsProvider).markRead(widget.conversationId);
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
    if (text.isEmpty) return;
    _textController.clear();

    try {
      await ref.read(messageActionsProvider).send(
            conversationId: widget.conversationId,
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
    final messagesAsync = ref.watch(conversationMessagesProvider(widget.conversationId));
    final buyerName = widget.buyerName ?? 'Customer';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(buyerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('Customer Conversation', style: TextStyle(color: colors.textTertiary, fontSize: 11)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages in this conversation yet.'));
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
                      return _SellerOrderBubble(message: msg, isMine: isMine);
                    }

                    return _SellerTextBubble(message: msg, isMine: isMine);
                  },
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
              error: (e, _) => Center(child: Text('Could not load messages.\n$e', textAlign: TextAlign.center)),
            ),
          ),
          _SellerComposerBar(
            controller: _textController,
            hint: 'Reply as store…',
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _SellerTextBubble extends StatelessWidget {
  const _SellerTextBubble({required this.message, required this.isMine});
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

class _SellerOrderBubble extends ConsumerWidget {
  const _SellerOrderBubble({required this.message, required this.isMine});
  final ChatMessage message;
  final bool isMine;

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
                Icon(Icons.receipt_long_rounded, size: 16, color: colors.ink),
                const SizedBox(width: 6),
                Text(
                  'ORDER EVENT',
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

class _SellerComposerBar extends StatelessWidget {
  const _SellerComposerBar({
    required this.controller,
    required this.hint,
    required this.onSend,
  });

  final TextEditingController controller;
  final String hint;
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
                decoration: InputDecoration(
                  hintText: hint,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
