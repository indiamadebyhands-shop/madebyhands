import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:madebyhands/features/buyer/domain/entities/product.dart';
import 'package:madebyhands/features/buyer/presentation/bloc/buyer_bloc.dart';
import 'package:madebyhands/features/buyer/presentation/theme/buyer_theme.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_background.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_empty_state.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_heading.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/product_thumbnail.dart';

class CartTab extends StatelessWidget {
  final VoidCallback onBrowse;
  final VoidCallback onCheckout;
  final ValueChanged<Product>? onProductTap;

  const CartTab({
    super.key,
    required this.onBrowse,
    required this.onCheckout,
    this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return BuyerBackground(
      child: BlocBuilder<BuyerBloc, BuyerState>(
        buildWhen: (previous, current) =>
            previous.products != current.products ||
            previous.cartQuantities != current.cartQuantities ||
            previous.cartCustomizations != current.cartCustomizations ||
            previous.pendingCartProductIds != current.pendingCartProductIds ||
            previous.isLoadingCart != current.isLoadingCart,
        builder: (context, state) {
          final productsInCart = state.products
              .where((product) => state.cartQuantities.containsKey(product.id))
              .toList();
          final itemCount = productsInCart.fold<int>(
            0,
            (total, product) => total + state.cartQuantities[product.id]!,
          );

          final subtotal = productsInCart.fold<int>(0, (total, product) {
            final selection =
                state.cartCustomizations[product.id] ??
                const ProductCustomizationSelection();
            return total +
                selection.unitPriceFor(product) *
                    state.cartQuantities[product.id]!;
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.isLoadingCart)
                const LinearProgressIndicator(minHeight: 2),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: BuyerPageHeader(
                  title: 'Your cart',
                  subtitle: productsInCart.isEmpty
                      ? 'Handmade pieces you are ready to buy.'
                      : '$itemCount ${itemCount == 1 ? 'item' : 'items'} ready for checkout',
                ),
              ),
              Expanded(
                child: productsInCart.isEmpty
                    ? BuyerEmptyState(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Your cart is empty',
                        message:
                            'Add a handmade piece and it will appear here.',
                        actionLabel: 'Start shopping',
                        onAction: onBrowse,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        itemCount: productsInCart.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final product = productsInCart[index];
                          final quantity = state.cartQuantities[product.id]!;
                          final customization =
                              state.cartCustomizations[product.id] ??
                              const ProductCustomizationSelection();
                          return _CartItemCard(
                            product: product,
                            quantity: quantity,
                            customization: customization,
                            isUpdating: state.pendingCartProductIds.contains(
                              product.id,
                            ),
                            onTap: onProductTap == null
                                ? null
                                : () => onProductTap!(product),
                          );
                        },
                      ),
              ),
              if (productsInCart.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  decoration: const BoxDecoration(
                    color: BuyerColors.card,
                    border: Border(top: BorderSide(color: BuyerColors.line)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Expanded(
                            child: Text(
                              'Subtotal',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: BuyerColors.body,
                              ),
                            ),
                          ),
                          Text(
                            '₹$subtotal',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: BuyerColors.maroon,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'A platform fee per creator is added at checkout.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: BuyerColors.muted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: onCheckout,
                        child: const Text('Review and place order'),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final Product product;
  final int quantity;
  final ProductCustomizationSelection customization;
  final bool isUpdating;
  final VoidCallback? onTap;

  const _CartItemCard({
    required this.product,
    required this.quantity,
    required this.customization,
    required this.isUpdating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unitPrice = customization.unitPriceFor(product);
    void setQuantity(int value) {
      if (isUpdating) return;
      final bloc = context.read<BuyerBloc>();
      bloc.add(BuyerUpdateCartQuantity(product, value));
      if (value > 0) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${product.name} removed from cart'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                while (bloc.state.pendingCartProductIds.contains(product.id)) {
                  await Future<void>.delayed(const Duration(milliseconds: 40));
                }
                if (bloc.isClosed) return;
                bloc.add(BuyerUpdateCartQuantity(product, quantity));
                if (!customization.isEmpty) {
                  bloc.add(
                    BuyerUpdateProductCustomization(product, customization),
                  );
                }
              },
            ),
          ),
        );
    }

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductThumbnail(product: product, size: 78, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BuyerHeading(
                      product.name,
                      size: 14.5,
                      color: BuyerColors.ink,
                      weight: FontWeight.w700,
                      maxLines: 2,
                    ),
                    if (!customization.isEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        customization.values.entries
                            .map(
                              (entry) =>
                                  '${entry.key}: ${entry.value.join(', ')}',
                            )
                            .join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BuyerColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '₹$unitPrice',
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: BuyerColors.maroon,
                            ),
                          ),
                        ),
                        _QuantityStepper(
                          quantity: quantity,
                          isUpdating: isUpdating,
                          onDecrease: isUpdating
                              ? null
                              : () => setQuantity(quantity - 1),
                          onIncrease: isUpdating || quantity >= product.stock
                              ? null
                              : () => setQuantity(quantity + 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pill-shaped − / count / + control.
class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final bool isUpdating;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  const _QuantityStepper({
    required this.quantity,
    required this.isUpdating,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    Widget button({
      required String tooltip,
      required IconData icon,
      required VoidCallback? onPressed,
    }) => IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      disabledColor: BuyerColors.goldSoft,
    );

    return Container(
      decoration: BoxDecoration(
        color: BuyerColors.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BuyerColors.gold, width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            tooltip: quantity == 1 ? 'Remove from cart' : 'Decrease quantity',
            icon: quantity == 1 ? Icons.delete_outline : Icons.remove,
            onPressed: onDecrease,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 22),
            child: isUpdating
                ? const Padding(
                    padding: EdgeInsets.all(4),
                    child: SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: BuyerColors.maroon,
                    ),
                  ),
          ),
          button(
            tooltip: 'Increase quantity',
            icon: Icons.add,
            onPressed: onIncrease,
          ),
        ],
      ),
    );
  }
}
