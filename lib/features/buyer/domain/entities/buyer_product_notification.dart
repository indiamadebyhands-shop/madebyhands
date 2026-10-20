import 'package:madebyhands/features/buyer/domain/entities/product.dart';
import 'package:madebyhands/features/orders/domain/order_status.dart';

enum BuyerProductNotificationReason { wishlisted, purchased, both }

enum BuyerNotificationType { newProduct, order, support }

class BuyerProductNotification {
  final String id;
  final Product? product;
  final String category;
  final DateTime publishedAt;
  final BuyerProductNotificationReason? reason;
  final BuyerNotificationType type;
  final String? orderId;
  final String? orderStatus;
  final String? orderRejectionReason;
  final String? customTitle;
  final String? customMessage;

  const BuyerProductNotification({
    required this.id,
    required this.product,
    required this.category,
    required this.publishedAt,
    required this.reason,
    this.type = BuyerNotificationType.newProduct,
    this.orderId,
    this.orderStatus,
    this.orderRejectionReason,
    this.customTitle,
    this.customMessage,
  });

  const BuyerProductNotification.order({
    required this.id,
    required this.orderId,
    required this.orderStatus,
    required this.publishedAt,
    this.orderRejectionReason,
  })  : product = null,
        category = '',
        reason = null,
        type = BuyerNotificationType.order,
        customTitle = null,
        customMessage = null;

  const BuyerProductNotification.support({
    required this.id,
    required String title,
    required String message,
    required this.publishedAt,
  })  : product = null,
        category = '',
        reason = null,
        type = BuyerNotificationType.support,
        orderId = null,
        orderStatus = null,
        orderRejectionReason = null,
        customTitle = title,
        customMessage = message;

  String get title {
    if (type == BuyerNotificationType.support) {
      return customTitle ?? 'Support Update';
    }
    if (type != BuyerNotificationType.order) return 'New in $category';
    final bucket = OrderStatus.buyerStatus(orderStatus ?? '');
    return switch (bucket) {
      OrderStatus.rejected || OrderStatus.cancelled => 'Order rejected',
      OrderStatus.delivered => 'Order delivered',
      OrderStatus.dispatched => 'Order dispatched',
      _ => 'Order accepted',
    };
  }

  String get message {
    if (type == BuyerNotificationType.support) {
      return customMessage ?? '';
    }
    if (type != BuyerNotificationType.order) {
      return switch (reason) {
        BuyerProductNotificationReason.wishlisted =>
          '${product!.artisan} added ${product!.name} in a category you have wishlisted.',
        BuyerProductNotificationReason.purchased =>
          '${product!.artisan} added ${product!.name} in a category you have purchased from.',
        BuyerProductNotificationReason.both =>
          '${product!.artisan} added ${product!.name} in a category you follow.',
        null => '',
      };
    }

    final bucket = OrderStatus.buyerStatus(orderStatus ?? '');
    if (bucket == OrderStatus.rejected || bucket == OrderStatus.cancelled) {
      final reason = (orderRejectionReason ?? '').trim();
      final reasonText = reason.isEmpty ? '' : ' Reason: $reason.';
      return 'Order #$orderId was rejected by the creator.$reasonText '
          'You will be refunded in full within 5 days.';
    }
    if (bucket == OrderStatus.delivered) {
      return 'Order #$orderId has been delivered.';
    }
    if (bucket == OrderStatus.dispatched) {
      return 'Order #$orderId has been dispatched. Track it with the details provided.';
    }
    return 'Order #$orderId has been accepted by the creator and is now being prepared.';
  }
}
