import 'package:flutter/foundation.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/store.dart';
import '../../../core/services/db.dart';
import '../../admin/data/admin_repository.dart' show CustomerInfo;

import '../../../core/models/store_message.dart';

class MessageRepository {
  /// Backwards-compat stub
  Stream<List<StoreMessage>> watchThread(String uid) => Stream.value(const []);
  /// Fetches the official BookVerse store
  Future<Store?> getOfficialStore() async {
    try {
      final row = await db
          .from(Tables.stores)
          .select()
          .eq('is_official', true)
          .maybeSingle();
      return row == null ? null : Store.fromRow(row);
    } catch (_) {
      return null;
    }
  }

  /// Finds or creates a conversation between the current buyer and a store.
  Future<String> getOrCreateConversation(String storeId) async {
    final res = await db.rpc('get_or_create_conversation', params: {'p_store_id': storeId});
    return res as String;
  }

  /// Watches all conversations for a buyer (sorted by last_message_at desc)
  Stream<List<Conversation>> watchBuyerConversations(String buyerId) {
    return watchQuery(Tables.conversations, () async {
      try {
        final rows = await db
            .from(Tables.conversations)
            .select('*, stores(id, name, is_official)')
            .eq('buyer_id', buyerId)
            .order('last_message_at', ascending: false);

        return rows.map((r) => Conversation.fromRow(r)).toList();
      } catch (e) { debugPrint('Conversation fetch error: $e'); return const []; }
    });
  }

  /// Watches all conversations for a seller store (sorted by last_message_at desc)
  Stream<List<Conversation>> watchSellerConversations(String storeId) {
    return watchQuery(Tables.conversations, () async {
      try {
        final rows = await db
            .from(Tables.conversations)
            .select('*, stores(id, name, is_official)')
            .eq('store_id', storeId)
            .order('last_message_at', ascending: false);

        final buyerIds = rows.map((r) => r['buyer_id'] as String).toSet().toList();
        final profiles = await _fetchProfiles(buyerIds);

        return rows.map((r) {
          final conv = Conversation.fromRow(r);
          final p = profiles[conv.buyerId];
          return conv.copyWith(
            buyerName: p?.name.isNotEmpty == true ? p!.name : 'Customer',
            buyerPhoto: p?.photoUrl,
          );
        }).toList();
      } catch (e) { debugPrint('Conversation fetch error: $e'); return const []; }
    });
  }

  /// Watches conversations sent to BookVerse Official / Admin (by customers and sellers).
  /// Excludes 3rd-party seller-to-buyer conversations.
  Stream<List<Conversation>> watchAdminConversations() {
    return watchQuery(Tables.conversations, () async {
      try {
        final officialStore = await getOfficialStore();
        if (officialStore == null) return const [];

        final rows = await db
            .from(Tables.conversations)
            .select('*, stores(id, name, is_official)')
            .eq('store_id', officialStore.id)
            .order('last_message_at', ascending: false);

        if (rows.isEmpty) return const [];

        final buyerIds = rows.map((r) => r['buyer_id'] as String).toSet().toList();
        final convIds = rows.map((r) => r['id'] as String).toList();

        final profiles = await _fetchProfiles(buyerIds);
        final sellerStores = await _fetchSellerStores(buyerIds);

        // Fetch unread count where message is unread
        final unreadMap = <String, int>{};
        try {
          final unreadRows = await db
              .from(Tables.messages)
              .select('conversation_id, sender_id')
              .inFilter('conversation_id', convIds)
              .eq('is_read', false);
          for (final u in unreadRows) {
            final cid = u['conversation_id'] as String;
            unreadMap[cid] = (unreadMap[cid] ?? 0) + 1;
          }
        } catch (_) {}

        return rows.map((r) {
          final conv = Conversation.fromRow(r);
          final p = profiles[conv.buyerId];
          final storeName = sellerStores[conv.buyerId];
          final roleBadge = storeName != null ? 'Seller · $storeName' : 'Customer';
          return conv.copyWith(
            buyerName: p?.name.isNotEmpty == true ? p!.name : (storeName ?? 'User'),
            buyerPhoto: p?.photoUrl,
            senderRoleBadge: roleBadge,
            unreadCount: unreadMap[conv.id] ?? 0,
          );
        }).toList();
      } catch (e) {
        debugPrint('Conversation fetch error: $e');
        return const [];
      }
    });
  }

  Future<Map<String, String>> _fetchSellerStores(Iterable<String> uids) async {
    final ids = uids.toSet().toList();
    if (ids.isEmpty) return const {};
    try {
      final rows = await db
          .from(Tables.stores)
          .select('owner_id, name')
          .inFilter('owner_id', ids);
      return {
        for (final r in rows)
          if (r['owner_id'] != null && r['name'] != null)
            r['owner_id'] as String: r['name'] as String,
      };
    } catch (_) {
      return {};
    }
  }

  /// Watches messages in a conversation (realtime, ordered by created_at asc)
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return watchQuery(Tables.messages, () async {
      try {
        final rows = await db
            .from(Tables.messages)
            .select()
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: true);
        return rows.map(ChatMessage.fromRow).toList();
      } catch (e) { debugPrint('Conversation fetch error: $e'); return const []; }
    });
  }

  /// Sends a message in a conversation
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
    ChatMessageType type = ChatMessageType.text,
    String? orderId,
  }) async {
    await db.from(Tables.messages).insert({
      'conversation_id': conversationId,
      'sender_id': senderId,
      'body': text.trim(),
      'type': type.toDbString(),
      'order_id': orderId,
      'is_read': false,
    });
  }

  /// Marks unread messages in a conversation as read
  Future<void> markConversationRead(String conversationId) async {
    try {
      await db.rpc('mark_conversation_read', params: {'p_conversation_id': conversationId});
    } catch (_) {}
  }

  /// All approved seller stores that buyers can message
  Stream<List<Store>> watchApprovedStores() {
    return watchQuery(Tables.stores, () async {
      try {
        final rows = await db
            .from(Tables.stores)
            .select()
            .eq('status', 'active')
            .eq('is_official', false)
            .order('name', ascending: true);
        return rows.map(Store.fromRow).toList();
      } catch (_) {
        return const [];
      }
    });
  }

  /// Total unread count for bottom navigation badge
  Stream<int> watchTotalUnreadCount(String uid) {
    return watchQuery(Tables.messages, () async {
      try {
        // Count unread messages in conversations where this user is buyer
        final convRows = await db
            .from(Tables.conversations)
            .select('id')
            .eq('buyer_id', uid);
        final convIds = convRows.map((r) => r['id'] as String).toList();
        if (convIds.isEmpty) return 0;

        final unread = await db
            .from(Tables.messages)
            .select('id')
            .inFilter('conversation_id', convIds)
            .eq('is_read', false)
            .neq('sender_id', uid);
        return unread.length;
      } catch (_) {
        return 0;
      }
    });
  }

  Future<Map<String, CustomerInfo>> _fetchProfiles(Iterable<String> uids) async {
    final ids = uids.toSet().toList();
    if (ids.isEmpty) return const {};
    try {
      final rows = await db
          .from(Tables.profiles)
          .select('id, display_name, email, photo_url')
          .inFilter('id', ids);
      return {
        for (final r in rows)
          r['id'] as String: CustomerInfo(
            uid: r['id'] as String,
            name: r['display_name'] as String? ?? '',
            email: r['email'] as String? ?? '',
            photoUrl: r['photo_url'] as String?,
          ),
      };
    } catch (_) {
      return {};
    }
  }
}
