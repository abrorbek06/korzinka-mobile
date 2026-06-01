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

  factory PickerUser.fromJson(Map<String, dynamic> json) {
    String? parseString(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        final trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      if (value is num) return value.toString();
      if (value is List && value.isNotEmpty) {
        return value.first.toString();
      }
      return null;
    }

    return PickerUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: parseString(json['fullName']),
      avatarUrl: parseString(json['avatarUrl']),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

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
