import 'package:equatable/equatable.dart';

import '../services/db.dart';

import 'shipping_address.dart';

/// The order lifecycle shown on the Orders tab: `pending` (awaiting online
/// payment confirmation — never resolves without a real payment backend,
/// see README), `toShip` (payment confirmed, or COD placed — admin needs
/// to dispatch it), `toReceive` (dispatched, in transit), `completed`
/// (delivered — eligible for a review), `cancelled`, `failed`.
enum OrderStatus {
  pending,
  toShip,
  toReceive,
  completed,
  cancelled,
  failed;

  static OrderStatus fromKey(String? key) => OrderStatus.values.firstWhere(
        (s) => s.name == key,
        orElse: () => OrderStatus.pending,
      );

  String get label => switch (this) {
        OrderStatus.pending => 'Pending Payment',
        OrderStatus.toShip => 'To Ship',
        OrderStatus.toReceive => 'To Receive',
        OrderStatus.completed => 'Completed',
        OrderStatus.cancelled => 'Cancelled',
        OrderStatus.failed => 'Failed',
      };
}

enum PaymentMethod {
  gcash,
  maya,
  card,
  cashOnDelivery;

  static PaymentMethod fromKey(String? key) => PaymentMethod.values.firstWhere(
        (m) => m.name == key,
        orElse: () => PaymentMethod.cashOnDelivery,
      );

  String get label => switch (this) {
        PaymentMethod.gcash => 'GCash',
        PaymentMethod.maya => 'Maya',
        PaymentMethod.card => 'Card',
        PaymentMethod.cashOnDelivery => 'Cash on Delivery',
      };
}

class OrderLineItem extends Equatable {
  const OrderLineItem({
    required this.bookId,
    required this.title,
    required this.coverUrl,
    required this.unitPrice,
    required this.quantity,
  });

  final String bookId;
  final String title;
  final String coverUrl;
  final double unitPrice;
  final int quantity;

  /// Total price for this line: [unitPrice] × [quantity].
  double get lineTotal => unitPrice * quantity;

  factory OrderLineItem.fromMap(Map<String, dynamic> map) => OrderLineItem(
        bookId: map['bookId'] as String? ?? '',
        title: map['title'] as String? ?? '',
        coverUrl: map['coverUrl'] as String? ?? '',
        unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
        quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toMap() => {
        'bookId': bookId,
        'title': title,
        'coverUrl': coverUrl,
        'unitPrice': unitPrice,
        'quantity': quantity,
      };

  @override
  List<Object?> get props => [bookId, unitPrice, quantity];
}

class Order extends Equatable {
  const Order({
    required this.id,
    required this.uid,
    required this.items,
    required this.subtotal,
    required this.shippingCost,
    required this.voucherCode,
    required this.voucherDiscount,
    required this.total,
    required this.shippingAddress,
    required this.shippingOptionId,
    this.status = OrderStatus.pending,
    this.paymentMethod = PaymentMethod.cashOnDelivery,
    this.paymongoReferenceId,
    this.rated = false,
    this.createdAt,
    this.paidAt,
  });

  final String id;
  final String uid;
  final List<OrderLineItem> items;
  final double subtotal;
  final double shippingCost;
  final String? voucherCode;
  final double voucherDiscount;
  final double total;
  final ShippingAddress? shippingAddress;
  final String shippingOptionId;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final String? paymongoReferenceId;

  /// Whether the buyer has already submitted a review for this order — a
  /// "To Review" order drops off that list once true.
  final bool rated;
  final DateTime? createdAt;
  final DateTime? paidAt;

  factory Order.fromRow(Map<String, dynamic> row) {
    return Order(
      id: row['id'] as String,
      uid: row['user_id'] as String? ?? '',
      items: (row['items'] as List? ?? const [])
          .map((e) => OrderLineItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      subtotal: toDouble(row['subtotal']),
      shippingCost: toDouble(row['shipping_cost']),
      voucherCode: row['voucher_code'] as String?,
      voucherDiscount: toDouble(row['voucher_discount']),
      total: toDouble(row['total']),
      shippingAddress: ShippingAddress.fromOrderSnapshot(
        row['shipping_address'] == null ? null : Map<String, dynamic>.from(row['shipping_address'] as Map),
      ),
      shippingOptionId: row['shipping_option_id'] as String? ?? 'standard',
      status: OrderStatus.fromKey(row['status'] as String?),
      paymentMethod: PaymentMethod.fromKey(row['payment_method'] as String?),
      paymongoReferenceId: row['paymongo_reference_id'] as String?,
      rated: row['rated'] as bool? ?? false,
      createdAt: parseTimestamp(row['created_at']),
      paidAt: parseTimestamp(row['paid_at']),
    );
  }

  Map<String, dynamic> toRow() => {
        'id': id,
        'user_id': uid,
        'items': items.map((e) => e.toMap()).toList(),
        'subtotal': subtotal,
        'shipping_cost': shippingCost,
        'voucher_code': voucherCode,
        'voucher_discount': voucherDiscount,
        'total': total,
        'shipping_address': shippingAddress?.toOrderSnapshot(),
        'shipping_option_id': shippingOptionId,
        'status': status.name,
        'payment_method': paymentMethod.name,
        'paymongo_reference_id': paymongoReferenceId,
        'rated': rated,
        'paid_at': paidAt?.toUtc().toIso8601String(),
      };

  @override
  List<Object?> get props => [id, uid, status, total];
}
