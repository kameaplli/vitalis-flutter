/// Direct message conversation between two users.
class DmConversation {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherAvatarUrl;
  final DmMessage? lastMessage;
  final int unreadCount;
  final bool isOtherOnline;
  final DateTime updatedAt;

  DmConversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherAvatarUrl,
    this.lastMessage,
    this.unreadCount = 0,
    this.isOtherOnline = false,
    required this.updatedAt,
  });

  factory DmConversation.fromJson(Map<String, dynamic> json) =>
      DmConversation(
        id: json['id'] ?? '',
        otherUserId: json['other_user_id'] ?? '',
        otherUserName: json['other_user_name'] ?? '',
        otherAvatarUrl: json['other_avatar_url'],
        lastMessage: json['last_message'] != null
            ? DmMessage.fromJson(json['last_message'] as Map<String, dynamic>)
            : null,
        unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
        isOtherOnline: json['is_other_online'] == true,
        updatedAt:
            DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'other_user_id': otherUserId,
        'other_user_name': otherUserName,
        'other_avatar_url': otherAvatarUrl,
        'last_message': lastMessage?.toJson(),
        'unread_count': unreadCount,
        'is_other_online': isOtherOnline,
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// A single direct message.
class DmMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final String? imageUrl;
  final bool isRead;
  final DateTime createdAt;

  DmMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    this.imageUrl,
    this.isRead = false,
    required this.createdAt,
  });

  factory DmMessage.fromJson(Map<String, dynamic> json) => DmMessage(
        id: json['id'] ?? '',
        conversationId: json['conversation_id'] ?? '',
        senderId: json['sender_id'] ?? '',
        text: json['text'] ?? '',
        imageUrl: json['image_url'],
        isRead: json['is_read'] == true,
        createdAt:
            DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'text': text,
        'image_url': imageUrl,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };
}
