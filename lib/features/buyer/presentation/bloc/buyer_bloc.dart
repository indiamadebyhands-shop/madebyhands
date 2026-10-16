import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:madebyhands/core/error/failures.dart';
import 'package:madebyhands/features/buyer/domain/entities/product.dart';
import 'package:madebyhands/features/buyer/domain/entities/public_creator.dart';
import 'package:madebyhands/features/buyer/domain/repositories/buyer_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'buyer_event.dart';
part 'buyer_state.dart';

class BuyerBloc extends Bloc<BuyerEvent, BuyerState> {
  final BuyerRepository _repository;
  StreamSubscription? _productSubscription;
  StreamSubscription? _favoriteSubscription;
  StreamSubscription? _creatorSubscription;
  StreamSubscription? _categorySubscription;
  String? _cartUserId;

  BuyerBloc({required BuyerRepository repository})
    : _repository = repository,
      super(const BuyerState()) {
    on<BuyerWatchProducts>(_onWatchProducts);
    on<BuyerProductsUpdated>(_onProductsUpdated);
    on<BuyerWatchFavorites>(_onWatchFavorites);
    on<BuyerWatchCreators>(_onWatchCreators);
    on<BuyerCreatorsUpdated>(_onCreatorsUpdated);
    on<BuyerLoadCart>(_onLoadCart);
    on<BuyerFavoritesUpdated>(_onFavoritesUpdated);
    on<BuyerToggleFavorite>(_onToggleFavorite);
    on<BuyerUpdateCartQuantity>(_onUpdateCartQuantity);
    on<BuyerUpdateProductCustomization>(_onUpdateProductCustomization);
    on<BuyerErrorOccurred>(_onErrorOccurred);
    on<BuyerWatchCategories>(_onWatchCategories);
    on<BuyerCategoriesUpdated>(
      (event, emit) => emit(state.copyWith(categories: event.categories)),
    );
    on<BuyerSessionEnded>(_onSessionEnded);
  }

  void _onWatchCategories(
    BuyerWatchCategories event,
    Emitter<BuyerState> emit,
  ) {
    _categorySubscription?.cancel();
    _categorySubscription = _repository.watchCategories().listen(
      (categories) => add(BuyerCategoriesUpdated(categories)),
      // Filters fall back to the default category list.
      onError: (_) {},
    );
  }

  Future<void> _cancelSubscriptions() async {
    for (final subscription in [
      _productSubscription,
      _favoriteSubscription,
      _creatorSubscription,
      _categorySubscription,
    ]) {
      await subscription?.cancel();
    }
    _productSubscription = null;
    _favoriteSubscription = null;
    _creatorSubscription = null;
    _categorySubscription = null;
  }

  Future<void> _onSessionEnded(
    BuyerSessionEnded event,
    Emitter<BuyerState> emit,
  ) async {
    await _cancelSubscriptions();
    _cartUserId = null;
    emit(const BuyerState());
  }

  void _onWatchCreators(BuyerWatchCreators event, Emitter<BuyerState> emit) {
    _creatorSubscription?.cancel();
    _creatorSubscription = _repository.watchPublicCreators().listen(
      (creators) => add(BuyerCreatorsUpdated(creators)),
      onError: (error) => add(BuyerErrorOccurred(friendlyErrorMessage(error))),
    );
  }

  void _onCreatorsUpdated(
    BuyerCreatorsUpdated event,
    Emitter<BuyerState> emit,
  ) => emit(state.copyWith(creators: event.creators));

  Future<void> _onLoadCart(
    BuyerLoadCart event,
    Emitter<BuyerState> emit,
  ) async {
    _cartUserId = event.userId;
    emit(state.copyWith(isLoadingCart: true));
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString('buyer_cart_${event.userId}');
      if (raw == null || raw.isEmpty) {
        emit(
          state.copyWith(
            cartQuantities: const {},
            cartCustomizations: const {},
            isLoadingCart: false,
          ),
        );
        return;
      }
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      var quantities = <String, int>{
        for (final entry in (decoded['quantities'] as Map? ?? const {}).entries)
          entry.key.toString(): (entry.value as num).round(),
      };
      final selections = <String, ProductCustomizationSelection>{};
      for (final entry
          in (decoded['customizations'] as Map? ?? const {}).entries) {
        final data = Map<String, dynamic>.from(entry.value as Map);
        selections[entry.key.toString()] = ProductCustomizationSelection(
          values: {
            for (final valueEntry
                in (data['values'] as Map? ?? const {}).entries)
              valueEntry.key.toString(): List<String>.from(
                valueEntry.value as List? ?? const [],
              ),
          },
          additionalPrice: (data['additionalPrice'] as num?)?.round() ?? 0,
        );
      }
      if (state.products.isNotEmpty) {
        quantities = _sanitizeCart(quantities, state.products);
        selections.removeWhere(
          (productId, _) => !quantities.containsKey(productId),
        );
      }
      emit(
        state.copyWith(
          cartQuantities: quantities,
          cartCustomizations: selections,
          isLoadingCart: false,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          cartQuantities: const {},
          cartCustomizations: const {},
          isLoadingCart: false,
        ),
      );
    }
  }

  BuyerRepository get repository => _repository;

  void _onWatchProducts(BuyerWatchProducts event, Emitter<BuyerState> emit) {
    emit(state.copyWith(isLoadingProducts: true));
    _productSubscription?.cancel();
    _productSubscription = _repository.watchProducts().listen(
      (products) => add(BuyerProductsUpdated(products)),
      onError: (err) => add(BuyerErrorOccurred(friendlyErrorMessage(err))),
    );
  }

  Future<void> _onProductsUpdated(
    BuyerProductsUpdated event,
    Emitter<BuyerState> emit,
  ) async {
    final quantities = _sanitizeCart(state.cartQuantities, event.products);
    final selections = Map<String, ProductCustomizationSelection>.from(
      state.cartCustomizations,
    )..removeWhere((productId, _) => !quantities.containsKey(productId));
    emit(
      state.copyWith(
        products: event.products,
        cartQuantities: quantities,
        cartCustomizations: selections,
        isLoadingProducts: false,
      ),
    );
    await _persistCart(quantities, selections);
  }

  void _onWatchFavorites(BuyerWatchFavorites event, Emitter<BuyerState> emit) {
    emit(state.copyWith(isLoadingFavorites: true));
    _favoriteSubscription?.cancel();
    _favoriteSubscription = _repository
        .watchFavoriteProductIds(event.userId)
        .listen(
          (ids) => add(BuyerFavoritesUpdated(ids)),
          onError: (_) =>
              add(const BuyerErrorOccurred('Could not load your wishlist.')),
        );
  }

  void _onFavoritesUpdated(
    BuyerFavoritesUpdated event,
    Emitter<BuyerState> emit,
  ) {
    emit(
      state.copyWith(favoriteIds: event.favoriteIds, isLoadingFavorites: false),
    );
  }

  Future<void> _onToggleFavorite(
    BuyerToggleFavorite event,
    Emitter<BuyerState> emit,
  ) async {
    if (state.pendingFavoriteIds.contains(event.product.id)) return;
    final isFavorite = state.favoriteIds.contains(event.product.id);
    final updatedFavorites = {...state.favoriteIds};
    isFavorite
        ? updatedFavorites.remove(event.product.id)
        : updatedFavorites.add(event.product.id);
    emit(
      state.copyWith(
        favoriteIds: updatedFavorites,
        pendingFavoriteIds: {...state.pendingFavoriteIds, event.product.id},
      ),
    );
    try {
      await _repository.setFavorite(
        userId: event.userId,
        productId: event.product.id,
        isFavorite: !isFavorite,
      );
    } catch (_) {
      emit(
        state.copyWith(
          favoriteIds: {...state.favoriteIds}
            ..remove(event.product.id)
            ..addAll(isFavorite ? [event.product.id] : const <String>[]),
        ),
      );
      add(const BuyerErrorOccurred('Could not update your wishlist.'));
    } finally {
      emit(
        state.copyWith(
          pendingFavoriteIds: {...state.pendingFavoriteIds}
            ..remove(event.product.id),
        ),
      );
    }
  }

  Future<void> _onUpdateCartQuantity(
    BuyerUpdateCartQuantity event,
    Emitter<BuyerState> emit,
  ) async {
    if (state.pendingCartProductIds.contains(event.product.id)) return;
    final newCart = Map<String, int>.from(state.cartQuantities);
    final customizations = Map<String, ProductCustomizationSelection>.from(
      state.cartCustomizations,
    );
    final availableStock = event.product.stock;
    final quantity = availableStock <= 0
        ? 0
        : event.quantity.clamp(0, availableStock);
    if (quantity <= 0) {
      newCart.remove(event.product.id);
      customizations.remove(event.product.id);
    } else {
      newCart[event.product.id] = quantity;
    }
    emit(
      state.copyWith(
        cartQuantities: newCart,
        cartCustomizations: customizations,
        pendingCartProductIds: {
          ...state.pendingCartProductIds,
          event.product.id,
        },
      ),
    );
    await _persistCart(newCart, customizations);
    emit(
      state.copyWith(
        pendingCartProductIds: {...state.pendingCartProductIds}
          ..remove(event.product.id),
      ),
    );
  }

  Future<void> _onUpdateProductCustomization(
    BuyerUpdateProductCustomization event,
    Emitter<BuyerState> emit,
  ) async {
    final customizations = Map<String, ProductCustomizationSelection>.from(
      state.cartCustomizations,
    );
    event.selection.isEmpty
        ? customizations.remove(event.product.id)
        : customizations[event.product.id] = event.selection;
    emit(state.copyWith(cartCustomizations: customizations));
    await _persistCart(state.cartQuantities, customizations);
  }

  Future<void> _persistCart(
    Map<String, int> quantities,
    Map<String, ProductCustomizationSelection> customizations,
  ) async {
    final userId = _cartUserId;
    if (userId == null || userId.isEmpty) return;
    try {
      final payload = jsonEncode({
        'quantities': quantities,
        'customizations': {
          for (final entry in customizations.entries)
            entry.key: {
              'values': entry.value.values,
              'additionalPrice': entry.value.additionalPrice,
            },
        },
      });
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('buyer_cart_$userId', payload);
    } catch (_) {
      // Cart remains usable in memory when platform storage is unavailable.
    }
  }

  Map<String, int> _sanitizeCart(
    Map<String, int> quantities,
    List<Product> products,
  ) {
    final productsById = {for (final product in products) product.id: product};
    final sanitized = <String, int>{};
    for (final entry in quantities.entries) {
      final product = productsById[entry.key];
      if (product == null || !product.isAvailable || product.stock <= 0) {
        continue;
      }
      sanitized[entry.key] = entry.value.clamp(1, product.stock);
    }
    return sanitized;
  }

  void _onErrorOccurred(BuyerErrorOccurred event, Emitter<BuyerState> emit) {
    emit(
      state.copyWith(
        errorMessage: event.message,
        isLoadingProducts: false,
        isLoadingFavorites: false,
        isLoadingCart: false,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _cancelSubscriptions();
    return super.close();
  }
}
