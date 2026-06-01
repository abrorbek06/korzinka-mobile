import 'package:flutter/foundation.dart';
import '../services/notifications_api.dart';
import '../services/notification_service.dart';

class NotificationsProvider extends ChangeNotifier {
  int _unreadCount = 0;
  bool _loading = false;
  String? _token;

  int get unreadCount => _unreadCount;
  bool get loading => _loading;

  Future<void> init(String token) async {
    _token = token;
    NotificationService.instance.onForegroundMessage = refreshCount;
    await refreshCount();
  }

  Future<void> refreshCount() async {
    if (_token == null) return;
    _loading = true;
    notifyListeners();

    try {
      final count = await NotificationsApi.fetchUnreadCount(_token!);
      _unreadCount = count;
    } catch (_) {
      // Ignore failures; keep the last known count.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
