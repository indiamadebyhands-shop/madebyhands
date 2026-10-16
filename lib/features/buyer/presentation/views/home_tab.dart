import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:madebyhands/features/buyer/domain/entities/product.dart';
import 'package:madebyhands/features/buyer/domain/entities/saved_address.dart';
import 'package:madebyhands/features/buyer/presentation/bloc/buyer_bloc.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/arch_backdrop.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/product_card.dart';

class HomeTab extends StatefulWidget {
  final String userName;
  final String userId;
  final ValueChanged<Product> onProductTap;
  final VoidCallback onBrowseAll;
  final ValueChanged<String>? onSearchSubmitted;
  final ValueChanged<String>? onCategoryTap;
  final SavedAddress? selectedAddress;
  final VoidCallback? onAddressTap;
  final VoidCallback? onProfileTap;
  final int unreadNotificationCount;
  final VoidCallback onNotificationsTap;

  const HomeTab({
    super.key,
    required this.userName,
    required this.userId,
    required this.onProductTap,
    required this.onBrowseAll,
    this.onSearchSubmitted,
    this.onCategoryTap,
    this.selectedAddress,
    this.onAddressTap,
    this.onProfileTap,
    required this.unreadNotificationCount,
    required this.onNotificationsTap,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static const int _initialStoryPage = 1000;
  static const List<String> _homeCategoryOrder = [
    'Paintings, Drawing, Fine Art & Traditional Art',
    'Digital Art, Illustration, Design & Photography',
    'Pottery, Ceramics, Clay & Sculpture',
    'Textile, Fiber, Embroidery, Toys & Dolls',
    'Fashion, Jewellery & Wearables',
    'Home Décor & Lifestyle',
    'Wood, Metal, Leather & Natural Crafts',
    'Paper, Books & Stationery',
    'Handicrafts & Artisan Goods',
    'Resin & Mixed-Material Art',
    'Other Creative Works',
  ];

  late final PageController _storyPageController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _homeSearchController = TextEditingController();

  final GlobalKey _overlayKey = GlobalKey();
  double _overlayBottom = 0;

  final List<Map<String, String>> _stories = [
    {
      'title': 'The Story of Madhubani Art',
      'description':
          'Ancient folk painting tradition from Mithila celebrating nature, mythology and vibrant heritage.',
      'image':
          'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?q=80&w=800&auto=format&fit=crop',
    },
    {
      'title': 'The Heritage of Phulkari',
      'description':
          'Handcrafted floral embroidery woven with silk threads, passing down generations of stories.',
      'image':
          'https://images.unsplash.com/photo-1606744888344-493238951221?q=80&w=800&auto=format&fit=crop',
    },
    {
      'title': 'Royal Terracotta & Pottery',
      'description':
          'Earthy clay sculptures and traditional pottery shaped by hand across royal artisan guilds.',
      'image':
          'https://images.unsplash.com/photo-1565193566173-7a0ee3dbe261?q=80&w=800&auto=format&fit=crop',
    },
  ];

  @override
  void initState() {
    super.initState();
    _storyPageController = PageController(
      initialPage: _initialStoryPage * _stories.length,
    );
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (mounted) {
      setState(() {});
    }
  }

  void _measureOverlay() {
    final box = _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    if ((bottom - _overlayBottom).abs() > 0.5) {
      setState(() => _overlayBottom = bottom);
    }
  }

  @override
  void dispose() {
    _storyPageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _homeSearchController.dispose();
    super.dispose();
  }

  void _openSearch() {
    widget.onBrowseAll();
  }

  void _submitSearch() {
    final query = _homeSearchController.text.trim();
    if (query.isEmpty) {
      _openSearch();
    } else {
      widget.onSearchSubmitted?.call(query);
    }
  }

  void _openCategory(String category) {
    final onCategoryTap = widget.onCategoryTap;
    onCategoryTap == null ? _openSearch() : onCategoryTap(category);
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.userName.trim().isEmpty
        ? 'there'
        : widget.userName.trim().split(' ').first;

    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;

    const storiesScrollThreshold = 290.0;
    const brandingCollapseDistance = 150.0;

    final collapseProgress =
        ((scrollOffset - storiesScrollThreshold) / brandingCollapseDistance)
            .clamp(0.0, 1.0);

    final brandingHeightFactor = 1.0 - collapseProgress;
    final brandingOpacity = 1.0 - collapseProgress;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureOverlay();
    });

    final fadeStrength = (scrollOffset / 40.0).clamp(0.0, 1.0);

    // The arch starts just under the status bar; the header follows it down
    // so the logo sits inside the crown.
    final headerInset = ArchBackdrop.headerInset(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EE),
      body: Stack(
        children: [
          // 1. Background frame overlay
          const Positioned.fill(child: ArchBackdrop()),

          // 2. Scrollable Body
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              final h = bounds.height;
              final searchBottom = _overlayBottom.clamp(0.0, h);
              final hiddenUntil = searchBottom - 22.0 * fadeStrength;
              final visibleFrom = searchBottom + 38.0 * fadeStrength;
              final s1 = (hiddenUntil / h).clamp(0.0, 1.0);
              final s2 = (visibleFrom / h).clamp(0.0, 1.0);
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                ],
                stops: [0.0, s1, s2, 1.0],
              ).createShader(bounds);
            },
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                controller: _scrollController,
                key: const PageStorageKey('buyer-home-scroll'),
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                // On wide screens the arch stops growing, so the content is
                // held to the same width and stays inside it.
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: ArchBackdrop.defaultMaxArchWidth - 56.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 244.0 + headerInset),
                        _buildHistoricalArtSection(),
                        const SizedBox(height: 18),
                        _buildCategoryDivider(),
                        const SizedBox(height: 14),
                        _buildCategoryProductSections(),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Fixed/Sticky Top Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 1.0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: ArchBackdrop.defaultMaxArchWidth,
                  ),
                  child: Column(
                    // key removed from here
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // FIXED: logo + MADE BY HANDS text
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          28.0,
                          headerInset,
                          28.0,
                          0,
                        ),
                        child: _buildHeaderWithBrandingAndTopRightIcons(),
                      ),
                      const SizedBox(height: 2),

                      // COLLAPSING: Hello user, address, profile & notification icons
                      Transform.translate(
                        offset: const Offset(0, -30),
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.topCenter,
                            heightFactor: brandingHeightFactor,
                            child: Opacity(
                              opacity: brandingOpacity,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28.0,
                                ),
                                child: _buildGreetingAndAddress(firstName),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Search Bar (lifts up as it gets pinned)
                      Transform.translate(
                        offset: Offset(0, -30.0 * collapseProgress),
                        child: Padding(
                          key: _overlayKey, // key now lives here
                          padding: const EdgeInsets.symmetric(horizontal: 28.0),
                          child: _buildSearchBar(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderWithBrandingAndTopRightIcons() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/main_page_elements/mbh_logo.png',
            height: 65,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.palette, size: 40, color: Color(0xFF8B261D)),
          ),
          Transform.translate(
            offset: const Offset(0, -25),
            child: Image.asset(
              'assets/main_page_elements/madebyhands_text.png',
              height: 75,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Text(
                'MADE BY HANDS',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: const Color(0xFF8B261D),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingAndAddress(String firstName) {
    final addressText = widget.selectedAddress == null
        ? 'Add a delivery address'
        : 'Deliver to: ${widget.selectedAddress!.formatted}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hello, $firstName',
                textAlign: TextAlign.left,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF331818),
                ),
              ),
              const SizedBox(height: 1),
              InkWell(
                onTap: widget.onAddressTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 1,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 13,
                        color: Color(0xFF8B261D),
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          addressText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.questrial(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF5A4438),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 14,
                        color: Color(0xFF8B261D),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: widget.onProfileTap,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(
                  Icons.account_circle_outlined,
                  color: Color(0xFF4A1F18),
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Open notifications',
              onPressed: widget.onNotificationsTap,
              visualDensity: VisualDensity.compact,
              icon: Badge(
                isLabelVisible: widget.unreadNotificationCount > 0,
                label: Text('${widget.unreadNotificationCount}'),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF4A1F18),
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF0),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFC49A6C), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B1D1D).withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _homeSearchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _submitSearch(),
        style: GoogleFonts.montserrat(
          color: const Color(0xFF331818),
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search products or categories...',
          hintStyle: GoogleFonts.montserrat(
            color: const Color(0xFF8A7F73),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: IconButton(
            tooltip: 'Search products and categories',
            onPressed: _submitSearch,
            icon: const Icon(Icons.search, color: Color(0xFF8B261D), size: 18),
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }

  Widget _buildHistoricalArtSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interesting Facts & Stories',
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B1D1D),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _storyPageController,
            itemBuilder: (context, index) {
              final story = _stories[index % _stories.length];
              return _buildStoryCard(story);
            },
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: AnimatedBuilder(
            animation: _storyPageController,
            builder: (context, child) {
              final page =
                  _storyPageController.hasClients &&
                      _storyPageController.page != null
                  ? _storyPageController.page!
                  : (_initialStoryPage * _stories.length).toDouble();
              final activeIndex = (page.round()) % _stories.length;
              return AnimatedSmoothIndicator(
                activeIndex: activeIndex,
                count: _stories.length,
                effect: const ExpandingDotsEffect(
                  activeDotColor: Color(0xFF8B261D),
                  dotColor: Color(0xFFE2D0B5),
                  dotHeight: 7,
                  dotWidth: 7,
                  expansionFactor: 2.5,
                  spacing: 6,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStoryCard(Map<String, String> story) {
    return Container(
      margin: const EdgeInsets.only(left: 2, top: 2, right: 14, bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A1208).withValues(alpha: 0.65),
            blurRadius: 12,
            spreadRadius: -2,
            offset: const Offset(6, 8),
          ),
          BoxShadow(
            color: const Color(0xFF2A1208).withValues(alpha: 0.80),
            blurRadius: 8,
            spreadRadius: -1,
            offset: const Offset(3, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 1. Artwork Image
            Positioned.fill(
              child: story['image']!.startsWith('http')
                  ? Image.network(
                      story['image']!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Image.asset(
                        'assets/main_page_elements/painting_main.png',
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.asset(
                      story['image']!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Image.asset(
                        'assets/main_page_elements/painting_main.png',
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
            // 2. Dark Gradient Overlay at Bottom
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.20),
                      Colors.black.withValues(alpha: 0.80),
                    ],
                    stops: const [0.4, 0.65, 1.0],
                  ),
                ),
              ),
            ),
            // 3. Heading (Montserrat w700) & Description (Montserrat w400, 1-2 lines) at Bottom Left
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    story['title']!,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (story['description'] != null &&
                      story['description']!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      story['description']!,
                      style: GoogleFonts.montserrat(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.90),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDivider() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Categories',
        style: GoogleFonts.montserrat(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF6B1D1D),
        ),
      ),
    );
  }

  Widget _buildCategoryProductSections() {
    return BlocBuilder<BuyerBloc, BuyerState>(
      buildWhen: (previous, current) =>
          previous.categories != current.categories ||
          previous.products != current.products ||
          previous.favoriteIds != current.favoriteIds ||
          previous.pendingFavoriteIds != current.pendingFavoriteIds,
      builder: (context, state) {
        final sections = <({String category, List<Product> products})>[];
        for (final category in _homeCategoryOrder) {
          final normalizedCategory = category.trim().toLowerCase();
          final products = state.products.where((product) {
            return product.allCategories.any(
              (productCategory) =>
                  productCategory.trim().toLowerCase() == normalizedCategory,
            );
          }).toList();
          if (products.isNotEmpty) {
            sections.add((category: category, products: products));
          }
        }

        if (sections.isEmpty) return const SizedBox.shrink();

        return Column(
          children: sections.map((section) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          section.category,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6B1D1D),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openCategory(section.category),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'See all',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF8B261D),
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: Color(0xFF8B261D),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 225,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: section.products.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final product = section.products[index];
                        return SizedBox(
                          width: 145,
                          child: ProductCard(
                            product: product,
                            isSaved: state.favoriteIds.contains(product.id),
                            isUpdating: state.pendingFavoriteIds.contains(
                              product.id,
                            ),
                            onTap: () => widget.onProductTap(product),
                            onSave: () => context.read<BuyerBloc>().add(
                              BuyerToggleFavorite(
                                userId: widget.userId,
                                product: product,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
