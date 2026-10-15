import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';
import 'package:madebyhands/features/buyer/domain/entities/buyer_product_notification.dart';
import 'package:madebyhands/features/buyer/domain/entities/product.dart';
import 'package:madebyhands/features/buyer/domain/entities/public_creator.dart';
import 'package:madebyhands/features/buyer/domain/entities/saved_address.dart';
import 'package:madebyhands/features/buyer/presentation/bloc/buyer_bloc.dart';
import 'package:madebyhands/features/buyer/presentation/bloc/buyer_cubit.dart';
import 'package:madebyhands/features/buyer/presentation/pages/order_history_page.dart';
import 'package:madebyhands/features/buyer/presentation/pages/buyer_notifications_page.dart';
import 'package:madebyhands/features/buyer/presentation/pages/buyer_account_page.dart';
import 'package:madebyhands/features/buyer/presentation/pages/category_details_page.dart';
import 'package:madebyhands/features/buyer/presentation/pages/checkout_page.dart';
import 'package:madebyhands/features/buyer/presentation/pages/product_details_page.dart';
import 'package:madebyhands/features/buyer/presentation/pages/public_creator_storefront_page.dart';
import 'package:madebyhands/features/buyer/presentation/pages/saved_addresses_page.dart';
import 'package:madebyhands/features/buyer/presentation/views/cart_tab.dart';
import 'package:madebyhands/features/buyer/presentation/views/home_tab.dart';
import 'package:madebyhands/features/buyer/presentation/views/profile_tab.dart';
import 'package:madebyhands/features/buyer/presentation/views/saved_tab.dart';
import 'package:madebyhands/features/buyer/presentation/views/search_tab.dart';
import 'package:madebyhands/features/buyer/presentation/theme/buyer_theme.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_background.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_empty_state.dart';
import 'package:madebyhands/init_dependencies.dart';
import 'package:madebyhands/features/support/presentation/pages/support_center_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BuyerDashboardPage extends StatefulWidget {
  final UserEntity user;
  final VoidCallback onLogout;

  const BuyerDashboardPage({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  State<BuyerDashboardPage> createState() => _BuyerDashboardPageState();
}

class _BuyerDashboardPageState extends State<BuyerDashboardPage> {
  late final BuyerCubit _navigationCubit;
  late UserEntity _currentUser;
  SavedAddress? _selectedAddress;
  List<BuyerProductNotification> _notifications = const [];
  final Set<String> _readNotificationIds = {};
  StreamSubscription<List<SavedAddress>>? _addressSubscription;
  StreamSubscription<List<BuyerProductNotification>>? _notificationSubscription;
  String? _pendingSharedProductId;
  String? _pendingSharedCreatorId;

  /// Category the Shop tab should filter by when opened from Home.
  final ValueNotifier<String?> _shopCategory = ValueNotifier(null);
  final ValueNotifier<String?> _shopSearch = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _navigationCubit = BuyerCubit();
    _pendingSharedProductId = Uri.base.queryParameters['product']?.trim();
    _pendingSharedCreatorId = Uri.base.queryParameters['creator']?.trim();
    // Initialize data streaming
    context.read<BuyerBloc>()
      ..add(BuyerWatchProducts())
      ..add(BuyerWatchCreators())
      ..add(BuyerWatchCategories())
      ..add(BuyerWatchFavorites(_currentUser.uid))
      ..add(BuyerLoadCart(_currentUser.uid));
    _restoreReadNotifications();
    final repository = context.read<BuyerBloc>().repository;
    _addressSubscription = repository.watchAddresses(_currentUser.uid).listen((
      addresses,
    ) {
      if (!mounted) return;
      final defaults = addresses.where((address) => address.isDefault);
      setState(() {
        _selectedAddress = defaults.isNotEmpty
            ? defaults.first
            : addresses.isNotEmpty
            ? addresses.first
            : null;
      });
    }, onError: (_) {});
    _notificationSubscription = repository
        .watchBuyerNotifications(_currentUser.uid)
        .listen((notifications) {
          if (!mounted) return;
          setState(() {
            _notifications = notifications;
            final activeIds = notifications
                .map((notification) => notification.id)
                .toSet();
            _readNotificationIds.removeWhere(
              (notificationId) => !activeIds.contains(notificationId),
            );
          });
        }, onError: (_) {});
  }

  Future<void> _restoreReadNotifications() async {
    List<String>? stored;
    try {
      final preferences = await SharedPreferences.getInstance();
      stored = preferences.getStringList(
        'buyer_read_notifications_${_currentUser.uid}',
      );
    } catch (_) {
      return;
    }
    if (!mounted || stored == null) return;
    final restoredIds = stored;
    setState(() => _readNotificationIds.addAll(restoredIds));
  }

  Future<void> _persistReadNotifications() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(
        'buyer_read_notifications_${_currentUser.uid}',
        _readNotificationIds.toList(),
      );
    } catch (_) {
      // Read state still remains available for the current session.
    }
  }

  @override
  void dispose() {
    _shopCategory.dispose();
    _shopSearch.dispose();
    _navigationCubit.close();
    _addressSubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _openProduct(Product initialProduct) {
    final buyerBloc = context.read<BuyerBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: buyerBloc,
          child: BlocBuilder<BuyerBloc, BuyerState>(
            buildWhen: (previous, current) =>
                previous.products != current.products ||
                previous.favoriteIds != current.favoriteIds ||
                previous.cartQuantities != current.cartQuantities ||
                previous.cartCustomizations != current.cartCustomizations ||
                previous.creators != current.creators,
            builder: (context, state) {
              // Show live stock and price when the listing changes.
              final product =
                  state.products
                      .where((item) => item.id == initialProduct.id)
                      .firstOrNull ??
                  initialProduct;
              final artisanName = product.artisan.trim().toLowerCase();
              final productCreator = state.creators.where((creator) {
                if (product.creatorUid.isNotEmpty &&
                    creator.uid == product.creatorUid) {
                  return true;
                }
                if (artisanName.isEmpty) return false;
                return creator.displayName.trim().toLowerCase() ==
                        artisanName ||
                    creator.name.trim().toLowerCase() == artisanName;
              }).firstOrNull;
              return ProductDetailsPage(
                product: product,
                isSaved: state.favoriteIds.contains(product.id),
                cartQuantity: state.cartQuantities[product.id] ?? 0,
                cartCount: state.cartQuantities.values.fold(
                  0,
                  (total, quantity) => total + quantity,
                ),
                onSave: () => buyerBloc.add(
                  BuyerToggleFavorite(
                    userId: _currentUser.uid,
                    product: product,
                  ),
                ),
                onCartQuantityChanged: (quantity) {
                  buyerBloc.add(BuyerUpdateCartQuantity(product, quantity));
                },
                customizationSelection:
                    state.cartCustomizations[product.id] ??
                    const ProductCustomizationSelection(),
                onCustomizationChanged: (selection) => buyerBloc.add(
                  BuyerUpdateProductCustomization(product, selection),
                ),
                onOpenCart: _openCart,
                onOpenWishlist: _openWishlist,
                onOpenSearch: _openSearch,
                onBuyNow: (selection) => _openBuyNow(
                  product,
                  state.cartQuantities[product.id] ?? 0,
                  selection,
                ),
                buyerRepository: buyerBloc.repository,
                buyerId: _currentUser.uid,
                buyerName: _currentUser.name,
                onCreatorTap: productCreator == null
                    ? null
                    : () => _openCreator(productCreator),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openPendingSharedProduct(BuyerState state) {
    final productId = _pendingSharedProductId;
    if (productId == null || productId.isEmpty) return;

    final matchingProducts = state.products.where(
      (product) => product.id == productId,
    );
    if (matchingProducts.isNotEmpty) {
      final product = matchingProducts.first;
      _pendingSharedProductId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openProduct(product);
      });
      return;
    }

    if (state.isLoadingProducts) return;
    _pendingSharedProductId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('This shared product is no longer available'),
          ),
        );
    });
  }

  void _openPendingSharedCreator(BuyerState state) {
    final creatorId = _pendingSharedCreatorId;
    if (creatorId == null || creatorId.isEmpty) return;

    final matchingCreators = state.creators.where(
      (creator) => creator.uid == creatorId,
    );
    if (matchingCreators.isNotEmpty) {
      final creator = matchingCreators.first;
      _pendingSharedCreatorId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openCreator(creator);
      });
      return;
    }

    if (state.creators.isEmpty) return;
    _pendingSharedCreatorId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('This shared creator profile is no longer available'),
          ),
        );
    });
  }

  void _openCreator(PublicCreator creator) {
    final buyerBloc = context.read<BuyerBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: buyerBloc,
          child: PublicCreatorStorefrontPage(
            creator: creator,
            buyerId: _currentUser.uid,
            onProductTap: _openProduct,
          ),
        ),
      ),
    );
  }

  void _openShop() {
    _navigationCubit.changePage(1);
  }

  void _openSearch() {
    final buyerBloc = context.read<BuyerBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: buyerBloc,
          child: BuyerBackground(
            child: Scaffold(
              appBar: AppBar(title: const Text('Search shop')),
              body: SearchTab(
                userId: _currentUser.uid,
                onProductTap: _openProduct,
                onCreatorTap: _openCreator,
                autofocusSearch: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openWishlist() {
    _navigationCubit.changePage(2);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openCart() {
    _navigationCubit.changePage(3);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openShopSearch(String query) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      _openShop();
      return;
    }
    _shopCategory.value = null;
    _shopSearch.value = normalizedQuery;
    _navigationCubit.changePage(1);
  }

  void _openShopCategory(String category) {
    final buyerBloc = context.read<BuyerBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: buyerBloc,
          child: CategoryDetailsPage(
            categoryTitle: category,
            userId: _currentUser.uid,
            onProductTap: _openProduct,
            onOpenCart: _openCart,
          ),
        ),
      ),
    );
  }

  void _openNotifications() {
    final buyerRepository = context.read<BuyerBloc>().repository;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BuyerNotificationsPage(
          notifications: _notifications,
          readNotificationIds: _readNotificationIds,
          onNotificationTap: (notification) {
            setState(() => _readNotificationIds.add(notification.id));
            _persistReadNotifications();
            if (notification.product != null) {
              _openProduct(notification.product!);
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrderHistoryPage(
                    userId: _currentUser.uid,
                    repository: buyerRepository,
                  ),
                ),
              );
            }
          },
          onMarkAllRead: () {
            setState(() {
              _readNotificationIds.addAll(
                _notifications.map((notification) => notification.id),
              );
            });
            _persistReadNotifications();
          },
        ),
      ),
    );
  }

  void _openCheckout() {
    final buyerBloc = context.read<BuyerBloc>();
    final state = buyerBloc.state;
    final products = state.products
        .where((product) => state.cartQuantities.containsKey(product.id))
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          user: _currentUser,
          products: products,
          quantities: Map<String, int>.from(state.cartQuantities),
          customizations: Map<String, ProductCustomizationSelection>.from(
            state.cartCustomizations,
          ),
          buyerRepository: buyerBloc.repository,
          onOrderPlaced: () {
            for (final product in products) {
              buyerBloc.add(BuyerUpdateCartQuantity(product, 0));
            }
          },
        ),
      ),
    );
  }

  void _openBuyNow(
    Product product,
    int cartQuantity,
    ProductCustomizationSelection customization,
  ) {
    final buyerBloc = context.read<BuyerBloc>();
    final quantity = cartQuantity > 0 ? cartQuantity : 1;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          user: _currentUser,
          products: [product],
          quantities: {product.id: quantity},
          customizations: {product.id: customization},
          buyerRepository: buyerBloc.repository,
          onOrderPlaced: () {
            if (buyerBloc.state.cartQuantities.containsKey(product.id)) {
              buyerBloc.add(BuyerUpdateCartQuantity(product, 0));
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Home keeps the app theme it was designed against; every other buyer
    // surface, including dialogs opened from the tabs, uses the buyer theme.
    final appTheme = Theme.of(context);
    return Theme(data: BuyerTheme.data, child: _buildShell(context, appTheme));
  }

  Widget _buildShell(BuildContext context, ThemeData appTheme) {
    return BlocProvider.value(
      value: _navigationCubit,
      child: BlocListener<BuyerBloc, BuyerState>(
        listenWhen: (previous, current) {
          final hasNewError =
              current.errorMessage != null &&
              current.errorMessage != previous.errorMessage &&
              current.products.isNotEmpty;
          final sharedProductStateChanged =
              _pendingSharedProductId != null &&
              (previous.products != current.products ||
                  previous.isLoadingProducts != current.isLoadingProducts);
          final sharedCreatorStateChanged =
              _pendingSharedCreatorId != null &&
              previous.creators != current.creators;
          return hasNewError ||
              sharedProductStateChanged ||
              sharedCreatorStateChanged;
        },
        listener: (context, state) {
          if (state.errorMessage != null && state.products.isNotEmpty) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
          _openPendingSharedProduct(state);
          _openPendingSharedCreator(state);
        },
        child: BlocBuilder<BuyerCubit, int>(
          builder: (context, selectedIndex) {
            return BlocBuilder<BuyerBloc, BuyerState>(
              // The tabs listen to the bloc themselves; the shell only swaps
              // between loading, error and content.
              buildWhen: (previous, current) =>
                  _shellMode(previous) != _shellMode(current),
              builder: (context, buyerState) {
                if (buyerState.isLoadingProducts &&
                    buyerState.products.isEmpty) {
                  return const BuyerBackground(
                    child: Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (buyerState.errorMessage != null &&
                    buyerState.products.isEmpty) {
                  return BuyerBackground(
                    child: Scaffold(
                      body: BuyerEmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Something went wrong',
                        message: buyerState.errorMessage!,
                      ),
                    ),
                  );
                }

                final pages = [
                  Theme(
                    data: appTheme,
                    child: HomeTab(
                      userName: _currentUser.name,
                      userId: _currentUser.uid,
                      onProductTap: _openProduct,
                      selectedAddress: _selectedAddress,
                      onAddressTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SavedAddressesPage(
                            userId: _currentUser.uid,
                            repository: context.read<BuyerBloc>().repository,
                          ),
                        ),
                      ),
                      onBrowseAll: _openShop,
                      onSearchSubmitted: _openShopSearch,
                      onCategoryTap: _openShopCategory,
                      onProfileTap: () => _navigationCubit.changePage(4),
                      unreadNotificationCount: _notifications
                          .where(
                            (notification) =>
                                !_readNotificationIds.contains(notification.id),
                          )
                          .length,
                      onNotificationsTap: _openNotifications,
                    ),
                  ),
                  BuyerTabFrame(
                    child: SearchTab(
                      userId: _currentUser.uid,
                      onProductTap: _openProduct,
                      onCreatorTap: _openCreator,
                      categoryRequest: _shopCategory,
                      searchRequest: _shopSearch,
                    ),
                  ),
                  BuyerTabFrame(
                    child: SavedTab(
                      userId: _currentUser.uid,
                      onProductTap: _openProduct,
                      onBrowse: () => _navigationCubit.changePage(1),
                    ),
                  ),
                  BuyerTabFrame(
                    child: CartTab(
                      onBrowse: () => _navigationCubit.changePage(1),
                      onCheckout: _openCheckout,
                      onProductTap: _openProduct,
                    ),
                  ),
                  BuyerTabFrame(
                    child: ProfileTab(
                      user: _currentUser,
                      onAccount: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BuyerAccountPage(
                            user: _currentUser,
                            repository: serviceLocator(),
                            onProfileUpdated: (user) {
                              if (mounted) setState(() => _currentUser = user);
                            },
                          ),
                        ),
                      ),
                      onOrders: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OrderHistoryPage(
                            userId: _currentUser.uid,
                            repository: context.read<BuyerBloc>().repository,
                          ),
                        ),
                      ),
                      onAddresses: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SavedAddressesPage(
                            userId: _currentUser.uid,
                            repository: context.read<BuyerBloc>().repository,
                          ),
                        ),
                      ),
                      onSupport: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BuyerBackground(
                            child: SupportCenterPage(
                              user: _currentUser,
                              repository: serviceLocator(),
                              pageWrapper: (page) =>
                                  BuyerBackground(child: page),
                            ),
                          ),
                        ),
                      ),
                      onLogout: widget.onLogout,
                    ),
                  ),
                ];

                final safeIndex = selectedIndex.clamp(0, pages.length - 1);

                return Scaffold(
                  backgroundColor: BuyerColors.paper,
                  body: IndexedStack(index: safeIndex, children: pages),
                  // The bar picks up the Home arch's look: the same cream,
                  // a gold hairline along its top edge, and a solid maroon
                  // pill behind the selected tab.
                  bottomNavigationBar: Container(
                    padding: const EdgeInsets.only(top: 1.2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDB98A),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF6B1D1D,
                          ).withValues(alpha: 0.10),
                          blurRadius: 14,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: NavigationBarTheme(
                        data: NavigationBarThemeData(
                          height: 78,
                          elevation: 0,
                          backgroundColor: const Color(0xFFFCF0DE),
                          surfaceTintColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          indicatorColor: const Color(0xFF8B261D),
                          iconTheme: WidgetStateProperty.resolveWith((states) {
                            return IconThemeData(
                              color: states.contains(WidgetState.selected)
                                  ? const Color(0xFFFCF0DE)
                                  : const Color(
                                      0xFF8B261D,
                                    ).withValues(alpha: 0.86),
                            );
                          }),
                          labelTextStyle: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            return GoogleFonts.montserrat(
                              fontSize: 11.5,
                              fontWeight: states.contains(WidgetState.selected)
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: states.contains(WidgetState.selected)
                                  ? const Color(0xFF8B261D)
                                  : const Color(
                                      0xFF8B261D,
                                    ).withValues(alpha: 0.86),
                            );
                          }),
                        ),
                        child: NavigationBar(
                          height: 78,
                          selectedIndex: safeIndex,
                          onDestinationSelected: _navigationCubit.changePage,
                          destinations: const [
                            NavigationDestination(
                              icon: Icon(Icons.home_outlined),
                              selectedIcon: Icon(Icons.home),
                              label: 'Home',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.search),
                              selectedIcon: Icon(Icons.search),
                              label: 'Shop',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.favorite_border),
                              selectedIcon: Icon(Icons.favorite),
                              label: 'Wishlist',
                            ),
                            NavigationDestination(
                              icon: _CartBadge(
                                icon: Icons.shopping_bag_outlined,
                              ),
                              selectedIcon: _CartBadge(
                                icon: Icons.shopping_bag,
                              ),
                              label: 'Cart',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.person_outline),
                              selectedIcon: Icon(Icons.person),
                              label: 'Account',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// 0 = loading, 1 = error, 2 = content.
  static int _shellMode(BuyerState state) {
    if (state.isLoadingProducts && state.products.isEmpty) return 0;
    if (state.errorMessage != null && state.products.isEmpty) return 1;
    return 2;
  }
}

class _CartBadge extends StatelessWidget {
  final IconData icon;

  const _CartBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BuyerBloc, BuyerState, int>(
      selector: (state) => state.cartQuantities.values.fold(
        0,
        (total, quantity) => total + quantity,
      ),
      builder: (context, count) => Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: Icon(icon),
      ),
    );
  }
}
