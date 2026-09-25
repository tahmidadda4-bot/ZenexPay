import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../firebase_options.dart';
import '../main.dart' show rootNavigatorKey;
import '../screens/notifications_page.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Notification payloads are displayed by Android/FCM while the app is in
  // the background or terminated. Data-only messages can be handled here.
}

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'zenexpay_high_importance',
    'ZenexPay Notifications',
    description: 'Important ZenexPay account, task and wallet updates.',
    importance: Importance.max,
  );

  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await local.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        _openNotificationCenter(response.payload);
      },
    );

    final androidPlugin = local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      // The navigator may not exist yet during cold start; schedule it.
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        _openNotificationCenter(jsonEncode(initial.data));
      });
    }

    messaging.onTokenRefresh.listen((token) async {
      await saveToken(token);
    });

    _ready = true;
    await registerCurrentDevice();
  }

  static Future<void> registerCurrentDevice() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      debugPrint('========== ZenexPay FCM DEBUG ==========');
      debugPrint('USER ID: ${user?.id}');

      if (user == null) {
        debugPrint('ERROR: No logged-in user');
        return;
      }

      final token = await messaging.getToken();

      debugPrint('FCM TOKEN: $token');

      if (token == null || token.isEmpty) {
        debugPrint('ERROR: FCM token is NULL or EMPTY');
        return;
      }

      await saveToken(token);

      debugPrint('FCM saveToken() finished');
      debugPrint('========================================');
    } catch (e, stack) {
      debugPrint('FCM REGISTRATION ERROR: $e');
      debugPrint('$stack');
    }
  }

  static Future<void> saveToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      debugPrint('FCM SAVE ERROR: User is null');
      return;
    }

    if (token.isEmpty) {
      debugPrint('FCM SAVE ERROR: Token is empty');
      return;
    }

    try {
      debugPrint('Saving FCM token to Supabase...');
      debugPrint('User ID: ${user.id}');
      debugPrint('Token length: ${token.length}');

      final response = await Supabase.instance.client
          .from('device_tokens')
          .upsert(
            {
              'user_id': user.id,
              'token': token,
              'platform': 'android',
            },
            onConflict: 'token',
          )
          .select();

      debugPrint('SUPABASE TOKEN SAVE SUCCESS: $response');
    } catch (e, stack) {
      debugPrint('SUPABASE TOKEN SAVE ERROR: $e');
      debugPrint('$stack');
    }
  }

  static Future<void> removeCurrentToken() async {
    try {
      final token = await messaging.getToken();
      final user = Supabase.instance.client.auth.currentUser;
      if (token != null && user != null) {
        await Supabase.instance.client
            .from('device_tokens')
            .delete()
            .eq('user_id', user.id)
            .eq('token', token);
      }
      await messaging.deleteToken();
    } catch (_) {}
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final n = message.notification;
    final title = n?.title ?? message.data['title'] ?? 'ZenexPay';
    final body = n?.body ?? message.data['body'] ?? 'You have a new update.';

    await local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static void _handleOpenedMessage(RemoteMessage message) {
    _openNotificationCenter(jsonEncode(message.data));
  }

  static void _openNotificationCenter(String? payload) {
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }
}
