import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/store_message.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/message_repository.dart';

final messageRepositoryProvider = Provider((ref) => MessageRepository());

final storeThreadProvider = StreamProvider<List<StoreMessage>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(messageRepositoryProvider).watchThread(uid);
});

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
