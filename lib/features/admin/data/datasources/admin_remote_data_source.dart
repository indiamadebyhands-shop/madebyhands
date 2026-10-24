import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:madebyhands/core/constants/product_categories.dart';
import 'package:madebyhands/core/services/notification_messaging_service.dart';
import 'package:madebyhands/features/creator/data/models/creator_profile_model.dart';

abstract interface class AdminRemoteDataSource {
  Future<Map<String, dynamic>> getPlatformSettings();
  Future<void> updatePlatformSettings(
    double flatFee,
    double percentFee,
    double commissionThreshold,
  );
  Future<List<CreatorProfileModel>> getCreatorProfiles();
  Future<void> approveCreator(String uid);
  Future<void> rejectCreator(String uid, String reason);
  Future<List<String>> getCategories({bool seedDefaults = false});
  Future<void> addCategory(String name);
  Future<void> deleteCategory(String name);
  Future<List<String>> resetCategoriesToDefaults();
  Future<void> setModerationState({
    required String uid,
    required int level,
    required String reason,
  });
  Future<void> reviewProduct({
    required String productId,
    required bool approve,
    required String reviewerName,
    required String reviewerEmail,
    String? rejectionReason,
  });
}

class AdminRemoteDataSourceImpl implements AdminRemoteDataSource {
  final FirebaseFirestore firestore;

  AdminRemoteDataSourceImpl(this.firestore);

  @override
  Future<Map<String, dynamic>> getPlatformSettings() async {
    final doc = await firestore
        .collection('settings')
        .doc('platform_economics')
        .get();
    return doc.data() ??
        const {
          'flatFee': 50.0,
          'percentFee': 5.0,
          'commissionThreshold': 999.0,
        };
  }

  @override
  Future<void> updatePlatformSettings(
    double flatFee,
    double percentFee,
    double commissionThreshold,
  ) => firestore.collection('settings').doc('platform_economics').set({
    'flatFee': flatFee,
    'percentFee': percentFee,
    'commissionThreshold': commissionThreshold,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  @override
  Future<List<CreatorProfileModel>> getCreatorProfiles() async {
    final snapshot = await firestore.collection('creator_profiles').get();
    return snapshot.docs
        .map((doc) => CreatorProfileModel.fromJson(doc.data(), doc.id))
        .toList();
  }

  /// Verification is separate from product approval: verifying a creator
  /// never publishes their products.
  @override
  Future<void> approveCreator(String uid) async {
    final batch = firestore.batch();
    batch.set(firestore.collection('creator_profiles').doc(uid), {
      'verificationStatus': 'Verified',
      'verificationNote': FieldValue.delete(),
      'verifiedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(firestore.collection('users').doc(uid), {
      'isVerified': true,
    }, SetOptions(merge: true));
    batch.set(firestore.collection('notifications').doc(), {
      'creatorUid': uid,
      'title': 'You are now a Verified Creator',
      'message':
          'Your verification was approved. You can now list products for review.',
      'type': 'verification',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
    await batch.commit();

    NotificationMessagingService.sendPushNotification(
      targetUserId: uid,
      title: 'You are now a Verified Creator',
      message:
          'Your verification was approved. You can now list products for review.',
      category: 'verification',
      targetId: uid,
    );
  }

  /// Rejects a pending request or revokes an existing verification. A
  /// creator who is no longer verified cannot sell, so their live listings
  /// are hidden; they can republish after being verified again.
  @override
  Future<void> rejectCreator(String uid, String reason) async {
    final liveProducts = await firestore
        .collection('products')
        .where('creatorUid', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .get();
    final batch = firestore.batch();
    for (final product in liveProducts.docs) {
      batch.update(product.reference, {
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.set(firestore.collection('creator_profiles').doc(uid), {
      'verificationStatus': 'Rejected',
      'verificationNote': reason,
    }, SetOptions(merge: true));
    batch.set(firestore.collection('users').doc(uid), {
      'isVerified': false,
    }, SetOptions(merge: true));
    batch.set(firestore.collection('notifications').doc(), {
      'creatorUid': uid,
      'title': 'Verification needs attention',
      'message': 'Your verification was not approved. Reason: $reason',
      'type': 'verification',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
    await batch.commit();

    NotificationMessagingService.sendPushNotification(
      targetUserId: uid,
      title: 'Verification needs attention',
      message: 'Your verification was not approved. Reason: $reason',
      category: 'verification',
      targetId: uid,
    );
  }

  @override
  Future<List<String>> getCategories({bool seedDefaults = false}) async {
    final snapshot = await firestore.collection('categories').get();
    if (snapshot.docs.isNotEmpty) {
      final names =
          snapshot.docs
              .map((doc) => doc.data()['name'] as String? ?? doc.id)
              .where((name) => name.trim().isNotEmpty)
              .toList()
            ..sort();
      return names;
    }
    if (seedDefaults) {
      final batch = firestore.batch();
      for (final name in kProductCategories) {
        batch.set(firestore.collection('categories').doc(_categoryId(name)), {
          'name': name,
        });
      }
      await batch.commit();
      return List<String>.from(kProductCategories);
    }
    // Firestore is the single source of truth: an empty collection means
    // admin has configured (or deleted down to) zero categories — never
    // silently substitute the hardcoded defaults here.
    return const [];
  }

  @override
  Future<void> addCategory(String name) => firestore
      .collection('categories')
      .doc(_categoryId(name))
      .set({'name': name.trim()});

  @override
  Future<void> deleteCategory(String name) async {
    // Older categories used the display name as the document id.
    final snapshot = await firestore
        .collection('categories')
        .where('name', isEqualTo: name)
        .get();
    final batch = firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(firestore.collection('categories').doc(_categoryId(name)));
    await batch.commit();
  }

  /// Wipes every current category document and reseeds exactly
  /// [kProductCategories] — the admin "Reset to defaults" action. Existing
  /// products keep whatever category strings they were tagged with; this
  /// only changes what creators are offered going forward.
  @override
  Future<List<String>> resetCategoriesToDefaults() async {
    final snapshot = await firestore.collection('categories').get();
    final batch = firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    for (final name in kProductCategories) {
      batch.set(firestore.collection('categories').doc(_categoryId(name)), {
        'name': name,
      });
    }
    await batch.commit();
    return List<String>.from(kProductCategories);
  }

  /// Persists the creator-facing warning state with the admin's existing
  /// Firestore permissions. Final Auth disabling still happens server-side.
  @override
  Future<void> setModerationState({
    required String uid,
    required int level,
    required String reason,
  }) async {
    if (![0, 1, 2, 3].contains(level)) {
      throw ArgumentError.value(level, 'level', 'Must be between 0 and 3.');
    }

    if (level >= 2) {
      final productReferences =
          <String, DocumentReference<Map<String, dynamic>>>{};
      for (final field in const ['creatorUid', 'creatorId']) {
        final snapshot = await firestore
            .collection('products')
            .where(field, isEqualTo: uid)
            .get();
        for (final product in snapshot.docs) {
          productReferences[product.reference.path] = product.reference;
        }
      }
      final references = productReferences.values.toList();
      for (var start = 0; start < references.length; start += 450) {
        final batch = firestore.batch();
        for (final reference in references.skip(start).take(450)) {
          batch.update(reference, {
            'isActive': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    }

    final profileReference = firestore.collection('creator_profiles').doc(uid);
    final profileExists = (await profileReference.get()).exists;
    final batch = firestore.batch();
    batch.set(firestore.collection('users').doc(uid), {
      'isSuspended': level == 3,
      'creatorModerationLevel': level,
      'creatorModerationReason': level == 0
          ? FieldValue.delete()
          : reason.trim(),
      'creatorModerationIssuedAt': level == 0
          ? FieldValue.delete()
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (profileExists) {
      batch.update(profileReference, {
        'isStorefrontVisible': level < 2,
        'moderationLevel': level,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Approving publishes the listing; rejecting hides it with a reason the
  /// creator sees. The creator is notified either way.
  @override
  Future<void> reviewProduct({
    required String productId,
    required bool approve,
    required String reviewerName,
    required String reviewerEmail,
    String? rejectionReason,
  }) async {
    final productRef = firestore.collection('products').doc(productId);
    final product = await productRef.get();
    final data = product.data();
    if (data == null) throw StateError('This product no longer exists.');
    final creatorUid =
        data['creatorUid'] as String? ?? data['creatorId'] as String? ?? '';
    final name = data['name'] as String? ?? 'Your product';
    // An approved listing only goes live while its creator is verified.
    var creatorVerified = false;
    if (approve && creatorUid.isNotEmpty) {
      final creator = await firestore
          .collection('creator_profiles')
          .doc(creatorUid)
          .get();
      creatorVerified = creator.data()?['verificationStatus'] == 'Verified';
    }

    final batch = firestore.batch();
    batch.update(productRef, {
      'status': approve ? 'Approved' : 'Rejected',
      'isActive': approve && creatorVerified,
      'approvedBy': reviewerName,
      'approvedByEmail': reviewerEmail,
      'rejectionReason': approve ? '' : (rejectionReason ?? '').trim(),
      if (approve) 'approvedAt': FieldValue.serverTimestamp(),
      if (approve) 'editHistory': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (creatorUid.isNotEmpty) {
      final notifTitle = approve ? 'Product approved' : 'Product needs changes';
      final notifMessage = approve
          ? (creatorVerified
                ? '"$name" is now live in your storefront.'
                : '"$name" was approved and will go live once your account is verified.')
          : '"$name" was not approved. Reason: ${(rejectionReason ?? '').trim()}';

      batch.set(firestore.collection('notifications').doc(), {
        'creatorUid': creatorUid,
        'title': notifTitle,
        'message': notifMessage,
        'type': 'product',
        'targetId': productId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      NotificationMessagingService.sendPushNotification(
        targetUserId: creatorUid,
        title: notifTitle,
        message: notifMessage,
        category: 'product',
        targetId: productId,
      );
    }
    await batch.commit();
  }

  /// Firestore ids cannot contain '/', which category names may.
  static String _categoryId(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
