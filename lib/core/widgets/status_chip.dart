import 'package:flutter/material.dart';

import '../theme/app_color_tokens.dart';

/// Small colored pill used for order and listing statuses.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

/// Label and color for a `books.listing_status`.
(String, Color) listingStatusStyle(String status, AppColorTokens colors) => switch (status) {
      'published' => ('Live', colors.success),
      'pending_review' => ('In review', colors.accentOrange),
      'draft' => ('Draft', colors.textTertiary),
      'rejected' => ('Rejected', colors.error),
      'suspended' => ('Suspended', colors.error),
      'archived' => ('Archived', colors.textTertiary),
      _ => (status, colors.textTertiary),
    };
