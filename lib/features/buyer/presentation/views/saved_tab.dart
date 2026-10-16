import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:madebyhands/features/buyer/domain/entities/product.dart';
import 'package:madebyhands/features/buyer/presentation/bloc/buyer_bloc.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_background.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_empty_state.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_heading.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/product_card.dart';

class SavedTab extends StatelessWidget {
  final String userId;
  final ValueChanged<Product> onProductTap;
  final VoidCallback onBrowse;

  const SavedTab({
    super.key,
    required this.userId,
    required this.onProductTap,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    return BuyerBackground(
      child: BlocBuilder<BuyerBloc, BuyerState>(
        buildWhen: (previous, current) =>
            previous.products != current.products ||
            previous.favoriteIds != current.favoriteIds ||
            previous.pendingFavoriteIds != current.pendingFavoriteIds ||
            previous.isLoadingFavorites != current.isLoadingFavorites,
        builder: (context, state) {
          final products = state.products
              .where((product) => state.favoriteIds.contains(product.id))
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.isLoadingFavorites)
                const LinearProgressIndicator(minHeight: 2),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: BuyerPageHeader(
                  title: 'Saved pieces',
                  subtitle: products.isEmpty
                      ? 'Pieces you love, kept in one place.'
                      : '${products.length} ${products.length == 1 ? 'piece' : 'pieces'} on your wishlist',
                ),
              ),
              Expanded(
                child: products.isEmpty
                    ? BuyerEmptyState(
                        icon: Icons.favorite_border,
                        title: 'Nothing saved yet',
                        message: 'Tap the heart on a product to keep it here.',
                        actionLabel: 'Browse products',
                        onAction: onBrowse,
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 240,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.65,
                            ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return ProductCard(
                            product: product,
                            isSaved: true,
                            isUpdating: state.pendingFavoriteIds.contains(
                              product.id,
                            ),
                            onTap: () => onProductTap(product),
                            onSave: () => _removeWithUndo(context, product),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _removeWithUndo(BuildContext context, Product product) {
    final bloc = context.read<BuyerBloc>();
    bloc.add(BuyerToggleFavorite(userId: userId, product: product));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${product.name} removed from wishlist'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              while (bloc.state.pendingFavoriteIds.contains(product.id)) {
                await Future<void>.delayed(const Duration(milliseconds: 40));
              }
              if (bloc.isClosed) return;
              if (!bloc.state.favoriteIds.contains(product.id)) {
                bloc.add(BuyerToggleFavorite(userId: userId, product: product));
              }
            },
          ),
        ),
      );
  }
}
