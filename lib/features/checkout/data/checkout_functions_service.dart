import 'package:supabase_flutter/supabase_flutter.dart';

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
    final result = await _functions.invoke('create-invoice', body: {
      'orderId': orderId,
      'order_id': orderId,
      'amount': amount,
      'description': description ?? 'Order #${orderId.substring(0, 8)}',
      'product_name': description ?? 'Order #${orderId.substring(0, 8)}',
      'customerEmail': customerEmail,
      'paymentMethod': paymentMethod,
    });
    if (result.status != 200) {
      throw Exception('Failed to create payment invoice: ${result.data}');
    }
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Creates a PayMongo e-wallet `source` and returns the hosted checkout
  /// URL to open in a WebView.
  Future<String> createEwalletSource({
    required String orderId,
    required double amount,
    required String type, // 'gcash' | 'paymaya'
  }) async {
    final result = await _functions.invoke('createEwalletSource', body: {
      'orderId': orderId,
      'amount': amount,
      'type': type,
    });
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
    final result = await _functions.invoke('createCardPayment', body: {
      'orderId': orderId,
      'amount': amount,
      'paymentMethodId': paymentMethodId,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return CardPaymentResult(
      status: data['status'] as String,
      redirectUrl: data['redirectUrl'] as String?,
    );
  }
}

class CardPaymentResult {
  CardPaymentResult({required this.status, this.redirectUrl});
  final String status; // 'succeeded' | 'awaiting_next_action' | 'failed'
  final String? redirectUrl;
}
