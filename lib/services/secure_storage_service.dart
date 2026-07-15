import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Authentication keys
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';
  static const String _passwordKey =
      'user_password'; // For offline login (optional)

  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
      debugPrint('🔐 Token saved securely');
    } catch (e) {
      debugPrint('❌ Error saving token: $e');
      rethrow;
    }
  }

  Future<String?> getToken() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      return token;
    } catch (e) {
      debugPrint('❌ Error reading token: $e');
      return null;
    }
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    try {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
      debugPrint('🔐 Refresh token saved securely');
    } catch (e) {
      debugPrint('❌ Error saving refresh token: $e');
      rethrow;
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      final refreshToken = await _storage.read(key: _refreshTokenKey);
      return refreshToken;
    } catch (e) {
      debugPrint('❌ Error reading refresh token: $e');
      return null;
    }
  }

  Future<void> saveUserData(String userDataJson) async {
    try {
      await _storage.write(key: _userDataKey, value: userDataJson);
      debugPrint('🔐 User data saved securely');
    } catch (e) {
      debugPrint('❌ Error saving user data: $e');
      rethrow;
    }
  }

  Future<String?> getUserData() async {
    try {
      final userData = await _storage.read(key: _userDataKey);
      return userData;
    } catch (e) {
      debugPrint('❌ Error reading user data: $e');
      return null;
    }
  }

  Future<void> savePassword(String password) async {
    try {
      await _storage.write(key: _passwordKey, value: password);
      debugPrint('🔐 Password saved securely');
    } catch (e) {
      debugPrint('❌ Error saving password: $e');
      rethrow;
    }
  }

  Future<String?> getPassword() async {
    try {
      final password = await _storage.read(key: _passwordKey);
      return password;
    } catch (e) {
      debugPrint('❌ Error reading password: $e');
      return null;
    }
  }

  Future<void> saveEncryptedData(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      debugPrint('🔐 Encrypted data saved: $key');
    } catch (e) {
      debugPrint('❌ Error saving encrypted data: $e');
      rethrow;
    }
  }

  Future<String?> getEncryptedData(String key) async {
    try {
      final value = await _storage.read(key: key);
      return value;
    } catch (e) {
      debugPrint('❌ Error reading encrypted data: $e');
      return null;
    }
  }

  Future<void> deleteData(String key) async {
    try {
      await _storage.delete(key: key);
      debugPrint('🗑️ Data deleted: $key');
    } catch (e) {
      debugPrint('❌ Error deleting data: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      debugPrint('🗑️ All secure data cleared');
    } catch (e) {
      debugPrint('❌ Error clearing secure data: $e');
    }
  }

  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      debugPrint('❌ Error checking for key: $e');
      return false;
    }
  }

  // Convenience methods for auth operations
  Future<void> clearAuthData() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _userDataKey);
      await _storage.delete(key: _passwordKey);
      debugPrint('🗑️ Auth data cleared');
    } catch (e) {
      debugPrint('❌ Error clearing auth data: $e');
    }
  }

  Future<bool> hasValidAuthData() async {
    final token = await getToken();
    final userData = await getUserData();
    return token != null && userData != null;
  }

  // Check if secure storage is available
  Future<bool> isAvailable() async {
    try {
      await _storage.write(key: 'test', value: 'test');
      await _storage.delete(key: 'test');
      return true;
    } catch (e) {
      debugPrint('❌ Secure storage not available: $e');
      return false;
    }
  }

  // Get all keys (for debugging)
  Future<Map<String, String>> getAllKeys() async {
    try {
      final allData = await _storage.readAll();
      return allData;
    } catch (e) {
      debugPrint('❌ Error reading all keys: $e');
      return {};
    }
  }
}
