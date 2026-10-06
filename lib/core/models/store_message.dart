import 'package:equatable/equatable.dart';

import '../services/db.dart';

/// BookVerse is a single-storefront app (no multi-vendor marketplace), so
/// "conversations with sellers" resolves to one ongoing thread per buyer
/// with "BookVerse Store" — modeled as a flat list of messages tagged by
/// sender rather than a full conversations/threads schema.
enum MessageSender {
  user,
  store;

  static MessageSender fromKey(String? key) => key == 'store' ? MessageSender.store : MessageSender.user;
}

class StoreMessage extends Equatable {
  const StoreMessage({
    required this.id,
    required this.uid,
    required this.sender,
    required this.text,
    this.createdAt,
  });

  final String id;
  final String uid;
  final MessageSender sender;
  final String text;
  final DateTime? createdAt;

  factory StoreMessage.fromRow(Map<String, dynamic> row) {
    return StoreMessage(
      id: row['id'] as String,
      uid: row['user_id'] as String? ?? '',
      sender: MessageSender.fromKey(row['sender'] as String?),
      text: row['text'] as String? ?? '',
      createdAt: parseTimestamp(row['created_at']),
    );
  }

  Map<String, dynamic> toRow() => {
        'user_id': uid,
        'sender': sender.name,
        'text': text,
      };

  @override
  List<Object?> get props => [id, uid, sender, text];
}
