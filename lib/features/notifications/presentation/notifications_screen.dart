import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/app_notification.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import 'notification_providers.dart';

final _notificationsTabProvider = StateProvider<NotificationCategory>((ref) => NotificationCategory.orderUpdate);

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final notificationsAsync = ref.watch(userNotificationsProvider);
    final selectedTab = ref.watch(_notificationsTabProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Semantics(
            button: true,
            label: 'Messages',
            child: IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              onPressed: () => context.push('/messages'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(child: _TabButton(category: NotificationCategory.orderUpdate, selected: selectedTab)),
                const SizedBox(width: 10),
                Expanded(child: _TabButton(category: NotificationCategory.announcement, selected: selectedTab)),
              ],
            ),
          ),
          Expanded(
            child: notificationsAsync.when(
              data: (items) {
                final filtered = items.where((n) => n.category == selectedTab).toList();
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'Nothing here yet',
                    message: 'You\'ll see updates here as they happen.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _NotificationTile(notification: filtered[i]),
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
              error: (err, _) => Center(child: Text('Could not load notifications.', style: TextStyle(color: colors.error))),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends ConsumerWidget {
  const _TabButton({required this.category, required this.selected});
  final NotificationCategory category;
  final NotificationCategory selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isSelected = category == selected;
    return GestureDetector(
      onTap: () => ref.read(_notificationsTabProvider.notifier).state = category,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colors.ink : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? colors.ink : colors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          category.label,
          style: TextStyle(
            color: isSelected ? colors.onInk : colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});
  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        if (!notification.read) ref.read(notificationActionsProvider).markRead(notification.id);
        if (notification.relatedOrderId != null) context.push('/orders/${notification.relatedOrderId}');
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.read ? colors.surface : colors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                color: notification.read ? Colors.transparent : colors.error,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  Text(notification.body, style: TextStyle(color: colors.textSecondary, fontSize: 12.5, height: 1.4)),
                  if (notification.createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(DateFormat.yMMMd().add_jm().format(notification.createdAt!), style: TextStyle(color: colors.textTertiary, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
