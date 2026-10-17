import '../../../core/models/app_notification.dart';
import '../../../core/services/db.dart';

/// Repository responsible for user notifications and unread message updates.
class NotificationRepository {
  Stream<List<AppNotification>> watchForUser(String userId) {
    return watchQuery(Tables.notifications, () async {
      final rows = await db
          .from(Tables.notifications)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return rows.map(AppNotification.fromRow).toList();
    });
  }

  Future<void> create({
    required String userId,
    required NotificationCategory category,
    required String title,
    required String body,
    String? relatedOrderId,
  }) async {
    await db.from(Tables.notifications).insert(AppNotification(
          id: '',
          userId: userId,
          category: category,
          title: title,
          body: body,
          relatedOrderId: relatedOrderId,
        ).toRow());
  }

  Future<void> markRead(String notificationId) async {
    await db.from(Tables.notifications).update({'read': true}).eq('id', notificationId);
  }
}
