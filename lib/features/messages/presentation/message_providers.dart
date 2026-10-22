import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/store.dart';
import '../../../core/models/store_message.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/message_repository.dart';

final messageRepositoryProvider = Provider((ref) => MessageRepository());

/// Convenience: the signed-in user's UID, or null when logged out.
final authUidProvider = Provider<String?>((ref) => ref.watch(authStateProvider).value?.uid);

// ─── Official store thread (BookVerse Support) ────────────────────────────────

final storeThreadProvider = StreamProvider<List<StoreMessage>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(messageRepositoryProvider).watchThread(uid);
});

/// True while the user has text in the compose box and hasn't sent yet.
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

// ─── Seller store list ────────────────────────────────────────────────────────

/// All approved (non-official, active) stores a buyer can chat with.
final approvedStoresProvider = StreamProvider<List<Store>>((ref) {
  return ref.watch(messageRepositoryProvider).watchApprovedStores();
});

// ─── Buyer ↔ Seller thread ────────────────────────────────────────────────────

/// Messages in a buyer's thread with a specific seller store.
final sellerThreadProvider =
    StreamProvider.family<List<StoreMessage>, String>((ref, storeId) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(messageRepositoryProvider).watchThread(uid, storeId: storeId);
});

class SellerMessageActions {
  SellerMessageActions(this.ref);
  final Ref ref;

  /// Buyer sends a message to a seller store.
  Future<void> send(String text, String storeId) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null || text.trim().isEmpty) return;
    await ref.read(messageRepositoryProvider).send(uid, text.trim(), storeId: storeId);
    // Notify the seller — fails silently if the RPC doesn't exist yet.
    try {
      await ref
          .read(messageRepositoryProvider)
          .notifySellerOnMessage(storeId, 'New message', text.trim());
    } catch (_) {}
  }
}

final sellerMessageActionsProvider = Provider((ref) => SellerMessageActions(ref));

// ─── Seller inbox ─────────────────────────────────────────────────────────────

/// All customer threads for a seller's store (seller-side inbox).
final sellerInboxProvider =
    StreamProvider.family<List<SellerCustomerThread>, String>((ref, storeId) {
  return ref.watch(messageRepositoryProvider).watchSellerThreads(storeId);
});

/// A specific customer's thread viewed by the seller.
final sellerCustomerThreadProvider =
    StreamProvider.family<List<StoreMessage>, (String storeId, String customerUid)>(
        (ref, args) {
  final (storeId, customerUid) = args;
  return ref.watch(messageRepositoryProvider).watchThread(customerUid, storeId: storeId);
});
