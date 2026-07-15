import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:korzinkab_mobile/utils/snackbar_utils.dart';
import '../config/app_config.dart';
import '../utils/app_keys.dart';

// Background handler must be a top-level function
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Optionally handle background message (could show local notification)
  // For brevity we won't show a local notification here; the OS will deliver the push.
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  String? _authToken;
  String? _deviceToken;
  Future<void> Function()? onForegroundMessage;

  static Future<void> initialize() async {
    // Initialize Firebase
    await Firebase.initializeApp();

    // Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize local notifications for foreground display
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await instance._local.initialize(settings: initSettings);

    // Request permissions on iOS
    if (!kIsWeb) {
      await instance._fm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Foreground message handling
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      if (notification != null) {
        // Show system/local notification
        await instance._showLocalNotification(
          notification.title,
          notification.body,
        );

        // Also show an in-app top message when the app is in foreground.
        // Use the global ScaffoldMessengerState context to insert a top overlay.
        final messenger = AppKeys.scaffoldMessengerKey.currentState;
        if (messenger != null) {
          final contentText =
              (notification.title != null &&
                  (notification.body?.isNotEmpty ?? false))
              ? '${notification.title}\n${notification.body}'
              : (notification.body ?? notification.title ?? '');
          messenger.context.showTopMessage(
            contentText,
            backgroundColor: const Color(0xFF2DD06F),
          );
        }

        // Refresh unread badge count when a foreground notification arrives.
        instance.onForegroundMessage?.call();
      }
    });

    // Token handling
    instance._deviceToken = await instance._fm.getToken();
    instance._fm.onTokenRefresh.listen((t) => instance._handleNewToken(t));
  }

  Future<void> _showLocalNotification(String? title, String? body) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'General',
      channelDescription: 'General notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const platform = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _local.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: platform,
    );
  }

  void _handleNewToken(String token) {
    _deviceToken = token;
    _tryRegisterDevice();
  }

  void setAuthToken(String? token) {
    _authToken = token;
    _tryRegisterDevice();
  }

  Future<void> _tryRegisterDevice() async {
    if (_authToken == null || _deviceToken == null) return;
    final url = Uri.parse('${AppConfig.baseUrl}/notifications/devices');
    final body = jsonEncode({
      'token': _deviceToken,
      'platform': defaultTargetPlatformIsIOS() ? 'ios' : 'android',
    });
    try {
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: body,
      );
    } catch (_) {
      // ignore network errors silently; will retry on next token/auth change
    }
  }

  bool defaultTargetPlatformIsIOS() {
    try {
      return defaultTargetPlatform == TargetPlatform.iOS;
    } catch (_) {
      return false;
    }
  }
}
