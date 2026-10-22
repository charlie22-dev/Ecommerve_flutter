import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/store_message.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../admin/presentation/widgets/admin_table.dart';
import '../../messages/presentation/message_providers.dart';
import 'seller_providers.dart';

/// Seller inbox — lists all customers who have messaged this seller's store.
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
            appBar: AppBar(title: const Text('Messages')),
            body: const Center(child: Text('Store not found.')),
          );
        }
        return _SellerInbox(storeId: store.id, storeName: store.name);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Messages')),
        body: Center(child: CircularProgressIndicator(color: colors.ink)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Messages')),
        body: Center(child: Text('Could not load store.\n$e', textAlign: TextAlign.center)),
      ),
    );
  }
}

class _SellerInbox extends ConsumerWidget {
  const _SellerInbox({required this.storeId, required this.storeName});

  final String storeId;
  final String storeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final threadsAsync = ref.watch(sellerInboxProvider(storeId));

    return Scaffold(
      appBar: AppBar(title: Text('$storeName · Messages')),
      body: threadsAsync.when(
        data: (threads) {
          if (threads.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No messages yet',
              message: 'When customers message your store, their conversations appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: threads.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, indent: 72, color: colors.borderSubtle),
            itemBuilder: (context, i) {
              final t = threads[i];
              final last = t.lastMessage;
              return ListTile(
                onTap: () => context.push(
                  '${AppRoute.sellerMessages}/${t.customer.uid}?storeId=$storeId',
                ),
                leading: InitialAvatar(t.customer.label, photoUrl: t.customer.photoUrl, radius: 20),
                title: Text(
                  t.customer.label,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: t.needsReply ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${last.sender == MessageSender.store ? 'You: ' : ''}${last.displayContent}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: t.needsReply ? colors.textPrimary : colors.textTertiary,
                    fontSize: 13,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (last.createdAt != null)
                      Text(
                        DateFormat.MMMd().format(last.createdAt!),
                        style: TextStyle(color: colors.textTertiary, fontSize: 11),
                      ),
                    if (t.needsReply) ...[
                      const SizedBox(height: 4),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: colors.error, shape: BoxShape.circle),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
        error: (e, _) =>
            Center(child: Text('Could not load messages.\n$e', textAlign: TextAlign.center)),
      ),
    );
  }
}
