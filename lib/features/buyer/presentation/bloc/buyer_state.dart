part of 'buyer_bloc.dart';

class BuyerState extends Equatable {
  final List<Product> products;
  final List<PublicCreator> creators;

  /// Admin-managed category names for filters (see `categories` collection).
  final List<String> categories;
  final Set<String> favoriteIds;
  final Map<String, int> cartQuantities;
  final Map<String, ProductCustomizationSelection> cartCustomizations;
  final bool isLoadingProducts;
  final bool isLoadingFavorites;
  final bool isLoadingCart;
  final Set<String> pendingFavoriteIds;
  final Set<String> pendingCartProductIds;
  final String? errorMessage;

  const BuyerState({
    this.products = const [],
    this.creators = const [],
    this.categories = const [],
    this.favoriteIds = const {},
    this.cartQuantities = const {},
    this.cartCustomizations = const {},
    this.isLoadingProducts = false,
    this.isLoadingFavorites = false,
    this.isLoadingCart = false,
    this.pendingFavoriteIds = const {},
    this.pendingCartProductIds = const {},
    this.errorMessage,
  });

  BuyerState copyWith({
    List<Product>? products,
    List<PublicCreator>? creators,
    List<String>? categories,
    Set<String>? favoriteIds,
    Map<String, int>? cartQuantities,
    Map<String, ProductCustomizationSelection>? cartCustomizations,
    bool? isLoadingProducts,
    bool? isLoadingFavorites,
    bool? isLoadingCart,
    Set<String>? pendingFavoriteIds,
    Set<String>? pendingCartProductIds,
    String? errorMessage,
  }) {
    return BuyerState(
      products: products ?? this.products,
      creators: creators ?? this.creators,
      categories: categories ?? this.categories,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      cartQuantities: cartQuantities ?? this.cartQuantities,
      cartCustomizations: cartCustomizations ?? this.cartCustomizations,
      isLoadingProducts: isLoadingProducts ?? this.isLoadingProducts,
      isLoadingFavorites: isLoadingFavorites ?? this.isLoadingFavorites,
      isLoadingCart: isLoadingCart ?? this.isLoadingCart,
      pendingFavoriteIds: pendingFavoriteIds ?? this.pendingFavoriteIds,
      pendingCartProductIds:
          pendingCartProductIds ?? this.pendingCartProductIds,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    products,
    creators,
    categories,
    favoriteIds,
    cartQuantities,
    cartCustomizations,
    isLoadingProducts,
    isLoadingFavorites,
    isLoadingCart,
    pendingFavoriteIds,
    pendingCartProductIds,
    errorMessage,
  ];
}
