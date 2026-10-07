import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import '../main.dart';
import 'package:app_badge_plus/app_badge_plus.dart';

class PushService {
  final ApiClient _apiClient;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  PushService(this._apiClient);

  bool get _isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> initLocalNotifications() async {
    if (_isInitialized) return;

    // Reset badge count on startup
    try {
      if (await AppBadgePlus.isSupported()) {
        AppBadgePlus.updateBadge(0);
      }
    } catch (_) {}

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    try {
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) {
            try {
              final Map<String, dynamic> data = Map<String, dynamic>.from(jsonDecode(response.payload!));
              handleNotificationNavigation(data);
            } catch (e) {
              debugPrint('Ошибка навигации из локального уведомления: $e');
            }
          }
        },
      );
    } catch (e) {
      debugPrint('Local notifications init error: $e');
    }

    if (_isFirebaseAvailable) {
      try {
        // Слушаем уведомления в foreground (когда приложение открыто)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final title = message.notification?.title ?? message.data['title'] ?? message.data['message_title'];
          final body = message.notification?.body ?? message.data['body'] ?? message.data['message_body'] ?? message.data['message'];
          
          // Update badge count from push if available
          final badgeStr = message.data['badge'] ?? message.data['unread_count'];
          if (badgeStr != null) {
            final badgeVal = int.tryParse(badgeStr.toString());
            if (badgeVal != null) {
              updateBadgeCount(badgeVal);
            }
          }

          // In foreground, always display local notification so user sees the incoming notification
          if (title != null || body != null) {
            _showLocalNotification(
              title: title ?? 'Новое уведомление',
              body: body ?? '',
              data: message.data,
            );
          }
        });
      } catch (e) {
        debugPrint('Firebase messaging listener setup error: $e');
      }
    }

    _isInitialized = true;
  }

  Future<void> updateBadgeCount(int count) async {
    try {
      if (await AppBadgePlus.isSupported()) {
        AppBadgePlus.updateBadge(count);
      }
    } catch (_) {}
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final muteUntil = prefs.getInt('mute_notifications_until') ?? 0;
      if (DateTime.now().millisecondsSinceEpoch < muteUntil) {
        debugPrint('Notifications are currently muted. Skipping local notification.');
        return;
      }
    } catch (e) {
      debugPrint('Error reading mute settings: $e');
    }

    const androidDetails = AndroidNotificationDetails(
      'main_channel',
      'Основной канал',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    try {
      await _localNotifications.show(
        id: title.hashCode ^ body.hashCode,
        title: title,
        body: body,
        notificationDetails: details,
        payload: jsonEncode(data),
      );
    } catch (e) {
      debugPrint('Show local notification error: $e');
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid) return;
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  Future<String?> registerToken() async {
    try {
      await initLocalNotifications();
      if (!_isFirebaseAvailable) return null;

      await _requestNotificationPermission();

      await FirebaseMessaging.instance.requestPermission();
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return null;

      final platform = Platform.isIOS ? 'ios' : 'android';

      await _apiClient.dio.post('/device-tokens', data: {
        'token': fcmToken,
        'platform': platform,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', fcmToken);

      return fcmToken;
    } catch (e) {
      debugPrint('Firebase token registration skipped or failed: $e');
      return null;
    }
  }

  Future<void> unregisterToken() async {
    try {
      if (!_isFirebaseAvailable) return;
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await _apiClient.dio.delete('/device-tokens/$fcmToken');
      }
    } catch (e) {
      debugPrint('Firebase token unregistration error: $e');
    }
  }
}
