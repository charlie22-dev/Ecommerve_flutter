import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/models/order.dart';

/// Calls the Supabase Edge Functions that hold the PayMongo **secret** key
/// server-side (`createEwalletSource`, `createCardPayment`). These must be
/// deployed separately — see supabase/SETUP.md → "Online payments".
class CheckoutFunctionsService {
  CheckoutFunctionsService({FunctionsClient? functions})
    : _functions = functions ?? Supabase.instance.client.functions;

  final FunctionsClient _functions;

  /// Creates a Xendit Invoice for online payments (GCash, Maya, Card, etc.)
  /// and returns the hosted invoice data including `invoice_url`.
  Future<Map<String, dynamic>> createXenditInvoice({
    required String orderId,
    required double amount,
    String? description,
    String? customerEmail,
    String? paymentMethod,
  }) async {
    final result = await _functions.invoke(
      'create-invoice',
      body: {
        'orderId': orderId,
        'order_id': orderId,
        'amount': amount,
        'description': description ?? 'Order #${orderId.substring(0, 8)}',
        'product_name': description ?? 'Order #${orderId.substring(0, 8)}',
        'customerEmail': customerEmail,
        'paymentMethod': paymentMethod,
        if (kIsWeb)
          'returnUrl': '${Uri.base.origin}/#/order-confirmation/$orderId',
      },
    );
    if (result.status != 200) {
      throw Exception('Failed to create payment invoice: ${result.data}');
    }
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// The Edge Function checks Xendit using its secret key and atomically
  /// records the verified transaction before returning the updated receipt.
  Future<Order?> syncPayment(String orderId) async {
    try {
      final result = await _functions.invoke(
        'sync-payment',
        body: {'orderId': orderId},
      );
      final data = Map<String, dynamic>.from(result.data as Map);
      final row = data['order'];
      return row == null
          ? null
          : Order.fromRow(Map<String, dynamic>.from(row as Map));
    } on FunctionException catch (error) {
      throw PaymentVerificationException.fromFunctionError(error);
    } catch (error) {
      throw PaymentVerificationException(
        'Payment status could not be reached. Check your connection and try again.',
        cause: error,
      );
    }
  }

  /// Creates a PayMongo e-wallet `source` and returns the hosted checkout
  /// URL to open in a WebView.
  Future<String> createEwalletSource({
    required String orderId,
    required double amount,
    required String type, // 'gcash' | 'paymaya'
  }) async {
    final result = await _functions.invoke(
      'createEwalletSource',
      body: {'orderId': orderId, 'amount': amount, 'type': type},
    );
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['checkoutUrl'] as String;
  }

  /// Attaches a client-tokenized card payment method to a PaymentIntent.
  /// Returns 'succeeded' or, if 3-D Secure is required, a redirect URL.
  Future<CardPaymentResult> payWithCard({
    required String orderId,
    required double amount,
    required String paymentMethodId,
  }) async {
    final result = await _functions.invoke(
      'createCardPayment',
      body: {
        'orderId': orderId,
        'amount': amount,
        'paymentMethodId': paymentMethodId,
      },
    );
    final data = Map<String, dynamic>.from(result.data as Map);
    return CardPaymentResult(
      status: data['status'] as String,
      redirectUrl: data['redirectUrl'] as String?,
    );
  }
}

class PaymentVerificationException implements Exception {
  const PaymentVerificationException(this.message, {this.cause});

  final String message;
  final Object? cause;

  factory PaymentVerificationException.fromFunctionError(
    FunctionException error,
  ) {
    final body = error.details;
    final payload = body is Map ? body : null;
    final serverMessage = payload?['error']?.toString();
    final code = payload?['code']?.toString();
    final message = switch (code) {
      'PAYMENT_NOT_CONFIGURED' =>
        'Online payment verification is not configured on the server.',
      'PAYMENT_MIGRATION_MISSING' => 'Payment records are not set up in the database. Apply the verified payment migration.',
      'XENDIT_CREDENTIALS' => 'The Xendit server key was rejected. Check that the configured key matches this Xendit account.',
      'XENDIT_INVOICE_NOT_FOUND' => 'Xendit could not find this invoice. The order needs payment support review.',
      'ORDER_INVOICE_MISMATCH' => 'The payment invoice does not match this order. Contact support before retrying payment.',
      _ => switch (error.status) {
        0 => 'Payment status could not be reached. Check your connection and try again.',
        401 => 'Your session expired. Sign in again to check this payment.',
        404 => 'Payment verification is not deployed or this order could not be found.',
        503 =>
          serverMessage ??
              'Online payment verification is not configured on the server.',
        502 =>
          serverMessage ??
              'The payment provider could not verify this invoice yet.',
        _ =>
          serverMessage ??
              'Payment status could not be verified. Please try again.',
      },
    };
    return PaymentVerificationException(message, cause: error);
  }

  @override
  String toString() => message;
}

class CardPaymentResult {
  CardPaymentResult({required this.status, this.redirectUrl});
  final String status; // 'succeeded' | 'awaiting_next_action' | 'failed'
  final String? redirectUrl;
}
