import 'dart:convert';

enum UserRole {
  ADMIN,
  STORE_MANAGER,
  SALES_MANAGER,
  SCM,
  PICKER,
  ACCOUNTANT,
  BASIC;

  String get displayName {
    switch (this) {
      case ADMIN:
        return 'Admin';
      case STORE_MANAGER:
        return 'Store Manager';
      case SALES_MANAGER:
        return 'Sales Manager';
      case SCM:
        return 'SCM';
      case PICKER:
        return 'Picker';
      case ACCOUNTANT:
        return 'Accountant';
      case BASIC:
        return 'Basic';
    }
  }

  bool get canCreateOrders => this != PICKER && this != BASIC;

  bool get canManageTransitions =>
      this == ADMIN || this == STORE_MANAGER || this == SALES_MANAGER || this == SCM;
}

class AuthenticatedUser {
  final String id;
  final String username;
  final String? email;
  final UserRole role;
  final bool isActive;
  final String? branchId;

  const AuthenticatedUser({
    required this.id,
    required this.username,
    this.email,
    required this.role,
    required this.isActive,
    this.branchId,
  });

  factory AuthenticatedUser.fromJson(Map<String, dynamic> json) {
    // Handle role being either a string or a list (e.g., ["ADMIN"])
    String? roleString;
    final role = json['role'];
    if (role is String) {
      roleString = role;
    } else if (role is List && role.isNotEmpty) {
      roleString = role.first.toString();
    }

    return AuthenticatedUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString(),
      role: UserRole.values.firstWhere(
        (r) => r.name.toLowerCase() == roleString?.toLowerCase(),
        orElse: () => UserRole.BASIC,
      ),
      isActive: json['isActive'] as bool? ?? true,
      branchId: json['branchId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'role': role.name,
        'isActive': isActive,
        'branchId': branchId,
      };

  String toJsonString() => jsonEncode(toJson());

  static AuthenticatedUser fromJsonString(String str) =>
      AuthenticatedUser.fromJson(jsonDecode(str) as Map<String, dynamic>);
}
