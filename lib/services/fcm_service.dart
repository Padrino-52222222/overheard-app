import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final plugin = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(const InitializationSettings(android: android));
  final n = message.notification;
  if (n == null) return;
  const channel = AndroidNotificationChannel(
    'heardover_channel',
    'HeardOver Bildirimleri',
    importance: Importance.high,
  );
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  await plugin.show(
    n.hashCode,
    n.title,
    n.body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'heardover_channel',
        'HeardOver Bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
}

class FcmService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // İzin iste
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Bildirim kanalı oluştur
    const channel = AndroidNotificationChannel(
      'heardover_channel',
      'HeardOver Bildirimleri',
      description: 'Arkadaşlık istekleri, beğeniler ve paylaşımlar',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Local notifications başlat
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(initSettings);

    // Arka plan handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Uygulama açıkken gelen bildirim
    FirebaseMessaging.onMessage.listen((message) async {
      final n = message.notification;
      if (n == null) return;
      await _localNotifications.show(
        n.hashCode,
        n.title,
        n.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'heardover_channel',
            'HeardOver Bildirimleri',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    });

    // Token kaydet
    await _saveToken();
    _messaging.onTokenRefresh.listen(_updateToken);
  }

  // Giriş sonrası token güncelle
  static Future<void> updateTokenAfterLogin() async {
    await _saveToken();
  }

  static Future<void> _saveToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
      }
    } catch (_) {}
  }

  static Future<void> _updateToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': token});
    } catch (_) {}
  }
}