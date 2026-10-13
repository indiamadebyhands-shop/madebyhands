import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:madebyhands/features/buyer/presentation/theme/buyer_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:madebyhands/features/buyer/domain/entities/product.dart';
import 'package:madebyhands/features/buyer/domain/entities/public_creator.dart';
import 'package:madebyhands/features/buyer/presentation/bloc/buyer_bloc.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_background.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_heading.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/product_card.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicCreatorStorefrontPage extends StatelessWidget {
  final PublicCreator creator;
  final String buyerId;
  final ValueChanged<Product>? onProductTap;

  const PublicCreatorStorefrontPage({
    super.key,
    required this.creator,
    required this.buyerId,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return BuyerBackground(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            creator.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: BlocBuilder<BuyerBloc, BuyerState>(
          buildWhen: (previous, current) =>
              previous.products != current.products ||
              previous.favoriteIds != current.favoriteIds,
          builder: (context, state) => _StorefrontBody(
            creator: creator,
            products: state.products
                .where((product) => product.creatorUid == creator.uid)
                .toList(),
            favoriteIds: state.favoriteIds,
            onProductTap: onProductTap,
            onSave: (product) => context.read<BuyerBloc>().add(
              BuyerToggleFavorite(userId: buyerId, product: product),
            ),
          ),
        ),
      ),
    );
  }
}

class _StorefrontBody extends StatelessWidget {
  final PublicCreator creator;
  final List<Product> products;
  final Set<String> favoriteIds;
  final ValueChanged<Product>? onProductTap;
  final ValueChanged<Product>? onSave;

  const _StorefrontBody({
    required this.creator,
    required this.products,
    required this.favoriteIds,
    this.onProductTap,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final onProductTap = this.onProductTap;
    final onSave = this.onSave;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _CreatorHeader(creator: creator)),
        if (creator.exhibitionPictures.isNotEmpty)
          SliverToBoxAdapter(
            child: _ExhibitionGallery(images: creator.exhibitionPictures),
          ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 0),
          sliver: SliverToBoxAdapter(child: Divider(height: 1)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          sliver: SliverToBoxAdapter(
            child: BuyerHeading(
              'Storefront · ${products.length} ${products.length == 1 ? 'product' : 'products'}',
            ),
          ),
        ),
        if (products.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Text(
                  'No available products from this creator yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BuyerColors.body),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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
                    isSaved: favoriteIds.contains(product.id),
                    onTap: onProductTap == null
                        ? null
                        : () => onProductTap(product),
                    onSave: onSave == null ? null : () => onSave(product),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _CreatorHeader extends StatelessWidget {
  final PublicCreator creator;

  const _CreatorHeader({required this.creator});

  Future<void> _shareCreator(
    BuildContext context,
    BuildContext shareButtonContext,
  ) async {
    final creatorLink = Uri.https('www.madebyhands.shop', '/', {
      'creator': creator.uid,
    });
    final renderBox = shareButtonContext.findRenderObject() as RenderBox?;

    try {
      await SharePlus.instance.share(
        ShareParams(
          title: creator.displayName,
          subject: 'Discover ${creator.displayName} on MadeByHands',
          text: 'Discover ${creator.displayName} on MadeByHands: $creatorLink',
          sharePositionOrigin: renderBox == null
              ? null
              : renderBox.localToGlobal(Offset.zero) & renderBox.size,
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: creatorLink.toString()));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Creator link copied')));
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (creator.portfolio.isNotEmpty) ...[
          AspectRatio(
            aspectRatio: 16 / 7,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    creator.portfolio.first,
                    fit: BoxFit.cover,
                    cacheWidth: 1200,
                    errorBuilder: (_, _, _) => Container(
                      color: BuyerColors.blush,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_outlined,
                        size: 38,
                        color: BuyerColors.maroon,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Builder(
                    builder: (shareButtonContext) => IconButton.filledTonal(
                      tooltip: 'Share creator profile',
                      onPressed: () =>
                          _shareCreator(context, shareButtonContext),
                      icon: const Icon(Icons.share_outlined, size: 14),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(30, 30),
                        maximumSize: const Size(30, 30),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: Colors.white.withValues(alpha: 0.30),
                        foregroundColor: BuyerColors.maroon,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: BuyerColors.blush,
              backgroundImage: creator.profileImage.isEmpty
                  ? null
                  : NetworkImage(creator.profileImage),
              child: creator.profileImage.isEmpty
                  ? const Icon(Icons.storefront, size: 32)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: BuyerHeading(
                          creator.displayName,
                          size: 20,
                          color: BuyerColors.ink,
                          weight: FontWeight.w800,
                        ),
                      ),
                      if (creator.isVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, size: 18),
                      ],
                    ],
                  ),
                  if (creator.location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            creator.location,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: BuyerColors.body,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (creator.bio.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            creator.bio,
            style: const TextStyle(height: 1.5, color: BuyerColors.body),
          ),
        ],
        if (creator.story.isNotEmpty) ...[
          const SizedBox(height: 20),
          const BuyerHeading('Creator story'),
          const SizedBox(height: 6),
          Text(
            creator.story,
            style: const TextStyle(height: 1.5, color: BuyerColors.body),
          ),
        ],
        if (creator.socialLinks.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: creator.socialLinks.map((link) {
              return ActionChip(
                avatar: const Icon(Icons.link, size: 18),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    _linkLabel(link),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                onPressed: () => _openLink(context, link),
              );
            }).toList(),
          ),
        ],
      ],
    ),
  );

  static String _linkLabel(String raw) {
    final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
    final host = uri?.host.replaceFirst('www.', '') ?? '';
    return host.isEmpty ? 'Link' : host;
  }

  Future<void> _openLink(BuildContext context, String raw) async {
    final normalized = raw.startsWith('http') ? raw : 'https://$raw';
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this link.')),
        );
      }
    }
  }
}

class _ExhibitionGallery extends StatelessWidget {
  final List<String> images;

  const _ExhibitionGallery({required this.images});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: Column(
      key: const Key('creator-exhibition-gallery'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: BuyerHeading('Exhibition showcase'),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                images[index],
                width: 150,
                height: 150,
                cacheWidth: 450,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 150,
                  child: ColoredBox(
                    color: BuyerColors.sand,
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
