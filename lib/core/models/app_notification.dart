import 'package:equatable/equatable.dart';

import '../services/db.dart';

/// `orderUpdate` — generated when one of the user's own orders changes
/// status (placed, dispatched, delivered). `announcement` — general
/// app/store news (currently just the one-time welcome notice on sign-up;
/// created by the signup trigger in supabase/schema.sql).
enum NotificationCategory {
  orderUpdate,
  announcement;

  static NotificationCategory fromKey(String? key) => NotificationCategory.values.firstWhere(
        (c) => c.name == key,
        orElse: () => NotificationCategory.announcement,
      );

  String get label => switch (this) {
        NotificationCategory.orderUpdate => 'Order Updates',
        NotificationCategory.announcement => 'Latest Updates',
      };
}

/// An in-app notification row shown on the Notifications screen.
/// Tapping one with a [relatedOrderId] navigates to that order's detail page.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.category,
    required this.title,
    required this.body,
    this.relatedOrderId,
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String userId;
  final NotificationCategory category;
  final String title;
  final String body;
  final String? relatedOrderId;
  final bool read;
  final DateTime? createdAt;

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    return AppNotification(
      id: row['id'] as String,
      userId: row['user_id'] as String? ?? '',
      category: NotificationCategory.fromKey(row['category'] as String?),
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      relatedOrderId: row['related_order_id'] as String?,
      read: row['read'] as bool? ?? false,
      createdAt: parseTimestamp(row['created_at']),
    );
  }

  Map<String, dynamic> toRow() => {
        'user_id': userId,
        'category': category.name,
        'title': title,
        'body': body,
        'related_order_id': relatedOrderId,
        'read': read,
      };

  @override
  List<Object?> get props => [id, userId, category, title, read];
}
