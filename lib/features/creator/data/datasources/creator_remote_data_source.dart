import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:madebyhands/core/services/notification_messaging_service.dart';
import 'package:madebyhands/features/creator/data/models/creator_bank_account_model.dart';
import 'package:madebyhands/features/creator/data/models/creator_notification_model.dart';
import 'package:madebyhands/features/creator/data/models/creator_order_model.dart';
import 'package:madebyhands/features/creator/data/models/creator_product_model.dart';
import 'package:madebyhands/features/creator/data/models/creator_profile_model.dart';
import 'package:madebyhands/features/orders/domain/order_status.dart';

/// Private verification documents, stored in `creator_verifications/{uid}`.
class VerificationDocumentsModel {
  final String businessName;
  final String address;
  final String latestPhoto;
  final String idCard;

  const VerificationDocumentsModel({
    required this.businessName,
    required this.address,
    required this.latestPhoto,
    required this.idCard,
  });
}

abstract interface class CreatorRemoteDataSource {
  Future<CreatorProfileModel?> getCreatorProfile(String uid);

  /// Creates or updates the public, creator-editable profile fields.
  Future<void> saveCreatorProfile(CreatorProfileModel profile);

  Future<String> uploadProfileImage({required File image, required String uid});

  Future<List<String>> uploadPortfolioImages({
    required List<File> images,
    required String uid,
  });

  Future<List<String>> uploadExhibitionPictures({
    required List<File> images,
    required String uid,
  });

  Future<String> uploadVerificationFile({
    required File file,
    required String uid,
    required String fileName,
  });

  Future<VerificationDocumentsModel?> getVerificationDocuments(String uid);

  /// Stores the documents privately, marks the profile 'In-Process' and
  /// alerts the admins.
  Future<void> submitVerification({
    required String uid,
    required String creatorName,
    required VerificationDocumentsModel documents,
  });

  Future<void> addProduct(CreatorProductModel product);
  Future<void> updateProduct(CreatorProductModel product);
  Future<void> deleteProduct(String productId);
  Future<void> setProductPublished(String productId, bool published);
  Future<void> updateStock(String productId, int stock);
  Future<CreatorProductModel?> getProduct(String productId);

  Future<List<String>> uploadProductImages({
    required List<File> images,
    required String uid,
    required String folder,
  });

  Stream<List<CreatorProductModel>> watchCreatorProducts(String uid);
  Stream<List<CreatorOrderModel>> watchCreatorOrders(String uid);

  /// Moves an order forward in fulfilment. Rejections go through the API.
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? consignmentNumber,
    String? carrierName,
  });

  Stream<List<CreatorNotificationModel>> watchNotifications(String uid);
  Future<void> markNotificationAsRead(String notificationId);
  Future<void> markAllNotificationsAsRead(String uid);
  Future<void> deleteNotifications(List<String> notificationIds);

  Future<CreatorBankAccountModel?> getCreatorBankAccount(String uid);
  Future<void> saveCreatorBankAccount(CreatorBankAccountModel bankDetail);
}

class CreatorRemoteDataSourceImpl implements CreatorRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseStorage firebaseStorage;

  // Every upload has a unique, timestamped path and is never overwritten, so
  // clients and CDNs can cache it for a year.
  static final _imageMetadata = SettableMetadata(
    contentType: 'image/jpeg',
    cacheControl: 'public, max-age=31536000',
  );

  CreatorRemoteDataSourceImpl({
    required this.firestore,
    required this.firebaseStorage,
  });

  CollectionReference<Map<String, dynamic>> get _profiles =>
      firestore.collection('creator_profiles');
  CollectionReference<Map<String, dynamic>> get _products =>
      firestore.collection('products');
  CollectionReference<Map<String, dynamic>> get _notifications =>
      firestore.collection('notifications');

  /// Uploads [file] to [path] and returns its download URL. Works on web
  /// (where `File` wraps a blob URL) and on mobile.
  Future<String> _upload(File file, String path) async {
    final bytes = kIsWeb
        ? await XFile(file.path).readAsBytes()
        : await file.readAsBytes();
    final snapshot = await firebaseStorage
        .ref()
        .child(path)
        .putData(bytes, _imageMetadata);
    return snapshot.ref.getDownloadURL();
  }

  /// Storage path segment derived from user input.
  static String _segment(String value) {
    final cleaned = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (cleaned.isEmpty) return 'item';
    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }

  @override
  Future<CreatorProfileModel?> getCreatorProfile(String uid) async {
    final doc = await _profiles.doc(uid).get();
    final data = doc.data();
    return data == null ? null : CreatorProfileModel.fromJson(data, doc.id);
  }

  @override
  Future<void> saveCreatorProfile(CreatorProfileModel profile) async {
    final ref = _profiles.doc(profile.uid);
    final exists = (await ref.get()).exists;
    await ref.set({
      ...profile.toEditableJson(),
      if (!exists) 'verificationStatus': 'Unverified',
      if (!exists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<String> uploadProfileImage({
    required File image,
    required String uid,
  }) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return _upload(image, 'creator_profiles/$uid/profile_$stamp.jpg');
  }

  @override
  Future<List<String>> uploadPortfolioImages({
    required List<File> images,
    required String uid,
  }) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return [
      for (var i = 0; i < images.length; i++)
        await _upload(
          images[i],
          'creator_profiles/$uid/portfolio/image_${stamp}_$i.jpg',
        ),
    ];
  }

  @override
  Future<List<String>> uploadExhibitionPictures({
    required List<File> images,
    required String uid,
  }) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return [
      for (var i = 0; i < images.length; i++)
        await _upload(
          images[i],
          'creator_profiles/$uid/exhibition/image_${stamp}_$i.jpg',
        ),
    ];
  }

  @override
  Future<String> uploadVerificationFile({
    required File file,
    required String uid,
    required String fileName,
  }) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return _upload(
      file,
      'creator_profiles/$uid/verification/${stamp}_$fileName',
    );
  }

  @override
  Future<VerificationDocumentsModel?> getVerificationDocuments(String uid) async {
    final doc = await firestore.collection('creator_verifications').doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    return VerificationDocumentsModel(
      businessName: data['businessName'] as String? ?? '',
      address: data['address'] as String? ?? '',
      latestPhoto: data['latestPhoto'] as String? ?? '',
      idCard: data['idCard'] as String? ?? '',
    );
  }

  @override
  Future<void> submitVerification({
    required String uid,
    required String creatorName,
    required VerificationDocumentsModel documents,
  }) async {
    final batch = firestore.batch();
    batch.set(firestore.collection('creator_verifications').doc(uid), {
      'uid': uid,
      'businessName': documents.businessName,
      'address': documents.address,
      'latestPhoto': documents.latestPhoto,
      'idCard': documents.idCard,
      'submittedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_profiles.doc(uid), {
      'verificationStatus': 'In-Process',
      'businessName': documents.businessName,
      'verificationNote': FieldValue.delete(),
      // Clear documents that older app versions stored publicly.
      'address': FieldValue.delete(),
      'latestPhoto': FieldValue.delete(),
      'idCard': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_notifications.doc(), {
      'type': 'admin',
      'category': 'creator_verification',
      'title': 'New creator verification request',
      'message':
          '${creatorName.isEmpty ? 'A creator' : creatorName} submitted verification documents.',
      'targetId': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
    await batch.commit();

    NotificationMessagingService.sendPushNotification(
      targetUserId: 'admin',
      title: 'New creator verification request',
      message:
          '${creatorName.isEmpty ? 'A creator' : creatorName} submitted verification documents.',
      category: 'creator_verification',
      targetId: uid,
    );
  }

  @override
  Future<void> addProduct(CreatorProductModel product) async {
    final batch = firestore.batch();
    final productRef = _products.doc();
    batch.set(productRef, {
      ...product.toJson(),
      'orderCount': 0,
      'wishlistCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_notifications.doc(), {
      'type': 'admin',
      'category': 'product_submission',
      'title': 'New product awaiting review',
      'message':
          '${product.creatorName.isEmpty ? 'A creator' : product.creatorName} submitted "${product.name}" for approval.',
      'targetId': productRef.id,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
    await batch.commit();

    NotificationMessagingService.sendPushNotification(
      targetUserId: 'admin',
      title: 'New product awaiting review',
      message:
          '${product.creatorName.isEmpty ? 'A creator' : product.creatorName} submitted "${product.name}" for approval.',
      category: 'product_submission',
      targetId: productRef.id,
    );
  }

  @override
  Future<void> updateProduct(CreatorProductModel product) async {
    final data = product.toJson()
      ..remove('createdAt')
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await _products.doc(product.id).update(data);
  }

  @override
  Future<void> deleteProduct(String productId) =>
      _products.doc(productId).delete();

  @override
  Future<void> setProductPublished(String productId, bool published) =>
      _products.doc(productId).update({
        'isActive': published,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> updateStock(String productId, int stock) =>
      _products.doc(productId).update({
        'stock': stock,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<CreatorProductModel?> getProduct(String productId) async {
    final doc = await _products.doc(productId).get();
    final data = doc.data();
    return data == null ? null : CreatorProductModel.fromJson(data, doc.id);
  }

  @override
  Future<List<String>> uploadProductImages({
    required List<File> images,
    required String uid,
    required String folder,
  }) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'products/$uid/${_segment(folder)}';
    return [
      for (var i = 0; i < images.length; i++)
        await _upload(images[i], '$path/image_${stamp}_$i.jpg'),
    ];
  }

  @override
  Stream<List<CreatorProductModel>> watchCreatorProducts(String uid) =>
      _products.where('creatorUid', isEqualTo: uid).snapshots().map((snapshot) {
        final products = snapshot.docs
            .map((doc) => CreatorProductModel.fromJson(doc.data(), doc.id))
            .toList();
        products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return products;
      });

  @override
  Stream<List<CreatorOrderModel>> watchCreatorOrders(String uid) => firestore
      .collection('orders')
      .where('creatorId', isEqualTo: uid)
      .snapshots()
      .map((snapshot) {
        final orders = snapshot.docs
            .map((doc) => CreatorOrderModel.fromJson(doc.data(), doc.id))
            .toList();
        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return orders;
      });

  @override
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? consignmentNumber,
    String? carrierName,
  }) async {
    final stored = OrderStatus.storedValue(status);
    await firestore.collection('orders').doc(orderId).update({
      'status': stored,
      'updatedAt': FieldValue.serverTimestamp(),
      if (consignmentNumber != null && consignmentNumber.trim().isNotEmpty)
        'consignmentNumber': consignmentNumber.trim(),
      if (carrierName != null && carrierName.trim().isNotEmpty)
        'carrierName': carrierName.trim(),
      if (OrderStatus.isDelivered(stored))
        'deliveredAt': FieldValue.serverTimestamp(),
    });

    try {
      final orderDoc = await firestore.collection('orders').doc(orderId).get();
      if (orderDoc.exists) {
        final data = orderDoc.data();
        final buyerUid =
            data?['buyerUid'] as String? ?? data?['userId'] as String? ?? '';
        final shortId = data?['shortId'] as String? ?? '';
        final displayStatus = OrderStatus.label(stored);
        if (buyerUid.isNotEmpty) {
          final msg =
              'Order #${shortId.isNotEmpty ? shortId : orderId} status changed to $displayStatus.';
          await firestore.collection('notifications').add({
            'userId': buyerUid,
            'creatorUid': buyerUid,
            'type': 'order',
            'category': 'order',
            'title': 'Order Status Updated',
            'message': msg,
            'targetId': orderId,
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });
          NotificationMessagingService.sendPushNotification(
            targetUserId: buyerUid,
            title: 'Order Status Updated',
            message: msg,
            category: 'order',
            targetId: orderId,
          );
        }
      }
    } catch (_) {}
  }

  @override
  Stream<List<CreatorNotificationModel>> watchNotifications(String uid) =>
      _notifications.where('creatorUid', isEqualTo: uid).snapshots().map((
        snapshot,
      ) {
        final notifications = snapshot.docs
            .map((doc) => CreatorNotificationModel.fromJson(doc.data(), doc.id))
            .toList();
        notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return notifications;
      });

  @override
  Future<void> markNotificationAsRead(String notificationId) =>
      _notifications.doc(notificationId).update({'isRead': true});

  @override
  Future<void> markAllNotificationsAsRead(String uid) async {
    final snapshot = await _notifications
        .where('creatorUid', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();
    if (snapshot.docs.isEmpty) return;
    final batch = firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  @override
  Future<void> deleteNotifications(List<String> notificationIds) async {
    final batch = firestore.batch();
    for (final id in notificationIds) {
      batch.delete(_notifications.doc(id));
    }
    await batch.commit();
  }

  @override
  Future<CreatorBankAccountModel?> getCreatorBankAccount(String uid) async {
    final doc = await firestore.collection('creator_bank_accounts').doc(uid).get();
    final data = doc.data();
    return data == null ? null : CreatorBankAccountModel.fromJson(data, uid);
  }

  @override
  Future<void> saveCreatorBankAccount(CreatorBankAccountModel bankDetail) async {
    final ref = firestore.collection('creator_bank_accounts').doc(bankDetail.uid);
    final exists = (await ref.get()).exists;
    await ref.set({
      ...bankDetail.toJson(),
      if (!exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
