import 'package:uuid/uuid.dart';

import '../../../core/models/app_notification.dart';
import '../../../core/models/order.dart';
import '../../../core/models/shipping_address.dart';
import '../../../core/services/db.dart';
import '../../notifications/data/notification_repository.dart';

class OrderRepository {
  OrderRepository({NotificationRepository? notifications})
      : _notifications = notifications ?? NotificationRepository();

  final NotificationRepository _notifications;

  /// Creates an order the client owns, in `pending` (online payment methods
  /// — never resolves further without a real payment backend) or `toShip`
  /// (Cash on Delivery, no payment gate needed), as enforced by the
  /// "orders: create own" policy. Only an admin may advance it past that.
  Future<String> createOrder({
    required String uid,
    required List<OrderLineItem> items,
    required double subtotal,
    required double shippingCost,
    required String shippingOptionId,
    required ShippingAddress? shippingAddress,
    required PaymentMethod paymentMethod,
    String? voucherCode,
    double voucherDiscount = 0,
  }) async {
    final total = (subtotal + shippingCost - voucherDiscount).clamp(0, double.infinity).toDouble();
    final id = const Uuid().v4();
    final order = Order(
      id: id,
      uid: uid,
      items: items,
      subtotal: subtotal,
      shippingCost: shippingCost,
      voucherCode: voucherCode,
      voucherDiscount: voucherDiscount,
      total: total,
      shippingAddress: shippingAddress,
      shippingOptionId: shippingOptionId,
      status: paymentMethod == PaymentMethod.cashOnDelivery ? OrderStatus.toShip : OrderStatus.pending,
      paymentMethod: paymentMethod,
    );
    await db.from(Tables.orders).insert(order.toRow());
    await _notifications.create(
      userId: uid,
      category: NotificationCategory.orderUpdate,
      title: 'Order placed',
      body: order.status == OrderStatus.toShip
          ? 'Your order #${_shortId(id)} is confirmed and will be shipped soon.'
          : 'Your order #${_shortId(id)} is awaiting payment confirmation.',
      relatedOrderId: id,
    );
    return id;
  }

  Stream<Order?> watchOrder(String orderId) {
    return watchQuery(Tables.orders, () async {
      final row = await db.from(Tables.orders).select().eq('id', orderId).maybeSingle();
      return row == null ? null : Order.fromRow(row);
    });
  }

  Stream<List<Order>> watchOrdersForUser(String uid) {
    return watchQuery(Tables.orders, () async {
      final rows =
          await db.from(Tables.orders).select().eq('user_id', uid).order('created_at', ascending: false);
      return rows.map(Order.fromRow).toList();
    });
  }

  /// Admin-only (enforced by the `orders_guard_update` trigger). Also
  /// notifies the order's owner, who isn't necessarily the admin calling
  /// this.
  Future<void> updateStatus(String orderId, OrderStatus status) async {
    final row = await db
        .from(Tables.orders)
        .update({
          'status': status.name,
          if (status == OrderStatus.toShip) 'paid_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', orderId)
        .select('user_id')
        .maybeSingle();
    final ownerUid = row?['user_id'] as String?;
    if (ownerUid == null) return;

    final (title, body) = switch (status) {
      OrderStatus.toReceive => ('Order shipped', 'Order #${_shortId(orderId)} is on its way to you.'),
      OrderStatus.completed => (
          'Order delivered',
          'Order #${_shortId(orderId)} has been delivered — let us know what you think!'
        ),
      OrderStatus.cancelled => ('Order cancelled', 'Order #${_shortId(orderId)} was cancelled.'),
      _ => (null, null),
    };
    if (title == null) return;

    await _notifications.create(
      userId: ownerUid,
      category: NotificationCategory.orderUpdate,
      title: title,
      body: body!,
      relatedOrderId: orderId,
    );
  }

  Future<void> markRated(String orderId) async {
    await db.from(Tables.orders).update({'rated': true}).eq('id', orderId);
  }

  static String _shortId(String id) => id.substring(0, 8).toUpperCase();
}
