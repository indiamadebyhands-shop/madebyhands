import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:madebyhands/core/theme/app_theme.dart';

/// The buyer panel's palette, taken from the Home tab: the cream of its
/// arched panel, gold outlines and maroon accents.
abstract final class BuyerColors {
  /// Page background (see `BuyerBackground`) — the cream of the Home arch.
  static const paper = Color(0xFFFCF0DE);

  /// Cards — a lighter ivory that lifts off the page.
  static const card = Color(0xFFFFFAF0);

  /// Text fields and pill controls — the Home search bar's fill.
  static const field = Color(0xFFFFFDF8);
  static const sand = Color(0xFFF4E6CF);
  static const clay = Color(0xFFEAD9C6);

  /// Tint behind a selected or highlighted item.
  static const blush = Color(0xFFF6DCCF);

  /// Icons, links, prices and filled buttons.
  static const maroon = Color(0xFF8B261D);

  /// Section headings ("Historical Art & Stories", "Categories").
  static const maroonDeep = Color(0xFF6B1D1D);

  /// Titles and primary text.
  static const ink = Color(0xFF331818);

  /// Descriptive text.
  static const body = Color(0xFF5A4438);

  /// Hints, captions and metadata.
  static const muted = Color(0xFF8A7F73);

  /// Card outlines and dividers — the soft gold of the Home category cards.
  static const line = Color(0xFFE3C9A1);

  /// Field and pill outlines — the Home search bar's border.
  static const gold = Color(0xFFC49A6C);
  static const goldSoft = Color(0xFFE2D0B5);

  static const star = Color(0xFFE0A72F);
}

/// Theme for every buyer screen. Applied by `BuyerBackground`, so a page
/// wrapped in it gets the Home tab's fonts, pill fields and buttons and the
/// product card's surfaces without styling each widget by hand.
abstract final class BuyerTheme {
  static final ThemeData data = _build();

  static OutlineInputBorder _inputBorder(Color color, [double width = 1.1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: color, width: width),
      );

  static ThemeData _build() {
    final base = AppTheme.lightThemeMode;

    final scheme = base.colorScheme.copyWith(
      primary: BuyerColors.maroon,
      onPrimary: Colors.white,
      primaryContainer: BuyerColors.blush,
      onPrimaryContainer: BuyerColors.maroonDeep,
      secondary: BuyerColors.maroon,
      onSecondary: Colors.white,
      secondaryContainer: BuyerColors.blush,
      onSecondaryContainer: BuyerColors.maroonDeep,
      tertiary: BuyerColors.gold,
      onTertiary: BuyerColors.ink,
      surface: BuyerColors.card,
      onSurface: BuyerColors.ink,
      // Also the default colour of icon buttons and popup-menu icons.
      onSurfaceVariant: BuyerColors.maroon,
      surfaceContainerLowest: BuyerColors.field,
      surfaceContainerLow: BuyerColors.paper,
      surfaceContainer: BuyerColors.paper,
      surfaceContainerHigh: BuyerColors.paper,
      surfaceContainerHighest: BuyerColors.sand,
      surfaceTint: Colors.transparent,
      outline: BuyerColors.gold,
      outlineVariant: BuyerColors.line,
    );

    // Home's headings are Montserrat Black in deep maroon.
    TextStyle heading(double size, {Color color = BuyerColors.maroonDeep}) =>
        GoogleFonts.montserrat(
          fontSize: size,
          fontWeight: FontWeight.w900,
          color: color,
          height: 1.2,
        );
    TextStyle sans(
      double size,
      FontWeight weight, {
      Color color = BuyerColors.ink,
      double? height,
    }) => GoogleFonts.montserrat(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );

    final textTheme = base.textTheme.copyWith(
      displayLarge: heading(34),
      displayMedium: heading(30),
      displaySmall: heading(26),
      headlineLarge: heading(24),
      headlineMedium: heading(22),
      headlineSmall: heading(20),
      titleLarge: heading(17),
      titleMedium: sans(15, FontWeight.w700),
      titleSmall: sans(13.5, FontWeight.w700),
      bodyLarge: sans(15, FontWeight.w500, height: 1.45),
      bodyMedium: sans(13.5, FontWeight.w500, height: 1.4),
      bodySmall: sans(12, FontWeight.w500, color: BuyerColors.muted),
      labelLarge: sans(14, FontWeight.w700),
      labelMedium: sans(12.5, FontWeight.w600),
      labelSmall: sans(11.5, FontWeight.w600, color: BuyerColors.muted),
    );

    const pill = StadiumBorder();

    return base.copyWith(
      colorScheme: scheme,
      // Buyer pages sit on the backdrop drawn by BuyerBackground.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: BuyerColors.field,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashColor: BuyerColors.maroon.withValues(alpha: 0.08),
      highlightColor: BuyerColors.maroon.withValues(alpha: 0.05),
      iconTheme: const IconThemeData(color: BuyerColors.maroon),
      dividerTheme: const DividerThemeData(
        color: BuyerColors.line,
        thickness: 1,
        space: 24,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: BuyerColors.maroon,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: BuyerColors.maroon),
        actionsIconTheme: const IconThemeData(color: BuyerColors.maroon),
        titleTextStyle: sans(19, FontWeight.w800, color: BuyerColors.maroon),
        systemOverlayStyle: defaultSystemUiOverlayStyle,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFFFCF0DE),
        indicatorColor: BuyerColors.blush,
      ),
      // The product card: ivory surface, thin gold outline, 20px corners and
      // a soft maroon-tinted shadow.
      cardTheme: CardThemeData(
        color: BuyerColors.card,
        surfaceTintColor: Colors.transparent,
        shadowColor: BuyerColors.maroonDeep.withValues(alpha: 0.35),
        elevation: 2,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: BuyerColors.line, width: 1.2),
        ),
      ),
      // No textColor here: ListTile would paint it over the subtitle's own
      // colour as well as the title's.
      listTileTheme: ListTileThemeData(
        iconColor: BuyerColors.maroon,
        titleTextStyle: sans(14.5, FontWeight.w700),
        subtitleTextStyle: sans(
          12.5,
          FontWeight.w500,
          color: BuyerColors.body,
          height: 1.35,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Finite width, so buttons sit side by side in dialogs; full-width
          // buttons get their width from a stretching parent.
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          backgroundColor: BuyerColors.maroon,
          foregroundColor: Colors.white,
          disabledBackgroundColor: BuyerColors.goldSoft,
          disabledForegroundColor: BuyerColors.muted,
          shape: pill,
          textStyle: sans(14.5, FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          backgroundColor: BuyerColors.field,
          foregroundColor: BuyerColors.maroon,
          disabledForegroundColor: BuyerColors.muted,
          side: const BorderSide(color: BuyerColors.maroon, width: 1.2),
          shape: pill,
          textStyle: sans(14.5, FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BuyerColors.maroon,
          shape: pill,
          textStyle: sans(13.5, FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: BuyerColors.maroon,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: pill,
        extendedTextStyle: sans(14, FontWeight.w700),
      ),
      // The Home search bar: a cream pill with a thin gold outline.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BuyerColors.field,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 13,
        ),
        border: _inputBorder(BuyerColors.gold),
        enabledBorder: _inputBorder(BuyerColors.gold),
        disabledBorder: _inputBorder(BuyerColors.goldSoft),
        focusedBorder: _inputBorder(BuyerColors.maroon, 1.4),
        errorBorder: _inputBorder(Colors.redAccent),
        focusedErrorBorder: _inputBorder(Colors.redAccent, 1.4),
        labelStyle: sans(13, FontWeight.w500, color: BuyerColors.muted),
        floatingLabelStyle: sans(
          13,
          FontWeight.w600,
          color: BuyerColors.maroon,
        ),
        hintStyle: sans(12.5, FontWeight.w500, color: BuyerColors.muted),
        helperStyle: sans(11.5, FontWeight.w500, color: BuyerColors.muted),
        counterStyle: sans(11, FontWeight.w500, color: BuyerColors.muted),
        prefixIconColor: BuyerColors.maroon,
        suffixIconColor: BuyerColors.maroon,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: BuyerColors.maroon,
        selectionColor: BuyerColors.maroon.withValues(alpha: 0.22),
        selectionHandleColor: BuyerColors.maroon,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: BuyerColors.field,
        selectedColor: BuyerColors.blush,
        checkmarkColor: BuyerColors.maroon,
        deleteIconColor: BuyerColors.maroon,
        iconTheme: const IconThemeData(color: BuyerColors.maroon, size: 18),
        side: const BorderSide(color: BuyerColors.gold),
        shape: pill,
        labelStyle: sans(12.5, FontWeight.w600, color: BuyerColors.maroon),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: BuyerColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: heading(18),
        contentTextStyle: sans(
          13.5,
          FontWeight.w500,
          color: BuyerColors.body,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BuyerColors.paper,
        modalBackgroundColor: BuyerColors.paper,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: BuyerColors.gold,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: BuyerColors.ink,
        actionTextColor: BuyerColors.goldSoft,
        contentTextStyle: sans(13, FontWeight.w600, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: BuyerColors.field,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: BuyerColors.line),
        ),
        textStyle: sans(13.5, FontWeight.w600),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BuyerColors.maroon,
        linearTrackColor: BuyerColors.goldSoft,
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: BuyerColors.maroon,
        textColor: Colors.white,
      ),
    );
  }
}
