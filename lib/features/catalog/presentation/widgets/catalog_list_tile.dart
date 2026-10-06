import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/require_login.dart';
import '../../../../core/models/book.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/widgets/book_cover_image.dart';
import '../../../../core/widgets/rating_stars.dart';
import '../../../wishlist/presentation/wishlist_providers.dart';

/// basis.png's Browse/Catalog row: cover thumb, title/author, star rating
/// (+ "TOP" badge for standout titles), a 2-line blurb, and a bookmark
/// toggle — replaces a grid for the catalog list view.
class CatalogListTile extends ConsumerWidget {
  const CatalogListTile({super.key, required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistIds = ref.watch(wishlistIdsProvider).value ?? const {};
    final isWishlisted = wishlistIds.contains(book.id);
    final isTop = book.rating >= 4.8;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 64, height: 96, child: BookCoverImage(url: book.coverUrl)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: isWishlisted ? 'Remove from wishlist' : 'Add to wishlist',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () {
                            if (ensureLoggedIn(context, ref)) ref.read(wishlistActionsProvider).toggle(book.id, isWishlisted);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              isWishlisted ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              size: 20,
                              color: isWishlisted ? context.colors.ink : context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(book.author, style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      RatingStars(rating: book.rating, size: 13),
                      if (isTop) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.colors.ink,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'TOP',
                            style: TextStyle(color: context.colors.onInk, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (book.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      book.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.colors.textTertiary, fontSize: 12.5, height: 1.35),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
