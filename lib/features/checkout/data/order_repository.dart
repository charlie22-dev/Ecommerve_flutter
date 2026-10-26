import '../../../core/models/app_notification.dart';
import '../../../core/models/order.dart';
import '../../../core/services/db.dart';
import '../../notifications/data/notification_repository.dart';
import 'checkout_functions_service.dart';

class OrderRepository {
  OrderRepository({NotificationRepository? notifications})
    : _notifications = notifications ?? NotificationRepository();

  final NotificationRepository _notifications;

  /// Places an order through the `place_order` Postgres function, which
  /// prices it from the database (books, voucher, shipping), takes the stock
  /// and splits it per seller. The app only sends what and how many — any
  /// price it computed is for display. Retrying with the same
  /// [idempotencyKey] returns the first order instead of a duplicate.
  Future<({String id, double total})> createOrder({
    required String uid,
    required List<OrderLineItem> items,
    required String addressId,
    required String shippingOptionId,
    required PaymentMethod paymentMethod,
    required String idempotencyKey,
    bool fromCart = true,
    String? voucherCode,
  }) async {
    final result = await db.rpc(
      'place_order',
      params: {
        'p_items': [
          for (final i in items)
            {
              'book_id': i.bookId,
              'quantity': i.quantity,
              'checkout_source': fromCart ? 'cart' : 'buyNow',
            },
        ],
        'p_address_id': addressId,
        'p_shipping_option_id': shippingOptionId,
        'p_payment_method': paymentMethod.name,
        'p_voucher_code': voucherCode,
        'p_idempotency_key': idempotencyKey,
      },
    );
    final row = Map<String, dynamic>.from(result as Map);
    final id = row['id'] as String;
    // A notification failure must not turn a committed purchase into a failed checkout.
    try {
      await _notifications.create(
        userId: uid,
        category: NotificationCategory.orderUpdate,
        title: 'Order placed',
        body: paymentMethod == PaymentMethod.cashOnDelivery
            ? 'Your order #${_shortId(id)} is confirmed and will be shipped soon.'
            : 'Your order #${_shortId(id)} is awaiting payment confirmation.',
        relatedOrderId: id,
      );
    } catch (_) {
      // The order is already committed; its receipt remains the source of truth.
    }
    return (id: id, total: toDouble(row['total']));
  }

  Stream<Order?> watchOrder(String orderId) {
    return watchQuery(Tables.orders, () async {
      final row = await db
          .from(Tables.orders)
          .select()
          .eq('id', orderId)
          .maybeSingle();
      return row == null ? null : Order.fromRow(row);
    });
  }

  Future<Order?> getOrder(String orderId) async {
    final row = await db
        .from(Tables.orders)
        .select()
        .eq('id', orderId)
        .maybeSingle();
    return row == null ? null : Order.fromRow(row);
  }

  Future<Order?> refreshPayment(String orderId) async {
    try {
      return await CheckoutFunctionsService().syncPayment(orderId);
    } catch (_) {
      // A delivered webhook remains authoritative if provider verification is
      // temporarily unavailable. Never fabricate a successful payment.
      return getOrder(orderId);
    }
  }

  Stream<List<Order>> watchOrdersForUser(String uid) {
    return watchQuery(Tables.orders, () async {
      final rows = await db
          .from(Tables.orders)
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);
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
          if (status == OrderStatus.toShip)
            'paid_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', orderId)
        .select('user_id')
        .maybeSingle();
    final ownerUid = row?['user_id'] as String?;
    if (ownerUid == null) return;

    final (title, body) = switch (status) {
      OrderStatus.toReceive => (
        'Order shipped',
        'Order #${_shortId(orderId)} is on its way to you.',
      ),
      OrderStatus.completed => (
        'Order delivered',
        'Order #${_shortId(orderId)} has been delivered — let us know what you think!',
      ),
      OrderStatus.cancelled => (
        'Order cancelled',
        'Order #${_shortId(orderId)} was cancelled.',
      ),
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
