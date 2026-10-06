import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/paymongo_config.dart';

/// Thin wrapper around the PayMongo REST API calls that are safe to make
/// directly from the client — tokenizing a card with the **public** key.
/// Everything that touches the secret key goes through Cloud Functions
/// instead (see `checkout_functions_service.dart`).
class PaymongoClient {
  String get _authHeader => 'Basic ${base64Encode(utf8.encode('${PaymongoConfig.publicKey}:'))}';

  Future<String> createPaymentMethod({
    required String cardNumber,
    required int expMonth,
    required int expYear,
    required String cvc,
    required String billingName,
    required String billingEmail,
  }) async {
    final response = await http.post(
      Uri.parse('${PaymongoConfig.apiBase}/payment_methods'),
      headers: {'Content-Type': 'application/json', 'Authorization': _authHeader},
      body: jsonEncode({
        'data': {
          'attributes': {
            'type': 'card',
            'details': {
              'card_number': cardNumber.replaceAll(' ', ''),
              'exp_month': expMonth,
              'exp_year': expYear,
              'cvc': cvc,
            },
            'billing': {
              'name': billingName,
              'email': billingEmail,
            },
          },
        },
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final message = (body['errors'] as List?)?.firstOrNull?['detail'] as String?;
      throw PaymongoException(message ?? 'Card could not be validated.');
    }
    return body['data']['id'] as String;
  }
}

class PaymongoException implements Exception {
  PaymongoException(this.message);
  final String message;

  @override
  String toString() => message;
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
