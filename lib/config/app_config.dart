import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'dart:developer' as developer;

class AppConfig {
  static const bool enableLogging = true;

  static void log(
    String message, {
    String name = 'APP',
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!enableLogging) return;

    // developer.log IDE ning Debug Console'da chiroyli chiqadi
    developer.log(message, name: name, error: error, stackTrace: stackTrace);

    // Terminalda (flutter run) ko'rinishi uchun
    if (kDebugMode) {
      debugPrint('[$name] $message');
      if (error != null) debugPrint('Error: $error');
    }
  }

  // https://korzinka-backend.mock-ielts.uz
  // https://korzinka-backend.mock-ielts.uz

  // Returns a runtime base URL that works on mobile emulators/devices.
  // - Web and macOS use localhost
  // - Android emulator should use 10.0.2.2 to reach host machine
  // - Fallback to localhost otherwise
  static String get baseUrl {
    if (kIsWeb) return 'https://korzinka-backend.mock-ielts.uz';
    try {
      if (Platform.isAndroid) return 'https://korzinka-backend.mock-ielts.uz';
    } catch (_) {}
    return 'https://korzinka-backend.mock-ielts.uz';
  }

  static String get socketUrl {
    if (kIsWeb) return 'https://korzinka-backend.mock-ielts.uz';
    try {
      if (Platform.isAndroid) return 'https://korzinka-backend.mock-ielts.uz';
    } catch (_) {}
    return 'https://korzinka-backend.mock-ielts.uz';
  }

  static const String socketNamespace = '/socket';

  static const String tokenKey = 'jwt_token';
  static const String userKey = 'user_data';
  static const String hiddenStatusesKey = 'hidden_statuses';
  static const String statusChangeMethodKey = 'status_change_method_dropdown';

  // Pagination
  static const int defaultPageSize = 20;

  static VoidCallback? onUnauthorized;

  static void logout() {
    if (onUnauthorized != null) {
      onUnauthorized!();
    }
  }
}
