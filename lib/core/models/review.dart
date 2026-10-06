import 'package:equatable/equatable.dart';

import '../services/db.dart';

/// A buyer's review of a book, written from the "Rate this order" flow on
/// a completed order (see orders_screen.dart) — one review per book per
/// order, not editable after submission (matches most marketplace apps).
class Review extends Equatable {
  const Review({
    required this.id,
    required this.bookId,
    required this.orderId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.rating,
    this.text = '',
    this.photoUrl,
    this.createdAt,
  });

  final String id;
  final String bookId;
  final String orderId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final int rating;
  final String text;
  final String? photoUrl;
  final DateTime? createdAt;

  factory Review.fromRow(Map<String, dynamic> row) {
    return Review(
      id: row['id'] as String,
      bookId: row['book_id'] as String? ?? '',
      orderId: row['order_id'] as String? ?? '',
      userId: row['user_id'] as String? ?? '',
      userName: row['user_name'] as String? ?? 'Reader',
      userPhotoUrl: row['user_photo_url'] as String?,
      rating: toInt(row['rating'], 5),
      text: row['text'] as String? ?? '',
      photoUrl: row['photo_url'] as String?,
      createdAt: parseTimestamp(row['created_at']),
    );
  }

  Map<String, dynamic> toRow() => {
        'book_id': bookId,
        'order_id': orderId.isEmpty ? null : orderId,
        'user_id': userId,
        'user_name': userName,
        'user_photo_url': userPhotoUrl,
        'rating': rating,
        'text': text,
        'photo_url': photoUrl,
      };

  @override
  List<Object?> get props => [id, bookId, orderId, userId, rating];
}
