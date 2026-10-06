import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:madebyhands/core/error/failures.dart';
import 'package:madebyhands/core/theme/app_theme.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';
import 'package:madebyhands/features/auth/domain/repositories/auth_repository.dart';
import 'package:madebyhands/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:madebyhands/features/buyer/data/mock_buyer_repository.dart';
import 'package:madebyhands/features/buyer/data/mock_products.dart';
import 'package:madebyhands/features/buyer/domain/entities/buyer_product_notification.dart';
import 'package:madebyhands/features/buyer/domain/entities/product.dart';
import 'package:madebyhands/features/buyer/presentation/bloc/buyer_bloc.dart';
import 'package:madebyhands/features/buyer/presentation/pages/buyer_dashboard_page.dart';
import 'package:madebyhands/features/buyer/presentation/pages/buyer_account_page.dart';
import 'package:madebyhands/features/buyer/presentation/pages/checkout_page.dart';
import 'package:madebyhands/features/buyer/presentation/pages/product_details_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final buyer = UserEntity(
    uid: 'buyer-1',
    email: 'suhani@example.com',
    name: 'Suhani',
    role: 'buyer',
  );

  Widget buildDashboard({MockBuyerRepository? repository}) {
    return MaterialApp(
      theme: AppTheme.lightThemeMode,
      home: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                BuyerBloc(repository: repository ?? MockBuyerRepository())
                  ..add(BuyerWatchProducts())
                  ..add(BuyerWatchFavorites(buyer.uid)),
          ),
          // We provide a dummy AuthBloc since the UI needs it for Logout
          // but we won't trigger any real auth actions here
        ],
        child: BuyerDashboardPage(user: buyer, onLogout: () {}),
      ),
    );
  }

  testWidgets('buyer can browse and search products', (tester) async {
    await tester.pumpWidget(buildDashboard());
    await tester.pumpAndSettle();

    expect(find.text('Hello, Suhani'), findsOneWidget);
    expect(find.textContaining('21 Craft Lane'), findsOneWidget);
    expect(find.text('Interesting Facts & Stories'), findsOneWidget);
    expect(find.text('Shop by craft'), findsNothing);

    await tester.tap(find.text('Shop').last);
    await tester.pumpAndSettle();
    expect(find.text('Filter'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    expect(find.text('Filter by category'), findsOneWidget);
    expect(
      find.text('Paintings, Drawing, Fine Art & Traditional Art'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(
        CheckboxListTile,
        'Pottery, Ceramics, Clay & Sculpture',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.widgetWithText(
        CheckboxListTile,
        'Paintings, Drawing, Fine Art & Traditional Art',
      ),
    );
    await tester.pump();
    await tester.tap(
      find.widgetWithText(
        CheckboxListTile,
        'Pottery, Ceramics, Clay & Sculpture',
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Apply (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Filter (2)'), findsOneWidget);
    expect(find.text('Blue Pottery Vase'), findsOneWidget);
    expect(find.text('Handwoven Storage Basket'), findsNothing);

    await tester.tap(find.text('Clear'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'pottery');
    await tester.pump();

    expect(find.text('Blue Pottery Vase'), findsOneWidget);
  });

  testWidgets('home search finds products through category names', (
    tester,
  ) async {
    await tester.pumpWidget(buildDashboard());
    await tester.pumpAndSettle();

    final homeSearch = find.byType(TextField);
    expect(homeSearch, findsOneWidget);
    await tester.enterText(homeSearch, 'ceramics');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Explore handmade'), findsOneWidget);
    expect(find.text('Blue Pottery Vase'), findsOneWidget);
    expect(find.text('Handwoven Storage Basket'), findsNothing);
  });

  testWidgets('product details updates quantity and bag badge', (tester) async {
    await tester.pumpWidget(buildDashboard());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Shop').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'pottery');
    await tester.pump();
    await tester.ensureVisible(find.text('Blue Pottery Vase'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Pottery Vase'));
    await tester.pumpAndSettle();

    expect(find.text('Add to cart'), findsOneWidget);
    expect(find.textContaining('Buy now'), findsOneWidget);
    expect(find.byTooltip('Open cart'), findsOneWidget);

    await tester.tap(find.text('Add to cart'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNWidgets(2));
    expect(find.byTooltip('Increase quantity'), findsOneWidget);
    expect(find.byTooltip('Decrease quantity'), findsOneWidget);

    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsWidgets);

    await tester.tap(find.byTooltip('Open cart'));
    await tester.pumpAndSettle();
    expect(find.text('Your cart'), findsOneWidget);
    expect(find.text('Blue Pottery Vase'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('buyer receives and opens a matching new-product notification', (
    tester,
  ) async {
    final product = mockProducts.firstWhere(
      (item) => item.id == 'silver-earrings',
    );
    final repository = MockBuyerRepository(
      productNotifications: [
        BuyerProductNotification(
          id: product.id,
          product: product,
          category: product.category,
          publishedAt: DateTime(2026, 9, 28, 12),
          reason: BuyerProductNotificationReason.purchased,
        ),
      ],
    );
    await tester.pumpWidget(buildDashboard(repository: repository));
    await tester.pumpAndSettle();

    final notificationButton = find.byTooltip('Open notifications');
    expect(notificationButton, findsOneWidget);
    expect(
      find.descendant(of: notificationButton, matching: find.text('2')),
      findsOneWidget,
    );

    await tester.tap(notificationButton);
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('New in Jewellery'), findsOneWidget);
    expect(
      find.textContaining('category you have purchased from'),
      findsOneWidget,
    );

    await tester.tap(find.text('New in Jewellery'));
    await tester.pumpAndSettle();
    expect(find.text('Product details'), findsOneWidget);
    expect(find.byTooltip('Save item'), findsOneWidget);
  });

  testWidgets('buy now starts the direct checkout action', (tester) async {
    var buyNowPressed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightThemeMode,
        home: ProductDetailsPage(
          product: mockProducts.first,
          isSaved: false,
          cartQuantity: 0,
          cartCount: 0,
          onSave: () {},
          onCartQuantityChanged: (_) {},
          onOpenCart: () {},
          onBuyNow: (_) => buyNowPressed = true,
          onCustomizationChanged: (_) {},
          buyerRepository: MockBuyerRepository(),
          buyerId: buyer.uid,
          buyerName: buyer.name,
        ),
      ),
    );

    await tester.tap(find.textContaining('Buy now'));
    await tester.pump();

    expect(buyNowPressed, isTrue);
  });

  testWidgets(
    'buyer selects seller customizations and receives adjusted price',
    (tester) async {
      const product = Product(
        id: 'custom-journal',
        name: 'Personalized Journal',
        artisan: 'Paper Studio',
        category: 'Paper, Books & Stationery',
        description: 'A handmade journal.',
        price: 999,
        rating: 4.8,
        color: Color(0xFFD8BE8B),
        icon: Icons.menu_book_outlined,
        creatorUid: 'creator-paper',
        isCustomizable: true,
        customizations: [
          BuyerProductCustomization(
            name: 'Color',
            description: 'Choose the journal cover colour.',
            additionalPrice: 0,
            options: ['Forest green', 'Natural brown'],
          ),
          BuyerProductCustomization(
            name: 'Engraving',
            description: 'Choose the engraving format.',
            additionalPrice: 150,
            options: ['Initials', 'Full name'],
          ),
        ],
      );
      var latestSelection = const ProductCustomizationSelection();
      var buyNowSelection = const ProductCustomizationSelection();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightThemeMode,
          home: ProductDetailsPage(
            product: product,
            isSaved: false,
            cartQuantity: 0,
            cartCount: 0,
            onSave: () {},
            onCartQuantityChanged: (_) {},
            onOpenCart: () {},
            onBuyNow: (selection) => buyNowSelection = selection,
            onCustomizationChanged: (selection) => latestSelection = selection,
            buyerRepository: MockBuyerRepository(),
            buyerId: buyer.uid,
            buyerName: buyer.name,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Customize this product'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Forest green'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Full name'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Full name'));
      await tester.pump();

      expect(latestSelection.values['Color'], ['Forest green']);
      expect(latestSelection.values['Engraving'], ['Full name']);
      expect(latestSelection.additionalPrice, 150);
      expect(find.textContaining('₹1149'), findsOneWidget);

      await tester.tap(find.textContaining('Buy now'));
      expect(buyNowSelection.additionalPrice, 150);
      expect(buyNowSelection.values['Engraving'], ['Full name']);
    },
  );

  testWidgets('checkout opens product information and new address form', (
    tester,
  ) async {
    final product = mockProducts.first;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightThemeMode,
        home: CheckoutPage(
          user: buyer,
          products: [product],
          quantities: {product.id: 1},
          customizations: const {},
          buyerRepository: MockBuyerRepository(),
          onOrderPlaced: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Selected'), findsOneWidget);
    expect(find.textContaining('21 Craft Lane'), findsOneWidget);
    expect(find.text('Add new'), findsOneWidget);

    final productTile = find.byKey(ValueKey('checkout-product-${product.id}'));
    await tester.ensureVisible(productTile);
    await tester.pumpAndSettle();
    tester.widget<ListTile>(productTile).onTap!.call();
    await tester.pumpAndSettle();
    expect(find.text('Made by ${product.artisan}'), findsOneWidget);
    expect(find.text(product.description), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Price per item'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Price per item'), findsOneWidget);

    Navigator.of(tester.element(find.text('Price per item'))).pop();
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 1000),
      1000,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add new'));
    await tester.pumpAndSettle();
    expect(find.text('Add address'), findsOneWidget);
    expect(find.text('Recipient name'), findsOneWidget);
  });

  testWidgets('verified buyer can submit and edit a product review', (
    tester,
  ) async {
    final repository = MockBuyerRepository();
    final product = mockProducts.firstWhere(
      (item) => item.id == 'blue-pottery',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightThemeMode,
        home: ProductDetailsPage(
          product: product,
          isSaved: false,
          cartQuantity: 0,
          cartCount: 0,
          onSave: () {},
          onCartQuantityChanged: (_) {},
          onOpenCart: () {},
          onBuyNow: (_) {},
          onCustomizationChanged: (_) {},
          buyerRepository: repository,
          buyerId: buyer.uid,
          buyerName: buyer.name,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Reviews & ratings'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Reviews & ratings'), findsOneWidget);
    expect(find.text('Write a review'), findsOneWidget);
    expect(find.text('Verified purchase'), findsOneWidget);

    await tester.tap(find.text('Write a review'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('5 stars'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Your review'),
      'Loved the finish and careful packaging.',
    );
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();

    expect(
      find.text('Loved the finish and careful packaging.'),
      findsOneWidget,
    );
    expect(find.text('Edit your review'), findsOneWidget);
  });

  testWidgets('buyer cannot review a product without a delivered purchase', (
    tester,
  ) async {
    final product = mockProducts.firstWhere((item) => item.id == 'soy-candle');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightThemeMode,
        home: ProductDetailsPage(
          product: product,
          isSaved: false,
          cartQuantity: 0,
          cartCount: 0,
          onSave: () {},
          onCartQuantityChanged: (_) {},
          onOpenCart: () {},
          onBuyNow: (_) {},
          onCustomizationChanged: (_) {},
          buyerRepository: MockBuyerRepository(),
          buyerId: buyer.uid,
          buyerName: buyer.name,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Reviews & ratings'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('You can review this product after a delivered purchase.'),
      findsOneWidget,
    );
    expect(find.text('Write a review'), findsNothing);
  });

  testWidgets('buyer opens a creator profile and complete storefront', (
    tester,
  ) async {
    await tester.pumpWidget(buildDashboard());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Shop').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Asha');
    await tester.pumpAndSettle();

    final creatorTile = find.widgetWithText(ListTile, 'Asha Weaves');
    expect(creatorTile, findsOneWidget);
    await tester.tap(creatorTile);
    await tester.pumpAndSettle();

    expect(find.text('Creator story'), findsOneWidget);
    expect(find.text('Storefront · 1 product'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Handwoven Storage Basket'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    final storefrontProduct = find
        .ancestor(
          of: find.text('Handwoven Storage Basket'),
          matching: find.byType(InkWell),
        )
        .first;
    await tester.tap(storefrontProduct);
    await tester.pumpAndSettle();
    expect(find.text('Product details'), findsOneWidget);
    final detailsPage = tester.widget<ProductDetailsPage>(
      find.byType(ProductDetailsPage),
    );
    expect(detailsPage.product.materials, 'Natural dyed jute and cotton');
    expect(detailsPage.product.dimensions, '32 × 28 cm');
    await tester.scrollUntilVisible(
      find.text('Made by Asha Weaves'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Made by Asha Weaves'));
    await tester.pumpAndSettle();
    expect(find.text('Creator story'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final productDetailsScroll = find
        .descendant(
          of: find.byType(ProductDetailsPage),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(productDetailsScroll, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.textContaining('Natural dyed jute'), findsOneWidget);
    expect(find.textContaining('32 × 28 cm'), findsOneWidget);
  });

  testWidgets('buyer can open an order status notification', (tester) async {
    await tester.pumpWidget(buildDashboard());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Order delivered'), findsOneWidget);
    await tester.tap(find.text('Order delivered'));
    await tester.pumpAndSettle();
    expect(find.text('My orders'), findsOneWidget);
  });

  test('cart quantity is stock-limited and restored for the buyer', () async {
    final firstBloc = BuyerBloc(repository: MockBuyerRepository());
    addTearDown(firstBloc.close);
    firstBloc.add(const BuyerLoadCart('buyer-persistence'));
    firstBloc.add(BuyerWatchProducts());
    await firstBloc.stream.firstWhere((state) => state.products.isNotEmpty);
    final product = firstBloc.state.products.firstWhere(
      (item) => item.id == 'blue-pottery',
    );
    firstBloc.add(BuyerUpdateCartQuantity(product, 500));
    await firstBloc.stream.firstWhere(
      (state) => state.cartQuantities[product.id] == product.stock,
    );
    await Future<void>.delayed(Duration.zero);

    final restoredBloc = BuyerBloc(repository: MockBuyerRepository());
    addTearDown(restoredBloc.close);
    restoredBloc.add(BuyerWatchProducts());
    await restoredBloc.stream.firstWhere((state) => state.products.isNotEmpty);
    restoredBloc.add(const BuyerLoadCart('buyer-persistence'));
    await restoredBloc.stream.firstWhere(
      (state) => state.cartQuantities[product.id] == product.stock,
    );
    expect(restoredBloc.state.cartQuantities[product.id], product.stock);
  });

  testWidgets('buyer updates profile and deletes the account', (tester) async {
    final repository = _FakeAccountAuthRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightThemeMode,
        home: BlocProvider(
          create: (_) => AuthBloc(authRepository: repository),
          child: BuyerAccountPage(
            user: buyer,
            repository: repository,
            onProfileUpdated: (_) {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Suhani Mahajan');
    await tester.enterText(find.byType(TextFormField).at(1), '9876543210');
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(repository.updatedName, 'Suhani Mahajan');

    await tester.ensureVisible(find.text('Delete Account'));
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Why are you leaving? *'),
      'Switching to a different app',
    );
    await tester.tap(find.text('Permanently Delete'));
    await tester.pumpAndSettle();
    expect(repository.deletedUid, buyer.uid);
    expect(repository.deletedReason, 'Switching to a different app');
  });
}

class _FakeAccountAuthRepository implements AuthRepository {
  String? updatedName;
  String? deletedUid;
  String? deletedReason;

  @override
  Future<Either<Failure, UserEntity>> updateProfile({
    required String uid,
    required String name,
    required String phone,
  }) async {
    updatedName = name;
    return right(
      UserEntity(
        uid: uid,
        email: 'suhani@example.com',
        name: name,
        phone: phone,
        role: 'buyer',
      ),
    );
  }

  @override
  Future<Either<Failure, void>> deleteAccount(String uid, String reason) async {
    deletedUid = uid;
    deletedReason = reason;
    return right(null);
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async =>
      right(UserEntity(uid: 'buyer-1', email: '', name: '', role: 'buyer'));

  @override
  Future<Either<Failure, UserEntity>> signInWithGoogle() async =>
      getCurrentUser();

  @override
  Future<Either<Failure, UserEntity>> signInAsTestBuyer() async =>
      getCurrentUser();

  @override
  Future<Either<Failure, UserEntity>> signUpWithRole({
    required String uid,
    required String email,
    required String name,
    required String phone,
    required String role,
  }) async => getCurrentUser();

  @override
  Future<Either<Failure, void>> signOut() async => right(null);
}
