import '../../../core/models/review.dart';
import '../../../core/services/db.dart';

class ReviewRepository {
  Stream<List<Review>> watchForBook(String bookId) {
    return watchQuery(Tables.reviews, () async {
      final rows =
          await db.from(Tables.reviews).select().eq('book_id', bookId).order('created_at', ascending: false);
      return rows.map(Review.fromRow).toList();
    });
  }

  Future<void> add(Review review) async {
    await db.from(Tables.reviews).insert(review.toRow());
  }
}
