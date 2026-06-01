import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class NotificationItem {
  final String id; // recipient id
  final String notificationId;
  final String type;
  final String entityType;
  final String entityId;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.notificationId,
    required this.type,
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> j) {
    return NotificationItem(
      id: j['id'].toString(),
      notificationId: j['notificationId'].toString(),
      type: j['type'] ?? '',
      entityType: j['entityType'] ?? '',
      entityId: j['entityId']?.toString() ?? '',
      title: j['title'] ?? '',
      body: j['body'] ?? '',
      createdAt: DateTime.parse(j['createdAt']),
      isRead: j['readAt'] != null,
    );
  }
}

class NotificationsApi {
  static Future<List<NotificationItem>> fetchNotifications(String token,
      {int page = 1, int limit = 50}) async {
    final url = Uri.parse('${AppConfig.baseUrl}/notifications?page=$page&limit=$limit');
    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });
    if (res.statusCode != 200) throw Exception('Failed to load notifications');
    final body = jsonDecode(res.body);
    final data = body['data'] as List<dynamic>;
    return data.map((e) => NotificationItem.fromJson(e)).toList();
  }

  static Future<int> fetchUnreadCount(String token) async {
    final url = Uri.parse('${AppConfig.baseUrl}/notifications/unread-count');
    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });
    if (res.statusCode != 200) throw Exception('Failed to load unread count');
    final body = jsonDecode(res.body);
    return body['unreadCount'] as int? ?? 0;
  }

  static Future<void> markRead(String token, String recipientId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/notifications/$recipientId/read');
    final res = await http.patch(url, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });
    if (res.statusCode != 200) throw Exception('Failed to mark read');
  }
}
