import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../utils/constants.dart';

// ---------------------------------------------------------------------------
// Top-level background message handler
// ---------------------------------------------------------------------------

/// Must be a top-level function (not a class method) so that the Firebase
/// Messaging plugin can invoke it in a separate isolate.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are shown automatically by the OS on Android/iOS.
  // Add any silent processing here if needed (e.g., updating a badge count).
}

// ---------------------------------------------------------------------------
// Service class
// ---------------------------------------------------------------------------

/// Manages FCM push notifications for the bws_chat module.
///
/// Call [initialize] once at app startup (after Firebase.initializeApp).
class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FlutterLocalNotificationsPlugin _localNotifications;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Initialises FCM and the local-notification plugin.
  ///
  /// - Requests permission on iOS / macOS.
  /// - Registers the background message handler.
  /// - Sets up the foreground notification channel (Android).
  /// - Wires foreground message display via flutter_local_notifications.
  Future<void> initialize() async {
    // Register background handler before any await calls.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (iOS / macOS; no-op on Android).
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Suppress the default FCM notification heads-up on Android so we can
    // display it ourselves via flutter_local_notifications with full control.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );

    // Initialise the local notifications plugin.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      ),
    );

    // Create the Android notification channel.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            ChatNotifications.channelId,
            ChatNotifications.channelName,
            description: ChatNotifications.channelDescription,
            importance: Importance.high,
          ),
        );

    // Show foreground messages via local notifications.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  // ---------------------------------------------------------------------------
  // Token management
  // ---------------------------------------------------------------------------

  /// Returns the current FCM registration token for this device, or `null`
  /// if the token is not yet available.
  Future<String?> getToken() => _messaging.getToken();

  /// Saves [token] to Firestore under the user's token sub-collection so the
  /// server can target this device for push notifications.
  ///
  /// Also registers a token-refresh listener to keep the stored token current.
  Future<void> saveToken(String userId, String token) async {
    await _tokensRef(userId).doc(token).set({
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
      'platform': _platformString(),
    });

    // Keep the token refreshed automatically.
    _messaging.onTokenRefresh.listen((newToken) async {
      await _tokensRef(userId).doc(newToken).set({
        'token': newToken,
        'updatedAt': FieldValue.serverTimestamp(),
        'platform': _platformString(),
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Sending notifications
  // ---------------------------------------------------------------------------

  /// Sends a chat push notification to [recipientId].
  ///
  /// This method writes a Firestore document that is picked up by a Cloud
  /// Function responsible for the actual FCM send. Sending FCM messages
  /// directly from a client is not supported; the server key must be kept
  /// server-side.
  ///
  /// The Cloud Function should watch `fcm_triggers/{docId}` and call the
  /// FCM Admin SDK.
  Future<void> sendChatNotification({
    required String recipientId,
    required String senderName,
    required String message,
    required String roomId,
  }) async {
    await _firestore.collection('fcm_triggers').add({
      'recipientId': recipientId,
      'data': {
        ChatNotifications.payloadRoomId: roomId,
        ChatNotifications.payloadSenderId: senderName,
        ChatNotifications.payloadType: 'chat_message',
      },
      'notification': {
        'title': senderName,
        'body': message,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // Topic subscription
  // ---------------------------------------------------------------------------

  /// Subscribes this device to the FCM topic for [roomId], allowing
  /// server-side fan-out notifications without iterating recipient tokens.
  Future<void> subscribeToRoom(String roomId) =>
      _messaging.subscribeToTopic(_roomTopic(roomId));

  /// Unsubscribes this device from the FCM topic for [roomId].
  Future<void> unsubscribeFromRoom(String roomId) =>
      _messaging.unsubscribeFromTopic(_roomTopic(roomId));

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Displays a foreground [message] as a local notification.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      ChatNotifications.channelId,
      ChatNotifications.channelName,
      channelDescription: ChatNotifications.channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      ),
      payload: message.data[ChatNotifications.payloadRoomId],
    );
  }

  CollectionReference<Map<String, dynamic>> _tokensRef(String userId) =>
      _firestore
          .collection(ChatCollections.users)
          .doc(userId)
          .collection('fcm_tokens');

  String _roomTopic(String roomId) => 'room_$roomId';

  String _platformString() {
    // Determined at compile-time via conditional imports in a real project.
    // Returning a constant here keeps this file platform-agnostic.
    return 'mobile';
  }
}
