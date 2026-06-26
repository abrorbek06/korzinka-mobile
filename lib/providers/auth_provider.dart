import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthState { initial, loading, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    // AppConfig dagi signalni AuthProvider.logout() ga bog'laymiz
    AppConfig.onUnauthorized = () {
      logout();
    };
  }
  final AuthService _authService = AuthService();

  AuthState _state = AuthState.initial;
  AuthenticatedUser? _user;
  String? _token;
  String? _error;

  AuthState get state => _state;
  AuthenticatedUser? get user => _user;
  String? get token => _token;
  String? get error => _error;
  bool get isAuthenticated =>
      _state == AuthState.authenticated && _token != null;

  Future<void> tryRestoreSession() async {
    _setState(AuthState.loading);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(AppConfig.tokenKey);
      final savedUser = prefs.getString(AppConfig.userKey);

      if (savedToken == null || savedUser == null) {
        _setState(AuthState.unauthenticated);
        return;
      }

      // Try to verify token is still valid, but don't fail on network errors
      try {
        final user = await _authService.getMe(savedToken);
        _token = savedToken;
        _user = user;
      } catch (_) {
        // If verification fails (network error, server down, etc.),
        // still restore session with stored data. Token will be validated on next API call.
        _token = savedToken;
        _user = AuthenticatedUser.fromJsonString(savedUser);
      }
      _setState(AuthState.authenticated);
    } catch (_) {
      await _clearSession();
      _setState(AuthState.unauthenticated);
    }
  }

  Future<bool> login(String username, String password) async {
    _error = null;
    _setState(AuthState.loading);
    try {
      final result = await _authService.login(
        username: username,
        password: password,
      );
      _token = result.accessToken;
      _user = result.user;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConfig.tokenKey, _token!);
      await prefs.setString(AppConfig.userKey, _user!.toJsonString());

      _setState(AuthState.authenticated);
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _setState(AuthState.unauthenticated);
      return false;
    } catch (_) {
      _error = 'Network error. Please check your connection.';
      _setState(AuthState.unauthenticated);
      return false;
    }
  }

  Future<void> logout() async {
    await _clearSession();
    _setState(AuthState.unauthenticated);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.tokenKey);
    await prefs.remove(AppConfig.userKey);
    _token = null;
    _user = null;
  }

  void _setState(AuthState state) {
    _state = state;
    notifyListeners();
  }
}
