import 'package:flutter/material.dart';

import '../models/book.dart';
import '../theme/app_color_tokens.dart';
import 'book_cover_image.dart';
import 'rating_stars.dart';

/// Catalog grid/rail card: cover, optional pill tag, title, author,
/// rating, and price.
class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.book,
    required this.onTap,
    this.width = 148,
    this.badgeLabel,
    this.trailing,
  });

  final Book book;
  final VoidCallback onTap;
  final double width;
  final String? badgeLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
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
          ],
        ),
      ),
    );
  }
}
