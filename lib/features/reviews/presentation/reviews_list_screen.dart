import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import 'review_providers.dart';
import 'widgets/reviews_section.dart';

class ReviewsListScreen extends ConsumerWidget {
  const ReviewsListScreen({super.key, required this.bookId});
  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final reviewsAsync = ref.watch(bookReviewsProvider(bookId));
    final aggregate = ref.watch(bookReviewAggregateProvider(bookId));

    return Scaffold(
      appBar: AppBar(
        title: Text(aggregate.count > 0 ? '${aggregate.average.toStringAsFixed(1)} · ${aggregate.count} Reviews' : 'Reviews'),
      ),
      body: reviewsAsync.when(
        data: (reviews) {
          if (reviews.isEmpty) {
            return const EmptyState(icon: Icons.reviews_outlined, title: 'No reviews yet');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: reviews.length,
            separatorBuilder: (_, _) => Divider(height: 28, color: colors.borderSubtle),
            itemBuilder: (context, i) => ReviewTile(review: reviews[i]),
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
        error: (err, _) => Center(child: Text('Could not load reviews.', style: TextStyle(color: colors.error))),
      ),
    );
  }
}
