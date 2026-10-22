import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/store.dart';
import '../../../core/theme/app_color_tokens.dart';
import 'message_providers.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final officialThreadAsync = ref.watch(storeThreadProvider);
    final storesAsync = ref.watch(approvedStoresProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Official BookVerse Support ──────────────────────────────────
          _StoreRow(
            avatar: CircleAvatar(
              radius: 22,
              backgroundColor: colors.ink,
              child: Icon(Icons.storefront_rounded, color: colors.onInk, size: 20),
            ),
            name: 'BookVerse Store',
            subtitle: officialThreadAsync.when(
              data: (msgs) => msgs.isEmpty
                  ? 'Start a conversation with our support team'
                  : msgs.last.displayContent,
              loading: () => 'Loading…',
              error: (_, _) => 'Tap to open',
            ),
            onTap: () => context.push('/messages/store'),
          ),

          // ── Approved seller stores ──────────────────────────────────────
          storesAsync.when(
            data: (stores) => Column(
              children: stores
                  .map((s) => _SellerStoreRow(store: s))
                  .toList(),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── helpers ─────────────────────────────────────────────────────────────────

class _StoreRow extends StatelessWidget {
  const _StoreRow({
    required this.avatar,
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  final Widget avatar;
  final String name;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellerStoreRow extends ConsumerWidget {
  const _SellerStoreRow({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final threadAsync = ref.watch(sellerThreadProvider(store.id));
    final lastMsg = threadAsync.value?.isNotEmpty == true ? threadAsync.value!.last : null;

    final initial = store.name.isNotEmpty ? store.name[0].toUpperCase() : 'S';
    final avatar = CircleAvatar(
      radius: 22,
      backgroundColor: colors.accentBlue,
      child: Text(initial, style: TextStyle(color: colors.onInk, fontWeight: FontWeight.w700)),
    );

    return _StoreRow(
      avatar: avatar,
      name: store.name,
      subtitle: lastMsg != null ? lastMsg.displayContent : 'Send a message to this seller',
      onTap: () => context.push('/messages/seller/${store.id}?name=${Uri.encodeComponent(store.name)}'),
    );
  }
}
