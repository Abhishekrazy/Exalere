import 'package:flutter/material.dart';

class AppThemeOption {
  final String name;
  final ThemeData themeData;
  final Color primaryColor;
  final Color backgroundColor;
  final Color cardColor;

  const AppThemeOption({
    required this.name,
    required this.themeData,
    required this.primaryColor,
    required this.backgroundColor,
    required this.cardColor,
  });
}

class AppThemes {
  // 1. Netflix Obsidian (Default)
  static final AppThemeOption netflixBlack = AppThemeOption(
    name: 'Netflix Obsidian',
    primaryColor: const Color(0xFFE50914),
    backgroundColor: const Color(0xFF08090C),
    cardColor: const Color(0xFF14171E),
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
    ),
  );

  // 2. JioHotstar Midnight
  static final AppThemeOption jioHotstar = AppThemeOption(
    name: 'Hotstar Midnight',
    primaryColor: const Color(0xFF00D2FF),
    backgroundColor: const Color(0xFF0B0E17),
    cardColor: const Color(0xFF131926),
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
    ),
  );

  // 3. TokyoNight
  static final AppThemeOption tokyoNight = AppThemeOption(
    name: 'TokyoNight',
    primaryColor: const Color(0xFF7AA2F7),
    backgroundColor: const Color(0xFF1A1B26),
    cardColor: const Color(0xFF24283B),
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
    ),
  );

  // 4. Catppuccin Mocha
  static final AppThemeOption catppuccin = AppThemeOption(
    name: 'Catppuccin',
    primaryColor: const Color(0xFFCBA6F7),
    backgroundColor: const Color(0xFF1E1E2E),
    cardColor: const Color(0xFF313244),
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
    ),
  );

  // 5. Nord
  static final AppThemeOption nord = AppThemeOption(
    name: 'Nord',
    primaryColor: const Color(0xFF88C0D0),
    backgroundColor: const Color(0xFF2E3440),
    cardColor: const Color(0xFF3B4252),
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
    ),
  );

  // 6. Dracula
  static final AppThemeOption dracula = AppThemeOption(
    name: 'Dracula',
    primaryColor: const Color(0xFFBD93F9),
    backgroundColor: const Color(0xFF282A36),
    cardColor: const Color(0xFF44475A),
    themeData: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF282A36),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFBD93F9),
        secondary: Color(0xFFFF79C6),
        surface: Color(0xFF44475A),
        error: Color(0xFFFF5555),
      ),
      cardTheme: const CardThemeData(color: Color(0xFF44475A), elevation: 0),
    ),
  );

  // 7. Midnight OLED (True Black with Netflix Crimson)
  static final AppThemeOption midnightOled = AppThemeOption(
    name: 'Midnight OLED',
    primaryColor: const Color(0xFFE50914),
    backgroundColor: const Color(0xFF000000),
    cardColor: const Color(0xFF141414),
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
