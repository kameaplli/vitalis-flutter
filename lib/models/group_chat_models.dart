import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:hugeicons/hugeicons.dart';

class GroupChat {
  final String id;
  final String name;
  final String? description;
  final String? avatarUrl;
  final String creatorId;
  final GroupChatAccess access;
  final int memberCount;
  final int unreadCount;
  final ChatMessage? lastMessage;
  final bool isMember;
  final GroupChatRole? myRole;
  final bool isMuted;
  final GroupNotifPref notifPref;
  final DateTime createdAt;

  GroupChat({
    required this.id,
    required this.name,
    this.description,
    this.avatarUrl,
    required this.creatorId,
    this.access = GroupChatAccess.public_,
    this.memberCount = 0,
    this.unreadCount = 0,
    this.lastMessage,
    this.isMember = false,
    this.myRole,
    this.isMuted = false,
    this.notifPref = GroupNotifPref.all,
    required this.createdAt,
  });

  bool get isAdmin =>
      myRole == GroupChatRole.admin || myRole == GroupChatRole.owner;

  factory GroupChat.fromJson(Map<String, dynamic> json) {
    return GroupChat(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      avatarUrl: json['avatar_url'],
      creatorId: json['creator_id'] ?? '',
      access: GroupChatAccess.fromString(json['access'] ?? 'public'),
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      lastMessage: json['last_message'] != null
          ? ChatMessage.fromJson(json['last_message'] as Map<String, dynamic>)
          : null,
      isMember: json['is_member'] == true,
      myRole: json['my_role'] != null
          ? GroupChatRole.fromString(json['my_role'] as String)
          : null,
      isMuted: json['is_muted'] == true,
      notifPref: GroupNotifPref.fromString(json['notif_pref'] ?? 'all'),
      createdAt:
          DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'avatar_url': avatarUrl,
        'creator_id': creatorId,
        'access': access.value,
        'member_count': memberCount,
        'unread_count': unreadCount,
        'last_message': lastMessage?.toJson(),
        'is_member': isMember,
        'my_role': myRole?.value,
        'is_muted': isMuted,
        'notif_pref': notifPref.value,
        'created_at': createdAt.toIso8601String(),
      };
}

class MessageReaction {
  final String emoji;
  final int count;
  final bool userReacted;

  MessageReaction({required this.emoji, this.count = 0, this.userReacted = false});

  factory MessageReaction.fromJson(Map<String, dynamic> json) => MessageReaction(
        emoji: json['emoji'] ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
        userReacted: json['user_reacted'] == true,
      );

  Map<String, dynamic> toJson() => {
        'emoji': emoji,
        'count': count,
        'user_reacted': userReacted,
      };
}

class ReadReceipt {
  final String userId;
  final String userName;
  final DateTime readAt;

  ReadReceipt({required this.userId, required this.userName, required this.readAt});

  factory ReadReceipt.fromJson(Map<String, dynamic> json) => ReadReceipt(
        userId: json['user_id'] ?? '',
        userName: json['user_name'] ?? '',
        readAt: DateTime.tryParse(json['read_at'] ?? '') ?? DateTime.now(),
      );
}

class ChatMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String text;
  final String? imageUrl;
  final bool isPinned;
  final List<MessageReaction> reactions;
  final int readByCount;
  final List<ReadReceipt> readReceipts;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.text,
    this.imageUrl,
    this.isPinned = false,
    this.reactions = const [],
    this.readByCount = 0,
    this.readReceipts = const [],
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      groupId: json['group_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      senderName: json['sender_name'] ?? '',
      senderAvatarUrl: json['sender_avatar_url'],
      text: json['text'] ?? '',
      imageUrl: json['image_url'],
      isPinned: json['is_pinned'] == true,
      reactions: (json['reactions'] as List<dynamic>?)
              ?.map((r) => MessageReaction.fromJson(r as Map<String, dynamic>))
              .toList() ??
          const [],
      readByCount: (json['read_by_count'] as num?)?.toInt() ?? 0,
      readReceipts: (json['read_receipts'] as List<dynamic>?)
              ?.map((r) => ReadReceipt.fromJson(r as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt:
          DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  ChatMessage copyWith({
    bool? isPinned,
    List<MessageReaction>? reactions,
    int? readByCount,
    List<ReadReceipt>? readReceipts,
  }) =>
      ChatMessage(
        id: id,
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        text: text,
        imageUrl: imageUrl,
        isPinned: isPinned ?? this.isPinned,
        reactions: reactions ?? this.reactions,
        readByCount: readByCount ?? this.readByCount,
        readReceipts: readReceipts ?? this.readReceipts,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_avatar_url': senderAvatarUrl,
        'text': text,
        'image_url': imageUrl,
        'is_pinned': isPinned,
        'reactions': reactions.map((r) => r.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };
}

class GroupMember {
  final String userId;
  final String userName;
  final String? avatarUrl;
  final GroupChatRole role;
  final DateTime joinedAt;

  GroupMember({
    required this.userId,
    required this.userName,
    this.avatarUrl,
    this.role = GroupChatRole.member,
    required this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? json['name'] ?? '',
      avatarUrl: json['avatar_url'],
      role: GroupChatRole.fromString(json['role'] ?? 'member'),
      joinedAt:
          DateTime.tryParse(json['joined_at'] ?? '') ?? DateTime.now(),
    );
  }
}

enum GroupChatAccess {
  public_('public'),
  inviteOnly('invite_only');

  final String value;
  const GroupChatAccess(this.value);

  static GroupChatAccess fromString(String s) {
    if (s == 'invite_only') return GroupChatAccess.inviteOnly;
    return GroupChatAccess.public_;
  }

  String get label => switch (this) {
        GroupChatAccess.public_ => 'Public',
        GroupChatAccess.inviteOnly => 'Invite Only',
      };
}

enum GroupNotifPref {
  all('all', 'All Messages'),
  mentionsOnly('mentions_only', 'Mentions Only'),
  muted('muted', 'Muted');

  final String value;
  final String label;
  const GroupNotifPref(this.value, this.label);

  static GroupNotifPref fromString(String s) => switch (s) {
        'mentions_only' => GroupNotifPref.mentionsOnly,
        'muted' => GroupNotifPref.muted,
        _ => GroupNotifPref.all,
      };

  List<List<dynamic>> get icon => switch (this) {
        GroupNotifPref.all => HugeIcons.strokeRoundedNotification01,
        GroupNotifPref.mentionsOnly => HugeIcons.strokeRoundedMail01,
        GroupNotifPref.muted => HugeIcons.strokeRoundedNotification01,
      };
}

enum GroupChatRole {
  owner('owner'),
  admin('admin'),
  member('member');

  final String value;
  const GroupChatRole(this.value);

  static GroupChatRole fromString(String s) => switch (s) {
        'owner' => GroupChatRole.owner,
        'admin' => GroupChatRole.admin,
        _ => GroupChatRole.member,
      };

  String get label => switch (this) {
        GroupChatRole.owner => 'Owner',
        GroupChatRole.admin => 'Admin',
        GroupChatRole.member => 'Member',
      };
}
