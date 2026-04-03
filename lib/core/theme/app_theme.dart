import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color _primaryOrange = Color(0xFFFF6B35);
  static const Color _primaryOrangeLight = Color(0xFFFF8C66);
  static const Color _primaryOrangeDark = Color(0xFFE55A2B);
  
  // Near-black colors for ultra dark theme
  static const Color _backgroundBlack = Color(0xFF0A0A0A);
  static const Color _surfaceBlack = Color(0xFF121212);
  static const Color _surfaceVariant = Color(0xFF1A1A1A);
  static const Color _cardBlack = Color(0xFF151515);

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
      fontFamily: GoogleFonts.inter().fontFamily,
    );
  }

  static ThemeData get darkTheme {
    return FlexThemeData.dark(
      scheme: FlexScheme.custom,
      colors: const FlexSchemeColor(
        primary: _primaryOrange,
        primaryContainer: _primaryOrangeDark,
        secondary: Color(0xFF03DAC6),
        secondaryContainer: Color(0xFF018786),
        tertiary: Color(0xFFBB86FC),
        tertiaryContainer: Color(0xFF3700B3),
        appBarColor: _backgroundBlack,
        error: Color(0xFFCF6679),
      ),
      surfaceMode: FlexSurfaceMode.custom,
      blendLevel: 0, // No blending for pure dark colors
      appBarOpacity: 1.0,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 0,
        useM2StyleDividerInM3: true,
        bottomNavigationBarSelectedLabelSchemeColor: SchemeColor.primary,
        bottomNavigationBarUnselectedLabelSchemeColor: SchemeColor.onSurfaceVariant,
        bottomNavigationBarSelectedIconSchemeColor: SchemeColor.primary,
        bottomNavigationBarUnselectedIconSchemeColor: SchemeColor.onSurfaceVariant,
        bottomNavigationBarBackgroundSchemeColor: SchemeColor.surface,
        // Remove ALL elevations
        bottomNavigationBarElevation: 0,
        cardElevation: 0,
        dialogElevation: 0,
        navigationBarElevation: 0,
        drawerElevation: 0,
        popupMenuElevation: 0,
        snackBarElevation: 0,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      fontFamily: GoogleFonts.inter().fontFamily,
    ).copyWith(
      // Override additional colors for ultra dark theme
      scaffoldBackgroundColor: _backgroundBlack,
      cardColor: _cardBlack,
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _surfaceBlack,
        elevation: 0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _backgroundBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ), dialogTheme: DialogThemeData(backgroundColor: _surfaceBlack),
    );
  }

  // Custom text styles with Inter font
  static TextTheme get textTheme {
    return GoogleFonts.interTextTheme();
  }

  // App specific color constants
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color errorColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF2196F3);

  // Minimal gradient usage - only subtle accent gradients
  static const LinearGradient primaryAccentGradient = LinearGradient(
    colors: [_primaryOrange, _primaryOrangeDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Ultra dark card styling
  static BoxDecoration get darkCardDecoration => BoxDecoration(
    color: _cardBlack,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: _surfaceVariant,
      width: 0.5,
    ),
  );
  
  // Dark container styling
  static BoxDecoration get darkContainerDecoration => BoxDecoration(
    color: _surfaceBlack,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: _surfaceVariant,
      width: 0.5,
    ),
  );
} 