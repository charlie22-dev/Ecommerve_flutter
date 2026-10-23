import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../router/app_router.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref);
});

/// Pure Supabase-powered Notification Service:
/// - Prompts Android 13+ & iOS for system notification permissions
/// - Subscribes to Supabase Realtime for instant in-app & device alerts
/// - Triggers high-priority local notification popups with sound & vibration
class PushNotificationService {
  PushNotificationService(this._ref);

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  RealtimeChannel? _realtimeSubscription;

  static const String channelId = 'bookverse_alerts';
  static const String channelName = 'BookVerse Alerts';
  static const String channelDescription = 'Order updates, customer messages, and bookstore notifications.';

  /// Call once at app startup
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Configure Flutter Local Notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    try {
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null) {
            _handleNotificationRouting(response.payload!);
          }
        },
      );

      // Create high importance Android notification channel
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.high,
            playSound: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('Local notifications init error: $e');
    }

    // 2. Start listening to Supabase Realtime notifications
    startRealtimeListener();

    // Listen for auth state changes so we attach/detach realtime listener automatically
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        startRealtimeListener();
      } else {
        _realtimeSubscription?.unsubscribe();
        _realtimeSubscription = null;
      }
    });
  }

  /// Request notification permissions on device (Android 13+ and iOS)
  Future<void> requestPermission() async {
    try {
      // 1. Request Android 13+ system notification permission directly via OS dialog
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidPlugin?.requestNotificationsPermission();
        debugPrint('Android system notification permission: $granted');
      }

      // 2. Request iOS permissions
      if (!kIsWeb && Platform.isIOS) {
        final iosPlugin = _localNotifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  /// Listens to Supabase Realtime for notifications destined for the current user
  void startRealtimeListener() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    _realtimeSubscription?.unsubscribe();

    _realtimeSubscription = Supabase.instance.client
        .channel('public:notifications:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            final title = row['title'] as String? ?? 'BookVerse Alert';
            final body = row['body'] as String? ?? '';
            final category = row['category'] as String? ?? 'announcement';

            showNotification(
              title: title,
              body: body,
              payload: jsonEncode({
                'type': category,
                'order_id': row['related_order_id'],
              }),
            );
          },
        )
        .subscribe();
  }

  /// Shows a local system heads-up notification with sound and vibration
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    final details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  Future<void> deleteTokenOnLogout() async {
    _realtimeSubscription?.unsubscribe();
    _realtimeSubscription = null;
  }

  void _handleNotificationRouting(String rawPayload) {
    try {
      final map = jsonDecode(rawPayload) as Map<String, dynamic>;
      final type = map['type'] as String?;
      final router = _ref.read(appRouterProvider);

      if (type == 'chat') {
        router.push('/messages');
      } else if (type == 'orderUpdate' || type == 'order') {
        final orderId = map['order_id'] as String?;
        if (orderId != null) {
          router.push('/orders/$orderId');
        } else {
          router.push('/orders');
        }
      } else {
        router.push('/notifications');
      }
    } catch (_) {
      _ref.read(appRouterProvider).push('/notifications');
    }
  }
}
