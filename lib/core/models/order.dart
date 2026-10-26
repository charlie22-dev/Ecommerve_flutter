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

/// Supported customer payment methods for settling an order at checkout.
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

/// Represents a completed or pending customer purchase order across all stores.
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
    this.taxAmount = 0,
    this.paymentStatus,
    this.paymentChannel,
    this.providerPaymentMethod,
    this.xenditInvoiceId,
    this.xenditPaymentId,
    this.xenditInvoiceStatus,
    this.amountPaid,
    this.paymentCurrency,
    this.paymentVerifiedAt,
  });

  final String id;
  final String uid;
  final List<OrderLineItem> items;
  final double subtotal;
  final double shippingCost;
  final String? voucherCode;
  final double voucherDiscount;
  final double total;
  final double taxAmount;
  final String? paymentStatus;
  final String? paymentChannel;
  final String? providerPaymentMethod;
  final String? xenditInvoiceId;
  final String? xenditPaymentId;
  final String? xenditInvoiceStatus;
  final double? amountPaid;
  final String? paymentCurrency;
  final DateTime? paymentVerifiedAt;

  bool get isPaid =>
      paymentStatus == 'paid' ||
      (paymentStatus == null &&
          paidAt != null &&
          paymentMethod != PaymentMethod.cashOnDelivery &&
          {
            OrderStatus.toShip,
            OrderStatus.toReceive,
            OrderStatus.completed,
          }.contains(status));

  String get paymentStatusLabel {
    if (isPaid) return 'Paid';
    if (paymentStatus == 'requires_review') {
      return 'Payment received · Review needed';
    }
    if (paymentMethod == PaymentMethod.cashOnDelivery) return 'Pay on delivery';
    if (paymentStatus == 'expired' || status == OrderStatus.failed) {
      return 'Payment expired or failed';
    }
    if (status == OrderStatus.cancelled) return 'Cancelled';
    return 'Pending payment';
  }

  /// Xendit records the actual channel selected on hosted checkout.
  String get paymentMethodLabel {
    final channel = paymentChannel ?? providerPaymentMethod;
    if (channel == null || channel.isEmpty) return paymentMethod.label;
    return switch (channel.toUpperCase()) {
      'GCASH' => 'GCash',
      'GRABPAY' || 'GRAB_PAY' => 'GrabPay',
      'PAYMAYA' || 'MAYA' => 'Maya',
      'CREDIT_CARD' || 'CARD' => 'Card',
      _ => channel.replaceAll('_', ' '),
    };
  }

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
          .map(
            (e) => OrderLineItem.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      subtotal: toDouble(row['subtotal']),
      shippingCost: toDouble(row['shipping_cost']),
      voucherCode: row['voucher_code'] as String?,
      voucherDiscount: toDouble(row['voucher_discount']),
      total: toDouble(row['total']),
      taxAmount: toDouble(row['tax_amount']),
      paymentStatus: row['payment_status'] as String?,
      paymentChannel: row['payment_channel'] as String?,
      providerPaymentMethod: row['provider_payment_method'] as String?,
      xenditInvoiceId: row['xendit_invoice_id'] as String?,
      xenditPaymentId: row['xendit_payment_id'] as String?,
      xenditInvoiceStatus: row['xendit_invoice_status'] as String?,
      amountPaid: (row['amount_paid'] as num?)?.toDouble(),
      paymentCurrency: row['payment_currency'] as String?,
      paymentVerifiedAt: parseTimestamp(row['payment_verified_at']),
      shippingAddress: ShippingAddress.fromOrderSnapshot(
        row['shipping_address'] == null
            ? null
            : Map<String, dynamic>.from(row['shipping_address'] as Map),
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
    'tax_amount': taxAmount,
    'payment_status': paymentStatus,
    'payment_channel': paymentChannel,
    'provider_payment_method': providerPaymentMethod,
    'xendit_invoice_id': xenditInvoiceId,
    'xendit_payment_id': xenditPaymentId,
    'xendit_invoice_status': xenditInvoiceStatus,
    'amount_paid': amountPaid,
    'payment_currency': paymentCurrency,
    'payment_verified_at': paymentVerifiedAt?.toUtc().toIso8601String(),
    'shipping_address': shippingAddress?.toOrderSnapshot(),
    'shipping_option_id': shippingOptionId,
    'status': status.name,
    'payment_method': paymentMethod.name,
    'paymongo_reference_id': paymongoReferenceId,
    'rated': rated,
    'paid_at': paidAt?.toUtc().toIso8601String(),
  };

  @override
  List<Object?> get props => [
    id,
    uid,
    status,
    total,
    paymentStatus,
    paymentChannel,
    providerPaymentMethod,
    xenditInvoiceId,
    xenditPaymentId,
    xenditInvoiceStatus,
    amountPaid,
    paymentCurrency,
    paidAt,
    paymentVerifiedAt,
  ];
}
