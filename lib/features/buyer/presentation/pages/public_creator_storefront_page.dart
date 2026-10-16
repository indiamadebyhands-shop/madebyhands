import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
              previous.favoriteIds != current.favoriteIds ||
              previous.pendingFavoriteIds != current.pendingFavoriteIds,
          builder: (context, state) => _StorefrontBody(
            creator: creator,
            products: state.products
                .where((product) => product.creatorUid == creator.uid)
                .toList(),
            favoriteIds: state.favoriteIds,
            pendingFavoriteIds: state.pendingFavoriteIds,
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
  final Set<String> pendingFavoriteIds;
  final ValueChanged<Product>? onProductTap;
  final ValueChanged<Product>? onSave;

  const _StorefrontBody({
    required this.creator,
    required this.products,
    required this.favoriteIds,
    required this.pendingFavoriteIds,
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
                    isUpdating: pendingFavoriteIds.contains(product.id),
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
          _ExpandableCreatorStory(text: creator.story),
        ],
        if (creator.socialLinks.isNotEmpty) ...[
          const SizedBox(height: 10),
          InkWell(
            key: const Key('creator-social-links-summary'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showSocialLinks(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link, size: 17, color: BuyerColors.maroon),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _socialLinksSummary(creator.socialLinks),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BuyerColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );

  static String _socialLinksSummary(List<String> links) {
    final firstName = _socialLinkInfo(links.first).name;
    final remaining = links.length - 1;
    return remaining == 0
        ? firstName
        : '$firstName and $remaining more ${remaining == 1 ? 'link' : 'links'}';
  }

  static _SocialLinkInfo _socialLinkInfo(String raw) {
    final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
    final host = (uri?.host ?? '').toLowerCase().replaceFirst('www.', '');
    if (host.contains('youtube.com') || host.contains('youtu.be')) {
      return const _SocialLinkInfo('YouTube', Icons.smart_display_outlined);
    }
    if (host.contains('instagram.com')) {
      return const _SocialLinkInfo('Instagram', Icons.camera_alt_outlined);
    }
    if (host.contains('facebook.com') || host.contains('fb.com')) {
      return const _SocialLinkInfo('Facebook', Icons.facebook_outlined);
    }
    if (host.contains('twitter.com') || host.contains('x.com')) {
      return const _SocialLinkInfo('X (Twitter)', Icons.alternate_email);
    }
    if (host.contains('linkedin.com')) {
      return const _SocialLinkInfo('LinkedIn', Icons.business_center_outlined);
    }
    if (host.contains('pinterest.com') || host.contains('pin.it')) {
      return const _SocialLinkInfo('Pinterest', Icons.push_pin_outlined);
    }
    return _SocialLinkInfo(
      host.isEmpty ? 'Website' : host,
      Icons.language_outlined,
    );
  }

  Future<void> _showSocialLinks(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      titlePadding: const EdgeInsets.fromLTRB(22, 18, 8, 4),
      contentPadding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
      title: Row(
        children: [
          const Expanded(
            child: Text('Links', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          IconButton(
            key: const Key('close-creator-social-links'),
            tooltip: 'Close links',
            onPressed: () => Navigator.of(dialogContext).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (
                var index = 0;
                index < creator.socialLinks.length;
                index++
              ) ...[
                if (index > 0) const SizedBox(height: 4),
                _socialLinkTile(context, creator.socialLinks[index]),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _socialLinkTile(BuildContext context, String link) {
    final info = _socialLinkInfo(link);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openLink(context, link),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(info.icon, size: 25, color: BuyerColors.maroon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.name,
                    style: const TextStyle(
                      color: BuyerColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    link.replaceFirst(RegExp(r'^https?://'), ''),
                    style: const TextStyle(color: BuyerColors.maroon),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

class _ExpandableCreatorStory extends StatefulWidget {
  final String text;

  const _ExpandableCreatorStory({required this.text});

  @override
  State<_ExpandableCreatorStory> createState() =>
      _ExpandableCreatorStoryState();
}

class _ExpandableCreatorStoryState extends State<_ExpandableCreatorStory> {
  static const _style = TextStyle(height: 1.5, color: BuyerColors.body);
  static const _linkStyle = TextStyle(
    height: 1.5,
    color: BuyerColors.ink,
    fontWeight: FontWeight.w800,
  );
  late final TapGestureRecognizer _readMoreRecognizer;
  late final TapGestureRecognizer _seeLessRecognizer;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _readMoreRecognizer = TapGestureRecognizer()
      ..onTap = () => setState(() => _expanded = true);
    _seeLessRecognizer = TapGestureRecognizer()
      ..onTap = () => setState(() => _expanded = false);
  }

  @override
  void dispose() {
    _readMoreRecognizer.dispose();
    _seeLessRecognizer.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ExpandableCreatorStory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = DefaultTextStyle.of(context).style.merge(_style);
    final linkStyle = textStyle.merge(_linkStyle);
    if (_expanded) {
      return Semantics(
        button: true,
        label: 'See less creator story',
        child: GestureDetector(
          key: const Key('creator-story-see-less'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = false),
          child: Text.rich(
            TextSpan(
              style: textStyle,
              children: [
                TextSpan(text: '${widget.text.trim()} '),
                TextSpan(
                  text: 'See less',
                  style: linkStyle,
                  recognizer: _seeLessRecognizer,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        final fullPainter = TextPainter(
          text: TextSpan(text: widget.text, style: textStyle),
          textDirection: direction,
          textScaler: textScaler,
          maxLines: 2,
        )..layout(maxWidth: constraints.maxWidth);

        if (!fullPainter.didExceedMaxLines) {
          return Text(widget.text, style: textStyle);
        }

        var low = 0;
        var high = widget.text.length;
        while (low < high) {
          final middle = (low + high + 1) ~/ 2;
          final candidate = widget.text.substring(0, middle).trimRight();
          final painter = TextPainter(
            text: TextSpan(
              style: textStyle,
              children: [
                TextSpan(text: '$candidate… '),
                TextSpan(text: 'Read more', style: linkStyle),
              ],
            ),
            textDirection: direction,
            textScaler: textScaler,
            maxLines: 2,
          )..layout(maxWidth: constraints.maxWidth);
          if (painter.didExceedMaxLines) {
            high = middle - 1;
          } else {
            low = middle;
          }
        }

        var visibleText = widget.text.substring(0, low).trimRight();
        final lastSpace = visibleText.lastIndexOf(' ');
        if (lastSpace > visibleText.length * 0.75) {
          visibleText = visibleText.substring(0, lastSpace);
        }

        // Keep a small safety margin for platform-specific font metrics.
        while (visibleText.isNotEmpty) {
          final exactPainter = TextPainter(
            text: TextSpan(
              style: textStyle,
              children: [
                TextSpan(text: '$visibleText… '),
                TextSpan(text: 'Read more', style: linkStyle),
              ],
            ),
            textDirection: direction,
            textScaler: textScaler,
            maxLines: 2,
          )..layout(maxWidth: constraints.maxWidth - 2);
          if (!exactPainter.didExceedMaxLines) break;
          visibleText = visibleText
              .substring(0, visibleText.length - 1)
              .trimRight();
        }

        return Semantics(
          button: true,
          label: 'Read more creator story',
          child: GestureDetector(
            key: const Key('creator-story-read-more'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = true),
            child: Text.rich(
              TextSpan(
                style: textStyle,
                children: [
                  TextSpan(text: '$visibleText… '),
                  TextSpan(
                    text: 'Read more',
                    style: linkStyle,
                    recognizer: _readMoreRecognizer,
                  ),
                ],
              ),
              maxLines: 2,
            ),
          ),
        );
      },
    );
  }
}

class _SocialLinkInfo {
  final String name;
  final IconData icon;

  const _SocialLinkInfo(this.name, this.icon);
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
