import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_notification.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/notification_repository.dart';

final notificationRepositoryProvider = Provider((ref) => NotificationRepository());

final userNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(notificationRepositoryProvider).watchForUser(uid);
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final items = ref.watch(userNotificationsProvider).value ?? const [];
  return items.where((n) => !n.read).length;
});

class NotificationActions {
  NotificationActions(this.ref);
  final Ref ref;

  Future<void> markRead(String id) => ref.read(notificationRepositoryProvider).markRead(id);
}

final notificationActionsProvider = Provider((ref) => NotificationActions(ref));
