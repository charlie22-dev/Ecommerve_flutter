import 'package:equatable/equatable.dart';

import '../services/db.dart';

/// Tag indicating whether a message was authored by the user or the store/seller.
enum MessageSender {
  user,
  store;

  static MessageSender fromKey(String? key) => key == 'store' ? MessageSender.store : MessageSender.user;
}

/// A chat message between a customer and either the official BookVerse Store
/// or an approved third-party seller's store.
class StoreMessage extends Equatable {
  const StoreMessage({
    required this.id,
    required this.uid,
    required this.sender,
    required this.text,
    this.storeId,
    this.createdAt,
  });

  final String id;
  final String uid;
  final MessageSender sender;
  final String text;
  final String? storeId;
  final DateTime? createdAt;

  /// Returns the human-readable message text without internal routing prefixes.
  String get displayContent {
    if (text.startsWith('[store:')) {
      final end = text.indexOf(']');
      if (end != -1) return text.substring(end + 1).trim();
    }
    return text;
  }

  factory StoreMessage.fromRow(Map<String, dynamic> row) {
    final rawText = row['text'] as String? ?? '';
    String? parsedStoreId = row['store_id'] as String?;
    if (parsedStoreId == null && rawText.startsWith('[store:')) {
      final end = rawText.indexOf(']');
      if (end != -1) {
        parsedStoreId = rawText.substring(7, end).trim();
      }
    }

    return StoreMessage(
      id: row['id'] as String,
      uid: row['user_id'] as String? ?? '',
      sender: MessageSender.fromKey(row['sender'] as String?),
      text: rawText,
      storeId: parsedStoreId,
      createdAt: parseTimestamp(row['created_at']),
    );
  }

  Map<String, dynamic> toRow() => {
        'user_id': uid,
        'sender': sender.name,
        'text': storeId != null && !text.startsWith('[store:') ? '[store:$storeId] $text' : text,
      };

  @override
  List<Object?> get props => [id, uid, sender, text, storeId];
}
