import 'package:flutter/material.dart';

import 'app_tokens.dart';
export 'app_tokens.dart';

/// Represents a selectable theme preset in Exalere with full design token integration.
class AppThemeOption {
  final String name;
  final ThemeData themeData;
  final Color primaryColor;
  final Color backgroundColor;
  final Color cardColor;
  final AppDesignTokens tokens;

  const AppThemeOption({
    required this.name,
    required this.themeData,
    required this.primaryColor,
    required this.backgroundColor,
    required this.cardColor,
    required this.tokens,
  });
}

/// Centralized repository of themes in Exalere.
/// Strictly uses 100% solid colors with zero gradients across Dark and Light modes.
class AppThemes {
  // ---------------------------------------------------------------------------
  // 1. DARK MODE (Solid Pitch & Obsidian)
  // ---------------------------------------------------------------------------
  static const AppDesignTokens darkTokens = AppDesignTokens(
    canvasBackground: Color(0xFF0D0E12),
    surfaceCard: Color(0xFF161920),
    surfaceElevated: Color(0xFF202530),
    surfaceGlass: Color(0xFF161920),
    borderSubtle: Color(0xFF2B3240),
    borderFocus: Color(0xFFE50914),
    primaryAccent: Color(0xFFE50914),
    secondaryAccent: Color(0xFF00D2FF),
    textPrimary: Colors.white,
    textSecondary: Color(0xFFC9D1D9),
    textMuted: Color(0xFF8B949E),
    liveColor: Color(0xFF10B981),
    vipColor: Color(0xFFFFB800),
    errorColor: Color(0xFFE50914),
    heroGradient: LinearGradient(
      colors: [Color(0xFFE50914), Color(0xFFE50914)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    scrimGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0D0E12), Color(0xFF0D0E12)],
    ),
  );

  static final AppThemeOption darkTheme = AppThemeOption(
    name: 'Dark Mode',
    primaryColor: const Color(0xFFE50914),
    backgroundColor: const Color(0xFF0D0E12),
    cardColor: const Color(0xFF161920),
    tokens: darkTokens,
    themeData: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0D0E12),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFE50914),
        secondary: Color(0xFF00D2FF),
        surface: Color(0xFF161920),
        error: Color(0xFFE50914),
        onPrimary: Colors.white,
        onSurface: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF161920),
        elevation: 0,
        shape: darkTokens.shapeMd,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF202530),
        shape: darkTokens.shapeLg,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: const Color(0xFF202530),
        shape: darkTokens.shapeLg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D0E12),
        elevation: 0,
      ),
      extensions: const [darkTokens],
    ),
  );

  // ---------------------------------------------------------------------------
  // 2. LIGHT MODE (Solid Pure Light)
  // ---------------------------------------------------------------------------
  static const AppDesignTokens lightTokens = AppDesignTokens(
    canvasBackground: Color(0xFFF6F8FA),
    surfaceCard: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEDF0F4),
    surfaceGlass: Color(0xFFFFFFFF),
    borderSubtle: Color(0xFFD0D7DE),
    borderFocus: Color(0xFFE50914),
    primaryAccent: Color(0xFFE50914),
    secondaryAccent: Color(0xFF0969DA),
    textPrimary: Color(0xFF1F2328),
    textSecondary: Color(0xFF424A53),
    textMuted: Color(0xFF656D76),
    liveColor: Color(0xFF1A7F37),
    vipColor: Color(0xFF9A6700),
    errorColor: Color(0xFFCF222E),
    heroGradient: LinearGradient(
      colors: [Color(0xFFE50914), Color(0xFFE50914)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    scrimGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF6F8FA), Color(0xFFF6F8FA)],
    ),
  );

  static final AppThemeOption lightTheme = AppThemeOption(
    name: 'Light Mode',
    primaryColor: const Color(0xFFE50914),
    backgroundColor: const Color(0xFFF6F8FA),
    cardColor: const Color(0xFFFFFFFF),
    tokens: lightTokens,
    themeData: ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF6F8FA),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFFE50914),
        secondary: Color(0xFF0969DA),
        surface: Color(0xFFFFFFFF),
        error: Color(0xFFCF222E),
        onPrimary: Colors.white,
        onSurface: Color(0xFF1F2328),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        shape: lightTokens.shapeMd,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFFEDF0F4),
        shape: lightTokens.shapeLg,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: const Color(0xFFEDF0F4),
        shape: lightTokens.shapeLg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF6F8FA),
        elevation: 0,
      ),
      extensions: const [lightTokens],
    ),
  );

  // Backward compatibility alias
  static AppThemeOption get netflixBlack => darkTheme;

  /// Selectable theme presets: Only 2 themes (Dark & Light)
  static final List<AppThemeOption> allThemes = [darkTheme, lightTheme];
}
