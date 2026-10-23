import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:madebyhands/core/constants/image_upload.dart';
import 'package:madebyhands/core/theme/app_theme.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';
import 'package:madebyhands/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:madebyhands/features/creator/domain/entities/creator_order.dart';
import 'package:madebyhands/features/creator/domain/entities/creator_profile.dart';
import 'package:madebyhands/features/creator/domain/repositories/creator_repository.dart';
import 'package:madebyhands/features/creator/presentation/bloc/creator_bloc.dart';
import 'package:madebyhands/features/creator/presentation/pages/creator_onboarding_page.dart';
import 'package:madebyhands/features/creator/presentation/pages/creator_verification_page.dart';
import 'package:madebyhands/features/orders/domain/order_status.dart';
import 'package:madebyhands/init_dependencies.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class CreatorHomeView extends StatefulWidget {
  final CreatorProfile profile;

  const CreatorHomeView({super.key, required this.profile});

  @override
  State<CreatorHomeView> createState() => _CreatorHomeViewState();
}

class _CreatorHomeViewState extends State<CreatorHomeView> {
  late final Stream<List<CreatorOrder>> _orders =
      serviceLocator<CreatorRepository>().watchCreatorOrders(
    widget.profile.uid,
  );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreatorBloc, CreatorState>(
      builder: (context, state) {
        final profile = state.profile ?? widget.profile;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _PortfolioBanner(profile: profile),
            const SizedBox(height: 18),
            _StorefrontCard(profile: profile),
            const SizedBox(height: 18),
            _VerificationStatusCard(profile: profile),
            const SizedBox(height: 20),
            const Text(
              'Your performance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B261D),
              ),
            ),
            const SizedBox(height: 10),
            _PerformanceSummary(orders: _orders),
            const SizedBox(height: 24),
            const _HistoricalArtSection(),
          ],
        );
      },
    );
  }
}

class _PortfolioBanner extends StatefulWidget {
  final CreatorProfile profile;

  const _PortfolioBanner({required this.profile});

  @override
  State<_PortfolioBanner> createState() => _PortfolioBannerState();
}

class _PortfolioBannerState extends State<_PortfolioBanner> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _changeBannerImage(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: kImageQuality,
      maxWidth: kProfileImageMaxSide,
      maxHeight: kProfileImageMaxSide,
    );
    if (pickedFile != null && context.mounted) {
      final croppedFile = await showDialog<File>(
        context: context,
        builder: (_) => _BannerCropDialog(
          imageFile: File(pickedFile.path),
        ),
      );
      if (croppedFile != null && context.mounted) {
        final profile = widget.profile;
        context.read<CreatorBloc>().add(
              CreatorSubmitOnboarding(
                uid: profile.uid,
                name: profile.name,
                bio: profile.bio,
                location: profile.location,
                state: profile.state,
                socialLinks: List.of(profile.socialLinks),
                portfolioImageFiles: [croppedFile],
                existingPortfolioUrls: const [],
                story: profile.story,
                existingProfileImageUrl: profile.profileImage,
                exhibitionImageFiles: const [],
                existingExhibitionPictureUrls: profile.exhibitionPictures,
              ),
            );
      }
    }
  }

  Future<void> _shareStorefront(
    BuildContext context,
    RenderBox? renderBox,
  ) async {
    final profile = widget.profile;
    final creatorLink = Uri.https('www.madebyhands.shop', '/', {
      'creator': profile.uid,
    });

    try {
      await SharePlus.instance.share(
        ShareParams(
          title: profile.name,
          subject: 'Check out ${profile.name} on MadeByHands',
          text:
              'Check out ${profile.name}\'s artisan studio on MadeByHands: $creatorLink',
          sharePositionOrigin: renderBox == null
              ? null
              : renderBox.localToGlobal(Offset.zero) & renderBox.size,
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: creatorLink.toString()));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Studio link copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final portfolio = widget.profile.portfolio;

    if (portfolio.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAF6EE),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: const Color(0xFF8B261D).withValues(alpha: 0.25),
          ),
        ),
        child: InkWell(
          onTap: () => _changeBannerImage(context),
          borderRadius: BorderRadius.circular(25),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2DEDD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.collections_outlined,
                    color: Color(0xFF8B261D),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Studio Banner',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: const Color(0xFF8B261D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Add banner image in Profile to showcase your craft studio.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedText,
                          height: 1.3,
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
    }

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: portfolio.length,
                itemBuilder: (context, index) {
                  final imageUrl = portfolio[index];
                  return Container(
                    margin: EdgeInsets.only(
                      right: portfolio.length > 1 ? 8 : 0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              cacheWidth: 800,
                              errorBuilder: (context, error, stack) =>
                                  Container(
                                color: const Color(0xFFEAE7DC),
                                child: const Icon(
                                  Icons.broken_image,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.4),
                                  ],
                                  stops: const [0.6, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: Colors.transparent,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.camera_alt_outlined,
                          size: 18,
                          color: Color(0xFF8B261D),
                        ),
                        onPressed: () => _changeBannerImage(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Builder(
                      builder: (shareContext) => CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.transparent,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.share_outlined,
                            size: 18,
                            color: Color(0xFF8B261D),
                          ),
                          onPressed: () => _shareStorefront(
                            context,
                            shareContext.findRenderObject() as RenderBox?,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (portfolio.length > 1) ...[
          const SizedBox(height: 8),
          Center(
            child: SmoothPageIndicator(
              controller: _pageController,
              count: portfolio.length,
              effect: const ExpandingDotsEffect(
                activeDotColor: Color(0xFF8B261D),
                dotColor: Color(0xFFE2D0B5),
                dotHeight: 7,
                dotWidth: 7,
                expansionFactor: 2.5,
                spacing: 6,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BannerCropDialog extends StatefulWidget {
  final File imageFile;

  const _BannerCropDialog({required this.imageFile});

  @override
  State<_BannerCropDialog> createState() => _BannerCropDialogState();
}

class _BannerCropDialogState extends State<_BannerCropDialog> {
  final TransformationController _transformationController =
      TransformationController();
  ui.Image? _decodedSourceImage;
  bool _isCropping = false;
  double _activeCropW = 0.0;
  double _activeCropH = 0.0;
  double _activeViewportW = 0.0;
  double _activeViewportH = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSourceImage();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadSourceImage() async {
    try {
      final bytes = await XFile(widget.imageFile.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _decodedSourceImage = frame.image;
        });
      }
    } catch (_) {
      try {
        final bytes = await widget.imageFile.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        if (mounted) {
          setState(() {
            _decodedSourceImage = frame.image;
          });
        }
      } catch (_) {}
    }
  }

  void _resetPosition() {
    _transformationController.value = Matrix4.identity();
  }

  Future<void> _saveAndConfirmCrop(
    double cropW,
    double cropH,
    double viewportW,
    double viewportH,
  ) async {
    if (_decodedSourceImage == null) return;
    setState(() => _isCropping = true);

    try {
      final srcImage = _decodedSourceImage!;
      final double srcW = srcImage.width.toDouble();
      final double srcH = srcImage.height.toDouble();
      final double imageRatio = srcW / srcH;
      const double targetRatio = 16 / 9;

      double baseW, baseH;
      if (imageRatio > targetRatio) {
        baseH = cropH;
        baseW = cropH * imageRatio;
      } else {
        baseW = cropW;
        baseH = cropW / imageRatio;
      }

      final Matrix4 transform = _transformationController.value;
      final double scale = transform.getMaxScaleOnAxis();
      final double tx = transform.storage[12];
      final double ty = transform.storage[13];

      final double u = ((viewportW - cropW) / 2.0 - tx) / scale -
          (viewportW - baseW) / 2.0;
      final double v = ((viewportH - cropH) / 2.0 - ty) / scale -
          (viewportH - baseH) / 2.0;

      final double deltaU = cropW / scale;
      final double deltaV = cropH / scale;

      final double normX = (u / baseW).clamp(0.0, 1.0);
      final double normY = (v / baseH).clamp(0.0, 1.0);
      final double normW = (deltaU / baseW).clamp(0.0, 1.0);
      final double normH = (deltaV / baseH).clamp(0.0, 1.0);

      final double srcCropX = normX * srcW;
      final double srcCropY = normY * srcH;
      final double srcCropW = (normW * srcW).clamp(1.0, srcW - srcCropX);
      final double srcCropH = (normH * srcH).clamp(1.0, srcH - srcCropY);

      const double outW = 1920.0;
      const double outH = 1080.0;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.drawImageRect(
        srcImage,
        Rect.fromLTWH(srcCropX, srcCropY, srcCropW, srcCropH),
        const Rect.fromLTWH(0, 0, outW, outH),
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final croppedUiImage =
          await picture.toImage(outW.toInt(), outH.toInt());
      final byteData =
          await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Crop failed');
      final pngBytes = byteData.buffer.asUint8List();

      if (kIsWeb) {
        final xFile = XFile.fromData(
          pngBytes,
          mimeType: 'image/png',
          name: 'cropped_banner_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        final croppedFile = File(xFile.path);
        if (mounted) {
          Navigator.pop(context, croppedFile);
        }
      } else {
        final tempDir = Directory.systemTemp;
        final croppedFile = File(
          '${tempDir.path}/cropped_banner_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await croppedFile.writeAsBytes(pngBytes);

        if (mounted) {
          Navigator.pop(context, croppedFile);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  Widget _buildCropFileImageWidget(
    File file, {
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
  }) {
    if (kIsWeb) {
      return Image.network(
        file.path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, color: Colors.grey),
      );
    } else {
      return Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, color: Colors.grey),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const double targetRatio = 16 / 9;

    return Dialog.fullscreen(
      backgroundColor: const Color(0xFFFAF6EE),
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF6EE),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF8B261D)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Crop Banner Image',
            style: TextStyle(
              color: Color(0xFF8B261D),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              child: Text(
                'Pan and zoom the image to fit inside the crop frame.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8A8F82), fontSize: 13),
              ),
            ),
            Expanded(
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const double padding = 24.0;
                    final double maxW = constraints.maxWidth - (padding * 2);
                    final double maxH = constraints.maxHeight - (padding * 2);
                    double cropW, cropH;
                    if (maxW / maxH > targetRatio) {
                      cropH = maxH;
                      cropW = maxH * targetRatio;
                    } else {
                      cropW = maxW;
                      cropH = maxW / targetRatio;
                    }
                    _activeCropW = cropW;
                    _activeCropH = cropH;
                    _activeViewportW = constraints.maxWidth;
                    _activeViewportH = constraints.maxHeight;

                    final cropRect = Rect.fromCenter(
                      center: Offset(
                        constraints.maxWidth / 2,
                        constraints.maxHeight / 2,
                      ),
                      width: cropW,
                      height: cropH,
                    );

                    double imageRatio = targetRatio;
                    if (_decodedSourceImage != null) {
                      imageRatio = _decodedSourceImage!.width /
                          _decodedSourceImage!.height;
                    }

                    double baseW, baseH;
                    if (imageRatio > targetRatio) {
                      baseH = cropH;
                      baseW = cropH * imageRatio;
                    } else {
                      baseW = cropW;
                      baseH = cropW / imageRatio;
                    }

                    final double marginH = (constraints.maxWidth - cropW) / 2;
                    final double marginV = (constraints.maxHeight - cropH) / 2;

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: InteractiveViewer(
                            transformationController:
                                _transformationController,
                            minScale: 1.0,
                            maxScale: 4.0,
                            boundaryMargin: EdgeInsets.symmetric(
                              horizontal: marginH,
                              vertical: marginV,
                            ),
                            clipBehavior: Clip.none,
                            child: Center(
                              child: SizedBox(
                                width: baseW,
                                height: baseH,
                                child: _buildCropFileImageWidget(
                                  widget.imageFile,
                                  width: baseW,
                                  height: baseH,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _BannerCropOverlayMaskPainter(
                                cropRect: cropRect,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resetPosition,
                      icon: const Icon(
                        Icons.refresh,
                        color: Color(0xFF8B261D),
                        size: 18,
                      ),
                      label: const Text(
                        'Reset Position',
                        style: TextStyle(
                          color: Color(0xFF8B261D),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF8B261D)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (_isCropping || _decodedSourceImage == null)
                          ? null
                          : () {
                              _saveAndConfirmCrop(
                                _activeCropW,
                                _activeCropH,
                                _activeViewportW,
                                _activeViewportH,
                              );
                            },
                      icon: _isCropping
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: const Text(
                        'Save',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF8B261D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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

class _BannerCropOverlayMaskPainter extends CustomPainter {
  final Rect cropRect;

  _BannerCropOverlayMaskPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final maskPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(cropRect, const Radius.circular(16.0)),
      );

    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    canvas.drawPath(maskPath, paint);

    final borderPaint = Paint()
      ..color = const Color(0xFF8B261D)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(cropRect, const Radius.circular(16.0)),
      borderPaint,
    );

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final x1 = cropRect.left + cropRect.width / 3;
    final x2 = cropRect.left + (cropRect.width / 3) * 2;
    final y1 = cropRect.top + cropRect.height / 3;
    final y2 = cropRect.top + (cropRect.height / 3) * 2;

    canvas.drawLine(
      Offset(x1, cropRect.top),
      Offset(x1, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(x2, cropRect.top),
      Offset(x2, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, y1),
      Offset(cropRect.right, y1),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, y2),
      Offset(cropRect.right, y2),
      gridPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _StorefrontCard extends StatelessWidget {
  final CreatorProfile profile;

  const _StorefrontCard({required this.profile});

  void _editProfile(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthSuccess
        ? authState.user
        : UserEntity(
            uid: profile.uid,
            email: '',
            name: profile.name,
            role: 'creator',
          );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatorOnboardingPage(
          user: user,
          existingProfile: profile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: const Color(0xFFF2DEDD),
          backgroundImage: profile.profileImage.isNotEmpty
              ? NetworkImage(profile.profileImage)
              : null,
          child: profile.profileImage.isEmpty
              ? const Icon(
                  Icons.person,
                  size: 36,
                  color: Color(0xFF8B261D),
                )
              : null,
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        color: const Color(0xFF2A1810),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (profile.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified,
                      size: 18,
                      color: Color(0xFF8B261D),
                    ),
                  ],
                ],
              ),
              if (profile.location.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2.0),
                      child: Icon(
                        Icons.location_on,
                        size: 14,
                        color: Color(0xFF8B261D),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        profile.location,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8A8F82),
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _editProfile(context),
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: Color(0xFF8B261D),
                ),
                label: const Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B261D),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: const BorderSide(
                    color: Color(0xFF8B261D),
                    width: 1.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VerificationStatusCard extends StatelessWidget {
  final CreatorProfile profile;

  const _VerificationStatusCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String title, String subtitle) = switch (profile) {
      final p when p.isVerified => (
        Icons.verified,
        Colors.green.shade800,
        'Verified creator',
        'You can list products. Tap to view submitted documents.',
      ),
      final p when p.isUnderReview => (
        Icons.hourglass_top,
        Colors.orange.shade800,
        'Verification under review',
        'An admin is reviewing your documents. Tap to update.',
      ),
      final p when p.isVerificationRejected => (
        Icons.error_outline,
        Colors.red.shade800,
        'Verification not approved',
        p.verificationNote.isEmpty
            ? 'Tap to update your documents and resubmit.'
            : '${p.verificationNote}\nTap to resubmit.',
      ),
      _ => (
        Icons.error_outline,
        Colors.red.shade800,
        'Get verified to start selling',
        'Tap to submit your documents.',
      ),
    };
    return Card(
      elevation: 1,
      color: const Color(0xFFFAF6EE).withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: const Color(0xFF8B261D).withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CreatorVerificationPage(profile: profile)),
        ),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF8B261D)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PerformanceSummary extends StatelessWidget {
  final Stream<List<CreatorOrder>> orders;

  const _PerformanceSummary({required this.orders});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CreatorOrder>>(
      stream: orders,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Could not load your sales right now.',
            style: TextStyle(color: AppColors.mutedText),
          );
        }
        final all = snapshot.data ?? const <CreatorOrder>[];
        final active = all.where((o) => !OrderStatus.isRejectedOrCancelled(o.status)).toList();
        final pending = active.where((o) => OrderStatus.isNew(o.status)).length;
        final inProgress = active.where((o) => OrderStatus.isInProgress(o.status)).length;
        final settled = active.where((o) => o.countsTowardEarnings && o.isPaidOut).toList();
        final totalEarned = settled.fold<int>(0, (total, o) => total + o.creatorNetAmount);

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: [
            _StatCard(
              title: 'New orders',
              value: '$pending',
              icon: Icons.new_releases_outlined,
              color: Colors.deepOrange.shade800,
            ),
            _StatCard(
              title: 'In progress',
              value: '$inProgress',
              icon: Icons.precision_manufacturing_outlined,
              color: Colors.indigo.shade800,
            ),
            _StatCard(
              title: 'Total orders',
              value: '${active.length}',
              icon: Icons.shopping_bag_outlined,
              color: const Color(0xFF8B261D),
            ),
            _StatCard(
              title: 'Earned (settled)',
              value: '₹$totalEarned',
              icon: Icons.payments_outlined,
              color: Colors.green.shade800,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6EE).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF8B261D).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoricalArtSection extends StatefulWidget {
  const _HistoricalArtSection();

  @override
  State<_HistoricalArtSection> createState() => _HistoricalArtSectionState();
}

class _HistoricalArtSectionState extends State<_HistoricalArtSection> {
  late final PageController _storyPageController;
  static const int _initialStoryPage = 1000;

  final List<Map<String, String>> _stories = const [
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
  }

  @override
  void dispose() {
    _storyPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interesting Facts and Stories',
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF8B261D),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _storyPageController,
            itemBuilder: (context, index) {
              final story = _stories[index % _stories.length];
              return _buildStoryCard(story);
            },
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: AnimatedBuilder(
            animation: _storyPageController,
            builder: (context, child) {
              final page = _storyPageController.hasClients &&
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
      margin: const EdgeInsets.only(right: 12, bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6EE),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                story['image']!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: AppColors.outline,
                  child: const Icon(Icons.brush, size: 40, color: AppColors.mutedText),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.3, 0.65, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    story['title']!,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (story['description'] != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      story['description']!,
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
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
}
