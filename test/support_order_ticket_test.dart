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

  testWidgets('general ticket form opens directly when user has no orders', (
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

    expect(find.text('Need help with my order'), findsNothing);
    expect(find.text('I need help with something else'), findsNothing);
    expect(find.text('Raise a support ticket'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Subject'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Describe the issue'),
      findsOneWidget,
    );
  });
}

class _FakeSupportRepository implements SupportRepository {
  final List<SupportOrderReference> orders;
  String? createdType;
  String? createdOrderId;
  String? createdMessage;

  _FakeSupportRepository({this.orders = const []});

  @override
  Future<String> createTicket({
    required String userId,
    required String userRole,
    required String userName,
    required String subject,
    required String message,
    String type = 'general',
    String? orderId,
  }) async {
    createdType = type;
    createdOrderId = orderId;
    createdMessage = message;
    return 'ticket-1';
  }

  @override
  Future<List<SupportOrderReference>> getValidOrders({
    required String userId,
    required String userRole,
  }) async => orders;

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
