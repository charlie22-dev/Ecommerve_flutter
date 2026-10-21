import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/review.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/widgets/rating_stars.dart';
import '../review_providers.dart';

/// Sits below the Description section on Book Details — aggregate rating
/// summary up top, then up to 3 latest reviews, with "View All Reviews"
/// when there are more than that (see reviews_list_screen.dart).
class ReviewsSection extends ConsumerWidget {
  const ReviewsSection({super.key, required this.bookId});
  final String bookId;

  static const _inlineLimit = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final reviewsAsync = ref.watch(bookReviewsProvider(bookId));
    final aggregate = ref.watch(bookReviewAggregateProvider(bookId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Reviews', style: Theme.of(context).textTheme.titleMedium),
            if (aggregate.count > 0)
              Row(
                children: [
                  Icon(Icons.star_rounded, color: colors.star, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${aggregate.average.toStringAsFixed(1)} · ${aggregate.count} review${aggregate.count == 1 ? '' : 's'}',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        reviewsAsync.when(
          data: (reviews) {
            if (reviews.isEmpty) {
              return Text(
                'No reviews yet — be the first to rate this book after your order arrives.',
                style: TextStyle(color: colors.textTertiary, fontSize: 13),
              );
            }
            final shown = reviews.take(_inlineLimit).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final review in shown) ...[
                  ReviewTile(review: review),
                  if (review != shown.last) Divider(height: 24, color: colors.borderSubtle),
                ],
                if (reviews.length > _inlineLimit) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.push('/reviews/$bookId'),
                    child: Text('View All ${reviews.length} Reviews'),
                  ),
                ],
              ],
            );
          },
          loading: () => Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.ink)),
          error: (err, _) => Text('Could not load reviews.', style: TextStyle(color: colors.error, fontSize: 13)),
        ),
      ],
    );
  }
}

class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: colors.surfaceMuted,
              backgroundImage: (review.userPhotoUrl?.isNotEmpty ?? false) ? NetworkImage(review.userPhotoUrl!) : null,
              child: (review.userPhotoUrl?.isNotEmpty ?? false)
                  ? null
                  : Icon(Icons.person_rounded, size: 18, color: colors.textTertiary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(review.userName, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  RatingStars(rating: review.rating.toDouble(), size: 12, showValue: false),
                ],
              ),
            ),
            if (review.createdAt != null)
              Text(DateFormat.yMMMd().format(review.createdAt!), style: TextStyle(color: colors.textTertiary, fontSize: 11)),
          ],
        ),
        if (review.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(review.text, style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4)),
        ],
        if (review.photoUrl != null && review.photoUrl!.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => Dialog(
                  backgroundColor: Colors.black.withValues(alpha: 0.92),
                  insetPadding: EdgeInsets.zero,
                  child: Stack(
                    children: [
                      Center(
                        child: InteractiveViewer(
                          maxScale: 4.0,
                          child: Image.network(
                            review.photoUrl!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.paddingOf(ctx).top + 10,
                        right: 16,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Image.network(
                    review.photoUrl!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('Tap to view', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
