import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class AppConfig {
  // Returns a runtime base URL that works on mobile emulators/devices.
  // - Web and macOS use localhost
  // - Android emulator should use 10.0.2.2 to reach host machine
  // - Fallback to localhost otherwise
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    } catch (_) {}
    return 'http://localhost:3000';
  }

  static String get socketUrl {
    if (kIsWeb) return 'http://localhost:3000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    } catch (_) {}
    return 'http://localhost:3000';
  }

  static const String socketNamespace = '/socket';

  static const String tokenKey = 'jwt_token';
  static const String userKey = 'user_data';
  static const String hiddenStatusesKey = 'hidden_statuses';

  // Pagination
  static const int defaultPageSize = 20;
}
