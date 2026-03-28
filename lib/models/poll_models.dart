class Poll {
  final String id;
  final String creatorId;
  final String creatorName;
  final String? creatorAvatarUrl;
  final String question;
  final List<PollOption> options;
  final PollAccess access;
  final int totalVotes;
  final String? userVoteOptionId; // null if user hasn't voted
  final bool isExpired;
  final DateTime expiresAt;
  final DateTime createdAt;

  Poll({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    this.creatorAvatarUrl,
    required this.question,
    required this.options,
    this.access = PollAccess.public_,
    this.totalVotes = 0,
    this.userVoteOptionId,
    this.isExpired = false,
    required this.expiresAt,
    required this.createdAt,
  });

  bool get hasVoted => userVoteOptionId != null;
  bool get isActive => !isExpired && DateTime.now().isBefore(expiresAt);

  factory Poll.fromJson(Map<String, dynamic> json) {
    return Poll(
      id: json['id'] ?? '',
      creatorId: json['creator_id'] ?? '',
      creatorName: json['creator_name'] ?? '',
      creatorAvatarUrl: json['creator_avatar_url'],
      question: json['question'] ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((o) => PollOption.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
      access: PollAccess.fromString(json['access'] ?? 'public'),
      totalVotes: (json['total_votes'] as num?)?.toInt() ?? 0,
      userVoteOptionId: json['user_vote_option_id'],
      isExpired: json['is_expired'] == true,
      expiresAt: DateTime.tryParse(json['expires_at'] ?? '') ??
          DateTime.now().add(const Duration(days: 7)),
      createdAt:
          DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'creator_id': creatorId,
        'creator_name': creatorName,
        'creator_avatar_url': creatorAvatarUrl,
        'question': question,
        'options': options.map((o) => o.toJson()).toList(),
        'access': access.value,
        'total_votes': totalVotes,
        'user_vote_option_id': userVoteOptionId,
        'is_expired': isExpired,
        'expires_at': expiresAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  Poll copyWith({
    String? userVoteOptionId,
    int? totalVotes,
    List<PollOption>? options,
    bool? isExpired,
  }) {
    return Poll(
      id: id,
      creatorId: creatorId,
      creatorName: creatorName,
      creatorAvatarUrl: creatorAvatarUrl,
      question: question,
      options: options ?? this.options,
      access: access,
      totalVotes: totalVotes ?? this.totalVotes,
      userVoteOptionId: userVoteOptionId ?? this.userVoteOptionId,
      isExpired: isExpired ?? this.isExpired,
      expiresAt: expiresAt,
      createdAt: createdAt,
    );
  }
}

class PollOption {
  final String id;
  final String text;
  final int voteCount;
  final double percentage; // 0.0 - 1.0

  PollOption({
    required this.id,
    required this.text,
    this.voteCount = 0,
    this.percentage = 0.0,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  PollOption copyWith({int? voteCount, double? percentage}) => PollOption(
        id: id,
        text: text,
        voteCount: voteCount ?? this.voteCount,
        percentage: percentage ?? this.percentage,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'vote_count': voteCount,
        'percentage': percentage,
      };
}

enum PollAccess {
  public_('public'),
  inviteOnly('invite_only');

  final String value;
  const PollAccess(this.value);

  static PollAccess fromString(String s) {
    if (s == 'invite_only') return PollAccess.inviteOnly;
    return PollAccess.public_;
  }

  String get label => switch (this) {
        PollAccess.public_ => 'Public',
        PollAccess.inviteOnly => 'Invite Only',
      };
}
