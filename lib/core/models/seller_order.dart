import '../services/db.dart';
import 'order.dart';
import 'shipping_address.dart';

/// One store's part of a customer order (`seller_orders`), which that store
/// fulfills on its own. Moves pending → confirmed → shipped → delivered
/// through the `update_seller_order` function.
enum SellerOrderStatus {
  pending,
  confirmed,
  processing,
  shipped,
  delivered,
  cancelled,
  refunded;

  static SellerOrderStatus fromKey(String? key) =>
      SellerOrderStatus.values.firstWhere((s) => s.name == key, orElse: () => SellerOrderStatus.pending);

  String get label => switch (this) {
        SellerOrderStatus.pending => 'New',
        SellerOrderStatus.confirmed => 'Confirmed',
        SellerOrderStatus.processing => 'Processing',
        SellerOrderStatus.shipped => 'Shipped',
        SellerOrderStatus.delivered => 'Delivered',
        SellerOrderStatus.cancelled => 'Cancelled',
        SellerOrderStatus.refunded => 'Refunded',
      };

  /// Still waiting on the seller to act.
  bool get needsAction => this == pending || this == confirmed;
}

/// Represents a sub-order assigned to an individual merchant/store for fulfillment.
class SellerOrder {
  const SellerOrder({
    required this.id,
    required this.orderId,
    required this.storeId,
    required this.status,
    required this.subtotal,
    required this.commissionTotal,
    this.storeName,
    this.shippingAddress,
    this.trackingCarrier,
    this.trackingNumber,
    this.createdAt,
    this.items = const [],
  });

  final String id;
  final String orderId;
  final String storeId;
  final SellerOrderStatus status;

  /// This store's items only, at the prices they sold for.
  final double subtotal;

  /// Platform commission on those items, fixed at the time of sale.
  final double commissionTotal;
  final String? storeName;
  final ShippingAddress? shippingAddress;
  final String? trackingCarrier;
  final String? trackingNumber;
  final DateTime? createdAt;
  final List<OrderLineItem> items;

  double get earnings => subtotal - commissionTotal;

  String get shortOrderId => orderId.substring(0, 8).toUpperCase();

  /// Reads a row selected with `*, order_items(*), stores(name)` — the
  /// embedded parts are optional.
  factory SellerOrder.fromRow(Map<String, dynamic> row) => SellerOrder(
        id: row['id'] as String,
        orderId: row['order_id'] as String,
        storeId: row['store_id'] as String,
        status: SellerOrderStatus.fromKey(row['status'] as String?),
        subtotal: toDouble(row['subtotal']),
        commissionTotal: toDouble(row['commission_total']),
        storeName: (row['stores'] as Map?)?['name'] as String?,
        shippingAddress: ShippingAddress.fromOrderSnapshot(
          row['shipping_address'] == null ? null : Map<String, dynamic>.from(row['shipping_address'] as Map),
        ),
        trackingCarrier: row['tracking_carrier'] as String?,
        trackingNumber: row['tracking_number'] as String?,
        createdAt: parseTimestamp(row['created_at']),
        items: [
          for (final i in (row['order_items'] as List? ?? const []))
            OrderLineItem(
              bookId: (i as Map)['book_id'] as String? ?? '',
              title: i['title'] as String? ?? '',
              coverUrl: i['cover_url'] as String? ?? '',
              unitPrice: toDouble(i['unit_price']),
              quantity: toInt(i['quantity'], 1),
            ),
        ],
      );
}
