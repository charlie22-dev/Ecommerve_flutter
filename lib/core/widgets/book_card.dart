import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/presentation/cart_providers.dart';
import '../auth/require_login.dart';
import '../models/book.dart';
import '../router/app_routes.dart';
import '../theme/app_color_tokens.dart';
import 'book_cover_image.dart';
import 'rating_stars.dart';

/// Catalog grid/rail card: cover, optional pill tag, title, author,
/// rating, price, and add-to-cart quick action.
class BookCard extends ConsumerWidget {
  const BookCard({
    super.key,
    required this.book,
    required this.onTap,
    this.width = 148,
    this.badgeLabel,
    this.trailing,
    this.showAddToCartButton = false,
    this.onAddToCart,
  });

  final Book book;
  final VoidCallback onTap;
  final double width;
  final String? badgeLabel;
  final Widget? trailing;
  final bool showAddToCartButton;
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
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  BookCoverImage(url: book.coverUrl),
                  if (badgeLabel != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.colors.ink,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badgeLabel!.toUpperCase(),
                          style: TextStyle(
                            color: context.colors.onInk,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  if (trailing != null) Positioned(top: 6, right: 6, child: trailing!),
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
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RatingStars(rating: book.rating, size: 12, showValue: true),
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
            if (showAddToCartButton) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: book.inStock
                      ? () {
                          if (onAddToCart != null) {
                            onAddToCart!();
                          } else {
                            _handleAddToCart(context, ref);
                          }
                        }
                      : null,
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                  label: Text(
                    book.inStock ? 'Add to Cart' : 'Out of stock',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    backgroundColor: context.colors.ink,
                    foregroundColor: context.colors.onInk,
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
