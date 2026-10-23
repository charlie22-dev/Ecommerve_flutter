import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../messages/presentation/message_providers.dart';
import 'widgets/admin_table.dart';

/// Inbox of customer threads for the Admin Panel.
class AdminMessagesScreen extends ConsumerWidget {
  const AdminMessagesScreen({super.key});

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (dt.year == now.year) return DateFormat('MMM d').format(dt);
    return DateFormat('MM/dd/yy').format(dt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final convsAsync = ref.watch(adminConversationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Customer Messages')),
      body: convsAsync.when(
        data: (conversations) {
          if (conversations.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No messages yet',
              message: 'When customers message the store, their conversations show up here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: conversations.length,
            separatorBuilder: (_, _) => Divider(height: 1, indent: 72, color: colors.borderSubtle),
            itemBuilder: (context, i) {
              final conv = conversations[i];
              final buyerName = conv.buyerName ?? 'Customer';
              final hasUnread = conv.unreadCount > 0;
              final storeName = conv.storeName ?? 'Store';

              return ListTile(
                onTap: () => context.push(
                  '${AppRoute.adminMessages}/${conv.id}?buyerName=${Uri.encodeComponent(buyerName)}',
                ),
                leading: InitialAvatar(buyerName, photoUrl: conv.buyerPhoto, radius: 20),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        buyerName,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colors.borderSubtle),
                      ),
                      child: Text(
                        storeName,
                        style: TextStyle(color: colors.textTertiary, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  conv.lastMessage.isEmpty ? 'No messages yet' : conv.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasUnread ? colors.textPrimary : colors.textTertiary,
                    fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(conv.lastMessageAt),
                      style: TextStyle(
                        color: hasUnread ? colors.error : colors.textTertiary,
                        fontSize: 11,
                        fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    if (hasUnread) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: colors.error, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          '${conv.unreadCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
        error: (e, _) => Center(child: Text('Could not load messages.\n$e', textAlign: TextAlign.center)),
      ),
    );
  }
}

/// One customer's thread, answered as "BookVerse Store" / Admin.
class AdminConversationScreen extends ConsumerStatefulWidget {
  const AdminConversationScreen({
    super.key,
    required this.conversationId,
    this.buyerName,
  });

  final String conversationId;
  final String? buyerName;

  @override
  ConsumerState<AdminConversationScreen> createState() => _AdminConversationScreenState();
}

class _AdminConversationScreenState extends ConsumerState<AdminConversationScreen> {
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

  String _formatTime(DateTime? dt) => dt == null ? '' : DateFormat.jm().format(dt);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final myUid = ref.watch(authUidProvider);
    final messagesAsync = ref.watch(conversationMessagesProvider(widget.conversationId));
    final name = widget.buyerName ?? 'Customer';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            InitialAvatar(name, radius: 18),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text('Admin Chat Mode', style: TextStyle(color: colors.textTertiary, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
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

                        return Align(
                          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
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
                                  msg.body,
                                  style: TextStyle(
                                    color: isMine ? colors.onInk : colors.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(msg.createdAt),
                                  style: TextStyle(
                                    color: isMine ? colors.onInk.withValues(alpha: 0.7) : colors.textTertiary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
                  error: (e, _) => Center(child: Text('Could not load conversation.\n$e', textAlign: TextAlign.center)),
                ),
              ),
              Container(
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
                          controller: _textController,
                          maxLines: 4,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Reply as BookVerse Store…',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _send,
                      style: IconButton.styleFrom(backgroundColor: colors.ink),
                      icon: Icon(Icons.send_rounded, color: colors.onInk, size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
