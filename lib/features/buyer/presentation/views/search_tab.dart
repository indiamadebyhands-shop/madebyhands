import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:madebyhands/features/buyer/presentation/theme/buyer_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:madebyhands/core/constants/product_categories.dart';
import 'package:madebyhands/features/buyer/domain/entities/product.dart';
import 'package:madebyhands/features/buyer/domain/entities/public_creator.dart';
import 'package:madebyhands/features/buyer/presentation/bloc/buyer_bloc.dart';
import 'package:madebyhands/features/buyer/presentation/pages/explore_storefronts_page.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_background.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_empty_state.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_heading.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/product_card.dart';

class SearchTab extends StatefulWidget {
  final String userId;
  final ValueChanged<Product> onProductTap;
  final ValueChanged<PublicCreator>? onCreatorTap;

  /// Set by other tabs (e.g. a category tile on Home) to open the shop
  /// filtered to one category. The tab clears it once applied.
  final ValueNotifier<String?>? categoryRequest;

  /// Query submitted from another tab, such as the Home search field.
  final ValueNotifier<String?>? searchRequest;

  /// Used when Shop search is opened as a focused route from product details.
  final bool autofocusSearch;

  const SearchTab({
    super.key,
    required this.userId,
    required this.onProductTap,
    this.onCreatorTap,
    this.categoryRequest,
    this.searchRequest,
    this.autofocusSearch = false,
  });

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  String _query = '';
  final Set<String> _selectedCategories = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.categoryRequest?.addListener(_applyCategoryRequest);
    widget.searchRequest?.addListener(_applySearchRequest);
    _applyCategoryRequest();
    _applySearchRequest();
  }

  @override
  void didUpdateWidget(SearchTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryRequest != widget.categoryRequest) {
      oldWidget.categoryRequest?.removeListener(_applyCategoryRequest);
      widget.categoryRequest?.addListener(_applyCategoryRequest);
    }
    if (oldWidget.searchRequest != widget.searchRequest) {
      oldWidget.searchRequest?.removeListener(_applySearchRequest);
      widget.searchRequest?.addListener(_applySearchRequest);
    }
  }

  @override
  void dispose() {
    widget.categoryRequest?.removeListener(_applyCategoryRequest);
    widget.searchRequest?.removeListener(_applySearchRequest);
    _searchController.dispose();
    super.dispose();
  }

  void _applyCategoryRequest() {
    final request = widget.categoryRequest;
    final category = request?.value;
    if (request == null || category == null) return;
    request.value = null;
    void apply() {
      _searchController.clear();
      _query = '';
      _selectedCategories
        ..clear()
        ..add(category);
    }

    // The notifier may fire during the first build; defer setState then.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(apply);
      });
    } else if (mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _applySearchRequest() {
    final request = widget.searchRequest;
    final query = request?.value?.trim();
    if (request == null || query == null || query.isEmpty) return;
    request.value = null;

    void apply() {
      _searchController.text = query;
      _searchController.selection = TextSelection.collapsed(
        offset: query.length,
      );
      _query = query;
      _selectedCategories.clear();
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(apply);
      });
    } else if (mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  bool _matchesCategory(Product product) {
    if (_selectedCategories.isEmpty) return true;
    return _selectedCategories.any(
      (category) => productMatchesCategory(product.allCategories, category),
    );
  }

  Future<void> _openCategoryFilter() async {
    // Admin's categories collection is the single source of truth — no
    // hardcoded fallback list here.
    final state = context.read<BuyerBloc>().state;
    final categories = [...state.categories];
    final draftSelection = Set<String>.from(_selectedCategories);
    final selection = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => FractionallySizedBox(
          heightFactor: 0.88,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BuyerHeading('Filter by category', size: 19),
                          SizedBox(height: 4),
                          Text(
                            'Select one or more categories',
                            style: TextStyle(color: BuyerColors.body),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close filters',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return CheckboxListTile(
                      value: draftSelection.contains(category),
                      title: Text(
                        category,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (selected) {
                        setModalState(() {
                          selected == true
                              ? draftSelection.add(category)
                              : draftSelection.remove(category);
                        });
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: BuyerColors.line)),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => setModalState(draftSelection.clear),
                      child: const Text('Clear all'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(
                          context,
                          Set<String>.from(draftSelection),
                        ),
                        child: Text(
                          draftSelection.isEmpty
                              ? 'Show all products'
                              : 'Apply (${draftSelection.length})',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selection != null && mounted) {
      setState(() {
        _selectedCategories
          ..clear()
          ..addAll(selection);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BuyerBackground(
      child: BlocBuilder<BuyerBloc, BuyerState>(
        buildWhen: (previous, current) =>
            previous.products != current.products ||
            previous.creators != current.creators ||
            previous.categories != current.categories ||
            previous.favoriteIds != current.favoriteIds,
        builder: (context, state) {
          final normalizedCategoryQuery = normalizeCategory(_query);
          final matchingCategories = state.categories
              .where(
                (category) => normalizeCategory(
                  category,
                ).contains(normalizedCategoryQuery),
              )
              .toList();
          final products = state.products.where((product) {
            final normalizedQuery = _query.trim().toLowerCase();
            final matchesCategory = _matchesCategory(product);
            final matchesQuery =
                normalizedQuery.isEmpty ||
                product.name.toLowerCase().contains(normalizedQuery) ||
                product.artisan.toLowerCase().contains(normalizedQuery) ||
                product.description.toLowerCase().contains(normalizedQuery) ||
                product.materials.toLowerCase().contains(normalizedQuery) ||
                product.categoryLabel.toLowerCase().contains(normalizedQuery) ||
                matchingCategories.any(
                  (category) =>
                      productMatchesCategory(product.allCategories, category),
                );
            return matchesCategory && matchesQuery;
          }).toList();
          final normalizedQuery = _query.trim().toLowerCase();
          final creators = normalizedQuery.isEmpty
              ? <PublicCreator>[]
              : state.creators.where((creator) {
                  if (!creator.isVerified) return false;
                  return creator.displayName.toLowerCase().contains(
                        normalizedQuery,
                      ) ||
                      creator.name.toLowerCase().contains(normalizedQuery) ||
                      creator.location.toLowerCase().contains(
                        normalizedQuery,
                      ) ||
                      creator.bio.toLowerCase().contains(normalizedQuery);
                }).toList();

          return CustomScrollView(
            key: const PageStorageKey('buyer-search'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverList.list(
                  children: [
                    const BuyerPageHeader(
                      title: 'Explore handmade',
                      subtitle: 'Find a piece with a story behind it.',
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchController,
                      autofocus: widget.autofocusSearch,
                      onChanged: (value) => setState(() => _query = value),
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, size: 20),
                        hintText: 'Search products, categories or creators',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _openCategoryFilter,
                          icon: const Icon(Icons.tune, size: 18),
                          label: Text(
                            _selectedCategories.isEmpty
                                ? 'Filter'
                                : 'Filter (${_selectedCategories.length})',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            side: const BorderSide(
                              color: BuyerColors.gold,
                              width: 1.1,
                            ),
                          ),
                        ),
                        if (_selectedCategories.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: () =>
                                setState(_selectedCategories.clear),
                            child: const Text('Clear'),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          '${products.length} ${products.length == 1 ? 'piece' : 'pieces'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: BuyerColors.body,
                          ),
                        ),
                      ],
                    ),
                    if (_selectedCategories.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedCategories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final category = _selectedCategories.elementAt(
                              index,
                            );
                            return InputChip(
                              backgroundColor: BuyerColors.blush,
                              label: Text(
                                category,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onDeleted: () => setState(
                                () => _selectedCategories.remove(category),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_query.trim().isEmpty) ...[
                      Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: BuyerColors.maroon,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.storefront,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: const Text('Explore Storefronts by Creators'),
                          subtitle: const Padding(
                            padding: EdgeInsets.only(top: 3),
                            child: Text(
                              'Discover verified artisans & full studio collections',
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExploreStorefrontsPage(
                                  userId: widget.userId,
                                  onProductTap: widget.onProductTap,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (creators.isNotEmpty) ...[
                      const BuyerHeading('Creators'),
                      const SizedBox(height: 10),
                      for (final creator in creators) ...[
                        Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: BuyerColors.blush,
                              foregroundColor: BuyerColors.maroon,
                              backgroundImage: creator.profileImage.isNotEmpty
                                  ? NetworkImage(creator.profileImage)
                                  : null,
                              child: creator.profileImage.isEmpty
                                  ? const Icon(Icons.storefront)
                                  : null,
                            ),
                            title: Text(
                              creator.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              creator.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: widget.onCreatorTap == null
                                ? null
                                : () => widget.onCreatorTap!(creator),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              if (products.isEmpty && creators.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: BuyerEmptyState(
                    icon: Icons.search_off,
                    title: 'No pieces found',
                    message: 'Try another search or change your filters.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 240,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.65,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      childCount: products.length,
                      (context, index) {
                        final product = products[index];
                        return ProductCard(
                          product: product,
                          isSaved: state.favoriteIds.contains(product.id),
                          onTap: () => widget.onProductTap(product),
                          onSave: () => context.read<BuyerBloc>().add(
                            BuyerToggleFavorite(
                              userId: widget.userId,
                              product: product,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
