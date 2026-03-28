// ─── Social Models ──────────────────────────────────────────────────────────

class SocialProfile {
  final String userId;
  final String? displayName;
  final String? bio;
  final List<String> badgeShowcase;
  final int xpTotal;
  final int level;
  final String? streakBuddyId;
  final Map<String, dynamic> privacySettings;
  final DateTime? createdAt;

  SocialProfile({
    required this.userId,
    this.displayName,
    this.bio,
    this.badgeShowcase = const [],
    this.xpTotal = 0,
    this.level = 1,
    this.streakBuddyId,
    this.privacySettings = const <String, dynamic>{},
    this.createdAt,
  });

  factory SocialProfile.fromJson(Map<String, dynamic> json) {
    return SocialProfile(
      userId: json['user_id'] ?? '',
      displayName: json['display_name'],
      bio: json['bio'],
      badgeShowcase: (json['badge_showcase'] as List<dynamic>?)
              ?.map((b) => b.toString())
              .toList() ??
          const [],
      xpTotal: (json['xp_total'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      streakBuddyId: json['streak_buddy_id'],
      privacySettings: (json['privacy_settings'] is Map)
              ? Map<String, dynamic>.from(json['privacy_settings'])
              : <String, dynamic>{},
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        if (displayName != null) 'display_name': displayName,
        if (bio != null) 'bio': bio,
        'badge_showcase': badgeShowcase,
        'xp_total': xpTotal,
        'level': level,
        if (streakBuddyId != null) 'streak_buddy_id': streakBuddyId,
        'privacy_settings': privacySettings,
      };
}

// ─── Connection ─────────────────────────────────────────────────────────────

class Connection {
  final String id;
  final String requesterId;
  final String addresseeId;
  final String connectionType; // buddy, family_circle, nutritionist
  final String status; // pending, accepted, rejected, removed
  final String? requesterName;
  final String? requesterAvatarUrl;
  final String? addresseeName;
  final String? addresseeAvatarUrl;
  final DateTime? createdAt;

  Connection({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.connectionType,
    required this.status,
    this.requesterName,
    this.requesterAvatarUrl,
    this.addresseeName,
    this.addresseeAvatarUrl,
    this.createdAt,
  });

  factory Connection.fromJson(Map<String, dynamic> json) {
    return Connection(
      id: json['id'] ?? '',
      requesterId: json['requester_id'] ?? json['other_user']?['user_id'] ?? '',
      addresseeId: json['addressee_id'] ?? '',
      connectionType: json['connection_type'] ?? '',
      status: json['status'] ?? '',
      requesterName: json['requester_name'] ?? json['other_user']?['name'] ?? '',
      requesterAvatarUrl: json['requester_avatar_url'] ?? json['other_user']?['avatar_url'],
      addresseeName: json['addressee_name'] ?? '',
      addresseeAvatarUrl: json['addressee_avatar_url'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}

// ─── Reaction Summary ───────────────────────────────────────────────────────

class ReactionSummary {
  final String type; // heart, fire, clap, star, flex, yum
  final int count;
  final bool userReacted; // did current user react with this type

  ReactionSummary({
    required this.type,
    this.count = 0,
    this.userReacted = false,
  });

  factory ReactionSummary.fromJson(Map<String, dynamic> json) {
    return ReactionSummary(
      type: json['type'] ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      userReacted: json['user_reacted'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'count': count,
        'user_reacted': userReacted,
      };
}

// ─── Feed Event ─────────────────────────────────────────────────────────────

class FeedEvent {
  final String id;
  final String actorId;
  final String actorName;
  final String? actorAvatarUrl;
  final String eventType;
  final String? contentType;
  final Map<String, dynamic> contentSnapshot;
  final bool isRead;
  final List<ReactionSummary> reactions;
  final DateTime createdAt;

  FeedEvent({
    required this.id,
    required this.actorId,
    required this.actorName,
    this.actorAvatarUrl,
    required this.eventType,
    this.contentType,
    this.contentSnapshot = const {},
    this.isRead = false,
    this.reactions = const [],
    this.commentCount = 0,
    required this.createdAt,
  });

  final int commentCount;

  FeedEvent copyWith({
    List<ReactionSummary>? reactions,
    int? commentCount,
  }) {
    return FeedEvent(
      id: id,
      actorId: actorId,
      actorName: actorName,
      actorAvatarUrl: actorAvatarUrl,
      eventType: eventType,
      contentType: contentType,
      contentSnapshot: contentSnapshot,
      isRead: isRead,
      reactions: reactions ?? this.reactions,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt,
    );
  }

  factory FeedEvent.fromJson(Map<String, dynamic> json) {
    return FeedEvent(
      id: json['id'] ?? '',
      actorId: json['actor']?['user_id'] ?? json['actor_id'] ?? '',
      actorName: json['actor']?['display_name'] ?? json['actor']?['name'] ?? json['actor_name'] ?? '',
      actorAvatarUrl: json['actor']?['avatar_url'] ?? json['actor_avatar_url'],
      eventType: json['event_type'] ?? '',
      contentType: json['content_type'],
      contentSnapshot:
          (json['content_snapshot'] as Map<String, dynamic>?) ?? const {},
      isRead: json['is_read'] == true,
      reactions: (json['reactions'] as List<dynamic>?)
              ?.map((r) =>
                  ReactionSummary.fromJson(r as Map<String, dynamic>))
              .toList() ??
          const [],
      commentCount: (json['comment_count'] as num?)?.toInt() ??
          (json['content_snapshot']?['comment_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'actor_id': actorId,
        'actor_name': actorName,
        'actor_avatar_url': actorAvatarUrl,
        'event_type': eventType,
        'content_type': contentType,
        'content_snapshot': contentSnapshot,
        'is_read': isRead,
        'reactions': reactions.map((r) => r.toJson()).toList(),
        'comment_count': commentCount,
        'created_at': createdAt.toIso8601String(),
      };

  // Helper getters
  bool get isAchievement => eventType == 'achievement';
  bool get isRecipe => contentType == 'recipe';
  bool get isStreak => eventType == 'streak' || contentType == 'streak';
  bool get isNote => contentType == 'note';
  bool get isMealPhoto => contentType == 'meal_photo';
}

// ─── Shared Item ────────────────────────────────────────────────────────────

class SharedItem {
  final String id;
  final String contentType;
  final String? contentId;
  final String audience;
  final Map<String, dynamic> contentSnapshot;
  final DateTime createdAt;

  SharedItem({
    required this.id,
    required this.contentType,
    this.contentId,
    required this.audience,
    this.contentSnapshot = const {},
    required this.createdAt,
  });

  factory SharedItem.fromJson(Map<String, dynamic> json) {
    return SharedItem(
      id: json['id'] ?? '',
      contentType: json['content_type'] ?? '',
      contentId: json['content_id'],
      audience: json['audience'] ?? 'connections',
      contentSnapshot:
          (json['content_snapshot'] as Map<String, dynamic>?) ?? const {},
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

// ─── Challenge ──────────────────────────────────────────────────────────────

class Challenge {
  final String id;
  final String creatorId;
  final String title;
  final String? description;
  final String challengeType;
  final String targetMetric;
  final double targetValue;
  final int targetDays;
  final int durationDays;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final bool isGlobal;
  final int maxParticipants;
  final int participantCount;
  final double? myCompletionPct; // null if not joined
  final bool? myCompleted;

  Challenge({
    required this.id,
    required this.creatorId,
    required this.title,
    this.description,
    required this.challengeType,
    required this.targetMetric,
    this.targetValue = 0,
    this.targetDays = 0,
    this.durationDays = 7,
    required this.startDate,
    required this.endDate,
    this.status = 'active',
    this.isGlobal = false,
    this.maxParticipants = 0,
    this.participantCount = 0,
    this.myCompletionPct,
    this.myCompleted,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] ?? '',
      creatorId: json['creator']?['user_id'] ?? json['creator_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      challengeType: json['challenge_type'] ?? '',
      targetMetric: json['target_metric'] ?? '',
      targetValue: (json['target_value'] as num?)?.toDouble() ?? 0,
      targetDays: (json['target_days'] as num?)?.toInt() ?? 0,
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 7,
      startDate:
          DateTime.tryParse(json['start_date'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'active',
      isGlobal: json['is_global'] == true,
      maxParticipants: (json['max_participants'] as num?)?.toInt() ?? 0,
      participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
      myCompletionPct: (json['my_completion_pct'] as num?)?.toDouble(),
      myCompleted: json['my_completed'] as bool?,
    );
  }

  // Helper getters
  bool get isActive => status == 'active';
  bool get isOpen => status == 'open' || status == 'active';
  bool get isCompleted => status == 'completed';

  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return 0;
    return endDate.difference(now).inDays;
  }

  int get daysElapsed {
    final now = DateTime.now();
    if (now.isBefore(startDate)) return 0;
    return now.difference(startDate).inDays;
  }
}

// ─── Challenge Member ───────────────────────────────────────────────────────

class ChallengeMember {
  final String userId;
  final String userName;
  final String? avatarUrl;
  final double completionPct;
  final bool completed;

  ChallengeMember({
    required this.userId,
    required this.userName,
    this.avatarUrl,
    this.completionPct = 0,
    this.completed = false,
  });

  factory ChallengeMember.fromJson(Map<String, dynamic> json) {
    return ChallengeMember(
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? '',
      avatarUrl: json['avatar_url'],
      completionPct: (json['completion_pct'] as num?)?.toDouble() ?? 0,
      completed: json['completed'] == true,
    );
  }
}

// ─── Social Notification ────────────────────────────────────────────────────

class SocialNotification {
  final String id;
  final String notificationType;
  final String title;
  final String? body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  SocialNotification({
    required this.id,
    required this.notificationType,
    required this.title,
    this.body,
    this.data = const {},
    this.isRead = false,
    required this.createdAt,
  });

  factory SocialNotification.fromJson(Map<String, dynamic> json) {
    return SocialNotification(
      id: json['id'] ?? '',
      notificationType: json['notification_type'] ?? '',
      title: json['title'] ?? '',
      body: json['body'],
      data: (json['data'] as Map<String, dynamic>?) ?? const {},
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

// ─── User Search Result ─────────────────────────────────────────────────────

class UserSearchResult {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? connectionStatus; // null, pending, accepted

  UserSearchResult({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.connectionStatus,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['user_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      avatarUrl: json['avatar_url'],
      connectionStatus: json['connection_status'],
    );
  }
}

// ─── Report ────────────────────────────────────────────────────────────────

enum ReportReason {
  spam('spam', 'Spam or scam'),
  harassment('harassment', 'Harassment or bullying'),
  hateSpeech('hate_speech', 'Hate speech'),
  misinformation('misinformation', 'Health misinformation'),
  inappropriate('inappropriate', 'Inappropriate content'),
  impersonation('impersonation', 'Impersonation'),
  other('other', 'Other');

  final String value;
  final String label;
  const ReportReason(this.value, this.label);
}

enum ReportTargetType {
  feedEvent('feed_event'),
  comment('comment'),
  user('user'),
  poll('poll'),
  groupChat('group_chat'),
  chatMessage('chat_message');

  final String value;
  const ReportTargetType(this.value);
}

// ─── Blocked User ──────────────────────────────────────────────────────────

class BlockedUser {
  final String userId;
  final String name;
  final String? avatarUrl;
  final DateTime blockedAt;

  BlockedUser({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.blockedAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      avatarUrl: json['avatar_url'],
      blockedAt: DateTime.tryParse(json['blocked_at'] ?? '') ?? DateTime.now(),
    );
  }
}

// ─── Friend Streak ──────────────────────────────────────────────────────────

class FriendStreak {
  final String userId;
  final String name;
  final String? avatarUrl;
  final int streakDays;

  FriendStreak({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.streakDays = 0,
  });

  factory FriendStreak.fromJson(Map<String, dynamic> json) {
    return FriendStreak(
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      avatarUrl: json['avatar_url'],
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Community Pulse (Dashboard Widget) ─────────────────────────────────────

class CommunityPulse {
  final List<FriendStreak> friendStreaks;
  final List<FeedEvent> recentActivity;
  final int unreadCount;

  CommunityPulse({
    this.friendStreaks = const [],
    this.recentActivity = const [],
    this.unreadCount = 0,
  });

  factory CommunityPulse.fromJson(Map<String, dynamic> json) {
    return CommunityPulse(
      friendStreaks: (json['friend_streaks'] as List<dynamic>?)
              ?.map((s) => FriendStreak.fromJson(s as Map<String, dynamic>))
              .toList() ??
          const [],
      recentActivity: (json['recent_activity'] as List<dynamic>?)
              ?.map((e) => FeedEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Comment ──────────────────────────────────────────────────────────────

class Comment {
  final String id;
  final String feedEventId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String? parentId;
  final String text;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.feedEventId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    this.parentId,
    required this.text,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? '',
      feedEventId: json['feed_event_id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? '',
      userAvatarUrl: json['user_avatar_url'],
      parentId: json['parent_id'],
      text: json['text'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
