import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:madebyhands/core/theme/app_theme.dart';
import 'package:madebyhands/features/buyer/presentation/theme/buyer_theme.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/arch_backdrop.dart';

/// The backdrop shared by every buyer screen. It also applies [BuyerTheme],
/// so anything built underneath — including dialogs and bottom sheets opened
/// from it — picks up the buyer fonts, buttons, fields and cards.
class BuyerBackground extends StatelessWidget {
  final Widget child;

  const BuyerBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: defaultSystemUiOverlayStyle,
      child: Theme(
        data: BuyerTheme.data,
        child: ColoredBox(color: BuyerColors.paper, child: child),
      ),
    );
  }
}

/// Frames a dashboard tab the way the Home tab is framed: the pink backdrop
/// behind the status bar, a scalloped edge, and the cream page below it. The
/// tab itself is kept clear of the status bar and the scallops.
class BuyerTabFrame extends StatelessWidget {
  final Widget child;

  const BuyerTabFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: pinkArchSystemUiOverlayStyle,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: BuyerColors.paper)),
          const Positioned(top: 0, left: 0, right: 0, child: ScallopedHeader()),
          Positioned.fill(
            child: SafeArea(
              minimum: EdgeInsets.zero,
              child: Padding(
                padding:
                    const EdgeInsets.only(top: ScallopedHeader.contentInset),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
