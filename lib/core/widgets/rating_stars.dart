import 'package:flutter/material.dart';

import '../theme/app_color_tokens.dart';

/// Renders a row of 5 star icons for a given [rating] value (0.0–5.0).
/// Half-stars are shown when the fractional part of [rating] is ≥ 0.5.
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.size = 14,
    this.showValue = true,
    this.reviewCount,
  });

  final double rating;
  final double size;
  final bool showValue;
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    final full = rating.floor();
    final hasHalf = (rating - full) >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          IconData icon;
          if (i < full) {
            icon = Icons.star_rounded;
          } else if (i == full && hasHalf) {
            icon = Icons.star_half_rounded;
          } else {
            icon = Icons.star_outline_rounded;
          }
          return Icon(icon, size: size, color: context.colors.star);
        }),
        if (showValue) ...[
          const SizedBox(width: 6),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: size * 0.9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (reviewCount != null) ...[
          const SizedBox(width: 4),
          Text(
            '($reviewCount)',
            style: TextStyle(color: context.colors.textTertiary, fontSize: size * 0.85),
          ),
        ],
      ],
    );
  }
}
