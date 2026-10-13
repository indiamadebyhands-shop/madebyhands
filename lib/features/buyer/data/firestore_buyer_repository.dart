import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:madebyhands/features/buyer/domain/entities/buyer_order.dart';
import 'package:madebyhands/features/buyer/domain/entities/buyer_product_notification.dart';
import 'package:madebyhands/features/buyer/domain/entities/product.dart';
import 'package:madebyhands/features/buyer/domain/entities/product_review.dart';
import 'package:madebyhands/features/buyer/domain/entities/public_creator.dart';
import 'package:madebyhands/features/buyer/domain/entities/saved_address.dart';
import 'package:madebyhands/features/buyer/domain/repositories/buyer_repository.dart';
import 'package:madebyhands/features/orders/domain/entities/marketplace_order.dart';
import 'package:madebyhands/features/orders/domain/order_status.dart';

class FirestoreBuyerRepository implements BuyerRepository {
  final FirebaseFirestore firestore;

  const FirestoreBuyerRepository({required this.firestore});

  /// Only published listings. `priceCart` in server/checkout.js rejects
  /// anything that is not explicitly `isActive == true`.
  Query<Map<String, dynamic>> get _liveProducts =>
      firestore.collection('products').where('isActive', isEqualTo: true);

  @override
  Stream<List<Product>> watchProducts() => _liveProducts.snapshots().map(
    (snapshot) => snapshot.docs.map(_productFromDocument).toList(),
  );

  @override
  Future<PlatformFeeSettings> getPlatformFeeSettings() async {
    final snapshot = await firestore
        .collection('settings')
        .doc('platform_economics')
        .get();
    return PlatformFeeSettings.fromMap(snapshot.data());
  }

  @override
  Stream<List<PublicCreator>> watchPublicCreators() => firestore
      .collection('creator_profiles')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map((document) {
          final data = document.data();
          return PublicCreator(
            uid: data['uid'] as String? ?? document.id,
            name: data['name'] as String? ?? '',
            businessName: data['businessName'] as String? ?? '',
            profileImage: data['profileImage'] as String? ?? '',
            bio: data['bio'] as String? ?? '',
            location: data['location'] as String? ?? '',
            socialLinks: List<String>.from(
              data['socialLinks'] as List? ?? const [],
            ),
            portfolio: List<String>.from(
              data['portfolio'] as List? ?? const [],
            ),
            exhibitionPictures: List<String>.from(
              data['exhibitionPictures'] as List? ?? const [],
            ),
            story: data['story'] as String? ?? '',
            isVerified: data['verificationStatus'] == 'Verified',
          );
        }).toList(),
      );

  // The admin-managed `categories` collection is the single source of truth
  // for which categories exist anywhere in the app — no hardcoded fallback
  // here. Whatever admin has configured (including nothing) is what shows.
  @override
  Stream<List<String>> watchCategories() =>
      firestore.collection('categories').snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => (doc.data()['name'] as String? ?? '').trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
      });

  @override
  Stream<Set<String>> watchFavoriteProductIds(String userId) => firestore
      .collection('users')
      .doc(userId)
      .collection('favorites')
      .snapshots()
      .handleError((_) => const <String>{})
      .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());

  @override
  Future<void> setFavorite({
    required String userId,
    required String productId,
    required bool isFavorite,
  }) async {
    final reference = firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(productId);
    final existing = await reference.get();
    if (existing.exists == isFavorite) return;
    if (isFavorite) {
      await reference.set({
        'productId': productId,
        'savedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await reference.delete();
    }
    // Wishlist saves feed the home "popular" ranking. Best effort: the
    // favourite itself is already stored.
    try {
      await firestore.collection('products').doc(productId).update({
        'wishlistCount': FieldValue.increment(isFavorite ? 1 : -1),
      });
    } catch (_) {}
  }

  @override
  Stream<List<BuyerOrder>> watchOrders(String userId) => firestore
      .collection('orders')
      .where('buyerId', isEqualTo: userId)
      .snapshots()
      .handleError((_) => const <BuyerOrder>[])
      .map((snapshot) {
        final orders = snapshot.docs.map(_orderFromDocument).toList();
        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return orders;
      });

  @override
  Stream<List<BuyerProductNotification>> watchNewProductNotifications(
    String userId,
  ) {
    late final StreamController<List<BuyerProductNotification>> controller;
    StreamSubscription? productSubscription;
    StreamSubscription? favoriteSubscription;
    StreamSubscription? orderSubscription;
    QuerySnapshot<Map<String, dynamic>>? productSnapshot;
    QuerySnapshot<Map<String, dynamic>>? favoriteSnapshot;
    QuerySnapshot<Map<String, dynamic>>? orderSnapshot;

    void emitNotifications() {
      final products = productSnapshot;
      final favorites = favoriteSnapshot;
      final orders = orderSnapshot;
      if (products == null || favorites == null || orders == null) return;

      final productsById = {
        for (final document in products.docs) document.id: document,
      };
      final wishlistedSince = <String, DateTime>{};
      final purchasedSince = <String, DateTime>{};
      final excludedProductIds = <String>{};
      final fallbackInterestDate = DateTime.now();

      void rememberInterest(
        Map<String, DateTime> interests,
        String category,
        DateTime since,
      ) {
        final normalized = _normalizeCategory(category);
        if (normalized.isEmpty) return;
        final existing = interests[normalized];
        if (existing == null || since.isBefore(existing)) {
          interests[normalized] = since;
        }
      }

      for (final favorite in favorites.docs) {
        final productId =
            favorite.data()['productId'] as String? ?? favorite.id;
        final product = productsById[productId];
        if (product == null) continue;
        excludedProductIds.add(productId);
        rememberInterest(
          wishlistedSince,
          product.data()['category'] as String? ?? '',
          _timestamp(favorite.data()['savedAt']) ?? fallbackInterestDate,
        );
      }

      for (final order in orders.docs) {
        final data = order.data();
        final orderedAt = _timestamp(data['createdAt']) ?? fallbackInterestDate;
        final items = data['items'] as List<dynamic>? ?? const [];
        for (final rawItem in items.whereType<Map>()) {
          final item = Map<String, dynamic>.from(rawItem);
          final productId = item['productId'] as String? ?? '';
          if (productId.isNotEmpty) excludedProductIds.add(productId);
          final category =
              item['category'] as String? ??
              productsById[productId]?.data()['category'] as String? ??
              '';
          rememberInterest(purchasedSince, category, orderedAt);
        }
      }

      final notifications = <BuyerProductNotification>[];
      for (final document in products.docs) {
        final data = document.data();
        if (data['isActive'] != true ||
            excludedProductIds.contains(document.id)) {
          continue;
        }
        final publishedAt =
            _timestamp(data['approvedAt']) ?? _timestamp(data['createdAt']);
        if (publishedAt == null) continue;
        final category = data['category'] as String? ?? '';
        final normalizedCategory = _normalizeCategory(category);
        final wishlistDate = wishlistedSince[normalizedCategory];
        final purchaseDate = purchasedSince[normalizedCategory];
        final matchesWishlist =
            wishlistDate != null && publishedAt.isAfter(wishlistDate);
        final matchesPurchase =
            purchaseDate != null && publishedAt.isAfter(purchaseDate);
        if (!matchesWishlist && !matchesPurchase) continue;

        notifications.add(
          BuyerProductNotification(
            id: document.id,
            product: _productFromDocument(document),
            category: category,
            publishedAt: publishedAt,
            reason: matchesWishlist && matchesPurchase
                ? BuyerProductNotificationReason.both
                : matchesWishlist
                ? BuyerProductNotificationReason.wishlisted
                : BuyerProductNotificationReason.purchased,
          ),
        );
      }
      notifications.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      if (!controller.isClosed) controller.add(notifications);
    }

    controller = StreamController<List<BuyerProductNotification>>(
      onListen: () {
        productSubscription = _liveProducts.snapshots().listen((snapshot) {
              productSnapshot = snapshot;
              emitNotifications();
            }, onError: controller.addError);
        favoriteSubscription = firestore
            .collection('users')
            .doc(userId)
            .collection('favorites')
            .snapshots()
            .listen((snapshot) {
              favoriteSnapshot = snapshot;
              emitNotifications();
            }, onError: controller.addError);
        orderSubscription = firestore
            .collection('orders')
            .where('buyerId', isEqualTo: userId)
            .snapshots()
            .listen((snapshot) {
              orderSnapshot = snapshot;
              emitNotifications();
            }, onError: controller.addError);
      },
      onCancel: () async {
        await productSubscription?.cancel();
        await favoriteSubscription?.cancel();
        await orderSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Stream<List<BuyerProductNotification>> watchBuyerNotifications(
    String userId,
  ) {
    late final StreamController<List<BuyerProductNotification>> controller;
    StreamSubscription<List<BuyerProductNotification>>? productSubscription;
    StreamSubscription<List<BuyerOrder>>? orderSubscription;
    List<BuyerProductNotification> products = const [];
    List<BuyerProductNotification> orders = const [];

    void emit() {
      final combined = [...products, ...orders]
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      if (!controller.isClosed) controller.add(combined);
    }

    controller = StreamController<List<BuyerProductNotification>>(
      onListen: () {
        productSubscription = watchNewProductNotifications(userId).listen((
          value,
        ) {
          products = value;
          emit();
        }, onError: controller.addError);
        orderSubscription = watchOrders(userId).listen((value) {
          orders = value
              .map(
                // Bucket to the buyer-facing status (confirmed / delivered /
                // rejected / cancelled) so intermediate creator fulfilment
                // transitions (processing, in_transit, shipped, out for
                // delivery) collapse into the same notification instead of
                // each spawning a separate one.
                (order) => BuyerProductNotification.order(
                  id: 'order-${order.id}-${OrderStatus.buyerStatus(order.status)}',
                  orderId: order.id,
                  orderStatus: order.status,
                  publishedAt: order.updatedAt ?? order.createdAt,
                  orderRejectionReason: order.rejectionReason,
                ),
              )
              .toList();
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await productSubscription?.cancel();
        await orderSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Stream<List<SavedAddress>> watchAddresses(String userId) => firestore
      .collection('users')
      .doc(userId)
      .collection('addresses')
      .snapshots()
      .map((snapshot) {
        final addresses = snapshot.docs.map(_addressFromDocument).toList();
        addresses.sort((a, b) {
          if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
          return a.label.compareTo(b.label);
        });
        return addresses;
      });

  @override
  Future<void> saveAddress(String userId, SavedAddress address) async {
    final collection = firestore
        .collection('users')
        .doc(userId)
        .collection('addresses');
    final reference = address.id.isEmpty
        ? collection.doc()
        : collection.doc(address.id);

    if (address.isDefault) {
      final batch = firestore.batch();
      final existing = await collection.get();
      for (final document in existing.docs) {
        batch.update(document.reference, {'isDefault': false});
      }
      batch.set(reference, _addressToMap(address));
      await batch.commit();
      return;
    }

    await reference.set(_addressToMap(address));
  }

  @override
  Future<void> deleteAddress(String userId, String addressId) => firestore
      .collection('users')
      .doc(userId)
      .collection('addresses')
      .doc(addressId)
      .delete();

  @override
  Stream<List<ProductReview>> watchProductReviews(String productId) => firestore
      .collection('products')
      .doc(productId)
      .collection('reviews')
      .snapshots()
      .map((snapshot) {
        final reviews = snapshot.docs.map(_reviewFromDocument).toList();
        reviews.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return reviews;
      });

  @override
  Future<ProductReviewEligibility> getProductReviewEligibility({
    required String buyerId,
    required String productId,
  }) async {
    final orders = await firestore
        .collection('orders')
        .where('buyerId', isEqualTo: buyerId)
        .get();
    for (final document in orders.docs) {
      final data = document.data();
      if (OrderStatus.normalize(data['status'] as String? ?? '') !=
          OrderStatus.delivered) {
        continue;
      }
      final items = data['items'] as List<dynamic>? ?? const [];
      final containsProduct = items.whereType<Map>().any(
        (item) => item['productId'] == productId,
      );
      if (containsProduct) {
        return ProductReviewEligibility.eligible(document.id);
      }
    }
    return const ProductReviewEligibility.ineligible();
  }

  @override
  Future<void> submitProductReview({
    required String buyerId,
    required String buyerName,
    required String productId,
    required int rating,
    required String comment,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(rating, 'rating', 'Must be between 1 and 5');
    }
    final normalizedComment = comment.trim();
    if (normalizedComment.length < 3 || normalizedComment.length > 1000) {
      throw ArgumentError.value(
        normalizedComment,
        'comment',
        'Must be between 3 and 1000 characters',
      );
    }
    final eligibility = await getProductReviewEligibility(
      buyerId: buyerId,
      productId: productId,
    );
    if (!eligibility.canReview) {
      throw StateError(eligibility.message);
    }

    final reference = firestore
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .doc(buyerId);
    final existing = await reference.get();
    await reference.set({
      'schemaVersion': 1,
      'productId': productId,
      'buyerId': buyerId,
      'buyerName': buyerName.trim().isEmpty ? 'Buyer' : buyerName.trim(),
      'rating': rating,
      'comment': normalizedComment,
      'verifiedPurchase': true,
      'orderId': eligibility.orderId,
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Product _productFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final categories = List<String>.from(
      data['categories'] as List? ?? const [],
    ).where((value) => value.trim().isNotEmpty).toList();
    final category =
        data['category'] as String? ??
        (categories.isNotEmpty ? categories.join(', ') : 'Handmade');
    final visual = _visualForCategory(
      categories.isNotEmpty ? categories.first : category,
    );
    final rawCustomizations =
        data['customizations'] as List<dynamic>? ?? const [];
    final customizations = rawCustomizations
        .whereType<Map>()
        .map((raw) {
          final customization = Map<String, dynamic>.from(raw);
          return BuyerProductCustomization(
            name: customization['name'] as String? ?? 'Customization',
            description: customization['description'] as String? ?? '',
            additionalPrice:
                (customization['additionalPrice'] as num?)?.round() ?? 0,
            images: List<String>.from(
              customization['images'] as List? ?? const [],
            ),
            isMultipleSelection:
                customization['isMultipleSelection'] as bool? ?? false,
            options: List<String>.from(
              customization['options'] as List? ?? const [],
            ).where((option) => option.trim().isNotEmpty).toList(),
          );
        })
        .where((customization) => customization.name.trim().isNotEmpty)
        .toList();
    final stock = (data['stock'] as num?)?.round() ?? 0;
    return Product(
      id: document.id,
      name: data['name'] as String? ?? 'Handmade piece',
      artisan:
          data['creatorName'] as String? ??
          data['artisan'] as String? ??
          data['sellerName'] as String? ??
          'MadeByHands artisan',
      category: category,
      categories: categories,
      description: data['description'] as String? ?? '',
      price: (data['price'] as num?)?.round() ?? 0,
      rating:
          (data['ratingAverage'] as num?)?.toDouble() ??
          (data['rating'] as num?)?.toDouble() ??
          0,
      color: Color((data['colorValue'] as num?)?.toInt() ?? visual.$1),
      icon: visual.$2,
      // Products exist with either spelling; server/checkout.js and
      // firestore.rules both accept creatorUid or creatorId.
      creatorUid: _creatorUid(data),
      images: List<String>.from(
        data['images'] as List? ?? const [],
      ).where((url) => url.trim().isNotEmpty).toList(),
      stock: stock,
      isAvailable: data['isActive'] == true && stock > 0,
      materials: data['materials'] as String? ?? '',
      dimensions: data['dimensions'] as String? ?? '',
      shippingInfo: data['shippingInfo'] as String? ?? '',
      isCustomizable: data['isCustomizable'] as bool? ?? false,
      customizations: customizations,
      orderCount: math.max(0, (data['orderCount'] as num?)?.round() ?? 0),
      wishlistCount: math.max(0, (data['wishlistCount'] as num?)?.round() ?? 0),
    );
  }

  BuyerOrder _orderFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final rawItems = data['items'] as List<dynamic>? ?? const [];
    final items = rawItems.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      return BuyerOrderItem(
        productId: item['productId'] as String? ?? '',
        name: item['name'] as String? ?? 'Handmade item',
        image: item['image'] as String? ?? '',
        quantity: (item['quantity'] as num?)?.round() ?? 1,
        unitPrice: (item['unitPrice'] as num?)?.round() ?? 0,
        baseUnitPrice:
            (item['baseUnitPrice'] as num?)?.round() ??
            (item['unitPrice'] as num?)?.round() ??
            0,
        customizationPrice: (item['customizationPrice'] as num?)?.round() ?? 0,
        customizations: _customizations(item['customizations']),
      );
    }).toList();
    final address = data['shippingAddress'] ?? data['deliveryAddress'];
    final createdAt =
        _timestamp(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final subtotal =
        (data['subtotal'] as num?)?.round() ??
        (data['totalAmount'] as num?)?.round() ??
        (data['total'] as num?)?.round() ??
        items.fold<int>(0, (total, item) => total + item.total);
    final platformFee = (data['flatFee'] as num?)?.round() ?? 0;
    return BuyerOrder(
      id: document.id,
      createdAt: createdAt,
      updatedAt: _timestamp(data['updatedAt']) ?? createdAt,
      deliveredAt: _timestamp(data['deliveredAt']),
      status: OrderStatus.normalize(data['status'] as String? ?? 'Placed'),
      total:
          (data['buyerPayableAmount'] as num?)?.round() ??
          subtotal + platformFee,
      subtotal: subtotal,
      platformFee: platformFee,
      buyerName: (data['buyerName'] as String?)?.trim().isNotEmpty == true
          ? (data['buyerName'] as String).trim()
          : 'Customer',
      refundStatus: data['refundStatus'] as String?,
      items: items,
      deliveryAddress: address is Map
          ? [
              address['addressLine'],
              address['city'],
              address['state'],
              address['postalCode'],
            ].whereType<String>().where((value) => value.isNotEmpty).join(', ')
          : address as String? ?? 'Address unavailable',
      rejectionReason: data['rejectionReason'] as String?,
      consignmentNumber: data['consignmentNumber'] as String?,
      carrierName: data['carrierName'] as String?,
      trackingUrl: data['trackingUrl'] as String?,
      lastLocation: data['lastLocation'] as String?,
      trackingUpdatedAt: _timestamp(data['trackingUpdatedAt']),
    );
  }

  String _creatorUid(Map<String, dynamic> data) {
    final uid = data['creatorUid'] as String? ?? '';
    if (uid.isNotEmpty) return uid;
    return data['creatorId'] as String? ?? '';
  }

  DateTime? _timestamp(Object? value) => value is Timestamp
      ? value.toDate()
      : value is DateTime
      ? value
      : null;

  String _normalizeCategory(String value) => value.trim().toLowerCase();

  Map<String, List<String>> _customizations(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): entry.value is List
            ? List<String>.from(entry.value as List)
            : [entry.value.toString()],
    };
  }

  SavedAddress _addressFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return SavedAddress(
      id: document.id,
      label: data['label'] as String? ?? 'Address',
      recipientName: data['recipientName'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      addressLine: data['addressLine'] as String? ?? '',
      city: data['city'] as String? ?? '',
      state: data['state'] as String? ?? '',
      postalCode: data['postalCode'] as String? ?? '',
      isDefault: data['isDefault'] as bool? ?? false,
    );
  }

  ProductReview _reviewFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final createdAt =
        _timestamp(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return ProductReview(
      id: document.id,
      buyerId: data['buyerId'] as String? ?? '',
      buyerName: data['buyerName'] as String? ?? 'Buyer',
      rating: ((data['rating'] as num?)?.round() ?? 0).clamp(1, 5),
      comment: data['comment'] as String? ?? '',
      verifiedPurchase: data['verifiedPurchase'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt: _timestamp(data['updatedAt']) ?? createdAt,
    );
  }

  Map<String, dynamic> _addressToMap(SavedAddress address) => {
    'label': address.label,
    'recipientName': address.recipientName,
    'phone': address.phone,
    'addressLine': address.addressLine,
    'city': address.city,
    'state': address.state,
    'postalCode': address.postalCode,
    'isDefault': address.isDefault,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Placeholder colour and icon shown until the product photo loads. The
  /// icons are constants so release builds can tree-shake the icon font.
  (int, IconData) _visualForCategory(String category) {
    final value = category.toLowerCase();
    if (value.contains('paint') || value.contains('art')) {
      return (0xFFE7C889, Icons.palette_outlined);
    }
    if (value.contains('pottery') || value.contains('ceramic') || value.contains('clay')) {
      return (0xFFAFC9D6, Icons.local_florist_outlined);
    }
    if (value.contains('jewel') || value.contains('fashion')) {
      return (0xFFD8D6D1, Icons.diamond_outlined);
    }
    if (value.contains('textile') || value.contains('fiber')) {
      return (0xFFE8AA91, Icons.checkroom_outlined);
    }
    if (value.contains('home') || value.contains('decor') || value.contains('décor')) {
      return (0xFFB8C99D, Icons.chair_outlined);
    }
    if (value.contains('paper') || value.contains('book')) {
      return (0xFFEAD9C6, Icons.menu_book_outlined);
    }
    return (0xFFD8BE8B, Icons.handyman_outlined);
  }
}
