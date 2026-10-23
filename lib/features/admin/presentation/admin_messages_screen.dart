import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../messages/presentation/message_providers.dart';
import 'widgets/admin_table.dart';

/// Inbox of customer and seller threads sent directly to BookVerse Admin.
class AdminMessagesScreen extends ConsumerStatefulWidget {
  const AdminMessagesScreen({super.key});

  @override
  ConsumerState<AdminMessagesScreen> createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends ConsumerState<AdminMessagesScreen> {
  int _selectedFilter = 0; // 0: All, 1: Customers, 2: Sellers

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

  Future<void> _refresh() async {
    ref.invalidate(adminConversationsProvider);
    await ref.read(adminConversationsProvider.future).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final convsAsync = ref.watch(adminConversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('BookVerse Messages'),
      ),
      body: convsAsync.when(
        data: (allConversations) {
          final filtered = allConversations.where((conv) {
            final isSeller = (conv.senderRoleBadge ?? '').startsWith('Seller');
            if (_selectedFilter == 1) return !isSeller;
            if (_selectedFilter == 2) return isSeller;
            return true;
          }).toList();

          final customerCount = allConversations.where((c) => !(c.senderRoleBadge ?? '').startsWith('Seller')).length;
          final sellerCount = allConversations.where((c) => (c.senderRoleBadge ?? '').startsWith('Seller')).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All (${allConversations.length})',
                      isSelected: _selectedFilter == 0,
                      onTap: () => setState(() => _selectedFilter = 0),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Customers ($customerCount)',
                      isSelected: _selectedFilter == 1,
                      onTap: () => setState(() => _selectedFilter = 1),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Sellers ($sellerCount)',
                      isSelected: _selectedFilter == 2,
                      onTap: () => setState(() => _selectedFilter = 2),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView(
                          children: [
                            SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
                            EmptyState(
                              icon: Icons.chat_bubble_outline_rounded,
                              title: 'No messages found',
                              message: _selectedFilter == 2
                                  ? 'No messages from sellers yet.'
                                  : _selectedFilter == 1
                                      ? 'No messages from customers yet.'
                                      : 'When customers or sellers message BookVerse, their chats appear here.',
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => Divider(height: 1, indent: 72, color: colors.borderSubtle),
                          itemBuilder: (context, i) {
                          final conv = filtered[i];
                          final buyerName = conv.buyerName ?? 'User';
                          final hasUnread = conv.unreadCount > 0;
                          final roleBadge = conv.senderRoleBadge ?? 'Customer';
                          final isSeller = roleBadge.startsWith('Seller');

                          return ListTile(
                            onTap: () => context.push(
                              '${AppRoute.adminMessages}/${conv.id}?buyerName=${Uri.encodeComponent(buyerName)}&roleBadge=${Uri.encodeComponent(roleBadge)}',
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
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isSeller
                                        ? colors.ink.withValues(alpha: 0.1)
                                        : colors.background,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSeller
                                          ? colors.ink.withValues(alpha: 0.3)
                                          : colors.borderSubtle,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isSeller ? Icons.storefront_rounded : Icons.person_outline_rounded,
                                        size: 11,
                                        color: isSeller ? colors.ink : colors.textTertiary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        roleBadge,
                                        style: TextStyle(
                                          color: isSeller ? colors.ink : colors.textTertiary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
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
                      ),
                    ),
              ),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
        error: (e, _) => Center(child: Text('Could not load messages.\n$e', textAlign: TextAlign.center)),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.isSelected, required this.onTap});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colors.ink : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? colors.ink : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? colors.onInk : colors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// One customer or seller thread, answered as "BookVerse Official" / Admin.
class AdminConversationScreen extends ConsumerStatefulWidget {
  const AdminConversationScreen({
    super.key,
    required this.conversationId,
    this.buyerName,
    this.roleBadge,
  });

  final String conversationId;
  final String? buyerName;
  final String? roleBadge;

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
                Text(
                  widget.roleBadge != null ? 'Official Chat · ${widget.roleBadge}' : 'BookVerse Support Mode',
                  style: TextStyle(color: colors.textTertiary, fontSize: 11),
                ),
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
