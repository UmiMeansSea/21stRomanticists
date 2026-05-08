import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised in main.dart before this is called.
  debugPrint('[FCM] Background message: ${message.messageId}');
}

/// Wraps Firebase Messaging and local notifications setup.
///
/// Call [init] once in main.dart after Firebase.initializeApp().
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'romanticists_main';
  static const _channelName = 'Romanticists Notifications';

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (Android 13+ / iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // Android local notification channel
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Submission updates and literary announcements.',
      importance: Importance.high,
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Init local plugin
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(initSettings);

    // Show foreground notifications as heads-up
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_onForeground);
  }

  // ─── Token management ─────────────────────────────────────────────────────

  /// Returns the current FCM token, or null if unavailable.
  Future<String?> getToken() => _messaging.getToken();

  /// Saves the FCM token for [uid] to Firestore so the backend can target
  /// push notifications at specific users.
  Future<void> saveToken(String uid) async {
    final token = await getToken();
    if (token == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tokens')
          .doc(token)
          .set({
        'token': token,
        'updatedAt': FieldValue.serverTimestamp(),
        'platform': 'android',
      });
      debugPrint('[FCM] Token saved for user $uid');

      // Also listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        saveToken(uid);
      });
    } catch (e) {
      debugPrint('[FCM] Failed to save token: $e');
    }
  }

  /// Removes the token from Firestore on sign-out.
  Future<void> removeToken(String uid) async {
    final token = await getToken();
    if (token == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tokens')
          .doc(token)
          .delete();
    } catch (_) {}
  }

  // ─── Foreground handler ───────────────────────────────────────────────────

  void _onForeground(RemoteMessage message) {
    debugPrint('[FCM] Foreground message: ${message.notification?.title}');
    final notification = message.notification;
    final android = message.notification?.android;
    if (notification == null) return;

    _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Submission updates and literary announcements.',
          importance: Importance.high,
          priority: Priority.high,
          icon: android?.smallIcon ?? '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
