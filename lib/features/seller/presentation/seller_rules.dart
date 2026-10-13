import 'package:flutter/material.dart';

import '../../../core/theme/app_color_tokens.dart';

/// BookVerse's marketplace rules for sellers. The "books only" rule and the
/// review/tracking steps are also enforced by the database
/// (`guard_book_write`, `moderate_listing`, `update_seller_order` in
/// supabase/schema.sql); the rest are policies admins enforce by rejecting
/// listings or suspending stores.
const sellerRules = <(IconData, String, String)>[
  (
    Icons.menu_book_outlined,
    'Books only',
    'Sell books, manga, manhwa, manhua, comics, novels, light novels and textbooks. '
        'No merchandise, figures, posters or other items.',
  ),
  (
    Icons.verified_outlined,
    'Genuine copies',
    'No pirated, photocopied, printed-at-home or counterfeit books.',
  ),
  (
    Icons.photo_camera_outlined,
    'Describe it honestly',
    'Use a real cover photo and the correct title, author, edition, language and price.',
  ),
  (
    Icons.fact_check_outlined,
    'Every listing is reviewed',
    'An admin approves each new listing before it appears in the store.',
  ),
  (
    Icons.local_shipping_outlined,
    'Ship on time',
    'Confirm and ship orders within 3 days, with the courier and tracking number.',
  ),
  (
    Icons.percent_rounded,
    'Platform commission',
    'BookVerse keeps a commission on each sale. Your rate is shown in Seller Center.',
  ),
  (
    Icons.gavel_rounded,
    'Breaking the rules',
    'Listings that break these rules are rejected or suspended, and repeated problems can get your store suspended.',
  ),
];

/// The rules as a list, for the application form and the Seller Center sheet.
class SellerRulesList extends StatelessWidget {
  const SellerRulesList({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        for (final (icon, title, body) in sellerRules)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: colors.textPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(body, style: TextStyle(color: colors.textSecondary, fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

void showSellerRulesSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Seller rules', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const SellerRulesList(),
          ],
        ),
      ),
    ),
  );
}
