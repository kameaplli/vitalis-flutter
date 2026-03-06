import 'family_member.dart';

class UserProfile {
  final int? age;
  final String? gender;
  final double? height;
  final List<FamilyMember> children;

  UserProfile({this.age, this.gender, this.height, this.children = const []});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      age: json['age'],
      gender: json['gender'],
      height: (json['height'] as num?)?.toDouble(),
      children: (json['children'] as List<dynamic>? ?? [])
          .map((c) => FamilyMember.fromJson(c))
          .toList(),
    );
  }
}

class AppUser {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final int? age;
  final String? gender;
  final double? height;
  final UserProfile profile;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.age,
    this.gender,
    this.height,
    required this.profile,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final profileData = json['profile'] ?? {};
    return AppUser(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      avatarUrl: json['avatar_url'],
      age: json['age'],
      gender: json['gender'],
      height: (json['height'] as num?)?.toDouble(),
      profile: UserProfile.fromJson(profileData),
    );
  }

  AppUser copyWith({
    String? name,
    String? avatarUrl,
    int? age,
    String? gender,
    double? height,
    UserProfile? profile,
  }) {
    return AppUser(
      id: id,
      email: email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      profile: profile ?? this.profile,
    );
  }
}
