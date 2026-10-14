import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:madebyhands/core/error/failures.dart';
import 'package:madebyhands/core/theme/app_theme.dart';
import 'package:madebyhands/features/creator/domain/entities/creator_product.dart';
import 'package:madebyhands/features/creator/domain/entities/creator_profile.dart';
import 'package:madebyhands/features/creator/domain/repositories/creator_repository.dart';
import 'package:madebyhands/features/creator/presentation/bloc/creator_bloc.dart';
import 'package:madebyhands/features/creator/presentation/pages/add_product_page.dart';
import 'package:madebyhands/init_dependencies.dart';

enum ProductSortCriteria { name, price, date }

class CreatorProductsView extends StatefulWidget {
  final CreatorProfile profile;
  const CreatorProductsView({super.key, required this.profile});

  @override
  State<CreatorProductsView> createState() => _CreatorProductsViewState();
}

class _CreatorProductsViewState extends State<CreatorProductsView> {
  late final Stream<List<CreatorProduct>> _products = serviceLocator<CreatorRepository>()
      .watchCreatorProducts(widget.profile.uid);
  ProductSortCriteria _criteria = ProductSortCriteria.date;
  bool _ascending = false;

  void _showSortOptions() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFFFAF6EE),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Widget tile(String title, ProductSortCriteria criteria) {
            final selected = _criteria == criteria;
            return ListTile(
              tileColor: selected ? const Color(0xFFF2DEDD) : null,
              title: Text(
                title,
                style: TextStyle(
                  color: selected ? const Color(0xFF8B261D) : AppColors.text,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: selected
                  ? Icon(
                      _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                      color: const Color(0xFF8B261D),
                    )
                  : null,
              onTap: () {
                setState(() {
                  if (_criteria == criteria) {
                    _ascending = !_ascending;
                  } else {
                    _criteria = criteria;
                    _ascending = criteria != ProductSortCriteria.date;
                  }
                });
                setSheetState(() {});
              },
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sort by',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B261D),
                  ),
                ),
                const SizedBox(height: 10),
                tile('Name', ProductSortCriteria.name),
                tile('Price', ProductSortCriteria.price),
                tile('Date added', ProductSortCriteria.date),
              ],
            ),
          );
        },
      ),
    );
  }

  List<CreatorProduct> _sorted(List<CreatorProduct> products) {
    final sorted = List<CreatorProduct>.of(products);
    int compare(CreatorProduct a, CreatorProduct b) => switch (_criteria) {
      ProductSortCriteria.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      ProductSortCriteria.price => a.price.compareTo(b.price),
      ProductSortCriteria.date => a.createdAt.compareTo(b.createdAt),
    };
    sorted.sort((a, b) => _ascending ? compare(a, b) : compare(b, a));
    return sorted;
  }

  void _addProduct() {
    if (!widget.profile.isVerified) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFFFAF6EE),
          title: const Text(
            'Verification required',
            style: TextStyle(color: Color(0xFF8B261D)),
          ),
          content: Text(
            widget.profile.isUnderReview
                ? 'Your verification is under review. You can add products once it is approved.'
                : 'Get verified from your dashboard to start listing products.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK', style: TextStyle(color: Color(0xFF8B261D))),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddProductPage(profile: widget.profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _addProduct,
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
        backgroundColor: const Color(0xFF8B261D),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<CreatorProduct>>(
        stream: _products,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load your products: ${friendlyErrorMessage(snapshot.error!)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.mutedText),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B261D)),
            );
          }
          final products = _sorted(snapshot.data!);
          final approved = products.where((p) => p.isApproved).toList();
          final pending = products.where((p) => p.isPendingApproval).toList();
          final rejected = products.where((p) => p.isRejected).toList();

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your inventory · ${products.length}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B261D),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sort',
                        onPressed: _showSortOptions,
                        icon: const Icon(Icons.sort),
                        color: const Color(0xFF8B261D),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  labelColor: const Color(0xFF8B261D),
                  indicatorColor: const Color(0xFF8B261D),
                  unselectedLabelColor: AppColors.mutedText,
                  tabs: [
                    Tab(text: 'Approved (${approved.length})'),
                    Tab(text: 'Pending (${pending.length})'),
                    Tab(text: 'Rejected (${rejected.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ProductList(
                        profile: widget.profile,
                        products: approved,
                        emptyMessage: 'No approved products yet.',
                      ),
                      _ProductList(
                        profile: widget.profile,
                        products: pending,
                        emptyMessage: 'Nothing waiting for review.',
                      ),
                      _ProductList(
                        profile: widget.profile,
                        products: rejected,
                        emptyMessage: 'No rejected products.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProductList extends StatelessWidget {
  final CreatorProfile profile;
  final List<CreatorProduct> products;
  final String emptyMessage;

  const _ProductList({
    required this.profile,
    required this.products,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Text(emptyMessage, style: const TextStyle(color: AppColors.mutedText)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 96),
      itemCount: products.length,
      itemBuilder: (context, index) =>
          _ProductTile(profile: profile, product: products[index]),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final CreatorProfile profile;
  final CreatorProduct product;

  const _ProductTile({required this.profile, required this.product});

  void _edit(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AddProductPage(profile: profile, initialProduct: product),
    ),
  );

  Future<void> _shareProduct(BuildContext context) async {
    final productLink = Uri.https('www.madebyhands.shop', '/', {
      'product': product.id,
    });
    final renderBox = context.findRenderObject() as RenderBox?;

    try {
      await SharePlus.instance.share(
        ShareParams(
          title: product.name,
          subject: 'Check out ${product.name} on MadeByHands',
          text:
              'Check out ${product.name} by ${product.creatorName} on '
              'MadeByHands: $productLink',
          sharePositionOrigin: renderBox == null
              ? null
              : renderBox.localToGlobal(Offset.zero) & renderBox.size,
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: productLink.toString()));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product link copied to clipboard')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bloc = context.read<CreatorBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFFAF6EE),
        title: const Text('Delete product?', style: TextStyle(color: Color(0xFF8B261D))),
        content: Text('"${product.name}" will be removed from your shop permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) bloc.add(CreatorDeleteProduct(product.id));
  }

  Future<void> _editStock(BuildContext context) async {
    final bloc = context.read<CreatorBloc>();
    final controller = TextEditingController(text: '${product.stock}');
    final formKey = GlobalKey<FormState>();
    final stock = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFFAF6EE),
        title: const Text('Update stock', style: TextStyle(color: Color(0xFF8B261D))),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Units available'),
            validator: (value) {
              final parsed = int.tryParse(value ?? '');
              if (parsed == null || parsed < 0 || parsed > 100000) {
                return 'Enter 0 – 100000.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, int.parse(controller.text));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B261D)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (stock != null && stock != product.stock) {
      bloc.add(CreatorUpdateStock(productId: product.id, stock: stock));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (String status, Color statusColor) = product.isRejected
        ? ('Rejected', Colors.red)
        : product.isPendingApproval
        ? ('In review', Colors.orange.shade800)
        : product.isActive
        ? ('Live', Colors.green.shade700)
        : ('Hidden', AppColors.mutedText);

    return Card(
      elevation: 1,
      color: const Color(0xFFFAF6EE).withValues(alpha: 0.95),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: const Color(0xFF8B261D).withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _edit(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox.square(
                  dimension: 64,
                  child: product.images.isNotEmpty
                      ? Image.network(
                          product.images.first,
                          fit: BoxFit.cover,
                          cacheWidth: 192,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: AppColors.outline,
                            child: Icon(Icons.image_not_supported),
                          ),
                        )
                      : const ColoredBox(
                          color: AppColors.outline,
                          child: Icon(Icons.image),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF8B261D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${product.price.round()} · Stock ${product.stock}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8B261D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      product.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    if (product.isRejected && product.rejectionReason.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          'Reason: ${product.rejectionReason}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Color(0xFF8B261D)),
                tooltip: 'Product actions',
                onSelected: (value) {
                  final bloc = context.read<CreatorBloc>();
                  switch (value) {
                    case 'edit':
                      _edit(context);
                    case 'stock':
                      _editStock(context);
                    case 'publish':
                      bloc.add(CreatorSetProductPublished(productId: product.id, published: true));
                    case 'unpublish':
                      bloc.add(CreatorSetProductPublished(productId: product.id, published: false));
                    case 'share':
                      _shareProduct(context);
                    case 'delete':
                      _confirmDelete(context);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(product.isRejected ? 'Edit & resubmit' : 'Edit (needs re-approval)'),
                  ),
                  const PopupMenuItem(value: 'stock', child: Text('Update stock')),
                  if (product.isApproved && !product.isActive && profile.isVerified)
                    const PopupMenuItem(value: 'publish', child: Text('Publish')),
                  if (product.isApproved && product.isActive)
                    const PopupMenuItem(value: 'unpublish', child: Text('Unpublish')),
                  if (product.isApproved)
                    const PopupMenuItem(value: 'share', child: Text('Share')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
