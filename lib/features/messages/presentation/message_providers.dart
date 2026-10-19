import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/store_message.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/message_repository.dart';

final messageRepositoryProvider = Provider((ref) => MessageRepository());

/// Convenience: the signed-in user's UID, or null when logged out.
final authUidProvider = Provider<String?>((ref) => ref.watch(authStateProvider).value?.uid);

final storeThreadProvider = StreamProvider<List<StoreMessage>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(messageRepositoryProvider).watchThread(uid);
});

/// True while the user has text in the compose box and hasn't sent yet.
/// Used to show the typing indicator bubble on the other side.
final isUserTypingProvider = StateProvider<bool>((ref) => false);

/// True while the store/admin has text and hasn't sent (simulated for UX).
final isStoreTypingProvider = StateProvider<bool>((ref) => false);

class MessageActions {
  MessageActions(this.ref);
  final Ref ref;

  Future<void> send(String text) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null || text.trim().isEmpty) return;
    await ref.read(messageRepositoryProvider).send(uid, text.trim());
  }

  Future<void> sendStoreWelcomeIfEmpty(List<StoreMessage> currentThread) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null || currentThread.isNotEmpty) return;
    await ref.read(messageRepositoryProvider).sendStoreWelcome(uid);
  }
}

final messageActionsProvider = Provider((ref) => MessageActions(ref));
