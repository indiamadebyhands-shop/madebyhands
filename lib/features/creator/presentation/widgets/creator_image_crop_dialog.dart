import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_background.dart';

class CreatorImageCropDialog extends StatefulWidget {
  final File imageFile;
  final double aspectRatio;
  final bool isCircle;
  final String title;

  const CreatorImageCropDialog({
    super.key,
    required this.imageFile,
    required this.aspectRatio,
    this.isCircle = false,
    required this.title,
  });

  @override
  State<CreatorImageCropDialog> createState() => _CreatorImageCropDialogState();
}

class _CreatorImageCropDialogState extends State<CreatorImageCropDialog> {
  ui.Image? _decodedSourceImage;
  bool _isCropping = false;

  Rect? _cropRect;
  Rect? _imageRect;

  Offset? _dragStartOffset;
  Rect? _dragStartCropRect;

  _ResizeHandle? _activeHandle;

  @override
  void initState() {
    super.initState();
    _loadSourceImage();
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

  void _initCropRectIfNeeded(Size workspaceSize) {
    if (_decodedSourceImage == null) return;

    final double srcW = _decodedSourceImage!.width.toDouble();
    final double srcH = _decodedSourceImage!.height.toDouble();
    final double imgRatio = srcW / srcH;

    const double padding = 24.0;
    final double maxW = workspaceSize.width - (padding * 2);
    final double maxH = workspaceSize.height - (padding * 2);

    double displayW, displayH;
    if (imgRatio > maxW / maxH) {
      displayW = maxW;
      displayH = maxW / imgRatio;
    } else {
      displayH = maxH;
      displayW = displayH * imgRatio;
    }

    final newImageRect = Rect.fromCenter(
      center: Offset(workspaceSize.width / 2, workspaceSize.height / 2),
      width: displayW,
      height: displayH,
    );

    if (_imageRect != newImageRect || _cropRect == null) {
      _imageRect = newImageRect;

      double cropW, cropH;
      if (displayW / displayH > widget.aspectRatio) {
        cropH = displayH * 0.9;
        cropW = cropH * widget.aspectRatio;
      } else {
        cropW = displayW * 0.9;
        cropH = cropW / widget.aspectRatio;
      }

      _cropRect = Rect.fromCenter(
        center: newImageRect.center,
        width: cropW,
        height: cropH,
      );
    }
  }

  void _resetPosition() {
    if (_imageRect == null) return;
    setState(() {
      final displayW = _imageRect!.width;
      final displayH = _imageRect!.height;

      double cropW, cropH;
      if (displayW / displayH > widget.aspectRatio) {
        cropH = displayH * 0.9;
        cropW = cropH * widget.aspectRatio;
      } else {
        cropW = displayW * 0.9;
        cropH = cropW / widget.aspectRatio;
      }

      _cropRect = Rect.fromCenter(
        center: _imageRect!.center,
        width: cropW,
        height: cropH,
      );
    });
  }

  void _handlePanStart(Offset position) {
    if (_cropRect == null || _imageRect == null) return;

    _dragStartOffset = position;
    _dragStartCropRect = _cropRect;

    const double hitRadius = 24.0;
    final rect = _cropRect!;

    if ((position - rect.topLeft).distance <= hitRadius) {
      _activeHandle = _ResizeHandle.topLeft;
    } else if ((position - rect.topRight).distance <= hitRadius) {
      _activeHandle = _ResizeHandle.topRight;
    } else if ((position - rect.bottomLeft).distance <= hitRadius) {
      _activeHandle = _ResizeHandle.bottomLeft;
    } else if ((position - rect.bottomRight).distance <= hitRadius) {
      _activeHandle = _ResizeHandle.bottomRight;
    } else if (rect.contains(position)) {
      _activeHandle = _ResizeHandle.center;
    } else {
      _activeHandle = null;
    }
  }

  void _handlePanUpdate(Offset position) {
    if (_dragStartOffset == null ||
        _dragStartCropRect == null ||
        _imageRect == null ||
        _activeHandle == null) {
      return;
    }

    final delta = position - _dragStartOffset!;
    final startRect = _dragStartCropRect!;
    final imgRect = _imageRect!;
    final R = widget.aspectRatio;

    if (_activeHandle == _ResizeHandle.center) {
      double left = startRect.left + delta.dx;
      double top = startRect.top + delta.dy;

      if (left < imgRect.left) left = imgRect.left;
      if (left + startRect.width > imgRect.right) {
        left = imgRect.right - startRect.width;
      }

      if (top < imgRect.top) top = imgRect.top;
      if (top + startRect.height > imgRect.bottom) {
        top = imgRect.bottom - startRect.height;
      }

      setState(() {
        _cropRect = Rect.fromLTWH(left, top, startRect.width, startRect.height);
      });
      return;
    }

    // Resize via corner handles while strictly preserving widget.aspectRatio
    double proposedW = startRect.width;

    switch (_activeHandle!) {
      case _ResizeHandle.bottomRight:
        proposedW = startRect.width + delta.dx;
        final maxW = imgRect.right - startRect.left;
        final maxH = imgRect.bottom - startRect.top;
        final allowedMaxW = (maxH * R < maxW) ? maxH * R : maxW;
        proposedW = proposedW.clamp(60.0, allowedMaxW);
        final finalH = proposedW / R;
        setState(() {
          _cropRect = Rect.fromLTWH(startRect.left, startRect.top, proposedW, finalH);
        });
        break;

      case _ResizeHandle.bottomLeft:
        proposedW = startRect.width - delta.dx;
        final maxW = startRect.right - imgRect.left;
        final maxH = imgRect.bottom - startRect.top;
        final allowedMaxW = (maxH * R < maxW) ? maxH * R : maxW;
        proposedW = proposedW.clamp(60.0, allowedMaxW);
        final finalH = proposedW / R;
        setState(() {
          _cropRect = Rect.fromLTWH(startRect.right - proposedW, startRect.top, proposedW, finalH);
        });
        break;

      case _ResizeHandle.topRight:
        proposedW = startRect.width + delta.dx;
        final maxW = imgRect.right - startRect.left;
        final maxH = startRect.bottom - imgRect.top;
        final allowedMaxW = (maxH * R < maxW) ? maxH * R : maxW;
        proposedW = proposedW.clamp(60.0, allowedMaxW);
        final finalH = proposedW / R;
        setState(() {
          _cropRect = Rect.fromLTWH(startRect.left, startRect.bottom - finalH, proposedW, finalH);
        });
        break;

      case _ResizeHandle.topLeft:
        proposedW = startRect.width - delta.dx;
        final maxW = startRect.right - imgRect.left;
        final maxH = startRect.bottom - imgRect.top;
        final allowedMaxW = (maxH * R < maxW) ? maxH * R : maxW;
        proposedW = proposedW.clamp(60.0, allowedMaxW);
        final finalH = proposedW / R;
        setState(() {
          _cropRect = Rect.fromLTWH(startRect.right - proposedW, startRect.bottom - finalH, proposedW, finalH);
        });
        break;

      default:
        break;
    }
  }

  Future<void> _saveAndConfirmCrop() async {
    if (_decodedSourceImage == null ||
        _cropRect == null ||
        _imageRect == null) {
      return;
    }
    setState(() => _isCropping = true);

    try {
      final srcImage = _decodedSourceImage!;
      final double srcW = srcImage.width.toDouble();
      final double srcH = srcImage.height.toDouble();

      final double normX =
          ((_cropRect!.left - _imageRect!.left) / _imageRect!.width)
              .clamp(0.0, 1.0);
      final double normY =
          ((_cropRect!.top - _imageRect!.top) / _imageRect!.height)
              .clamp(0.0, 1.0);
      final double normW =
          (_cropRect!.width / _imageRect!.width).clamp(0.0, 1.0);
      final double normH =
          (_cropRect!.height / _imageRect!.height).clamp(0.0, 1.0);

      final double srcCropX = normX * srcW;
      final double srcCropY = normY * srcH;
      final double srcCropW = (normW * srcW).clamp(1.0, srcW - srcCropX);
      final double srcCropH = (normH * srcH).clamp(1.0, srcH - srcCropY);

      final double outW = widget.aspectRatio == 1.0 ? 1080.0 : 1920.0;
      final double outH = widget.aspectRatio == 1.0 ? 1080.0 : 1080.0;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.drawImageRect(
        srcImage,
        Rect.fromLTWH(srcCropX, srcCropY, srcCropW, srcCropH),
        Rect.fromLTWH(0, 0, outW, outH),
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
          name: 'cropped_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        final croppedFile = File(xFile.path);
        if (mounted) {
          Navigator.pop(context, croppedFile);
        }
      } else {
        final tempDir = Directory.systemTemp;
        final croppedFile = File(
          '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.png',
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
    final isCircle = widget.isCircle;

    return BuyerBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF8B261D)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.title,
            style: const TextStyle(
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
                'Drag or resize the grid frame to select the crop area.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8A8F82), fontSize: 13),
              ),
            ),
            Expanded(
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final workspaceSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    _initCropRectIfNeeded(workspaceSize);

                    if (_imageRect == null || _cropRect == null) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final imgRect = _imageRect!;
                    final cropRect = _cropRect!;

                    return GestureDetector(
                      onPanStart: (details) =>
                          _handlePanStart(details.localPosition),
                      onPanUpdate: (details) =>
                          _handlePanUpdate(details.localPosition),
                      child: Stack(
                        children: [
                          Positioned(
                            left: imgRect.left,
                            top: imgRect.top,
                            width: imgRect.width,
                            height: imgRect.height,
                            child: _buildCropFileImageWidget(
                              widget.imageFile,
                              width: imgRect.width,
                              height: imgRect.height,
                              fit: BoxFit.fill,
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _CropOverlayMaskPainter(
                                  cropRect: cropRect,
                                  isCircle: isCircle,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: cropRect.left - 12,
                            top: cropRect.top - 12,
                            child: _buildCornerHandle(),
                          ),
                          Positioned(
                            left: cropRect.right - 12,
                            top: cropRect.top - 12,
                            child: _buildCornerHandle(),
                          ),
                          Positioned(
                            left: cropRect.left - 12,
                            top: cropRect.bottom - 12,
                            child: _buildCornerHandle(),
                          ),
                          Positioned(
                            left: cropRect.right - 12,
                            top: cropRect.bottom - 12,
                            child: _buildCornerHandle(),
                          ),
                        ],
                      ),
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
                          : _saveAndConfirmCrop,
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

  Widget _buildCornerHandle() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF8B261D),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

enum _ResizeHandle { topLeft, topRight, bottomLeft, bottomRight, center }

class _CropOverlayMaskPainter extends CustomPainter {
  final Rect cropRect;
  final bool isCircle;

  _CropOverlayMaskPainter({
    required this.cropRect,
    this.isCircle = false,
  });

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

    if (isCircle) {
      final circlePaint = Paint()
        ..color = const Color(0xFF8B261D)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      canvas.drawOval(cropRect, circlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
