import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../messages/presentation/message_providers.dart';
import 'seller_providers.dart';

/// Seller Inbox: lists all customer conversations for this store
class SellerMessagesScreen extends ConsumerWidget {
  const SellerMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final storeAsync = ref.watch(myStoreProvider);

    return storeAsync.when(
      data: (store) {
        if (store == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Store Messages')),
            body: const Center(child: Text('You do not have an approved store yet.')),
          );
        }
        return _SellerConversationListView(storeId: store.id, storeName: store.name);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Store Messages')),
        body: Center(child: CircularProgressIndicator(color: colors.ink)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Store Messages')),
        body: Center(child: Text('Could not load store.\n$e', textAlign: TextAlign.center)),
      ),
    );
  }
}

class _SellerConversationListView extends ConsumerStatefulWidget {
  const _SellerConversationListView({required this.storeId, required this.storeName});
  final String storeId;
  final String storeName;

  @override
  ConsumerState<_SellerConversationListView> createState() => _SellerConversationListViewState();
}

class _SellerConversationListViewState extends ConsumerState<_SellerConversationListView> {
  String _formatRelativeTime(DateTime? dt) {
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
    ref.invalidate(sellerConversationsProvider(widget.storeId));
    await ref
        .read(sellerConversationsProvider(widget.storeId).future)
        .then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final convsAsync = ref.watch(sellerConversationsProvider(widget.storeId));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.storeName} · Messages', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          // Banner for seller to directly message BookVerse Admin
          InkWell(
            onTap: () async {
              final official = await ref.read(officialStoreProvider.future);
              if (official == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Official BookVerse store not found')),
                  );
                }
                return;
              }
              try {
                final convId = await ref.read(messageActionsProvider).getOrCreateConversation(official.id);
                if (context.mounted) {
                  context.push('/messages/conversation/$convId?storeName=BookVerse%20Admin');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not open chat: $e')),
                  );
                }
              }
            },
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colors.ink.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.ink.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colors.ink,
                    radius: 18,
                    child: Icon(Icons.shield_rounded, color: colors.onInk, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Contact BookVerse Admin',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: colors.textPrimary),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(color: colors.ink, borderRadius: BorderRadius.circular(4)),
                              child: Text('OFFICIAL', style: TextStyle(color: colors.onInk, fontSize: 8.5, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Direct support for store inquiries, payouts & assistance',
                          style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chat_bubble_outline_rounded, color: colors.ink, size: 18),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text(
                  'Customer Inquiries',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: convsAsync.when(
              data: (conversations) {
                if (conversations.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      children: [
                        SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                        const EmptyState(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'No customer messages yet',
                          message: 'When buyers message your store or place orders, their chats will appear here.',
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    itemCount: conversations.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: colors.borderSubtle),
                    itemBuilder: (context, i) {
                      final conv = conversations[i];
                      final hasUnread = conv.unreadCount > 0;
                      final buyerName = conv.buyerName ?? 'Customer';
                      final initial = buyerName.isNotEmpty ? buyerName[0].toUpperCase() : 'C';

                      return InkWell(
                        onTap: () {
                          context.push(
                            '/seller/messages/${conv.id}?storeId=${widget.storeId}&buyerName=${Uri.encodeComponent(buyerName)}',
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          color: hasUnread ? colors.surface : Colors.transparent,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: colors.ink,
                                backgroundImage: conv.buyerPhoto != null ? NetworkImage(conv.buyerPhoto!) : null,
                                child: conv.buyerPhoto == null
                                    ? Text(
                                        initial,
                                        style: TextStyle(color: colors.onInk, fontWeight: FontWeight.w800, fontSize: 16),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            buyerName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                                              fontSize: 14.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatRelativeTime(conv.lastMessageAt),
                                          style: TextStyle(
                                            color: hasUnread ? colors.error : colors.textTertiary,
                                            fontSize: 11.5,
                                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            conv.lastMessage.isEmpty ? 'No messages yet' : conv.lastMessage,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: hasUnread ? colors.textPrimary : colors.textSecondary,
                                              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        if (hasUnread) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: colors.error,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '${conv.unreadCount}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
              error: (e, _) => Center(child: Text('Could not load messages.\n$e', textAlign: TextAlign.center)),
            ),
          ),
        ],
      ),
    );
  }
}
