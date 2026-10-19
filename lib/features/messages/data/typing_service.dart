import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/db.dart';

/// Broadcasts and listens for typing events over a Supabase Realtime
/// broadcast channel for a given user conversation thread.
///
/// No database rows are written — broadcast messages are ephemeral and are
/// only delivered to currently subscribed clients.
///
/// Usage:
///   final svc = TypingService(userId: uid, senderRole: 'user');
///   svc.onOtherTyping.listen((isTyping) { ... });
///   svc.sendTyping(true);
///   svc.dispose();
class TypingService {
  TypingService({required this.userId, required this.senderRole}) {
    _init();
  }

  /// The UID of the customer whose thread this is.
  final String userId;

  /// Either `'user'` (customer side) or `'store'` (admin side).
  final String senderRole;

  // The role we listen for — the opposite of senderRole.
  String get _otherRole => senderRole == 'user' ? 'store' : 'user';

  final _controller = StreamController<bool>.broadcast();

  /// Emits `true` when the other party starts typing, `false` when they stop.
  Stream<bool> get onOtherTyping => _controller.stream;

  RealtimeChannel? _channel;
  Timer? _clearTimer;

  void _init() {
    _channel = db
        .channel('typing:$userId')
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final role = payload['role'] as String?;
            final isTyping = payload['typing'] as bool? ?? false;
            if (role == _otherRole) {
              _clearTimer?.cancel();
              _controller.add(isTyping);
              if (isTyping) {
                // Auto-clear after 3 s in case the other client disconnects
                // without sending a stop event.
                _clearTimer = Timer(const Duration(seconds: 3), () {
                  if (!_controller.isClosed) _controller.add(false);
                });
              }
            }
          },
        )
        .subscribe();
  }

  /// Call with [isTyping] = true when the user starts typing,
  /// false when they stop or send.
  void sendTyping(bool isTyping) {
    _channel?.sendBroadcastMessage(
      event: 'typing',
      payload: {'role': senderRole, 'typing': isTyping},
    );
  }

  void dispose() {
    _clearTimer?.cancel();
    final c = _channel;
    if (c != null) db.removeChannel(c);
    _controller.close();
  }
}
