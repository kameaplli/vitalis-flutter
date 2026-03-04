class FamilyMember {
  final String id;
  final String name;
  final int? age;
  final String? gender;
  final String? allergies;
  final double? height;
  final String? avatarUrl;

  FamilyMember({
    required this.id,
    required this.name,
    this.age,
    this.gender,
    this.allergies,
    this.height,
    this.avatarUrl,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      age: json['age'],
      gender: json['gender'],
      allergies: json['allergies'],
      height: (json['height'] as num?)?.toDouble(),
      avatarUrl: json['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'age': age,
    'gender': gender,
    'allergies': allergies,
    'height': height,
    'avatar_url': avatarUrl,
  };
}
