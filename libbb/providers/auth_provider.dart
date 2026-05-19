import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

enum AuthState { initial, loading, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final _service = AuthService();

  AuthState _state = AuthState.initial;
  PickerUser? _user;
  String? _token;
  String? _error;

  AuthState get state => _state;
  PickerUser? get user => _user;
  String? get token => _token;
  String? get error => _error;
  bool get isAuth => _state == AuthState.authenticated;

  Future<void> restore() async {
    _set(AuthState.loading);
    try {
      final p = await SharedPreferences.getInstance();
      final t = p.getString(AppConfig.tokenKey);
      final u = p.getString(AppConfig.userKey);
      if (t == null || u == null) return _set(AuthState.unauthenticated);
      _user = await _service.getMe(t);
      _token = t;
      _set(AuthState.authenticated);
    } catch (_) {
      await _clear();
      _set(AuthState.unauthenticated);
    }
  }

  Future<bool> login(String username, String password) async {
    _error = null;
    _set(AuthState.loading);
    try {
      final r = await _service.login(username, password);
      _token = r.token;
      _user = r.user;
      final p = await SharedPreferences.getInstance();
      await p.setString(AppConfig.tokenKey, _token!);
      await p.setString(AppConfig.userKey, _user!.toJsonString());
      _set(AuthState.authenticated);
      return true;
    } on AppException catch (e) {
      _error = e.message;
      _set(AuthState.unauthenticated);
      return false;
    } catch (_) {
      _error = AppStrings.networkError;
      _set(AuthState.unauthenticated);
      return false;
    }
  }

  Future<void> logout() async {
    await _clear();
    _set(AuthState.unauthenticated);
  }

  Future<void> _clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(AppConfig.tokenKey);
    await p.remove(AppConfig.userKey);
    _token = null;
    _user = null;
  }

  void _set(AuthState s) {
    _state = s;
    notifyListeners();
  }
}
