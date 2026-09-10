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

/// Centralized repository of all theme presets in Exalere.
/// To add, modify, or customize themes, all variables are controlled here!
class AppThemes {
  // ---------------------------------------------------------------------------
  // 1. NETFLIX OBSIDIAN (Default Cinema)
  // ---------------------------------------------------------------------------
  static final AppDesignTokens netflixTokens = const AppDesignTokens(
    canvasBackground: Color(0xFF08090C),
    surfaceCard: Color(0xFF14171E),
    surfaceElevated: Color(0xFF1E232E),
    surfaceGlass: Color(0x9914171E),
    borderSubtle: Color(0xFF222836),
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
      colors: [Color(0xFFE50914), Color(0xFFB81D24)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    scrimGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Color(0xCC08090C), Color(0xFF08090C)],
    ),
  );

  static final AppThemeOption netflixBlack = AppThemeOption(
    name: 'Netflix Obsidian',
    primaryColor: const Color(0xFFE50914),
    backgroundColor: const Color(0xFF08090C),
    cardColor: const Color(0xFF14171E),
    tokens: netflixTokens,
    themeData: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF08090C),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFE50914),
        secondary: Color(0xFF00D2FF),
        surface: Color(0xFF14171E),
        error: Color(0xFFE50914),
      ),
      cardTheme: const CardThemeData(color: Color(0xFF14171E), elevation: 0),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extensions: [netflixTokens],
    ),
  );

  // ---------------------------------------------------------------------------
  // 2. JIOHOTSTAR MIDNIGHT
  // ---------------------------------------------------------------------------
  static final AppDesignTokens hotstarTokens = const AppDesignTokens(
    canvasBackground: Color(0xFF0B0E17),
    surfaceCard: Color(0xFF131926),
    surfaceElevated: Color(0xFF1C2436),
    surfaceGlass: Color(0x99131926),
    borderSubtle: Color(0xFF222C3D),
    borderFocus: Color(0xFF00D2FF),
    primaryAccent: Color(0xFF00D2FF),
    secondaryAccent: Color(0xFFFFC107),
    textPrimary: Colors.white,
    textSecondary: Color(0xFFC9D1D9),
    textMuted: Color(0xFF8B949E),
    liveColor: Color(0xFF10B981),
    vipColor: Color(0xFFFFC107),
    errorColor: Color(0xFFFF5252),
    heroGradient: LinearGradient(
      colors: [Color(0xFF00D2FF), Color(0xFF0088FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    scrimGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Color(0xCC0B0E17), Color(0xFF0B0E17)],
    ),
  );

  static final AppThemeOption jioHotstar = AppThemeOption(
    name: 'Hotstar Midnight',
    primaryColor: const Color(0xFF00D2FF),
    backgroundColor: const Color(0xFF0B0E17),
    cardColor: const Color(0xFF131926),
    tokens: hotstarTokens,
    themeData: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B0E17),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00D2FF),
        secondary: Color(0xFFFFC107),
        surface: Color(0xFF131926),
        error: Color(0xFFFF5252),
      ),
      cardTheme: const CardThemeData(color: Color(0xFF131926), elevation: 0),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extensions: [hotstarTokens],
    ),
  );

  // ---------------------------------------------------------------------------
  // 3. TOKYO NIGHT
  // ---------------------------------------------------------------------------
  static final AppDesignTokens tokyoTokens = const AppDesignTokens(
    canvasBackground: Color(0xFF1A1B26),
    surfaceCard: Color(0xFF24283B),
    surfaceElevated: Color(0xFF2E344F),
    surfaceGlass: Color(0x9924283B),
    borderSubtle: Color(0xFF383E5A),
    borderFocus: Color(0xFF7AA2F7),
    primaryAccent: Color(0xFF7AA2F7),
    secondaryAccent: Color(0xFFBB9AF7),
    textPrimary: Colors.white,
    textSecondary: Color(0xFFC0CAF5),
    textMuted: Color(0xFF7AA2F7),
    liveColor: Color(0xFF73DACA),
    vipColor: Color(0xFFE0AF68),
    errorColor: Color(0xFFF7768E),
    heroGradient: LinearGradient(
      colors: [Color(0xFF7AA2F7), Color(0xFFBB9AF7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    scrimGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Color(0xCC1A1B26), Color(0xFF1A1B26)],
    ),
  );

  static final AppThemeOption tokyoNight = AppThemeOption(
    name: 'TokyoNight',
    primaryColor: const Color(0xFF7AA2F7),
    backgroundColor: const Color(0xFF1A1B26),
    cardColor: const Color(0xFF24283B),
    tokens: tokyoTokens,
    themeData: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1A1B26),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF7AA2F7),
        secondary: Color(0xFFBB9AF7),
        surface: Color(0xFF24283B),
        error: Color(0xFFF7768E),
      ),
      cardTheme: const CardThemeData(color: Color(0xFF24283B), elevation: 0),
      extensions: [tokyoTokens],
    ),
  );

  // ---------------------------------------------------------------------------
  // 4. CATPPUCCIN MOCHA
  // ---------------------------------------------------------------------------
  static final AppDesignTokens catppuccinTokens = const AppDesignTokens(
    canvasBackground: Color(0xFF1E1E2E),
    surfaceCard: Color(0xFF313244),
    surfaceElevated: Color(0xFF45475A),
    surfaceGlass: Color(0x99313244),
    borderSubtle: Color(0xFF585B70),
    borderFocus: Color(0xFFCBA6F7),
    primaryAccent: Color(0xFFCBA6F7),
    secondaryAccent: Color(0xFFF5C2E7),
    textPrimary: Colors.white,
    textSecondary: Color(0xFFCDD6F4),
    textMuted: Color(0xFFA6ADC8),
    liveColor: Color(0xFFA6E3A1),
    vipColor: Color(0xFFF9E2AF),
    errorColor: Color(0xFFF38BA8),
    heroGradient: LinearGradient(
      colors: [Color(0xFFCBA6F7), Color(0xFFF5C2E7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    scrimGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Color(0xCC1E1E2E), Color(0xFF1E1E2E)],
    ),
  );

  static final AppThemeOption catppuccin = AppThemeOption(
    name: 'Catppuccin',
    primaryColor: const Color(0xFFCBA6F7),
    backgroundColor: const Color(0xFF1E1E2E),
    cardColor: const Color(0xFF313244),
    tokens: catppuccinTokens,
    themeData: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1E1E2E),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFCBA6F7),
        secondary: Color(0xFFF5C2E7),
        surface: Color(0xFF313244),
        error: Color(0xFFF38BA8),
      ),
      cardTheme: const CardThemeData(color: Color(0xFF313244), elevation: 0),
      extensions: [catppuccinTokens],
    ),
  );

  // ---------------------------------------------------------------------------
  // 5. NORD FROST
  // ---------------------------------------------------------------------------
  static final AppDesignTokens nordTokens = const AppDesignTokens(
    canvasBackground: Color(0xFF2E3440),
    surfaceCard: Color(0xFF3B4252),
    surfaceElevated: Color(0xFF434C5E),
    surfaceGlass: Color(0x993B4252),
    borderSubtle: Color(0xFF4C566A),
    borderFocus: Color(0xFF88C0D0),
    primaryAccent: Color(0xFF88C0D0),
    secondaryAccent: Color(0xFF81A1C1),
    textPrimary: Colors.white,
    textSecondary: Color(0xFFECEFF4),
    textMuted: Color(0xFFD8DEE9),
    liveColor: Color(0xFFA3BE8C),
    vipColor: Color(0xFFEBCB8B),
    errorColor: Color(0xFFBF616A),
    heroGradient: LinearGradient(
      colors: [Color(0xFF88C0D0), Color(0xFF81A1C1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    scrimGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Color(0xCC2E3440), Color(0xFF2E3440)],
    ),
  );

  static final AppThemeOption nord = AppThemeOption(
    name: 'Nord',
    primaryColor: const Color(0xFF88C0D0),
    backgroundColor: const Color(0xFF2E3440),
    cardColor: const Color(0xFF3B4252),
    tokens: nordTokens,
    themeData: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF2E3440),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF88C0D0),
        secondary: Color(0xFF81A1C1),
        surface: Color(0xFF3B4252),
        error: Color(0xFFBF616A),
      ),
      cardTheme: const CardThemeData(color: Color(0xFF3B4252), elevation: 0),
      extensions: [nordTokens],
    ),
  );

  // ---------------------------------------------------------------------------
  // 6. DRACULA
  // ---------------------------------------------------------------------------
  static final AppDesignTokens draculaTokens = const AppDesignTokens(
    canvasBackground: Color(0xFF282A36),
    surfaceCard: Color(0xFF44475A),
    surfaceElevated: Color(0xFF52566E),
    surfaceGlass: Color(0x9944475A),
    borderSubtle: Color(0xFF6272A4),
    borderFocus: Color(0xFFBD93F9),
    primaryAccent: Color(0xFFBD93F9),
    secondaryAccent: Color(0xFFFF79C6),
    textPrimary: Colors.white,
    textSecondary: Color(0xFFF8F8F2),
    textMuted: Color(0xFF6272A4),
    liveColor: Color(0xFF50FA7B),
    vipColor: Color(0xFFF1FA8C),
    errorColor: Color(0xFFFF5555),
    heroGradient: LinearGradient(
      colors: [Color(0xFFBD93F9), Color(0xFFFF79C6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    scrimGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Color(0xCC282A36), Color(0xFF282A36)],
    ),
  );

  static final AppThemeOption dracula = AppThemeOption(
    name: 'Dracula',
    primaryColor: const Color(0xFFBD93F9),
    backgroundColor: const Color(0xFF282A36),
    cardColor: const Color(0xFF44475A),
    tokens: draculaTokens,
    themeData: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF282A36),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFBD93F9),
        secondary: Color(0xFFBD93F9),
        surface: Color(0xFF44475A),
        error: Color(0xFFFF5555),
      ),
      cardTheme: const CardThemeData(color: Color(0xFF44475A), elevation: 0),
      extensions: [draculaTokens],
    ),
  );

  // ---------------------------------------------------------------------------
  // 7. MIDNIGHT OLED (True Pitch Black)
  // ---------------------------------------------------------------------------
  static final AppDesignTokens midnightOledTokens = const AppDesignTokens(
    canvasBackground: Color(0xFF000000),
    surfaceCard: Color(0xFF141414),
    surfaceElevated: Color(0xFF1F1F1F),
    surfaceGlass: Color(0x99141414),
    borderSubtle: Color(0xFF2E2E2E),
    borderFocus: Color(0xFFE50914),
    primaryAccent: Color(0xFFE50914),
    secondaryAccent: Color(0xFFB81D24),
    textPrimary: Colors.white,
    textSecondary: Color(0xFFC9D1D9),
    textMuted: Color(0xFF8B949E),
    liveColor: Color(0xFF10B981),
    vipColor: Color(0xFFFFB800),
    errorColor: Color(0xFFE50914),
    heroGradient: LinearGradient(
      colors: [Color(0xFFE50914), Color(0xFF8A0000)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    scrimGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Color(0xCC000000), Color(0xFF000000)],
    ),
  );

  static final AppThemeOption midnightOled = AppThemeOption(
    name: 'Midnight OLED',
    primaryColor: const Color(0xFFE50914),
    backgroundColor: const Color(0xFF000000),
    cardColor: const Color(0xFF141414),
    tokens: midnightOledTokens,
    themeData: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF000000),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFE50914),
        secondary: Color(0xFFB81D24),
        surface: Color(0xFF141414),
        error: Color(0xFFE50914),
      ),
      cardTheme: const CardThemeData(color: Color(0xFF141414), elevation: 0),
      extensions: [midnightOledTokens],
    ),
  );

  static final List<AppThemeOption> allThemes = [
    netflixBlack,
    jioHotstar,
    tokyoNight,
    catppuccin,
    nord,
    dracula,
    midnightOled,
  ];
}
