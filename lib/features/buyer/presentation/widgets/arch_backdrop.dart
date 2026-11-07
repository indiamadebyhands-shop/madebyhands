import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:madebyhands/core/theme/app_theme.dart';

/// The Home tab's backdrop: a cream arched window (a "jharokha") on a rose
/// pink field. It is drawn in code rather than stretched from a bitmap, so it
/// stays sharp at any size and keeps the arch's proportions: the scalloped
/// top is scaled uniformly with the screen width while the cream body simply
/// runs down to the bottom of whatever height it is given.
///
/// On wide screens (web, tablets) the arch stops growing at [maxArchWidth]
/// and is centred on the pink field instead of being blown up.
class ArchBackdrop extends StatelessWidget {
  const ArchBackdrop({super.key, this.maxArchWidth = defaultMaxArchWidth});

  /// The widest the arch is drawn. Content laid over the backdrop should be
  /// held to the same width so it stays inside the cream panel.
  static const defaultMaxArchWidth = 520.0;

  final double maxArchWidth;

  /// The tip of the arch starts this far above the bottom of the status
  /// bar: the bar's own content is centred, so its last few pixels are empty.
  static const _statusBarOverlap = 6.0;

  /// How far below the arch's top edge the header (logo) starts, in design
  /// units, so that it sits inside the crown with room around it.
  static const _headerDrop = 24.0;

  /// Where the arch starts, measured from the top of the screen. It begins
  /// just under the status bar so the clock and battery stay on plain pink.
  static double topOffset(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    return math.max(0.0, safeTop - _statusBarOverlap);
  }

  /// How far below the top safe-area edge the header content laid over the
  /// backdrop should start, so the logo lands inside the crown of the arch
  /// on every screen size.
  static double headerInset(
    BuildContext context, {
    double maxArchWidth = defaultMaxArchWidth,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final scale =
        math.min(width, maxArchWidth) / ArchBackdropPainter._designWidth;
    final safeTop = MediaQuery.paddingOf(context).top;
    return topOffset(context) - safeTop + _headerDrop * scale;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: pinkArchSystemUiOverlayStyle,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: ArchBackdropPainter(
            maxArchWidth: maxArchWidth,
            top: topOffset(context),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class ArchBackdropPainter extends CustomPainter {
  const ArchBackdropPainter({required this.maxArchWidth, this.top = 0});

  final double maxArchWidth;

  /// How far down the screen the arch starts.
  final double top;

  static const _pinkTop = Color(0xFFEF7790);
  static const _pinkBottom = Color(0xFFF48EA2);
  static const _grainLight = Color(0xFFFFE3E8);
  static const _grainDark = Color(0xFF9C2F52);
  static const _cream = Color(0xFFFCF0DE);
  static const _grain = Color(0xFFEFD9B8);
  static const _shade = Color(0xFFB8456A);
  static const _rim = Color(0xFFE9C9A0);

  // Everything below is in "design units": the arch is laid out on a grid
  // [_designWidth] wide and scaled uniformly to the screen, so it never
  // stretches.
  static const _designWidth = 328.0;
  static const _centreX = _designWidth / 2;
  static const _wallX = 6.0;

  /// The scallops' inner points (cusps) sit on this ellipse, which gives the
  /// arch its overall sweep: wide and low, so the header content fits inside.
  static const _guideCentreY = 113.0;
  static const _guideHalfWidth = 149.0;
  static const _guideRise = 86.0;

  /// Where the first and last cusps sit on the guide, as angles above the
  /// horizontal, and how many scallops run between them on each side.
  static const _firstCuspAngle = 4.0 * math.pi / 180;
  static const _lastCuspAngle = 74.0 * math.pi / 180;
  static const _scallopsPerSide = 3;

  /// How far each scallop bulges out, as a fraction of its width. The crown
  /// (the wider scallop across the top) is a little flatter.
  static const _bulge = 0.30;
  static const _crownBulge = 0.19;

  /// The crown rises into a point: the height of that point above the crown,
  /// and how far round the crown (from the vertical) it starts.
  static const _tipHeight = 10.0;
  static const _tipSpread = 17.0 * math.pi / 180;

  /// Radius of the small rounding where two scallops meet.
  static const _cuspRounding = 2.4;

  static Offset _onGuide(double angle) => Offset(
    _centreX - _guideHalfWidth * math.cos(angle),
    _guideCentreY - _guideRise * math.sin(angle),
  );

  /// Cusps spaced evenly along the guide, so every scallop is the same size.
  static List<Offset> _cusps() {
    const samples = 720;
    final points = <Offset>[];
    final lengths = <double>[0];
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      points.add(
        _onGuide(_firstCuspAngle + (_lastCuspAngle - _firstCuspAngle) * t),
      );
      if (i > 0) {
        lengths.add(lengths.last + (points[i] - points[i - 1]).distance);
      }
    }
    final cusps = <Offset>[points.first];
    var cursor = 0;
    for (var k = 1; k < _scallopsPerSide; k++) {
      final target = lengths.last * k / _scallopsPerSide;
      while (lengths[cursor] < target) {
        cursor++;
      }
      cusps.add(points[cursor]);
    }
    cusps.add(points.last);
    return cusps;
  }

  /// The point at distance [ra] from [a] and [rb] from [b] that lies nearest
  /// to [near] (one of the two places the circles cross).
  static Offset _crossing(
    Offset a,
    double ra,
    Offset b,
    double rb,
    Offset near,
  ) {
    final d = (b - a).distance;
    final along = (d * d + ra * ra - rb * rb) / (2 * d);
    final off = math.sqrt(math.max(0, ra * ra - along * along));
    final unit = (b - a) / d;
    final foot = a + unit * along;
    final normal = Offset(-unit.dy, unit.dx);
    final first = foot + normal * off;
    final second = foot - normal * off;
    return (first - near).distance < (second - near).distance ? first : second;
  }

  /// The top of the arch, wall to wall, in design units. It is made only of
  /// circular arcs that meet smoothly: the scallops, a small rounding at
  /// each cusp, and the two curves that sweep up to the tip.
  static final Path _designArch = _buildDesignArch();

  static Path _buildDesignArch() {
    final cusps = _cusps();
    Offset mirror(Offset o) => Offset(_designWidth - o.dx, o.dy);

    // Every side scallop is an arc of the same size of circle.
    final chord = (cusps[1] - cusps[0]).distance;
    final sagitta = chord * _bulge;
    final r = (chord * chord / 4 + sagitta * sagitta) / (2 * sagitta);

    // Scallop circles, from the wall up: [centre, radius].
    final centres = <Offset>[];
    final radii = <double>[];

    // The wall runs straight up into a half scallop, so there is no kink
    // where the arch springs from it.
    final dx = cusps.first.dx - (_wallX + r);
    final wallTopY = cusps.first.dy + math.sqrt(r * r - dx * dx);
    centres.add(Offset(_wallX + r, wallTopY));
    radii.add(r);

    for (var i = 0; i < cusps.length - 1; i++) {
      final from = cusps[i];
      final to = cusps[i + 1];
      final along = (to - from) / (to - from).distance;
      final inward = Offset(-along.dy, along.dx);
      centres.add((from + to) / 2 + inward * (r - sagitta));
      radii.add(r);
    }

    // The crown spans the top, from the last cusp to its mirror image.
    final last = cusps.last;
    final halfSpan = _centreX - last.dx;
    final crownSagitta = 2 * halfSpan * _crownBulge;
    final crownR =
        (halfSpan * halfSpan + crownSagitta * crownSagitta) /
        (2 * crownSagitta);
    final crownCentre = Offset(_centreX, last.dy - crownSagitta + crownR);
    centres.add(crownCentre);
    radii.add(crownR);

    // Left half as a chain of arcs: each entry ends at [points] and has a
    // radius and a direction.
    final points = <Offset>[];
    final arcRadii = <double>[];
    final clockwise = <bool>[];
    void arc(Offset to, double radius, {bool cw = true}) {
      points.add(to);
      arcRadii.add(radius);
      clockwise.add(cw);
    }

    for (var i = 0; i < cusps.length; i++) {
      // Round the cusp between scallop i and scallop i + 1 with a small
      // circle that touches both.
      final fillet = _crossing(
        centres[i],
        radii[i] + _cuspRounding,
        centres[i + 1],
        radii[i + 1] + _cuspRounding,
        cusps[i],
      );
      Offset touch(int k) =>
          centres[k] +
          (fillet - centres[k]) * (radii[k] / (radii[k] + _cuspRounding));
      arc(touch(i), radii[i]);
      arc(touch(i + 1), _cuspRounding, cw: false);
    }

    // Up the crown, then a reverse curve into the tip.
    final outward = Offset(-math.sin(_tipSpread), -math.cos(_tipSpread));
    final turn = crownCentre + outward * crownR;
    final tip = Offset(_centreX, crownCentre.dy - crownR - _tipHeight);
    final toTip = tip - turn;
    final tipR =
        toTip.distanceSquared /
        (2 * (outward.dx * toTip.dx + outward.dy * toTip.dy));
    arc(turn, crownR);
    arc(tip, tipR, cw: false);

    final path = Path()..moveTo(_wallX, wallTopY);
    for (var i = 0; i < points.length; i++) {
      path.arcToPoint(
        points[i],
        radius: Radius.circular(arcRadii[i]),
        clockwise: clockwise[i],
      );
    }
    for (var i = points.length - 1; i >= 0; i--) {
      path.arcToPoint(
        i == 0
            ? Offset(_designWidth - _wallX, wallTopY)
            : mirror(points[i - 1]),
        radius: Radius.circular(arcRadii[i]),
        clockwise: clockwise[i],
      );
    }
    return path;
  }

  /// A small square of fine speckles, light and dark, that is repeated over
  /// the pink field to give it a grainy, printed-paper feel. It is drawn once
  /// at twice its display size so the grain stays crisp on dense screens.
  static const _grainTile = 256.0;
  static const _grainDensity = 2.0;
  static final ui.Image _grainImage = _buildGrain();

  static ui.Image _buildGrain() {
    const side = _grainTile * _grainDensity;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final random = math.Random(11);
    Float32List speckles(int count) {
      final list = Float32List(count * 2);
      for (var i = 0; i < list.length; i++) {
        list[i] = random.nextDouble() * side;
      }
      return list;
    }

    void scatter(Color color, double alpha, double width, int count) {
      canvas.drawRawPoints(
        ui.PointMode.points,
        speckles(count),
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = width,
      );
    }

    scatter(_grainDark, 0.16, 1.6, 22000);
    scatter(_grainLight, 0.20, 1.6, 22000);
    scatter(_grainDark, 0.10, 2.6, 5000);
    scatter(_grainLight, 0.12, 2.6, 5000);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(side.toInt(), side.toInt());
    picture.dispose();
    return image;
  }

  double _scaleFor(Size size) =>
      (size.width < maxArchWidth ? size.width : maxArchWidth) / _designWidth;

  Path _archPath(Size size) {
    final scale = _scaleFor(size);
    final left = (size.width - _designWidth * scale) / 2;
    final matrix = Float64List.fromList([
      scale, 0, 0, 0, //
      0, scale, 0, 0, //
      0, 0, 1, 0, //
      left, top, 0, 1, //
    ]);
    final bottom = size.height + 40;
    return _designArch.transform(matrix)
      ..lineTo(left + (_designWidth - _wallX) * scale, bottom)
      ..lineTo(left + _wallX * scale, bottom)
      ..close();
  }

  /// Paints the grainy pink field over [area]. The fade from deeper to
  /// lighter pink is laid out over [fadeOver], so a strip of the field can
  /// be painted to match the top of the full-screen one.
  static void paintField(Canvas canvas, Rect area, {Rect? fadeOver}) {
    canvas.drawRect(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_pinkTop, _pinkBottom],
        ).createShader(fadeOver ?? area),
    );
    canvas.drawRect(
      area,
      Paint()
        ..shader = ui.ImageShader(
          _grainImage,
          TileMode.repeated,
          TileMode.repeated,
          Float64List.fromList([
            1 / _grainDensity, 0, 0, 0, //
            0, 1 / _grainDensity, 0, 0, //
            0, 0, 1, 0, //
            0, 0, 0, 1, //
          ]),
          filterQuality: FilterQuality.low,
        ),
    );
  }

  /// Paints a cream panel shaped like [panel]: a soft shadow behind it and
  /// the cream fill.
  static void paintPanel(Canvas canvas, Path panel, double scale) {
    canvas.drawPath(
      panel,
      Paint()
        ..color = _shade.withValues(alpha: 0.38)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 * scale),
    );
    canvas.drawPath(panel, Paint()..color = _cream);
  }

  /// Paints the thin gold rim just inside the edge of [panel], following
  /// every scallop. The canvas must already be clipped to [panel].
  static void paintRim(Canvas canvas, Path panel, double scale) {
    canvas.drawPath(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 9 * scale
        ..color = _rim.withValues(alpha: 0.9),
    );
    canvas.drawPath(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 7 * scale
        ..color = _cream,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = _scaleFor(size);
    paintField(canvas, Offset.zero & size);

    final arch = _archPath(size);
    paintPanel(canvas, arch, scale);

    canvas.save();
    canvas.clipPath(arch);

    // Faint horizontal grain, like handmade paper. A fixed seed keeps it
    // identical on every paint and for every size.
    final left = (size.width - _designWidth * scale) / 2;
    final random = math.Random(7);
    final grainPaint = Paint()
      ..color = _grain.withValues(alpha: 0.16)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.9 * scale;
    final rows = (size.height / scale / 11).ceil();
    for (var i = 0; i < rows; i++) {
      final y = top + (24 + i * 11 + random.nextDouble() * 8) * scale;
      final x = left + (random.nextDouble() * (_designWidth - 90)) * scale;
      final length = (40 + random.nextDouble() * 80) * scale;
      canvas.drawLine(Offset(x, y), Offset(x + length, y), grainPaint);
    }

    paintRim(canvas, arch, scale);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ArchBackdropPainter oldDelegate) =>
      oldDelegate.maxArchWidth != maxArchWidth || oldDelegate.top != top;
}

/// A strip of the Home backdrop for the top of the other buyer tabs: the
/// grainy pink field behind the status bar, ending in a row of the arch's
/// scallops where the cream page begins.
class ScallopedHeader extends StatelessWidget {
  const ScallopedHeader({super.key});

  /// How far the strip reaches below the status bar. Content laid over the
  /// page should start [contentInset] below the status bar.
  static const depth = 24.0;
  static const contentInset = 18.0;

  /// Total height of the strip on this screen.
  static double heightOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top + depth;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: pinkArchSystemUiOverlayStyle,
      child: SizedBox(
        height: heightOf(context),
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _ScallopedHeaderPainter(
              safeTop: MediaQuery.paddingOf(context).top,
              screenHeight: MediaQuery.sizeOf(context).height,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _ScallopedHeaderPainter extends CustomPainter {
  const _ScallopedHeaderPainter({
    required this.safeTop,
    required this.screenHeight,
  });

  final double safeTop;
  final double screenHeight;

  /// The cusps sit this far below the status bar; the scallops rise from
  /// there back up towards it.
  static const _cuspDrop = 14.0;
  static const _scallopWidth = 38.0;
  static const _bulge = 0.30;
  static const _cuspRounding = 2.4;

  /// The rim and shadow are drawn as they are on a phone-sized arch.
  static const _scale = 1.1;

  Path _panel(Size size) {
    final count = math.max(1, (size.width / _scallopWidth).round());
    final chord = size.width / count;
    final sagitta = chord * _bulge;
    final r = (chord * chord / 4 + sagitta * sagitta) / (2 * sagitta);
    final cuspY = safeTop + _cuspDrop;
    final centreY = cuspY + (r - sagitta);

    // The small circle that rounds a cusp sits straight above it and
    // touches the scallops on either side.
    final reach = r + _cuspRounding;
    final filletY = centreY - math.sqrt(reach * reach - chord * chord / 4);
    Offset touch(double cuspX, double centreX) {
      final centre = Offset(centreX, centreY);
      return centre + (Offset(cuspX, filletY) - centre) * (r / reach);
    }

    const overhang = 24.0;
    final bottom = size.height + overhang;
    final path = Path()
      ..moveTo(-overhang, bottom)
      ..lineTo(-overhang, cuspY)
      ..lineTo(0, cuspY);
    for (var i = 0; i < count; i++) {
      final centreX = (i + 0.5) * chord;
      final endX = (i + 1) * chord;
      if (i == count - 1) {
        path.arcToPoint(Offset(endX, cuspY), radius: Radius.circular(r));
      } else {
        path
          ..arcToPoint(touch(endX, centreX), radius: Radius.circular(r))
          ..arcToPoint(
            touch(endX, centreX + chord),
            radius: const Radius.circular(_cuspRounding),
            clockwise: false,
          );
      }
    }
    return path
      ..lineTo(size.width + overhang, cuspY)
      ..lineTo(size.width + overhang, bottom)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final area = Offset.zero & size;
    canvas.save();
    canvas.clipRect(area);
    ArchBackdropPainter.paintField(
      canvas,
      area,
      fadeOver: Rect.fromLTWH(0, 0, size.width, screenHeight),
    );
    final panel = _panel(size);
    ArchBackdropPainter.paintPanel(canvas, panel, _scale);
    canvas.clipPath(panel);
    ArchBackdropPainter.paintRim(canvas, panel, _scale);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScallopedHeaderPainter oldDelegate) =>
      oldDelegate.safeTop != safeTop ||
      oldDelegate.screenHeight != screenHeight;
}
