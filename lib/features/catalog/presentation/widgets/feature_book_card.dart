import 'package:flutter/material.dart';

import '../../../../core/models/book.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/widgets/book_cover_image.dart';

/// Wide "For You" carousel card — full-bleed artwork with the title/chapter
/// caption below, matching basis.png's landscape recommendation cards.
class FeatureBookCard extends StatelessWidget {
  const FeatureBookCard({super.key, required this.book, required this.onTap, this.width = 220});

  final Book book;
  final VoidCallback onTap;
  final double width;

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
              aspectRatio: 1.35,
              child: BookCoverImage(url: book.coverUrl, borderRadius: 14),
            ),
            const SizedBox(height: 8),
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
    );
  }
}
