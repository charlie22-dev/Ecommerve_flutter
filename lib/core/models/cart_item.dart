import 'package:equatable/equatable.dart';

import '../services/db.dart';

class CartItem extends Equatable {
  const CartItem({required this.bookId, this.quantity = 1, this.addedAt});

  final String bookId;
  final int quantity;
  final DateTime? addedAt;

  factory CartItem.fromRow(Map<String, dynamic> row) {
    return CartItem(
      bookId: row['book_id'] as String,
      quantity: toInt(row['quantity'], 1),
      addedAt: parseTimestamp(row['added_at']),
    );
  }

  CartItem copyWith({int? quantity}) =>
      CartItem(bookId: bookId, quantity: quantity ?? this.quantity, addedAt: addedAt);

  @override
  List<Object?> get props => [bookId, quantity];
}
