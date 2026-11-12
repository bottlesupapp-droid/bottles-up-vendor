import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppTheme {
  static const Color _primaryOrange = Color(0xFFFF6B35);
  static const Color _primaryOrangeLight = Color(0xFFFF8C66);

  static ThemeData get lightTheme {
    return FlexThemeData.light(
      scheme: FlexScheme.custom,
      colors: const FlexSchemeColor(
        primary: _primaryOrange,
        primaryContainer: _primaryOrangeLight,
        secondary: Color(0xFF03DAC6),
        secondaryContainer: Color(0xFF018786),
        tertiary: Color(0xFF6200EA),
        tertiaryContainer: Color(0xFF3700B3),
        appBarColor: _primaryOrange,
        error: Color(0xFFB00020),
      ),
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 20,
      appBarOpacity: 0.95,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 20,
        blendOnColors: false,
        useM2StyleDividerInM3: true,
        bottomNavigationBarSelectedLabelSchemeColor: SchemeColor.onPrimary,
        bottomNavigationBarUnselectedLabelSchemeColor: SchemeColor.onSurface,
        bottomNavigationBarSelectedIconSchemeColor: SchemeColor.onPrimary,
        bottomNavigationBarUnselectedIconSchemeColor: SchemeColor.onSurface,
        bottomNavigationBarBackgroundSchemeColor: SchemeColor.primary,
        // Remove elevations
        bottomNavigationBarElevation: 0,
        cardElevation: 0,
        dialogElevation: 0,
        navigationBarElevation: 0,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      fontFamily: fontFamily,
    );
  }

  /// The family name of the bundled Inter font (declared in pubspec.yaml). Bundled so text looks the same on every phone, offline, from the first
  /// frame; the app no longer downloads its font at run time.
  static const String fontFamily = 'Inter';

  /// The look of BottlesUp Business: see [BuTokens]. The app only uses this one (it is forced to dark).
  static ThemeData get darkTheme {
    const t = BuTokens.dark;
    final text = _textTheme(t);
    final scheme = ColorScheme.dark(
      primary: t.orange,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF3A1F17),
      onPrimaryContainer: t.orangeSoft,
      secondary: t.orangeSoft,
      onSecondary: Colors.black,
      secondaryContainer: t.raised,
      onSecondaryContainer: t.ink,
      tertiary: t.amber,
      onTertiary: Colors.black,
      tertiaryContainer: const Color(0xFF3A2C14),
      onTertiaryContainer: t.amber,
      error: t.red,
      onError: Colors.black,
      errorContainer: const Color(0xFF3A1A1A),
      onErrorContainer: const Color(0xFFFFB4B4),
      surface: t.bg,
      onSurface: t.ink,
      onSurfaceVariant: t.muted,
      surfaceContainerLowest: t.bg,
      surfaceContainerLow: t.panel,
      surfaceContainer: t.panel,
      surfaceContainerHigh: t.panel2,
      surfaceContainerHighest: t.raised,
      outline: t.line,
      outlineVariant: t.line,
      inverseSurface: t.ink,
      onInverseSurface: t.bg,
      surfaceTint: Colors.transparent,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.control));
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(BuRadius.control), borderSide: BorderSide(color: color, width: width));

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text,
      primaryTextTheme: text,
      scaffoldBackgroundColor: t.bg,
      canvasColor: t.bg,
      cardColor: t.panel,
      dividerColor: t.line,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      extensions: const [t],
      iconTheme: IconThemeData(color: t.soft),
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        foregroundColor: t.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: t.ink),
      ),
      cardTheme: CardThemeData(
        color: t.panel,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BuRadius.card),
          side: BorderSide(color: t.hairline),
        ),
      ),
      dividerTheme: DividerThemeData(color: t.line, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: t.soft,
        textColor: t.ink,
        subtitleTextStyle: text.bodyMedium?.copyWith(color: t.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: BuSpace.l),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: t.raised,
          disabledForegroundColor: t.muted,
          minimumSize: const Size(64, 52),
          shape: controlShape,
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: t.raised,
          disabledForegroundColor: t.muted,
          elevation: 0,
          minimumSize: const Size(64, 52),
          shape: controlShape,
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.ink,
          disabledForegroundColor: t.muted,
          side: BorderSide(color: t.line),
          minimumSize: const Size(64, 48),
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.orangeSoft,
          disabledForegroundColor: t.muted,
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: t.soft, shape: controlShape),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.card)),
        extendedTextStyle: text.labelLarge?.copyWith(fontSize: 15),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.panel,
        contentPadding: const EdgeInsets.symmetric(horizontal: BuSpace.l, vertical: BuSpace.l),
        hintStyle: text.bodyMedium?.copyWith(color: t.muted.withValues(alpha: 0.7)),
        labelStyle: text.bodyMedium?.copyWith(color: t.muted),
        floatingLabelStyle: text.bodySmall?.copyWith(color: t.orangeSoft),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: t.red),
        prefixIconColor: t.muted,
        suffixIconColor: t.muted,
        border: border(t.line),
        enabledBorder: border(t.line),
        focusedBorder: border(t.orange, 1.5),
        errorBorder: border(t.red),
        focusedErrorBorder: border(t.red, 1.5),
        disabledBorder: border(t.line.withValues(alpha: 0.5)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: t.orangeWash,
        disabledColor: Colors.transparent,
        side: BorderSide(color: t.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.tile)),
        labelStyle: text.labelMedium?.copyWith(color: t.soft),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: t.orangeSoft),
        checkmarkColor: t.orangeSoft,
        iconTheme: IconThemeData(color: t.soft, size: 18),
        padding: const EdgeInsets.symmetric(horizontal: BuSpace.s, vertical: BuSpace.xs),
        showCheckmark: true,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? t.raised : t.panel),
          foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? t.ink : t.muted),
          side: WidgetStatePropertyAll(BorderSide(color: t.line)),
          shape: WidgetStatePropertyAll(controlShape),
          textStyle: WidgetStatePropertyAll(text.labelMedium),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: t.ink,
        unselectedLabelColor: t.muted,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge,
        indicatorColor: t.orange,
        dividerColor: t.line,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : t.soft),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.orange : t.raised),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.orange : Colors.transparent),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: BorderSide(color: t.muted, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.orange : t.muted),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: t.orange, linearTrackColor: t.line, circularTrackColor: t.line),
      sliderTheme: SliderThemeData(activeTrackColor: t.orange, thumbColor: t.orange, inactiveTrackColor: t.line),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: t.panel,
        elevation: 0,
        selectedItemColor: t.orangeSoft,
        unselectedItemColor: t.muted,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.panel,
        indicatorColor: t.orangeWash,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.panel,
        modalBackgroundColor: t.panel,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: t.line,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(BuRadius.sheet))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.panel,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.sheet), side: BorderSide(color: t.hairline)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.raised,
        contentTextStyle: text.bodyMedium?.copyWith(color: t.ink),
        actionTextColor: t.orangeSoft,
        behavior: SnackBarBehavior.floating,
        shape: controlShape,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.panel2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.control), side: BorderSide(color: t.line)),
        textStyle: text.bodyMedium?.copyWith(color: t.ink),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(t.panel2),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.control), side: BorderSide(color: t.line))),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: t.raised, borderRadius: BorderRadius.circular(BuRadius.tile)),
        textStyle: text.bodySmall?.copyWith(color: t.ink),
      ),
    );
  }

  /// The type scale: Inter, with the design's tight tracking on large sizes. Titles are ink, body text is a soft grey, captions are muted.
  static TextTheme _textTheme(BuTokens t) {
    TextStyle s(double size, FontWeight weight, {double? tracking, double? height, Color? color}) => TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: tracking,
          height: height,
          color: color ?? t.ink,
        );
    return TextTheme(
      displayLarge: s(44, FontWeight.w600, tracking: -2),
      displayMedium: s(36, FontWeight.w600, tracking: -1.6),
      displaySmall: s(30, FontWeight.w600, tracking: -1.35, height: 1.12),
      headlineLarge: s(32, FontWeight.w600, tracking: -1.4, height: 1.12),
      headlineMedium: s(28, FontWeight.w600, tracking: -1.2, height: 1.15),
      headlineSmall: s(24, FontWeight.w600, tracking: -0.9, height: 1.2),
      titleLarge: s(20, FontWeight.w600, tracking: -0.5, height: 1.25),
      titleMedium: s(16, FontWeight.w600, tracking: -0.1, height: 1.3),
      titleSmall: s(14, FontWeight.w600, height: 1.3),
      bodyLarge: s(16, FontWeight.w400, height: 1.5),
      bodyMedium: s(14, FontWeight.w400, height: 1.5, color: t.soft),
      bodySmall: s(12, FontWeight.w400, height: 1.45, color: t.muted),
      labelLarge: s(14, FontWeight.w600),
      labelMedium: s(12, FontWeight.w600),
      labelSmall: s(11, FontWeight.w600, tracking: 0.3, color: t.muted),
    );
  }

  // Status colours, from the design: green for good, amber for needs-a-look, red for wrong. (The blue is for plain information.)
  static const Color successColor = Color(0xFF59D7A2);
  static const Color warningColor = Color(0xFFFFB258);
  static const Color errorColor = Color(0xFFFF6B6B);
  static const Color infoColor = Color(0xFF7AA8FF);

  // Minimal gradient usage - only subtle accent gradients
  static const LinearGradient primaryAccentGradient = LinearGradient(
    colors: [Color(0xFFFF7A45), Color(0xFFFF5A2F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// A card: the design's panel with its barely-there edge. Used by the screens that draw their own cards.
  static BoxDecoration get darkCardDecoration => BoxDecoration(
        color: BuTokens.dark.panel,
        borderRadius: BorderRadius.circular(BuRadius.card),
        border: Border.all(color: BuTokens.dark.hairline),
      );

  /// A container one step down from a card (a group inside a card, a sheet's body).
  static BoxDecoration get darkContainerDecoration => BoxDecoration(
        color: BuTokens.dark.panel2,
        borderRadius: BorderRadius.circular(BuRadius.control),
        border: Border.all(color: BuTokens.dark.hairline),
      );
}
