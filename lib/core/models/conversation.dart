import '../services/db.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.buyerId,
    required this.storeId,
    this.lastMessage = '',
    this.lastMessageAt,
    this.createdAt,
    this.storeName,
    this.storeLogo,
    this.buyerName,
    this.buyerPhoto,
    this.unreadCount = 0,
  });

  final String id;
  final String buyerId;
  final String storeId;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;

  // Joined presentation fields
  final String? storeName;
  final String? storeLogo;
  final String? buyerName;
  final String? buyerPhoto;
  final int unreadCount;

  factory Conversation.fromRow(Map<String, dynamic> row) {
    final stores = row['stores'] as Map<String, dynamic>?;
    final buyer = row['profiles'] as Map<String, dynamic>?;

    return Conversation(
      id: row['id'] as String,
      buyerId: row['buyer_id'] as String,
      storeId: row['store_id'] as String,
      lastMessage: row['last_message'] as String? ?? '',
      lastMessageAt: parseTimestamp(row['last_message_at']),
      createdAt: parseTimestamp(row['created_at']),
      storeName: stores?['name'] as String?,
      storeLogo: stores?['logo_url'] as String?,
      buyerName: buyer?['display_name'] as String?,
      buyerPhoto: buyer?['photo_url'] as String?,
      unreadCount: (row['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  Conversation copyWith({
    String? storeName,
    String? storeLogo,
    String? buyerName,
    String? buyerPhoto,
    int? unreadCount,
  }) {
    return Conversation(
      id: id,
      buyerId: buyerId,
      storeId: storeId,
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      createdAt: createdAt,
      storeName: storeName ?? this.storeName,
      storeLogo: storeLogo ?? this.storeLogo,
      buyerName: buyerName ?? this.buyerName,
      buyerPhoto: buyerPhoto ?? this.buyerPhoto,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
