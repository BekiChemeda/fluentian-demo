import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../network/api_client.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Background handlers should fail silently when Firebase is not configured.
  }
}

class PushNotificationService {
  PushNotificationService({required this.apiClient});

  final ApiClient apiClient;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final firebaseReady = await _initializeFirebase();
    if (!firebaseReady) {
      return;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final authorized = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!authorized) {
      return;
    }

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _registerToken(token);
    }

    _tokenSubscription = _messaging.onTokenRefresh.listen((token) {
      if (token.isEmpty) {
        return;
      }
      unawaited(_registerToken(token));
    });

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((_) {});
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((_) {});

    _initialized = true;
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    _tokenSubscription = null;
    _foregroundSubscription = null;
    _openedSubscription = null;
    _initialized = false;
  }

  Future<bool> _initializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await apiClient.dio.post('/notifications/device-token', data: {
        'token': token,
        'platform': 'fcm',
      });
    } catch (_) {
      // Device token registration is retried when the token refresh stream emits again.
    }
  }
}