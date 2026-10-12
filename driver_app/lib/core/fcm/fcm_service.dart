import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';

/// A single FCM event that reached this app instance.
class FcmEvent {
  final String type;
  final int? relatedId;
  final int? notificationId;
  final String? title;
  final String? body;

  const FcmEvent._({
    required this.type,
    this.relatedId,
    this.notificationId,
    this.title,
    this.body,
  });

  /// Parses a Firebase remote message into a typed event, or null when the
  /// payload carries nothing actionable for the UI.
  static FcmEvent? fromMessage(RemoteMessage message) {
    final type = (message.data['type'] ?? '').toString();
    if (type.isEmpty && message.notification == null) return null;
    return FcmEvent._(
      type: type,
      relatedId: int.tryParse((message.data['related_id'] ?? '').toString()),
      notificationId: int.tryParse((message.data['notification_id'] ?? '').toString()),
      title: message.notification?.title ?? (message.data['title'] ?? '').toString(),
      body: message.notification?.body ?? (message.data['body'] ?? '').toString(),
    );
  }
}

/// Surfaces a foreground FCM message in the system tray. Background and
/// terminated pushes are already shown by FCM itself, so this only matters
/// while the app is open and on-screen.
class ForegroundTray {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    try {
      const settings = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: settings));
    } catch (_) {
      // Notification display is best-effort and must never break app startup.
    }
  }

  static Future<void> show(RemoteMessage message) async {
    final event = FcmEvent.fromMessage(message);
    final title = event?.title;
    if (event == null || title == null || title.isEmpty) return;
    try {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        event.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'goride_messages',
            'رسائل خط سيري',
            channelDescription: 'إشعارات الطلبات والرسائل',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {
      // Never crash the app because an alert could not render.
    }
  }
}

@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  // Background / terminated pushes are already surfaced in the system tray
  // by FCM; the foreground listeners below handle in-app refresh.
}

/// Thin, failure-safe wrapper around Firebase Cloud Messaging.
///
/// Requires either `android/app/google-services.json` (FlutterFire default
/// setup) or a fully populated [FirebaseOptions] map passed to [initialize].
/// When neither is available the service stays disabled and the rest of the
/// app works exactly as before (in-app notifications only).
class FcmService {
  static bool _ready = false;
  static bool _attempted = false;

  static final StreamController<FcmEvent> _events = StreamController<FcmEvent>.broadcast();

  /// Broadcast stream of FCM events surfaced while the app runs (foreground
  /// messages, background tap, cold-start tap).
  static Stream<FcmEvent> get onEvent => _events.stream;

  static bool get isReady => _ready;

  static Future<bool> initialize({FirebaseOptions? options}) async {
    if (_attempted) return _ready;
    _attempted = true;
    try {
      await ForegroundTray.init();
      await Firebase.initializeApp(options: options);
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      _ready = true;

      FirebaseMessaging.onMessage.listen((message) {
        unawaited(ForegroundTray.show(message));
        _dispatch(message);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) => _dispatch(message));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _dispatch(initial);
      FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  static void _dispatch(RemoteMessage message) {
    final event = FcmEvent.fromMessage(message);
    if (event != null) _events.add(event);
  }

  /// Requests notification permission and returns the FCM token, or null.
  static Future<String?> currentToken() async {
    if (!_ready) return null;
    try {
      await FirebaseMessaging.instance.requestPermission();
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Stream of FCM tokens refreshed while the app runs.
  static Stream<String> get onTokenRefresh => _ready
      ? FirebaseMessaging.instance.onTokenRefresh
      : const Stream<String>.empty();

  /// Registers the current FCM token (and a stable device id) with the API.
  static Future<void> registerWithApi() async {
    final token = await currentToken();
    if (token == null || token.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('fcm_device_id');
    if (deviceId == null) {
      final rand = Random();
      deviceId = '${DateTime.now().microsecondsSinceEpoch}-${rand.nextInt(1 << 31)}';
      await prefs.setString('fcm_device_id', deviceId);
    }

    try {
      await ApiClient.instance.post('/auth/update-push-token', data: {
        'token': token,
        'platform': 'android',
        'device_id': deviceId,
      });
    } catch (e) {
      debugPrint('FcmService: failed to register push token: $e');
    }
  }
}