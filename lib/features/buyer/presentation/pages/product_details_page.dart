import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:madebyhands/features/buyer/presentation/theme/buyer_theme.dart';
import 'package:madebyhands/features/buyer/domain/entities/product.dart';
import 'package:madebyhands/features/buyer/domain/entities/product_review.dart';
import 'package:madebyhands/features/buyer/domain/repositories/buyer_repository.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_background.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_heading.dart';
import 'package:share_plus/share_plus.dart';

class ProductDetailsPage extends StatefulWidget {
  final Product product;
  final bool isSaved;
  final int cartQuantity;
  final int cartCount;
  final VoidCallback onSave;
  final ValueChanged<int> onCartQuantityChanged;
  final VoidCallback onOpenCart;
  final VoidCallback? onOpenWishlist;
  final VoidCallback? onOpenSearch;
  final ValueChanged<ProductCustomizationSelection> onBuyNow;
  final ProductCustomizationSelection customizationSelection;
  final ValueChanged<ProductCustomizationSelection> onCustomizationChanged;
  final BuyerRepository buyerRepository;
  final String buyerId;
  final String buyerName;
  final VoidCallback? onCreatorTap;

  const ProductDetailsPage({
    super.key,
    required this.product,
    required this.isSaved,
    required this.cartQuantity,
    required this.cartCount,
    required this.onSave,
    required this.onCartQuantityChanged,
    required this.onOpenCart,
    this.onOpenWishlist,
    this.onOpenSearch,
    required this.onBuyNow,
    this.customizationSelection = const ProductCustomizationSelection(),
    required this.onCustomizationChanged,
    required this.buyerRepository,
    required this.buyerId,
    required this.buyerName,
    this.onCreatorTap,
  });

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  late bool _isSaved = widget.isSaved;
  late Future<ProductReviewEligibility> _reviewEligibility;
  late final Stream<List<ProductReview>> _reviews = widget.buyerRepository
      .watchProductReviews(widget.product.id);
  late Map<String, List<String>> _customizationValues;

  @override
  void initState() {
    super.initState();
    _reviewEligibility = _loadReviewEligibility();
    _customizationValues = {
      for (final entry in widget.customizationSelection.values.entries)
        entry.key: List<String>.from(entry.value),
    };
  }

  Future<ProductReviewEligibility> _loadReviewEligibility() =>
      widget.buyerRepository.getProductReviewEligibility(
        buyerId: widget.buyerId,
        productId: widget.product.id,
      );

  ProductCustomizationSelection get _customizationSelection {
    final values = <String, List<String>>{
      for (final entry in _customizationValues.entries)
        if (entry.value.any((value) => value.trim().isNotEmpty))
          entry.key: entry.value
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(),
    };
    final additionalPrice = widget.product.customizations
        .where((customization) => values.containsKey(customization.name))
        .fold<int>(
          0,
          (total, customization) => total + customization.additionalPrice,
        );
    return ProductCustomizationSelection(
      values: values,
      additionalPrice: additionalPrice,
    );
  }

  void _updateCustomization(String name, List<String> values) {
    setState(() {
      if (values.every((value) => value.trim().isEmpty)) {
        _customizationValues.remove(name);
      } else {
        _customizationValues[name] = values;
      }
    });
    widget.onCustomizationChanged(_customizationSelection);
  }

  Future<void> _shareProduct(BuildContext shareButtonContext) async {
    final product = widget.product;
    final productLink = Uri.https('www.madebyhands.shop', '/', {
      'product': product.id,
    });
    final renderBox = shareButtonContext.findRenderObject() as RenderBox?;

    try {
      await SharePlus.instance.share(
        ShareParams(
          title: product.name,
          subject: 'Check out ${product.name} on MadeByHands',
          text:
              'Check out ${product.name} by ${product.artisan} on '
              'MadeByHands: $productLink',
          sharePositionOrigin: renderBox == null
              ? null
              : renderBox.localToGlobal(Offset.zero) & renderBox.size,
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: productLink.toString()));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Product link copied')));
    }
  }

  @override
  void didUpdateWidget(covariant ProductDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSaved != widget.isSaved) {
      _isSaved = widget.isSaved;
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final customizationSelection = _customizationSelection;
    final unitPrice = customizationSelection.unitPriceFor(product);

    return BuyerBackground(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Product details'),
          actions: [
            if (widget.onOpenSearch != null)
              IconButton(
                tooltip: 'Search products',
                onPressed: widget.onOpenSearch,
                icon: const Icon(Icons.search_rounded),
              ),
            if (widget.onOpenWishlist != null)
              IconButton(
                tooltip: 'Open wishlist',
                onPressed: widget.onOpenWishlist,
                icon: const Icon(Icons.favorite_border_rounded),
              ),
            IconButton(
              tooltip: 'Open cart',
              onPressed: widget.onOpenCart,
              icon: Badge(
                isLabelVisible: widget.cartCount > 0,
                label: Text('${widget.cartCount}'),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            _ProductGallery(product: product),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 7,
                  child: Text(
                    product.categoryLabel.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: BuyerColors.maroon,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: _isSaved ? 'Remove from saved' : 'Save item',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          widget.onSave();
                          setState(() => _isSaved = !_isSaved);
                        },
                        icon: Icon(
                          _isSaved ? Icons.favorite : Icons.favorite_border,
                        ),
                        color: BuyerColors.maroon,
                      ),
                      Builder(
                        builder: (shareButtonContext) => IconButton(
                          tooltip: 'Share product',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _shareProduct(shareButtonContext),
                          icon: const Icon(Icons.share_outlined),
                          color: BuyerColors.maroon,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            BuyerHeading(
              product.name,
              size: 22,
              color: BuyerColors.ink,
              weight: FontWeight.w800,
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: widget.onCreatorTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: BuyerColors.blush,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 22,
                        color: BuyerColors.maroon,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Made by ${product.artisan}',
                        style: const TextStyle(
                          color: BuyerColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (widget.onCreatorTap != null)
                      const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: BuyerColors.maroon,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹$unitPrice',
                  style: const TextStyle(
                    fontSize: 23,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: BuyerColors.maroon,
                  ),
                ),
                if (customizationSelection.additionalPrice > 0) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        'includes ₹${customizationSelection.additionalPrice} customization',
                        style: const TextStyle(
                          fontSize: 12,
                          color: BuyerColors.body,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            const BuyerHeading('About this piece'),
            const SizedBox(height: 8),
            Text(
              product.description,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: BuyerColors.body,
              ),
            ),
            if (product.materials.isNotEmpty ||
                product.dimensions.isNotEmpty ||
                product.shippingInfo.isNotEmpty) ...[
              const SizedBox(height: 20),
              const BuyerHeading('Product information'),
              const SizedBox(height: 10),
              if (product.materials.isNotEmpty)
                _DetailLine(
                  icon: Icons.texture,
                  text: 'Materials: ${product.materials}',
                ),
              if (product.dimensions.isNotEmpty)
                _DetailLine(
                  icon: Icons.straighten,
                  text: 'Dimensions: ${product.dimensions}',
                ),
              if (product.shippingInfo.isNotEmpty)
                _DetailLine(
                  icon: Icons.local_shipping_outlined,
                  text: 'Estimated shipping: ${product.shippingInfo}',
                ),
            ],
            if (product.isCustomizable &&
                product.customizations.any((c) => c.options.isNotEmpty)) ...[
              const SizedBox(height: 10),
              _ProductCustomizationSection(
                product: product,
                values: _customizationValues,
                onChanged: _updateCustomization,
              ),
            ],
            const SizedBox(height: 18),
            const _DetailLine(
              icon: Icons.handyman_outlined,
              text: 'Handmade in India',
            ),
            if (product.isAvailable && product.stock > 0 && product.stock <= 5)
              _DetailLine(
                icon: Icons.inventory_2_outlined,
                text: 'Only ${product.stock} left',
              ),
            const SizedBox(height: 4),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _ProductReviewsSection(
              product: product,
              reviewStream: _reviews,
              buyerId: widget.buyerId,
              buyerName: widget.buyerName,
              repository: widget.buyerRepository,
              eligibility: _reviewEligibility,
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: BuyerColors.card,
            border: Border(top: BorderSide(color: BuyerColors.line)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: !product.isAvailable || product.stock <= 0
                      ? OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(
                            Icons.remove_shopping_cart_outlined,
                            size: 18,
                          ),
                          label: const _ButtonLabel('Out of stock'),
                          style: OutlinedButton.styleFrom(
                            padding: _barButtonPadding,
                          ),
                        )
                      : widget.cartQuantity == 0
                      ? OutlinedButton.icon(
                          onPressed: () {
                            widget.onCartQuantityChanged(1);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${product.name} added to cart'),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: _barButtonPadding,
                          ),
                          icon: const Icon(Icons.add_shopping_cart, size: 18),
                          label: const _ButtonLabel('Add to cart'),
                        )
                      : Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: BuyerColors.field,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: BuyerColors.maroon,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                tooltip: 'Decrease quantity',
                                onPressed: () => widget.onCartQuantityChanged(
                                  widget.cartQuantity - 1,
                                ),
                                icon: const Icon(Icons.remove, size: 20),
                              ),
                              Text(
                                '${widget.cartQuantity}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: BuyerColors.maroon,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Increase quantity',
                                onPressed: widget.cartQuantity >= product.stock
                                    ? null
                                    : () => widget.onCartQuantityChanged(
                                        widget.cartQuantity + 1,
                                      ),
                                icon: const Icon(Icons.add, size: 20),
                                disabledColor: BuyerColors.goldSoft,
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: !product.isAvailable || product.stock <= 0
                        ? null
                        : () => widget.onBuyNow(customizationSelection),
                    style: FilledButton.styleFrom(padding: _barButtonPadding),
                    icon: const Icon(Icons.bolt, size: 18),
                    label: _ButtonLabel(
                      'Buy now  ·  ₹${unitPrice * (widget.cartQuantity == 0 ? 1 : widget.cartQuantity)}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The two bottom-bar buttons share half the width each, so they use
  /// tighter padding than the theme default to keep their labels on one line.
  static const _barButtonPadding = EdgeInsets.symmetric(horizontal: 12);
}

/// A single-line button label that shrinks rather than wraps when the button
/// is narrow (e.g. a large total on a small phone).
class _ButtonLabel extends StatelessWidget {
  final String text;

  const _ButtonLabel(this.text);

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, maxLines: 1, softWrap: false),
  );
}

class _ProductCustomizationSection extends StatelessWidget {
  final Product product;
  final Map<String, List<String>> values;
  final void Function(String name, List<String> values) onChanged;

  const _ProductCustomizationSection({
    required this.product,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: BuyerColors.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: BuyerColors.line, width: 1.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.tune_rounded, size: 20),
            SizedBox(width: 8),
            Expanded(child: BuyerHeading('Customize this product')),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Selections are optional and will be shared with the creator.',
          style: TextStyle(fontSize: 12.5, color: BuyerColors.body),
        ),
        ...product.customizations
            .where((customization) => customization.options.isNotEmpty)
            .map(
              (customization) => _CustomizationChoice(
                customization: customization,
                selectedValues: values[customization.name] ?? const [],
                onChanged: (selection) =>
                    onChanged(customization.name, selection),
              ),
            ),
      ],
    ),
  );
}

class _CustomizationChoice extends StatelessWidget {
  final BuyerProductCustomization customization;
  final List<String> selectedValues;
  final ValueChanged<List<String>> onChanged;

  const _CustomizationChoice({
    required this.customization,
    required this.selectedValues,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                customization.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: BuyerColors.ink,
                ),
              ),
            ),
            if (customization.additionalPrice > 0)
              Text(
                '+₹${customization.additionalPrice}',
                style: const TextStyle(
                  color: BuyerColors.maroon,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        if (customization.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            customization.description,
            style: const TextStyle(fontSize: 12.5, color: BuyerColors.body),
          ),
        ],
        if (customization.images.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: customization.images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  customization.images[index],
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 72,
                    color: BuyerColors.paper,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: customization.options.map((option) {
            final selected = selectedValues.contains(option);
            return customization.isMultipleSelection
                ? FilterChip(
                    label: Text(option),
                    selected: selected,
                    onSelected: (isSelected) {
                      final updated = List<String>.from(selectedValues);
                      isSelected ? updated.add(option) : updated.remove(option);
                      onChanged(updated);
                    },
                  )
                : ChoiceChip(
                    label: Text(option),
                    selected: selected,
                    onSelected: (isSelected) =>
                        onChanged(isSelected ? [option] : []),
                  );
          }).toList(),
        ),
      ],
    ),
  );
}

class _ProductReviewsSection extends StatelessWidget {
  final Product product;
  final Stream<List<ProductReview>> reviewStream;
  final String buyerId;
  final String buyerName;
  final BuyerRepository repository;
  final Future<ProductReviewEligibility> eligibility;

  const _ProductReviewsSection({
    required this.product,
    required this.reviewStream,
    required this.buyerId,
    required this.buyerName,
    required this.repository,
    required this.eligibility,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProductReview>>(
      stream: reviewStream,
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? const <ProductReview>[];
        final ownReview = reviews.where((review) => review.buyerId == buyerId);
        final average = reviews.isEmpty
            ? product.rating
            : reviews.fold<int>(0, (sum, review) => sum + review.rating) /
                  reviews.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: BuyerHeading('Reviews & ratings')),
                if (average > 0) ...[
                  const Icon(
                    Icons.star_rounded,
                    size: 20,
                    color: BuyerColors.star,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    average.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  '(${reviews.length})',
                  style: const TextStyle(color: BuyerColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<ProductReviewEligibility>(
              future: eligibility,
              builder: (context, eligibilitySnapshot) {
                if (eligibilitySnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                final result = eligibilitySnapshot.data;
                if (result?.canReview == true) {
                  return OutlinedButton.icon(
                    onPressed: () => _openReviewEditor(
                      context,
                      existing: ownReview.isEmpty ? null : ownReview.first,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                    ),
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: Text(
                      ownReview.isEmpty ? 'Write a review' : 'Edit your review',
                    ),
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      size: 20,
                      color: BuyerColors.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result?.message ??
                            'Could not verify your purchase right now.',
                        style: const TextStyle(color: BuyerColors.muted),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            if (snapshot.hasError)
              const Text(
                'Reviews are unavailable right now.',
                style: TextStyle(color: BuyerColors.body),
              )
            else if (reviews.isEmpty)
              const Text(
                'No reviews yet. Verified buyers can be the first to review.',
                style: TextStyle(color: BuyerColors.body),
              )
            else
              ...reviews.map((review) => _ReviewCard(review: review)),
          ],
        );
      },
    );
  }

  Future<void> _openReviewEditor(
    BuildContext context, {
    ProductReview? existing,
  }) async {
    var selectedRating = existing?.rating ?? 0;
    var isSaving = false;
    var reviewText = existing?.comment ?? '';
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            4,
            24,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BuyerHeading(
                  existing == null ? 'Write a review' : 'Edit your review',
                  size: 19,
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.verified, size: 16),
                    SizedBox(width: 5),
                    Text(
                      'Verified purchase',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: BuyerColors.maroon,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (index) {
                    final value = index + 1;
                    return IconButton(
                      tooltip: '$value stars',
                      onPressed: isSaving
                          ? null
                          : () => setSheetState(() => selectedRating = value),
                      icon: Icon(
                        value <= selectedRating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: BuyerColors.star,
                      ),
                    );
                  }),
                ),
                TextFormField(
                  initialValue: reviewText,
                  onChanged: (value) => reviewText = value,
                  enabled: !isSaving,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Your review',
                    hintText: 'What did you like about this product?',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final comment = reviewText.trim();
                            if (selectedRating == 0 || comment.length < 3) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Select a rating and write at least 3 characters.',
                                  ),
                                ),
                              );
                              return;
                            }
                            setSheetState(() => isSaving = true);
                            try {
                              await repository.submitProductReview(
                                buyerId: buyerId,
                                buyerName: buyerName,
                                productId: product.id,
                                rating: selectedRating,
                                comment: comment,
                              );
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    existing == null
                                        ? 'Review submitted'
                                        : 'Review updated',
                                  ),
                                ),
                              );
                            } catch (error) {
                              if (sheetContext.mounted) {
                                setSheetState(() => isSaving = false);
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not save review: ${_messageFor(error)}',
                                  ),
                                ),
                              );
                            }
                          },
                    child: Text(isSaving ? 'Saving…' : 'Submit review'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _messageFor(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}

class _ReviewCard extends StatelessWidget {
  final ProductReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: BuyerColors.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: BuyerColors.line, width: 1.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                review.buyerName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: BuyerColors.ink,
                ),
              ),
            ),
            ...List.generate(
              5,
              (index) => Icon(
                index < review.rating
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                size: 17,
                color: BuyerColors.star,
              ),
            ),
          ],
        ),
        if (review.verifiedPurchase) ...[
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.verified, size: 16, color: BuyerColors.maroon),
              SizedBox(width: 5),
              Text(
                'Verified purchase',
                style: TextStyle(
                  color: BuyerColors.maroon,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Text(
          review.comment,
          style: const TextStyle(height: 1.45, color: BuyerColors.body),
        ),
      ],
    ),
  );
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, size: 19, color: BuyerColors.maroon),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: BuyerColors.body,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Swipeable product photos with a page indicator, or the category
/// placeholder when the listing has no photos.
class _ProductGallery extends StatefulWidget {
  final Product product;

  const _ProductGallery({required this.product});

  @override
  State<_ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<_ProductGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final images = product.images
        .where((url) => url.trim().isNotEmpty)
        .toList();
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(color: product.color),
      child: Center(
        child: Icon(
          product.icon,
          size: 112,
          color: BuyerColors.ink.withValues(alpha: 0.62),
        ),
      ),
    );

    return AspectRatio(
      aspectRatio: 1.15,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: images.isEmpty
            ? placeholder
            : Stack(
                children: [
                  PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (page) => setState(() => _page = page),
                    itemBuilder: (context, index) => Image.network(
                      images[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      cacheWidth: 1200,
                      loadingBuilder: (context, child, progress) =>
                          progress == null ? child : placeholder,
                      errorBuilder: (_, _, _) => placeholder,
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < images.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _page ? 18 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: i == _page ? 0.95 : 0.6,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
