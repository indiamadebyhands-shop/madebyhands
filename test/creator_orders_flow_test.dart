import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:madebyhands/core/error/failures.dart';
import 'package:madebyhands/core/theme/app_theme.dart';
import 'package:madebyhands/features/buyer/domain/entities/buyer_order.dart';
import 'package:madebyhands/features/creator/domain/entities/creator_order.dart';
import 'package:madebyhands/features/creator/domain/entities/creator_profile.dart';
import 'package:madebyhands/features/creator/domain/repositories/creator_repository.dart';
import 'package:madebyhands/features/creator/presentation/bloc/creator_bloc.dart';
import 'package:madebyhands/features/creator/presentation/views/creator_orders_view.dart';
import 'package:madebyhands/init_dependencies.dart';

class _FakeCreatorRepository implements CreatorRepository {
  final List<CreatorOrder> orders;
  final updates = <({String orderId, String status})>[];

  _FakeCreatorRepository(this.orders);

  @override
  Stream<List<CreatorOrder>> watchCreatorOrders(String uid) =>
      Stream.value(orders);

  @override
  Future<Either<Failure, void>> updateOrderStatus(
    String orderId,
    String status, {
    String? consignmentNumber,
    String? carrierName,
  }) async {
    updates.add((orderId: orderId, status: status));
    return right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CreatorOrder _order(String status) => CreatorOrder(
  id: 'order-abc123',
  buyerId: 'b1',
  buyerName: 'Suhani',
  createdAt: DateTime(2026, 10, 1),
  status: status,
  totalAmount: 1299,
  items: const [
    BuyerOrderItem(
      productId: 'p1',
      name: 'Clay Vase',
      quantity: 1,
      unitPrice: 1299,
    ),
  ],
  deliveryAddress: '42 MG Road, Indore',
);

final _profile = CreatorProfile(
  uid: 'c1',
  name: 'Asha',
  profileImage: '',
  bio: '',
  location: '',
  socialLinks: const [],
  portfolio: const [],
  story: '',
  verificationStatus: 'Verified',
);

void main() {
  late _FakeCreatorRepository repository;

  Future<void> openOrder(WidgetTester tester, String status) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repository = _FakeCreatorRepository([_order(status)]);
    serviceLocator.registerSingleton<CreatorRepository>(repository);
    addTearDown(serviceLocator.reset);

    // Provided above MaterialApp, as in main.dart, so the bottom sheet and
    // dialogs (which live in the Navigator's overlay) can reach the bloc.
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => CreatorBloc(creatorRepository: repository),
        child: MaterialApp(
          theme: AppTheme.lightThemeMode,
          home: Scaffold(body: CreatorOrdersView(profile: _profile)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Out-for-delivery orders sit under the "Active" tab.
    await tester.tap(find.textContaining('Active'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Suhani').first);
    await tester.pumpAndSettle();
  }

  testWidgets('marking an order delivered asks for confirmation first', (
    tester,
  ) async {
    await openOrder(tester, 'out_for_delivery');

    await tester.tap(find.text('Mark as delivered'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm delivery'), findsOneWidget);
    expect(
      find.textContaining('Only mark this order as delivered'),
      findsOneWidget,
    );
    expect(repository.updates, isEmpty);

    // Confirming without ticking the box is refused.
    await tester.tap(find.text('Mark delivered'));
    await tester.pumpAndSettle();
    expect(
      find.text('Please confirm the statement above to continue.'),
      findsOneWidget,
    );
    expect(repository.updates, isEmpty);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark delivered'));
    await tester.pumpAndSettle();

    expect(repository.updates, hasLength(1));
    expect(repository.updates.single.status, 'Delivered');
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling the delivered confirmation changes nothing', (
    tester,
  ) async {
    await openOrder(tester, 'out_for_delivery');

    await tester.tap(find.text('Mark as delivered'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.updates, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
