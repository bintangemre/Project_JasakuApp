import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';

class FcmManager {
  static final FcmManager _instance = FcmManager._();
  factory FcmManager() => _instance;
  FcmManager._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();
  final _dio = ApiClient().dio;

  static Future<void> handleBackgroundMessage(RemoteMessage message) async {}

  Future<void> initialize() async {
    await _requestPermission();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotif.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    final token = await _messaging.getToken();
    if (token != null) {
      await _registerDevice(token);
    }

    _messaging.onTokenRefresh.listen(_registerDevice);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTapMessage);
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
        'deviceType': 'android',
      });
    } catch (_) {}
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? 'Jasaku';
    final body = message.notification?.body ?? '';
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
      payload: message.data['orderId'],
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    final orderId = response.payload;
    if (orderId != null) {
      _navigateToOrder(orderId);
    }
  }

  void _onNotificationTapMessage(RemoteMessage message) {
    final orderId = message.data['orderId'];
    if (orderId != null) {
      _navigateToOrder(orderId);
    }
  }

  void _navigateToOrder(String orderId) {}
}
