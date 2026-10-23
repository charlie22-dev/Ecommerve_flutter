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

class _SellerConversationListView extends ConsumerWidget {
  const _SellerConversationListView({required this.storeId, required this.storeName});
  final String storeId;
  final String storeName;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final convsAsync = ref.watch(sellerConversationsProvider(storeId));

    return Scaffold(
      appBar: AppBar(
        title: Text('$storeName · Customers', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: convsAsync.when(
        data: (conversations) {
          if (conversations.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No customer messages yet',
              message: 'When buyers message your store or place orders, their chats will appear here.',
            );
          }

          return ListView.separated(
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
                    '/seller/messages/${conv.id}?storeId=$storeId&buyerName=${Uri.encodeComponent(buyerName)}',
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
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
        error: (e, _) => Center(child: Text('Could not load messages.\n$e', textAlign: TextAlign.center)),
      ),
    );
  }
}
