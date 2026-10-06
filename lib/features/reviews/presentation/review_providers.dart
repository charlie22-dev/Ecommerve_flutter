import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/review.dart';
import '../data/review_repository.dart';

final reviewRepositoryProvider = Provider((ref) => ReviewRepository());

final bookReviewsProvider = StreamProvider.family<List<Review>, String>((ref, bookId) {
  return ref.watch(reviewRepositoryProvider).watchForBook(bookId);
});

/// Average rating + count computed live from the reviews stream — not the
/// cached `book.rating`/`ratingCount` fields, which a review-writing buyer
/// (not an admin) has no permission to update. This is the source of truth
/// shown in the Reviews section; `book.rating` elsewhere (catalog cards,
/// search results) stays as its seeded/admin-set value.
class ReviewAggregate {
  const ReviewAggregate({required this.average, required this.count});
  final double average;
  final int count;
}

final bookReviewAggregateProvider = Provider.family<ReviewAggregate, String>((ref, bookId) {
  final reviews = ref.watch(bookReviewsProvider(bookId)).value ?? const [];
  if (reviews.isEmpty) return const ReviewAggregate(average: 0, count: 0);
  final sum = reviews.fold<int>(0, (total, r) => total + r.rating);
  return ReviewAggregate(average: sum / reviews.length, count: reviews.length);
});

class ReviewActions {
  ReviewActions(this.ref);
  final Ref ref;

  Future<void> add(Review review) => ref.read(reviewRepositoryProvider).add(review);
}

final reviewActionsProvider = Provider((ref) => ReviewActions(ref));
