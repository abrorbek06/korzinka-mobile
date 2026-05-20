import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class PickerUser {
  final String id;
  final String username;
  final String name;
  final int activeAssignmentsCount;

  const PickerUser({
    required this.id,
    required this.username,
    required this.name,
    required this.activeAssignmentsCount,
  });

  factory PickerUser.fromJson(Map<String, dynamic> json) {
    // Handle name being either a string or a list
    String? nameString;
    final name = json['name'];
    if (name is String) {
      nameString = name;
    } else if (name is List && name.isNotEmpty) {
      nameString = name.first.toString();
    }

    return PickerUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      name: nameString ?? json['username']?.toString() ?? '',
      activeAssignmentsCount: json['activeAssignmentsCount'] as int? ?? 0,
    );
  }
}

class UsersService {
  final String _baseUrl = AppConfig.baseUrl;
  final String token;

  UsersService({required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<List<PickerUser>> getPickers({String? branchId}) async {
    final query = <String, String>{};
    if (branchId != null) {
      query['branchId'] = branchId;
    }

    final uri = Uri.parse(
      '$_baseUrl/users/pickers',
    ).replace(queryParameters: query);
    print('[UsersService] Fetching pickers from: ${uri.toString()}');

    late http.Response response;
    try {
      response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException catch (_) {
      throw ApiException('Request timed out', 504);
    }

    print('[UsersService] response status: ${response.statusCode}');
    print('[UsersService] raw response: ${response.body}');

    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
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

      final message =
          parseString(body?['message']) ??
          'Request failed (${response.statusCode})';
      throw ApiException(message, response.statusCode);
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (e) {
      print('[UsersService] Failed to decode JSON: $e');
      rethrow;
    }

    List<dynamic> rawItems = [];
    if (decoded is List) {
      rawItems = decoded;
    } else if (decoded is Map<String, dynamic>) {
      rawItems = (decoded['data'] ?? decoded['items'] ?? []) as List<dynamic>;
    }

    final pickers = <PickerUser>[];
    for (final j in rawItems) {
      try {
        pickers.add(PickerUser.fromJson(j as Map<String, dynamic>));
      } catch (e) {
        print('[UsersService] Failed to parse picker: $j');
        print(e);
      }
    }

    return pickers;
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  const ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
