import 'dart:async';

import 'package:madebyhands/core/constants/product_categories.dart';
import 'package:madebyhands/features/buyer/data/mock_products.dart';
import 'package:madebyhands/features/buyer/domain/entities/buyer_order.dart';
import 'package:madebyhands/features/buyer/domain/entities/buyer_product_notification.dart';
import 'package:madebyhands/features/buyer/domain/entities/product.dart';
import 'package:madebyhands/features/buyer/domain/entities/product_review.dart';
import 'package:madebyhands/features/buyer/domain/entities/public_creator.dart';
import 'package:madebyhands/features/buyer/domain/entities/saved_address.dart';
import 'package:madebyhands/features/buyer/domain/repositories/buyer_repository.dart';
import 'package:madebyhands/features/orders/domain/entities/marketplace_order.dart';
import 'package:madebyhands/features/orders/domain/order_status.dart';

class MockBuyerRepository implements BuyerRepository {
  final List<BuyerProductNotification> productNotifications;
  final List<PublicCreator>? publicCreators;

  MockBuyerRepository({
    this.productNotifications = const [],
    this.publicCreators,
  });

  final Set<String> _favorites = {};
  final List<SavedAddress> _addresses = [
    const SavedAddress(
      id: 'home',
      label: 'Home',
      recipientName: 'Suhani',
      phone: '9876543210',
      addressLine: '21 Craft Lane',
      city: 'Jaipur',
      state: 'Rajasthan',
      postalCode: '302001',
      isDefault: true,
    ),
  ];
  final _favoriteChanges = StreamController<Set<String>>.broadcast();
  final _addressChanges = StreamController<List<SavedAddress>>.broadcast();
  final _reviewChanges = StreamController<String>.broadcast();
  final Map<String, List<ProductReview>> _reviews = {
    'blue-pottery': [
      ProductReview(
        id: 'buyer-sample',
        buyerId: 'buyer-sample',
        buyerName: 'Ananya',
        rating: 5,
        comment: 'Beautiful craftsmanship and very secure packaging.',
        verifiedPurchase: true,
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
      ),
    ],
  };

  List<BuyerOrder> get _orders => [
    BuyerOrder(
      id: 'MBH-24091',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      deliveredAt: DateTime.now().subtract(const Duration(hours: 3)),
      status: 'Delivered',
      total: 2198,
      items: const [
        BuyerOrderItem(
          productId: 'woven-basket',
          name: 'Handwoven Storage Basket',
          quantity: 1,
          unitPrice: 1299,
        ),
        BuyerOrderItem(
          productId: 'blue-pottery',
          name: 'Blue Pottery Vase',
          quantity: 1,
          unitPrice: 899,
        ),
      ],
      deliveryAddress: '21 Craft Lane, Jaipur, Rajasthan 302001',
      consignmentNumber: 'SP123456789IN',
      carrierName: 'India Post',
    ),
  ];

  @override
  Stream<List<Product>> watchProducts() => Stream.value(mockProducts);

  @override
  Future<PlatformFeeSettings> getPlatformFeeSettings() async =>
      const PlatformFeeSettings();

  @override
  Stream<List<String>> watchCategories() =>
      Stream.value(List<String>.of(kProductCategories));

  @override
  Stream<List<PublicCreator>> watchPublicCreators() => Stream.value(
    publicCreators ??
        const [
          PublicCreator(
            uid: 'creator-asha',
            name: 'Asha Weaves',
            businessName: 'Asha Weaves',
            bio: 'Handwoven homeware made with natural fibres.',
            location: 'Jaipur, Rajasthan',
            story:
                'A family weaving practice carried forward by local artisans.',
            isVerified: true,
          ),
          PublicCreator(
            uid: 'creator-jaipur-clay',
            name: 'Jaipur Clay Studio',
            location: 'Jaipur, Rajasthan',
            isVerified: true,
          ),
        ],
  );

  @override
  Stream<Set<String>> watchFavoriteProductIds(String userId) async* {
    yield Set.unmodifiable(_favorites);
    yield* _favoriteChanges.stream;
  }

  @override
  Future<void> setFavorite({
    required String userId,
    required String productId,
    required bool isFavorite,
  }) async {
    isFavorite ? _favorites.add(productId) : _favorites.remove(productId);
    _favoriteChanges.add(Set.unmodifiable(_favorites));
  }

  @override
  Stream<List<BuyerOrder>> watchOrders(String userId) => Stream.value(_orders);

  @override
  Stream<List<BuyerProductNotification>> watchNewProductNotifications(
    String userId,
  ) => Stream.value(List.unmodifiable(productNotifications));

  @override
  Stream<List<BuyerProductNotification>> watchBuyerNotifications(
    String userId,
  ) => Stream.value([
    ...productNotifications,
    ..._orders.map(
      (order) => BuyerProductNotification.order(
        id: 'order-${order.id}-${OrderStatus.buyerStatus(order.status)}',
        orderId: order.id,
        orderStatus: order.status,
        publishedAt: order.updatedAt ?? order.createdAt,
      ),
    ),
  ]);

  @override
  Stream<List<SavedAddress>> watchAddresses(String userId) async* {
    yield List.unmodifiable(_addresses);
    yield* _addressChanges.stream;
  }

  @override
  Future<void> saveAddress(String userId, SavedAddress address) async {
    if (address.isDefault) {
      for (var index = 0; index < _addresses.length; index++) {
        _addresses[index] = _addresses[index].copyWith(isDefault: false);
      }
    }
    final normalized = address.id.isEmpty
        ? address.copyWith(
            id: 'address-${DateTime.now().microsecondsSinceEpoch}',
          )
        : address;
    final index = _addresses.indexWhere((item) => item.id == normalized.id);
    index == -1 ? _addresses.add(normalized) : _addresses[index] = normalized;
    _addressChanges.add(List.unmodifiable(_addresses));
  }

  @override
  Future<void> deleteAddress(String userId, String addressId) async {
    _addresses.removeWhere((address) => address.id == addressId);
    _addressChanges.add(List.unmodifiable(_addresses));
  }

  @override
  Stream<List<ProductReview>> watchProductReviews(String productId) async* {
    yield List.unmodifiable(_reviews[productId] ?? const []);
    await for (final changedProductId in _reviewChanges.stream) {
      if (changedProductId == productId) {
        yield List.unmodifiable(_reviews[productId] ?? const []);
      }
    }
  }

  @override
  Future<ProductReviewEligibility> getProductReviewEligibility({
    required String buyerId,
    required String productId,
  }) async {
    for (final order in _orders) {
      if (OrderStatus.normalize(order.status) == OrderStatus.delivered &&
          order.items.any((item) => item.productId == productId)) {
        return ProductReviewEligibility.eligible(order.id);
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
    final eligibility = await getProductReviewEligibility(
      buyerId: buyerId,
      productId: productId,
    );
    if (!eligibility.canReview) {
      throw StateError(eligibility.message);
    }
    final reviews = _reviews.putIfAbsent(productId, () => []);
    final existingIndex = reviews.indexWhere(
      (review) => review.buyerId == buyerId,
    );
    final now = DateTime.now();
    final review = ProductReview(
      id: buyerId,
      buyerId: buyerId,
      buyerName: buyerName,
      rating: rating,
      comment: comment.trim(),
      verifiedPurchase: true,
      createdAt: existingIndex == -1 ? now : reviews[existingIndex].createdAt,
      updatedAt: now,
    );
    existingIndex == -1 ? reviews.add(review) : reviews[existingIndex] = review;
    _reviewChanges.add(productId);
  }
}
