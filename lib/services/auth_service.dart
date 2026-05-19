import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/user_model.dart';

class AuthService {
  final String _baseUrl = AppConfig.baseUrl;

  Future<({String accessToken, AuthenticatedUser user})> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Handle accessToken being either a string or a list
      String accessTokenString;
      final accessToken = data['accessToken'];
      if (accessToken is String) {
        accessTokenString = accessToken;
      } else if (accessToken is List && accessToken.isNotEmpty) {
        accessTokenString = accessToken.first.toString();
      } else {
        accessTokenString = '';
      }

      return (
        accessToken: accessTokenString,
        user: AuthenticatedUser.fromJson(data['user'] as Map<String, dynamic>),
      );
    } else if (response.statusCode == 401) {
      throw AuthException('Invalid username or password.');
    } else {
      throw AuthException('Login failed. Please try again.');
    }
  }

  Future<AuthenticatedUser> getMe(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return AuthenticatedUser.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else if (response.statusCode == 401) {
      throw AuthException('Session expired. Please log in again.');
    } else {
      throw AuthException('Failed to fetch user profile.');
    }
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
