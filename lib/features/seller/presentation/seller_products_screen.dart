import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import 'seller_providers.dart';

/// The seller's own listings, any status, with the admin's note when a
/// listing was rejected or suspended.
class SellerProductsScreen extends ConsumerWidget {
  const SellerProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final listingsAsync = ref.watch(myListingsProvider);
    final canEdit = ref.watch(myStoreProvider).value?.isActive ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('My Listings')),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => context.push(AppRoute.sellerAddProduct),
              backgroundColor: colors.ink,
              foregroundColor: colors.onInk,
              tooltip: 'New listing',
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: listingsAsync.when(
        data: (books) {
          if (books.isEmpty) {
            return const EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No listings yet',
              message: 'Add your first book. An admin reviews it before it goes live in the store.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            itemCount: books.length,
            separatorBuilder: (_, _) => Divider(height: 20, color: colors.borderSubtle),
            itemBuilder: (context, i) {
              final book = books[i];
              final (label, color) = listingStatusStyle(book.listingStatus, colors);
              return InkWell(
                onTap: canEdit ? () => context.push('${AppRoute.sellerEditProduct}/${book.id}/edit') : null,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 52, height: 78, child: BookCoverImage(url: book.coverUrl, borderRadius: 8)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱${book.price.toStringAsFixed(2)}  ·  ${book.stock == 0 ? 'Out of stock' : '${book.stock} in stock'}',
                            style: TextStyle(
                              color: book.stock == 0 ? colors.error : colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          if (book.moderationNote != null &&
                              (book.listingStatus == 'rejected' || book.listingStatus == 'suspended')) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Admin: ${book.moderationNote}',
                              style: TextStyle(color: colors.error, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(label: label, color: color),
                  ],
                ),
              );
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
        error: (e, _) => Center(child: Text('Could not load your listings.\n$e', textAlign: TextAlign.center)),
      ),
    );
  }
}
