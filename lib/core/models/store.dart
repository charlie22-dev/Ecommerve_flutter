import '../services/db.dart';

/// A seller's shop (or the platform's own "BookVerse Official" store).
class Store {
  const Store({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.status = 'active',
    this.commissionRate,
    this.isOfficial = false,
    this.createdAt,
  });

  final String id;
  final String? ownerId;
  final String name;
  final String description;
  final String contactEmail;
  final String contactPhone;

  /// `active` or `suspended` — only admins change it (set_store_status).
  final String status;

  /// Store-specific commission; null means the platform default.
  final double? commissionRate;
  final bool isOfficial;
  final DateTime? createdAt;

  bool get isActive => status == 'active';

  factory Store.fromRow(Map<String, dynamic> row) => Store(
        id: row['id'] as String,
        ownerId: row['owner_id'] as String?,
        name: row['name'] as String? ?? '',
        description: row['description'] as String? ?? '',
        contactEmail: row['contact_email'] as String? ?? '',
        contactPhone: row['contact_phone'] as String? ?? '',
        status: row['status'] as String? ?? 'active',
        commissionRate: (row['commission_rate'] as num?)?.toDouble(),
        isOfficial: row['is_official'] as bool? ?? false,
        createdAt: parseTimestamp(row['created_at']),
      );
}

/// A request to become a seller, reviewed by an admin.
class SellerApplication {
  const SellerApplication({
    required this.id,
    required this.userId,
    required this.storeName,
    this.description = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.status = 'pending',
    this.adminNote,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String storeName;
  final String description;
  final String contactEmail;
  final String contactPhone;

  /// `pending`, `approved` or `rejected`.
  final String status;

  /// The admin's reason, shown to the applicant when rejected.
  final String? adminNote;
  final DateTime? createdAt;

  factory SellerApplication.fromRow(Map<String, dynamic> row) => SellerApplication(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        storeName: row['store_name'] as String? ?? '',
        description: row['description'] as String? ?? '',
        contactEmail: row['contact_email'] as String? ?? '',
        contactPhone: row['contact_phone'] as String? ?? '',
        status: row['status'] as String? ?? 'pending',
        adminNote: row['admin_note'] as String?,
        createdAt: parseTimestamp(row['created_at']),
      );
}
