import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/require_login.dart';
import '../../../../core/models/book.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/widgets/book_cover_image.dart';
import '../../../cart/presentation/cart_providers.dart';

/// Wide "For You" carousel card — full-bleed artwork with the title/chapter
/// caption below, matching basis.png's landscape recommendation cards,
/// equipped with a quick Add to Cart button.
class FeatureBookCard extends ConsumerWidget {
  const FeatureBookCard({
    super.key,
    required this.book,
    required this.onTap,
    this.width = 220,
    this.onAddToCart,
  });

  final Book book;
  final VoidCallback onTap;
  final double width;
  final VoidCallback? onAddToCart;

  void _handleAddToCart(BuildContext context, WidgetRef ref) {
    if (!book.inStock) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This book is out of stock')));
      return;
    }
    if (!ensureLoggedIn(context, ref)) return;
    ref.read(cartActionsProvider).add(book.id);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${book.title}" to cart'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'View Cart',
          onPressed: () => context.push(AppRoute.cart),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.35,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  BookCoverImage(url: book.coverUrl, borderRadius: 14),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          if (onAddToCart != null) {
                            onAddToCart!();
                          } else {
                            _handleAddToCart(context, ref);
                          }
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: book.inStock ? context.colors.ink : context.colors.surfaceMuted,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.32),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 19,
                            color: book.inStock ? context.colors.onInk : context.colors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (book.price > 0)
                  Text(
                    '₱${book.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
