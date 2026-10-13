import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/db.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/text_prompt_dialog.dart';
import '../data/admin_repository.dart';
import 'admin_providers.dart';

/// Sellers' listings waiting for approval, oldest first. Approving
/// publishes the listing; rejecting sends the seller your reason.
class AdminListingsScreen extends ConsumerWidget {
  const AdminListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Listing Review')),
      body: ref.watch(adminListingReviewProvider).when(
            data: (listings) {
              if (listings.isEmpty) {
                return const EmptyState(
                  icon: Icons.fact_check_outlined,
                  title: 'All caught up',
                  message: 'New listings from sellers show up here for review.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: listings.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _ListingCard(listing: listings[i]),
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
            error: (e, _) => Center(child: Text('Could not load listings.\n$e', textAlign: TextAlign.center)),
          ),
    );
  }
}

class _ListingCard extends ConsumerWidget {
  const _ListingCard({required this.listing});
  final ReviewListing listing;

  Future<void> _moderate(BuildContext context, WidgetRef ref, {required bool approve}) async {
    String? note;
    if (!approve) {
      final values = await showTextPromptDialog(
        context,
        title: 'Reject "${listing.book.title}"?',
        message: 'The seller sees this reason and can fix the listing and resubmit.',
        fields: const ['Reason (e.g. blurry cover, wrong price)'],
        confirmLabel: 'Reject',
        destructive: true,
      );
      if (values == null) return;
      note = values.first;
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(adminRepositoryProvider)
          .moderateListing(listing.book.id, approve ? 'published' : 'rejected', note: note);
      messenger.showSnackBar(SnackBar(content: Text(approve ? 'Listing published' : 'Listing rejected')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final book = listing.book;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => context.push('${AppRoute.adminEditProduct}/${book.id}/edit'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 60, height: 90, child: BookCoverImage(url: book.coverUrl, borderRadius: 8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
                      Text(book.author, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        '${listing.storeName} · ₱${book.price.toStringAsFixed(2)} · ${book.stock} in stock',
                        style: TextStyle(color: colors.textTertiary, fontSize: 12),
                      ),
                      if (book.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          book.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.textPrimary, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text('Tap to see every detail', style: TextStyle(color: colors.textTertiary, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _moderate(context, ref, approve: false),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: colors.error)),
                  child: Text('Reject', style: TextStyle(color: colors.error)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => _moderate(context, ref, approve: true),
                  style: FilledButton.styleFrom(backgroundColor: colors.ink, foregroundColor: colors.onInk),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
