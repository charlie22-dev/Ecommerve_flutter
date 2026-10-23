import '../services/db.dart';

enum ChatMessageType {
  text,
  order,
  system;

  static ChatMessageType fromString(String? val) => switch (val) {
        'order' => ChatMessageType.order,
        'system' => ChatMessageType.system,
        _ => ChatMessageType.text,
      };

  String toDbString() => name;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    this.senderId,
    required this.body,
    this.type = ChatMessageType.text,
    this.orderId,
    this.isRead = false,
    this.createdAt,
  });

  final String id;
  final String conversationId;
  final String? senderId;
  final String body;
  final ChatMessageType type;
  final String? orderId;
  final bool isRead;
  final DateTime? createdAt;

  factory ChatMessage.fromRow(Map<String, dynamic> row) {
    return ChatMessage(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      senderId: row['sender_id'] as String?,
      body: row['body'] as String? ?? '',
      type: ChatMessageType.fromString(row['type'] as String?),
      orderId: row['order_id'] as String?,
      isRead: row['is_read'] as bool? ?? false,
      createdAt: parseTimestamp(row['created_at']),
    );
  }

  Map<String, dynamic> toRow() => {
        'conversation_id': conversationId,
        'sender_id': senderId,
        'body': body,
        'type': type.toDbString(),
        'order_id': orderId,
        'is_read': isRead,
      };
}
