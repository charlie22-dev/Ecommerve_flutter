import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'db.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('FCM background message received: ${message.messageId}');
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});

class PushNotificationService {
  PushNotificationService();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String channelId = 'bookverse_alerts';
  static const String channelName = 'BookVerse Alerts';
  static const String channelDescription = 'Order updates, customer messages, and bookstore notifications.';

  /// Call once at app startup
  Future<void> initialize(BuildContext context) async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Firebase.initializeApp() skipped or failed (google-services.json may be pending): $e');
      return;
    }

    _initialized = true;

    // Configure Flutter Local Notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && context.mounted) {
          _handleNotificationRouting(context, response.payload!);
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

    // Foreground messages handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // Notification tapped while app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (context.mounted) {
        _handleRemoteMessageRouting(context, message.data);
      }
    });

    // Check if app was opened from a terminated state
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null && context.mounted) {
      _handleRemoteMessageRouting(context, initialMessage.data);
    }

    // Sync token on startup and listen for refreshes (FCM v17 API)
    FirebaseMessaging.instance.onRegistered.listen((token) async {
      await _registerToken(token);
    });
    await syncDeviceToken();
  }

  /// Request notification permissions with an explanation dialog on Android 13+
  Future<void> requestPermission(BuildContext context) async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await syncDeviceToken();
        return;
      }

      // Show friendly explanation dialog first
      if (context.mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('Stay updated on BookVerse'),
            content: const Text(
              'Get instant alerts when a bookstore replies to your messages, when your order ships, and when payments are confirmed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Allow notifications'),
              ),
            ],
          ),
        );

        if (proceed != true) return;
      }

      final requested = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (requested.authorizationStatus == AuthorizationStatus.authorized) {
        await syncDeviceToken();
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  /// Syncs current FCM token to Supabase device_tokens (FCM v17: use register())
  Future<void> syncDeviceToken() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      // register() triggers onRegistered which calls _registerToken
      await FirebaseMessaging.instance.register();
    } catch (e) {
      debugPrint('Could not sync device token: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await db.rpc('register_device_token', params: {
        'p_token': token,
        'p_platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      debugPrint('Device token registration error: $e');
    }
  }

  /// Deletes token on user logout (FCM v17: register() to get latest token via onRegistered)
  Future<void> deleteTokenOnLogout() async {
    try {
      // We stored the token via onRegistered; delete all tokens for this user
      await db.from('device_tokens').delete().eq(
            'user_id',
            Supabase.instance.client.auth.currentUser?.id ?? '',
          );
    } catch (_) {}
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

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
      id: message.hashCode,
      title: notification.title ?? 'BookVerse',
      body: notification.body ?? '',
      notificationDetails: details,
      payload: message.data['type'] ?? '',
    );
  }

  void _handleRemoteMessageRouting(BuildContext context, Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == 'chat') {
      final storeId = data['store_id'] as String?;
      if (storeId != null) {
        context.push('/messages/seller/$storeId');
      } else {
        context.push('/messages');
      }
    } else if (type == 'order') {
      final orderId = data['order_id'] as String?;
      if (orderId != null) {
        context.push('/orders/$orderId');
      } else {
        context.push('/orders');
      }
    }
  }

  void _handleNotificationRouting(BuildContext context, String payload) {
    if (payload == 'chat') {
      context.push('/messages');
    } else if (payload == 'order') {
      context.push('/orders');
    }
  }
}
