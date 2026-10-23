import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/require_login.dart';
import '../../../core/models/book.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/rating_stars.dart';
import '../../admin/presentation/admin_providers.dart';
import '../../cart/presentation/cart_providers.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../library/presentation/collection_providers.dart';
import '../../library/presentation/widgets/create_collection_sheet.dart';
import '../../messages/presentation/message_providers.dart';
import '../../reviews/presentation/review_providers.dart';
import '../../reviews/presentation/widgets/reviews_section.dart';
import '../../wishlist/presentation/wishlist_providers.dart';

class BookDetailsScreen extends ConsumerWidget {
  const BookDetailsScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookByIdProvider(bookId));

    return Scaffold(
      body: bookAsync.when(
        data: (book) {
          if (book == null) {
            return Center(
              child: Text('Book not found', style: TextStyle(color: context.colors.textSecondary)),
            );
          }
          return _BookDetailsBody(book: book);
        },
        loading: () => Center(child: CircularProgressIndicator(color: context.colors.ink)),
        error: (err, _) => Center(
          child: Text('Could not load this book.', style: TextStyle(color: context.colors.error)),
        ),
      ),
    );
  }
}

class _BookDetailsBody extends ConsumerStatefulWidget {
  const _BookDetailsBody({required this.book});

  final Book book;

  @override
  ConsumerState<_BookDetailsBody> createState() => _BookDetailsBodyState();
}

class _BookDetailsBodyState extends ConsumerState<_BookDetailsBody> {
  final _reviewsKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final wishlistIds = ref.watch(wishlistIdsProvider).value ?? const {};
    final isWishlisted = wishlistIds.contains(book.id);
    final isAdmin = ref.watch(isAdminProvider);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: context.colors.background,
          actions: [
            if (isAdmin)
              IconButton(
                tooltip: 'Edit product',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/admin/product/${book.id}/edit'),
              ),
            IconButton(
              tooltip: isWishlisted ? 'Remove from wishlist' : 'Add to wishlist',
              icon: Icon(
                isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isWishlisted ? context.colors.error : context.colors.textPrimary,
              ),
              onPressed: () {
                if (ensureLoggedIn(context, ref)) ref.read(wishlistActionsProvider).toggle(book.id, isWishlisted);
              },
            ),
            IconButton(
              tooltip: 'Add to collection',
              icon: const Icon(Icons.playlist_add_rounded),
              onPressed: () {
                if (ensureLoggedIn(context, ref)) _showCollectionPicker(context, ref, book.id);
              },
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final coverWidget = SizedBox(
                  width: wide(constraints) ? 300 : 170,
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: BookCoverImage(url: book.coverUrl, borderRadius: 14),
                  ),
                );
                final buyBox = <Widget>[
                  Text(book.title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('by ${book.author}', style: TextStyle(color: context.colors.textSecondary, fontSize: 14)),
                  if (book.storeId != null) ...[
                    const SizedBox(height: 4),
                    _StoreName(storeId: book.storeId!),
                  ],
                  const SizedBox(height: 10),
                  // Live aggregate from the `reviews` collection — the same
                  // source the Reviews section below lists — not the seeded
                  // `book.ratingCount`, which claimed e.g. "(1423)" reviews
                  // while the section underneath showed none. Tapping jumps
                  // down to the actual reviews.
                  _RatingSummary(bookId: book.id, reviewsKey: _reviewsKey),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [_Tag(book.type.label), _Tag(book.format.label), ...book.genres.map(_Tag.new)],
                  ),
                  const SizedBox(height: 20),
                  if (isAdmin)
                    PrimaryButton(
                      label: 'Edit in Admin Panel',
                      icon: Icons.edit_note_rounded,
                      onPressed: () => context.push('/admin/product/${book.id}/edit'),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: book.inStock ? 'Add to Cart · ₱${book.price.toStringAsFixed(0)}' : 'Out of stock',
                            icon: Icons.shopping_cart_rounded,
                            onPressed: book.inStock
                                ? () {
                                    if (!ensureLoggedIn(context, ref)) return;
                                    ref.read(cartActionsProvider).add(book.id);
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(content: Text('Added to cart')));
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Buy Now adds this book to the cart (if not already there)
                    // and jumps straight to checkout — if other items are
                    // already in the cart, they come along too, same as most
                    // ecommerce apps' "buy now" shortcut. Solid orange (not the
                    // theme's ink color) so it reads as the urgent CTA next to
                    // the neutral "Add to Cart" button above.
                    ElevatedButton.icon(
                      onPressed: book.inStock
                          ? () async {
                              if (!ensureLoggedIn(context, ref)) return;
                              await ref.read(cartActionsProvider).add(book.id);
                              if (context.mounted) context.push('/checkout');
                            }
                          : null,
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: const Text('Buy Now'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: context.colors.accentOrange,
                        foregroundColor: context.colors.onAccentOrange,
                        disabledBackgroundColor: context.colors.accentOrange.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ];
                final more = <Widget>[
                  const SizedBox(height: 28),
                  Text('Description', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    book.description.isEmpty ? 'No description available.' : book.description,
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  Text('Details', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _DetailsTable(book: book),
                  const SizedBox(height: 28),
                  ReviewsSection(key: _reviewsKey, bookId: book.id),
                ];
                // Website layout on wide screens: cover left, buy box right.
                if (wide(constraints)) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          coverWidget,
                          const SizedBox(width: 40),
                          Expanded(
                            // Align loosens Expanded's tight width so the cap applies.
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 560),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: buyBox),
                              ),
                            ),
                          ),
                        ],
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: more),
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: coverWidget),
                    const SizedBox(height: 20),
                    ...buyBox,
                    ...more,
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  static bool wide(BoxConstraints c) => c.maxWidth >= 700;

  void _showCollectionPicker(BuildContext context, WidgetRef ref, String bookId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return Consumer(
          builder: (context, sheetRef, _) {
            final collections = sheetRef.watch(collectionsProvider).value ?? const [];
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Add to collection', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                  ),
                  if (collections.isEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: Text(
                        'You have no collections yet.',
                        style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                      ),
                    )
                  else
                    ...collections.map(
                      (collection) => ListTile(
                        leading: Icon(Icons.collections_bookmark_outlined, color: context.colors.textPrimary),
                        title: Text(collection.title, style: TextStyle(color: context.colors.textPrimary)),
                        subtitle: Text(
                          '${collection.bookCount} books',
                          style: TextStyle(color: context.colors.textTertiary),
                        ),
                        onTap: () {
                          ref.read(collectionActionsProvider).addBook(collection.id, bookId);
                          Navigator.of(sheetContext).pop();
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Added to "${collection.title}"')));
                        },
                      ),
                    ),
                  ListTile(
                    leading: Icon(Icons.add_rounded, color: context.colors.textPrimary),
                    title: Text(
                      'New collection',
                      style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      CreateCollectionSheet.show(context);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RatingSummary extends ConsumerWidget {
  const _RatingSummary({required this.bookId, required this.reviewsKey});
  final String bookId;
  final GlobalKey reviewsKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aggregate = ref.watch(bookReviewAggregateProvider(bookId));
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        final target = reviewsKey.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: aggregate.count > 0
            ? RatingStars(rating: aggregate.average, reviewCount: aggregate.count, size: 16)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const RatingStars(rating: 0, size: 16, showValue: false),
                  const SizedBox(width: 6),
                  Text('No reviews yet', style: TextStyle(color: context.colors.textTertiary, fontSize: 13)),
                ],
              ),
      ),
    );
  }
}

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      MapEntry('Publisher', book.publisher.isEmpty ? '—' : book.publisher),
      MapEntry('Language', book.language),
      if (book.pages != null) MapEntry('Pages', '${book.pages}'),
      if (book.isbn != null) MapEntry('ISBN', book.isbn!),
      if (book.releaseDate != null) MapEntry('Released', DateFormat.yMMMd().format(book.releaseDate!)),
      MapEntry('Stock', book.inStock ? '${book.stock} available' : 'Out of stock'),
    ];

    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(row.key, style: TextStyle(color: context.colors.textTertiary, fontSize: 13)),
                  Text(row.value, style: TextStyle(color: context.colors.textPrimary, fontSize: 13)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Text(label, style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
    );
  }
}

class _StoreName extends ConsumerWidget {
  const _StoreName({required this.storeId});
  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final storeAsync = ref.watch(storeByIdProvider(storeId));
    final store = storeAsync.value;
    final name = store?.name ?? 'BookVerse Official';
    final currentUid = ref.watch(authUidProvider);
    final isOwner = store != null && store.ownerId != null && store.ownerId == currentUid;
    final canMessage = store != null && store.isActive && !isOwner;

    return Row(
      children: [
        Icon(Icons.storefront_rounded, size: 16, color: colors.ink),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            'Seller: $name',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (isOwner)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colors.ink.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Your store',
              style: TextStyle(color: colors.ink, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          )
        else if (canMessage)
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              if (!ensureLoggedIn(context, ref)) return;
              final path = store.isOfficial
                  ? '/messages/store'
                  : '/messages/seller/${store.id}?name=${Uri.encodeComponent(store.name)}';
              context.push(path);
            },
            icon: Icon(Icons.chat_bubble_outline_rounded, size: 14, color: colors.ink),
            label: Text(
              'Message',
              style: TextStyle(color: colors.ink, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}
