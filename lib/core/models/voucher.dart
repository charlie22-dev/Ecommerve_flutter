import 'package:equatable/equatable.dart';

import '../services/db.dart';

/// Whether the voucher shaves a percentage off the subtotal ([percent])
/// or deducts a fixed peso amount ([fixed]).
enum DiscountType {
  percent,
  fixed;

  static DiscountType fromKey(String? key) =>
      key == 'fixed' ? DiscountType.fixed : DiscountType.percent;
}

class Voucher extends Equatable {
  const Voucher({
    required this.id,
    required this.code,
    required this.title,
    this.description = '',
    required this.discountType,
    required this.discountValue,
    this.minPurchase = 0,
    this.maxDiscount,
    this.expiresAt,
    this.isActive = true,
  });

  final String id;
  final String code;
  final String title;
  final String description;
  final DiscountType discountType;
  final double discountValue;
  final double minPurchase;

  /// Caps a percent-off voucher's peso value (ignored for fixed vouchers).
  final double? maxDiscount;
  final DateTime? expiresAt;
  final bool isActive;

  /// True if [expiresAt] is set and is in the past (device local time).
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool isEligible(double subtotal) => isActive && !isExpired && subtotal >= minPurchase;

  double discountFor(double subtotal) {
    if (!isEligible(subtotal)) return 0;
    final raw = discountType == DiscountType.percent ? subtotal * discountValue / 100 : discountValue;
    final capped = maxDiscount != null ? raw.clamp(0, maxDiscount!) : raw;
    return capped.clamp(0, subtotal).toDouble();
  }

  String get discountLabel =>
      discountType == DiscountType.percent ? '${discountValue.toStringAsFixed(0)}% OFF' : '₱${discountValue.toStringAsFixed(0)} OFF';

  factory Voucher.fromRow(Map<String, dynamic> row) {
    return Voucher(
      id: row['id'] as String,
      code: row['code'] as String? ?? '',
      title: row['title'] as String? ?? '',
      description: row['description'] as String? ?? '',
      discountType: DiscountType.fromKey(row['discount_type'] as String?),
      discountValue: toDouble(row['discount_value']),
      minPurchase: toDouble(row['min_purchase']),
      maxDiscount: (row['max_discount'] as num?)?.toDouble(),
      expiresAt: parseTimestamp(row['expires_at']),
      isActive: row['is_active'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [id, code, discountType, discountValue];
}
