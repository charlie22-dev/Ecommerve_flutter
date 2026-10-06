import 'package:equatable/equatable.dart';

import '../../../core/models/book.dart';

/// A cart entry joined with its `Book` so the cart/checkout UI never has to
/// juggle two separate async lookups.
class CartLine extends Equatable {
  const CartLine({required this.book, required this.quantity});

  final Book book;
  final int quantity;

  double get lineTotal => book.price * quantity;

  @override
  List<Object?> get props => [book.id, quantity];
}
