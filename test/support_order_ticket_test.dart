import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';
import 'package:madebyhands/features/support/domain/entities/support_ticket.dart';
import 'package:madebyhands/features/support/domain/repositories/support_repository.dart';
import 'package:madebyhands/features/support/presentation/pages/support_center_page.dart';

void main() {
  final buyer = UserEntity(
    uid: 'buyer-1',
    email: 'buyer@example.com',
    name: 'Test Buyer',
    role: 'buyer',
  );
  final creator = UserEntity(
    uid: 'creator-1',
    email: 'creator@example.com',
    name: 'Test Creator',
    role: 'creator',
  );

  testWidgets('buyer can attach an eligible order to a support ticket', (
    tester,
  ) async {
    final repository = _FakeSupportRepository(
      orders: [
        SupportOrderReference(
          id: 'order-12345678',
          createdAt: DateTime(2026, 10, 20, 14, 30),
          status: 'shipped',
          total: 1450,
          itemSummaries: const ['Blue pottery vase × 1'],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SupportCenterPage(user: buyer, repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Raise ticket'));
    await tester.pumpAndSettle();
    expect(find.text('Need help with my order'), findsOneWidget);
    expect(find.text('I need help with something else'), findsOneWidget);

    await tester.tap(find.text('Need help with my order'));
    await tester.pumpAndSettle();
    expect(find.text('Order #12345678'), findsOneWidget);
    expect(find.textContaining('Blue pottery vase'), findsOneWidget);

    await tester.tap(find.text('Order #12345678'));
    await tester.pumpAndSettle();

    expect(repository.createdType, 'order');
    expect(repository.createdOrderId, 'order-12345678');
    expect(repository.createdMessage, contains('Order ID: order-12345678'));
    expect(repository.createdMessage, contains('Status: Shipped'));
    expect(find.text('Help with order #12345678'), findsOneWidget);
  });

  testWidgets('user without orders can continue to a general ticket', (
    tester,
  ) async {
    final repository = _FakeSupportRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: SupportCenterPage(user: buyer, repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Raise ticket'));
    await tester.pumpAndSettle();

    expect(find.text('Need help with my order'), findsOneWidget);
    expect(find.text('I need help with something else'), findsOneWidget);

    await tester.tap(find.text('Need help with my order'));
    await tester.pumpAndSettle();
    expect(find.text('You have no orders'), findsOneWidget);
    expect(
      find.text(
        'You can still tell us what you need help with and continue the chat normally.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Raise a support ticket'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Subject'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Describe the issue'),
      findsOneWidget,
    );
  });

  testWidgets('creator can attach one of their products to a ticket', (
    tester,
  ) async {
    final repository = _FakeSupportRepository(
      products: const [
        SupportProductReference(
          id: 'product-1',
          name: 'Hand-painted clay bowl',
          status: 'Approved',
          price: 899,
          isActive: true,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SupportCenterPage(user: creator, repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Raise ticket'));
    await tester.pumpAndSettle();
    expect(find.text('Product related'), findsOneWidget);
    expect(find.text('Order related'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);

    await tester.tap(find.text('Product related'));
    await tester.pumpAndSettle();
    expect(find.text('Select a product'), findsOneWidget);
    expect(find.text('Hand-painted clay bowl'), findsOneWidget);

    await tester.tap(find.text('Hand-painted clay bowl'));
    await tester.pumpAndSettle();

    expect(repository.createdType, 'product');
    expect(repository.createdProductId, 'product-1');
    expect(repository.createdMessage, contains('Product ID: product-1'));
    expect(repository.createdMessage, contains('Status: Approved'));
    expect(
      find.text('Help with product: Hand-painted clay bowl'),
      findsOneWidget,
    );
  });
}

class _FakeSupportRepository implements SupportRepository {
  final List<SupportOrderReference> orders;
  final List<SupportProductReference> products;
  String? createdType;
  String? createdOrderId;
  String? createdProductId;
  String? createdMessage;

  _FakeSupportRepository({this.orders = const [], this.products = const []});

  @override
  Future<String> createTicket({
    required String userId,
    required String userRole,
    required String userName,
    required String subject,
    required String message,
    String type = 'general',
    String? orderId,
    String? productId,
  }) async {
    createdType = type;
    createdOrderId = orderId;
    createdProductId = productId;
    createdMessage = message;
    return 'ticket-1';
  }

  @override
  Future<List<SupportOrderReference>> getValidOrders({
    required String userId,
    required String userRole,
  }) async => orders;

  @override
  Future<List<SupportProductReference>> getCreatorProducts(
    String creatorId,
  ) async => products;

  @override
  Future<void> resolveTicket(String ticketId) async {}

  @override
  Future<void> sendMessage({
    required String ticketId,
    required String senderId,
    required String senderRole,
    required String message,
  }) async {}

  @override
  Stream<List<SupportTicket>> watchAllTickets() => Stream.value(const []);

  @override
  Stream<List<SupportMessage>> watchMessages(String ticketId) =>
      Stream.value(const []);

  @override
  Stream<List<SupportTicket>> watchUserTickets(String userId) =>
      Stream.value(const []);
}
