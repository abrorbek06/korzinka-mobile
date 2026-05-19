import 'dart:convert';

class PickerUser {
  final String id;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final bool isActive;

  const PickerUser({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
    required this.isActive,
  });

  String get displayName => fullName ?? username;
  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : 'P';
  }

  factory PickerUser.fromJson(Map<String, dynamic> json) => PickerUser(
        id: json['id'] as String,
        username: json['username'] as String,
        fullName: json['fullName'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        isActive: json['isActive'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'fullName': fullName,
        'avatarUrl': avatarUrl,
        'isActive': isActive,
      };

  String toJsonString() => jsonEncode(toJson());
  static PickerUser fromJsonString(String s) =>
      PickerUser.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
