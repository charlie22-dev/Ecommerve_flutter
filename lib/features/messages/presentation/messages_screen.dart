import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/store.dart';
import '../../../core/theme/app_color_tokens.dart';
import 'message_providers.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
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

  Future<void> _openStoreChat(Store store) async {
    try {
      final convId = await ref.read(messageActionsProvider).getOrCreateConversation(store.id);
      if (mounted) {
        context.push('/messages/conversation/$convId?storeId=${store.id}&storeName=${Uri.encodeComponent(store.name)}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open chat: $e')),
        );
      }
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(buyerConversationsProvider);
    ref.invalidate(approvedStoresListProvider);
    ref.invalidate(officialStoreProvider);
    await Future.wait([
      ref.read(buyerConversationsProvider.future).then((_) {}, onError: (_) {}),
      ref.read(approvedStoresListProvider.future).then((_) {}, onError: (_) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final officialStoreAsync = ref.watch(officialStoreProvider);
    final approvedStoresAsync = ref.watch(approvedStoresListProvider);
    final conversationsAsync = ref.watch(buyerConversationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            // ── Official BookVerse Support ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: officialStoreAsync.when(
                data: (officialStore) {
                  if (officialStore == null) return const SizedBox.shrink();
                  return _OfficialStoreCard(
                    store: officialStore,
                    onTap: () => _openStoreChat(officialStore),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),

            const SizedBox(height: 12),

            // ── Active Conversations ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Recent Conversations',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),

            conversationsAsync.when(
              data: (convs) {
                if (convs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Center(
                        child: Text(
                          'No conversation history yet.\nTap a store below or message a seller from their book page!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.textTertiary, fontSize: 13),
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: convs.length,
                  separatorBuilder: (_, _) => Divider(height: 1, indent: 72, color: colors.borderSubtle),
                  itemBuilder: (context, i) {
                    final conv = convs[i];
                    final name = conv.storeName ?? 'Bookstore';
                    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'B';
                    final hasUnread = conv.unreadCount > 0;

                    return ListTile(
                      onTap: () {
                        context.push(
                          '/messages/conversation/${conv.id}?storeId=${conv.storeId}&storeName=${Uri.encodeComponent(name)}',
                        );
                      },
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: colors.ink,
                        backgroundImage: conv.storeLogo != null ? NetworkImage(conv.storeLogo!) : null,
                        child: conv.storeLogo == null
                            ? Text(initial, style: TextStyle(color: colors.onInk, fontWeight: FontWeight.w800))
                            : null,
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                        ),
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
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (e, _) => Center(child: Text('Could not load conversations: $e')),
            ),

            const SizedBox(height: 16),

            // ── Approved Bookstore Sellers ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Bookstore Sellers',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),

            approvedStoresAsync.when(
              data: (stores) {
                if (stores.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text('No seller bookstores registered yet.',
                          style: TextStyle(color: colors.textTertiary, fontSize: 13)),
                    ),
                  );
                }

                return Column(
                  children: stores.map((s) {
                    final initial = s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S';
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: colors.borderSubtle),
                        ),
                        onTap: () => _openStoreChat(s),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: colors.accentBlue,
                          child: Text(initial, style: TextStyle(color: colors.onInk, fontWeight: FontWeight.w700)),
                        ),
                        title: Text(s.name, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
                        subtitle: Text('Tap to message this bookstore',
                            style: TextStyle(color: colors.textTertiary, fontSize: 12)),
                        trailing: Icon(Icons.chat_bubble_outline_rounded, size: 20, color: colors.textTertiary),
                      ),
                    );
                  }).toList(),
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

class _OfficialStoreCard extends StatelessWidget {
  const _OfficialStoreCard({required this.store, required this.onTap});
  final Store store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colors.ink,
              child: Icon(Icons.verified_rounded, color: colors.onInk, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'BookVerse Store',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.ink,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'OFFICIAL',
                          style: TextStyle(
                            color: colors.onInk,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Customer support & official inquiries',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}
