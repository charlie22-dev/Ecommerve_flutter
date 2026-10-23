import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/store.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/message_repository.dart';

final messageRepositoryProvider = Provider((ref) => MessageRepository());

/// The signed-in user's UID, or null when logged out.
final authUidProvider = Provider<String?>((ref) => ref.watch(authStateProvider).value?.uid);

/// The official BookVerse store
final officialStoreProvider = FutureProvider<Store?>((ref) {
  return ref.watch(messageRepositoryProvider).getOfficialStore();
});

/// True while user is typing in chat composer
final isUserTypingProvider = StateProvider<bool>((ref) => false);

/// Buyer inbox: all conversations for the logged-in buyer
final buyerConversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(messageRepositoryProvider).watchBuyerConversations(uid);
});

/// Seller inbox: all conversations for the seller's store
final sellerConversationsProvider =
    StreamProvider.family<List<Conversation>, String>((ref, storeId) {
  return ref.watch(messageRepositoryProvider).watchSellerConversations(storeId);
});

/// Admin inbox: all conversations
final adminConversationsProvider = StreamProvider<List<Conversation>>((ref) {
  return ref.watch(messageRepositoryProvider).watchAdminConversations();
});

/// Messages in a specific conversation (realtime)
final conversationMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) {
  return ref.watch(messageRepositoryProvider).watchMessages(conversationId);
});

/// Total unread messages count for the bottom navigation icon badge
final unreadMessagesTotalCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(0);
  return ref.watch(messageRepositoryProvider).watchTotalUnreadCount(uid);
});

/// All approved stores a buyer can message
final approvedStoresListProvider = StreamProvider<List<Store>>((ref) {
  return ref.watch(messageRepositoryProvider).watchApprovedStores();
});

class MessageActions {
  MessageActions(this.ref);
  final Ref ref;

  Future<void> send({
    required String conversationId,
    required String text,
    ChatMessageType type = ChatMessageType.text,
    String? orderId,
  }) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null || text.trim().isEmpty) return;
    await ref.read(messageRepositoryProvider).sendMessage(
          conversationId: conversationId,
          senderId: uid,
          text: text,
          type: type,
          orderId: orderId,
        );
  }

  Future<void> markRead(String conversationId) async {
    await ref.read(messageRepositoryProvider).markConversationRead(conversationId);
  }

  Future<String> getOrCreateConversation(String storeId) async {
    return ref.read(messageRepositoryProvider).getOrCreateConversation(storeId);
  }
}

final messageActionsProvider = Provider((ref) => MessageActions(ref));
