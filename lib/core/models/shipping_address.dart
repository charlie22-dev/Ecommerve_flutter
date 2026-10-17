import 'package:equatable/equatable.dart';

/// Represents a buyer's saved delivery destination in their address book.
class ShippingAddress extends Equatable {
  const ShippingAddress({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phoneNumber,
    required this.addressLine,
    required this.city,
    required this.province,
    required this.postalCode,
    this.isDefault = false,
  });

  final String id;
  final String label; // e.g. "Home", "Work"
  final String recipientName;
  final String phoneNumber;
  final String addressLine;
  final String city;
  final String province;
  final String postalCode;
  final bool isDefault;

  /// Convenience getter that joins the address parts into one display string,
  /// e.g. "123 Main St, Manila, Metro Manila, 1000".
  String get fullAddress => '$addressLine, $city, $province, $postalCode';

  factory ShippingAddress.fromRow(Map<String, dynamic> row) {
    return ShippingAddress(
      id: row['id'] as String,
      label: row['label'] as String? ?? 'Home',
      recipientName: row['recipient_name'] as String? ?? '',
      phoneNumber: row['phone_number'] as String? ?? '',
      addressLine: row['address_line'] as String? ?? '',
      city: row['city'] as String? ?? '',
      province: row['province'] as String? ?? '',
      postalCode: row['postal_code'] as String? ?? '',
      isDefault: row['is_default'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toRow(String uid) => {
        if (id.isNotEmpty) 'id': id,
        'user_id': uid,
        'label': label,
        'recipient_name': recipientName,
        'phone_number': phoneNumber,
        'address_line': addressLine,
        'city': city,
        'province': province,
        'postal_code': postalCode,
        'is_default': isDefault,
      };

  /// Snapshot embedded on an `Order` so the shipping details survive even
  /// if the user later edits or deletes this saved address.
  Map<String, dynamic> toOrderSnapshot() => {
        'label': label,
        'recipientName': recipientName,
        'phoneNumber': phoneNumber,
        'addressLine': addressLine,
        'city': city,
        'province': province,
        'postalCode': postalCode,
      };

  static ShippingAddress? fromOrderSnapshot(Map<String, dynamic>? map) {
    if (map == null) return null;
    return ShippingAddress(
      id: '',
      label: map['label'] as String? ?? 'Home',
      recipientName: map['recipientName'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      addressLine: map['addressLine'] as String? ?? '',
      city: map['city'] as String? ?? '',
      province: map['province'] as String? ?? '',
      postalCode: map['postalCode'] as String? ?? '',
    );
  }

  ShippingAddress copyWith({
    String? label,
    String? recipientName,
    String? phoneNumber,
    String? addressLine,
    String? city,
    String? province,
    String? postalCode,
    bool? isDefault,
  }) {
    return ShippingAddress(
      id: id,
      label: label ?? this.label,
      recipientName: recipientName ?? this.recipientName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      addressLine: addressLine ?? this.addressLine,
      city: city ?? this.city,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  List<Object?> get props => [id, label, recipientName, phoneNumber, addressLine, city, province, postalCode, isDefault];
}
