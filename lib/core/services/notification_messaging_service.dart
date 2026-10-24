import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationMessagingService {
  static final NotificationMessagingService instance =
      NotificationMessagingService._internal();

  factory NotificationMessagingService() => instance;

  NotificationMessagingService._internal();

  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  bool _systemInitialized = false;
  String? _currentUserId;
  String? _currentUserRole;
  Function(Map<String, dynamic> data)? _onNotificationTap;
  final Set<String> _processedIds = {};

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _appOpenedSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _fcmMessagesSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _notificationsSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  Map<String, dynamic>? _pendingInitialData;

  bool get isInitialized => _systemInitialized && _currentUserId != null;

  static Future<void> initializeSystem() async {
    if (instance._systemInitialized) return;

    try {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initSettings =
          InitializationSettings(android: androidSettings, iOS: iosSettings);

      await _localNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          if (details.payload != null && details.payload!.isNotEmpty) {
            try {
              final data =
                  jsonDecode(details.payload!) as Map<String, dynamic>;
              instance._handleNotificationTap(data);
            } catch (_) {}
          }
        },
      );

      final androidPlugin = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_androidChannel);
      await androidPlugin?.requestNotificationsPermission();

      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        instance._pendingInitialData = initialMessage.data;
      }
    } catch (_) {}

    instance._systemInitialized = true;
  }

  Future<void> initialize({
    required String userId,
    String? role,
    Function(Map<String, dynamic> data)? onNotificationTap,
  }) async {
    if (!_systemInitialized) {
      await initializeSystem();
    }

    _currentUserId = userId;
    _currentUserRole = role;
    _onNotificationTap = onNotificationTap;

    if (userId.isNotEmpty) {
      await registerDeviceToken(userId);
      _setupListeners(userId, role);
    }

    if (_pendingInitialData != null) {
      final data = Map<String, dynamic>.from(_pendingInitialData!);
      _pendingInitialData = null;
      Future.microtask(() => _handleNotificationTap(data));
    }
  }

  Future<void> registerDeviceToken(String userId) async {
    _currentUserId = userId;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveTokenToFirestore(userId, token);
      }

      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription =
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _saveTokenToFirestore(userId, newToken);
      });
    } catch (_) {
      try {
        final token = 'fcm_token_$userId';
        await _saveTokenToFirestore(userId, token);
      } catch (_) {}
    }
  }

  Future<void> _saveTokenToFirestore(String userId, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _setupListeners(String userId, String? role) {
    _foregroundSubscription?.cancel();
    _foregroundSubscription =
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotificationFromMessage(message);
    });

    _appOpenedSubscription?.cancel();
    _appOpenedSubscription = FirebaseMessaging.onMessageOpenedApp
        .listen((RemoteMessage message) {
      _handleNotificationTap(message.data);
    });

    _fcmMessagesSubscription?.cancel();
    _notificationsSubscription?.cancel();

    final firestore = FirebaseFirestore.instance;

    // Listener 1: FCM messages
    final Stream<QuerySnapshot<Map<String, dynamic>>> fcmStream;
    if (role == 'admin') {
      fcmStream = firestore
          .collection('fcm_messages')
          .where('targetUserId', whereIn: [userId, 'admin'])
          .snapshots();
    } else {
      fcmStream = firestore
          .collection('fcm_messages')
          .where('targetUserId', isEqualTo: userId)
          .snapshots();
    }

    _fcmMessagesSubscription = fcmStream.listen((snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final docId = doc.id;
        if (_processedIds.contains(docId)) continue;
        _processedIds.add(docId);

        final notif = data['notification'] as Map<String, dynamic>? ?? {};
        final title = notif['title'] as String? ?? 'Notification';
        final body = notif['body'] as String? ?? '';
        final payloadData =
            Map<String, dynamic>.from(data['data'] as Map? ?? {});

        _showLocalNotification(
          id: docId.hashCode,
          title: title,
          body: body,
          data: payloadData,
        );
      }
    });

    // Listener 2: In-app notifications collection -> Phone Device Notifications
    final Stream<QuerySnapshot<Map<String, dynamic>>> notifStream;
    if (role == 'admin') {
      notifStream = firestore
          .collection('notifications')
          .where('type', isEqualTo: 'admin')
          .snapshots();
    } else {
      notifStream = firestore
          .collection('notifications')
          .where('creatorUid', isEqualTo: userId)
          .snapshots();
    }

    _notificationsSubscription = notifStream.listen((snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final docId = doc.id;
        if (_processedIds.contains(docId)) continue;
        _processedIds.add(docId);

        final title = data['title'] as String? ?? 'New Notification';
        final message = data['message'] as String? ?? '';
        final category =
            data['category'] as String? ?? data['type'] as String? ?? 'general';
        final targetId =
            data['targetId'] as String? ?? data['ticketId'] as String? ?? '';

        _showLocalNotification(
          id: docId.hashCode,
          title: title,
          body: message,
          data: {
            'category': category,
            'targetId': targetId,
            'type': data['type'] ?? '',
          },
        );
      }
    });

    // Also listen for buyer/user notifications if not admin
    if (role != 'admin') {
      firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .listen((snapshot) {
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final docId = doc.id;
          if (_processedIds.contains(docId)) continue;
          _processedIds.add(docId);

          final title = data['title'] as String? ?? 'New Notification';
          final message = data['message'] as String? ?? '';
          final category = data['category'] as String? ??
              data['type'] as String? ??
              'general';
          final targetId =
              data['targetId'] as String? ?? data['ticketId'] as String? ?? '';

          _showLocalNotification(
            id: docId.hashCode,
            title: title,
            body: message,
            data: {
              'category': category,
              'targetId': targetId,
              'type': data['type'] ?? '',
            },
          );
        }
      });
    }
  }

  void _showLocalNotificationFromMessage(RemoteMessage message) {
    final msgId = message.messageId ??
        '${message.notification?.title}_${message.notification?.body}';
    if (_processedIds.contains(msgId)) return;
    _processedIds.add(msgId);

    final title = message.notification?.title ??
        message.data['title'] as String? ??
        'Notification';
    final body = message.notification?.body ??
        message.data['body'] as String? ??
        '';

    _showLocalNotification(
      id: msgId.hashCode,
      title: title,
      body: body,
      data: message.data,
    );
  }

  void _showLocalNotification({
    required int id,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    if (title.isEmpty && body.isEmpty) return;

    _localNotificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    _onNotificationTap?.call(data);
  }

  static Future<void> sendPushNotification({
    required String targetUserId,
    required String title,
    required String message,
    String? category,
    String? targetId,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final List<String> tokens = [];

      if (targetUserId == 'admin') {
        final adminSnaps = await firestore
            .collection('users')
            .where('role', isEqualTo: 'admin')
            .get();
        for (final doc in adminSnaps.docs) {
          final t = doc.data()['fcmToken'] as String?;
          if (t != null && t.isNotEmpty) tokens.add(t);
        }
      } else {
        final userSnap =
            await firestore.collection('users').doc(targetUserId).get();
        if (userSnap.exists) {
          final t = userSnap.data()?['fcmToken'] as String?;
          if (t != null && t.isNotEmpty) tokens.add(t);
        }
      }

      await firestore.collection('fcm_messages').add({
        'targetUserId': targetUserId,
        'tokens': tokens,
        'notification': {
          'title': title,
          'body': message,
        },
        'data': {
          'title': title,
          'body': message,
          'category': category ?? 'general',
          'targetId': targetId ?? '',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (_) {}
  }

  String? get currentUserRole => _currentUserRole;
}
