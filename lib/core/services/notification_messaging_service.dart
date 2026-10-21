import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationMessagingService {
  static final NotificationMessagingService instance =
      NotificationMessagingService._internal();

  factory NotificationMessagingService() => instance;

  NotificationMessagingService._internal();

  bool _initialized = false;
  String? _currentUserId;

  bool get isInitialized => _initialized;

  Future<void> initialize({
    String? userId,
    Function(Map<String, dynamic> data)? onNotificationTap,
  }) async {
    _currentUserId = userId;

    if (userId != null && userId.isNotEmpty) {
      await registerDeviceToken(userId);
    }

    _initialized = true;
  }

  Future<void> registerDeviceToken(String userId) async {
    _currentUserId = userId;
    try {
      final token = 'fcm_token_$userId';
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
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

      for (final token in tokens) {
        await firestore.collection('fcm_messages').add({
          'token': token,
          'targetUserId': targetUserId,
          'notification': {
            'title': title,
            'body': message,
          },
          'data': {
            'category': category ?? 'general',
            'targetId': targetId ?? '',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
      }
    } catch (_) {}
  }
}
