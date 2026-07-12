import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../firebase/firebase_options.dart';


class FcmManager {
  static final FcmManager _instance = FcmManager._();
  factory FcmManager() => _instance;
  FcmManager._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();
  final _dio = ApiClient().dio;

  static void Function(String type, Map<String, String> data)? onNotificationTap;
  static void Function(RemoteMessage message)? onForegroundMessage;

  @pragma('vm:entry-point')
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {}
  }

  Future<void> initialize() async {
    await _requestPermission();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotif.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);

    final token = await _messaging.getToken();
    if (token != null) {
      await _registerDevice(token);
    }

    _messaging.onTokenRefresh.listen(_registerDevice);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTapMessage);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(seconds: 2), () {
        _onNotificationTapMessage(initialMessage);
      });
    }
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _registerDevice(String token) async {
    try {
      await _dio.post(ApiEndpoints.registerDevice, data: {
        'fcmToken': token,
        'deviceType': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
    } catch (_) {}
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? 'Jasaku';
    final body = message.notification?.body ?? '';
    final data = message.data;
    final payload = jsonEncode(data);

    const androidDetails = AndroidNotificationDetails(
      'jasaku_channel',
      'Jasaku Notifications',
      channelDescription: 'Notifikasi Jasaku',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: payload,
    );

    FcmManager.onForegroundMessage?.call(message);
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = Map<String, String>.from(
        jsonDecode(response.payload!) as Map,
      );
      _handleNotificationTap(data);
    } catch (_) {}
  }

  void _onNotificationTapMessage(RemoteMessage message) {
    final data = Map<String, String>.from(message.data);
    _handleNotificationTap(data);
  }

  void _handleNotificationTap(Map<String, String> data) {
    final type = data['type'] ?? '';
    onNotificationTap?.call(type, data);
  }
}
