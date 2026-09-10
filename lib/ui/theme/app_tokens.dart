import 'dart:ui';
import 'package:flutter/material.dart';

/// ============================================================================
/// EXALERE CENTRAL DESIGN SYSTEM & STYLE TOKENS
/// ============================================================================
/// All visual variables (Colors, Spacing, Radii, Typography, Shadows, Motion)
/// are declared here in ONE central location.
///
/// If you want to change the overall look, feel, card roundness, padding,
/// or color schemes in the future, change these tokens here without needing
/// to modify hundreds of separate screen files!
/// ============================================================================

/// ----------------------------------------------------------------------------
/// 1. SPACING & LAYOUT TOKENS
/// ----------------------------------------------------------------------------
class AppSpacing {
  AppSpacing._();

  static const double none = 0.0;
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  // Convenient SizedBox gaps for Row / Column
  static const SizedBox gapXxs = SizedBox(width: xxs, height: xxs);
  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapSm = SizedBox(width: sm, height: sm);
  static const SizedBox gapMd = SizedBox(width: md, height: md);
  static const SizedBox gapLg = SizedBox(width: lg, height: lg);
  static const SizedBox gapXl = SizedBox(width: xl, height: xl);
  static const SizedBox gapXxl = SizedBox(width: xxl, height: xxl);
  static const SizedBox gapXxxl = SizedBox(width: xxxl, height: xxxl);

  // Standard Edge Insets
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);
  static const EdgeInsets paddingXxl = EdgeInsets.all(xxl);

  // Screen Padding Helpers
  static const EdgeInsets screenMobile = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const EdgeInsets screenTv = EdgeInsets.symmetric(horizontal: 40, vertical: 24);
  static const EdgeInsets screenDesktop = EdgeInsets.symmetric(horizontal: 32, vertical: 20);

  static EdgeInsets screen(bool isTv) => isTv ? screenTv : screenMobile;
}

/// ----------------------------------------------------------------------------
/// 2. BORDER RADII & CORNER TOKENS
/// ----------------------------------------------------------------------------
class AppRadius {
  AppRadius._();

  static const double none = 0.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 28.0;
  static const double pill = 999.0;

  // Radius objects
  static const Radius rXs = Radius.circular(xs);
  static const Radius rSm = Radius.circular(sm);
  static const Radius rMd = Radius.circular(md);
  static const Radius rLg = Radius.circular(lg);
  static const Radius rXl = Radius.circular(xl);
  static const Radius rXxl = Radius.circular(xxl);
  static const Radius rPill = Radius.circular(pill);

  // BorderRadius objects
  static const BorderRadius borderNone = BorderRadius.zero;
  static const BorderRadius borderXs = BorderRadius.all(rXs);
  static const BorderRadius borderSm = BorderRadius.all(rSm);
  static const BorderRadius borderMd = BorderRadius.all(rMd);
  static const BorderRadius borderLg = BorderRadius.all(rLg);
  static const BorderRadius borderXl = BorderRadius.all(rXl);
  static const BorderRadius borderXxl = BorderRadius.all(rXxl);
  static const BorderRadius borderPill = BorderRadius.all(rPill);
}

/// ----------------------------------------------------------------------------
/// 3. MOTION & ANIMATION TOKENS
/// ----------------------------------------------------------------------------
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration backdropCrossfade = Duration(milliseconds: 500);

  static const Curve curveDefault = Curves.easeInOutCubic;
  static const Curve curveEaseOut = Curves.easeOutCubic;
  static const Curve curveBounce = Curves.easeOutBack;

  // Interactive Scales
  static const double tvFocusScale = 1.06;
  static const double desktopHoverScale = 1.02;
  static const double buttonPressScale = 0.96;
}

/// ----------------------------------------------------------------------------
/// 4. TYPOGRAPHY HIERARCHY
/// ----------------------------------------------------------------------------
class AppTypography {
  AppTypography._();

  static const TextStyle heroTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
    color: Colors.white,
  );

  static const TextStyle sectionHeading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: Colors.white,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    overflow: TextOverflow.ellipsis,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Color(0xFFC9D1D9),
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Color(0xFF8B949E),
  );

  static const TextStyle badge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: Colors.white,
  );

  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}

/// ----------------------------------------------------------------------------
/// 5. SHADOWS, ELEVATION & GLOW TOKENS
/// ----------------------------------------------------------------------------
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];

  static List<BoxShadow> tvFocusGlow(Color glowColor) => [
    BoxShadow(
      color: glowColor.withValues(alpha: 0.5),
      blurRadius: 20,
      spreadRadius: 2,
      offset: const Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> modal = [
    BoxShadow(
      color: Color(0x80000000),
      blurRadius: 30,
      spreadRadius: 4,
      offset: Offset(0, 10),
    ),
  ];
}

/// ----------------------------------------------------------------------------
/// 6. DYNAMIC THEME EXTENSION (APP DESIGN TOKENS)
/// ----------------------------------------------------------------------------
/// Allows complete theme switching dynamically at runtime.
/// Access anywhere in widget tree with: `context.tokens.<property>`
/// ----------------------------------------------------------------------------
@immutable
class AppDesignTokens extends ThemeExtension<AppDesignTokens> {
  final Color canvasBackground;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color surfaceGlass;
  final Color borderSubtle;
  final Color borderFocus;
  final Color primaryAccent;
  final Color secondaryAccent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color liveColor;
  final Color vipColor;
  final Color errorColor;
  final LinearGradient heroGradient;
  final LinearGradient scrimGradient;
  final double cardRadius;

  const AppDesignTokens({
    required this.canvasBackground,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.surfaceGlass,
    required this.borderSubtle,
    required this.borderFocus,
    required this.primaryAccent,
    required this.secondaryAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.liveColor,
    required this.vipColor,
    required this.errorColor,
    required this.heroGradient,
    required this.scrimGradient,
    this.cardRadius = AppRadius.md,
  });

  /// Dynamic border radii driven by the active theme's cardRadius:
  BorderRadius get borderRadiusXs => BorderRadius.circular((cardRadius * 0.35).clamp(2.0, 6.0));
  BorderRadius get borderRadiusSm => BorderRadius.circular((cardRadius * 0.65).clamp(4.0, 10.0));
  BorderRadius get borderRadiusMd => BorderRadius.circular(cardRadius);
  BorderRadius get borderRadiusLg => BorderRadius.circular(cardRadius * 1.35);
  BorderRadius get borderRadiusPill => BorderRadius.circular(999.0);

  @override
  AppDesignTokens copyWith({
    Color? canvasBackground,
    Color? surfaceCard,
    Color? surfaceElevated,
    Color? surfaceGlass,
    Color? borderSubtle,
    Color? borderFocus,
    Color? primaryAccent,
    Color? secondaryAccent,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? liveColor,
    Color? vipColor,
    Color? errorColor,
    LinearGradient? heroGradient,
    LinearGradient? scrimGradient,
    double? cardRadius,
  }) {
    return AppDesignTokens(
      canvasBackground: canvasBackground ?? this.canvasBackground,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceGlass: surfaceGlass ?? this.surfaceGlass,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderFocus: borderFocus ?? this.borderFocus,
      primaryAccent: primaryAccent ?? this.primaryAccent,
      secondaryAccent: secondaryAccent ?? this.secondaryAccent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      liveColor: liveColor ?? this.liveColor,
      vipColor: vipColor ?? this.vipColor,
      errorColor: errorColor ?? this.errorColor,
      heroGradient: heroGradient ?? this.heroGradient,
      scrimGradient: scrimGradient ?? this.scrimGradient,
      cardRadius: cardRadius ?? this.cardRadius,
    );
  }

  @override
  AppDesignTokens lerp(ThemeExtension<AppDesignTokens>? other, double t) {
    if (other is! AppDesignTokens) return this;
    return AppDesignTokens(
      canvasBackground: Color.lerp(canvasBackground, other.canvasBackground, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceGlass: Color.lerp(surfaceGlass, other.surfaceGlass, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderFocus: Color.lerp(borderFocus, other.borderFocus, t)!,
      primaryAccent: Color.lerp(primaryAccent, other.primaryAccent, t)!,
      secondaryAccent: Color.lerp(secondaryAccent, other.secondaryAccent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      liveColor: Color.lerp(liveColor, other.liveColor, t)!,
      vipColor: Color.lerp(vipColor, other.vipColor, t)!,
      errorColor: Color.lerp(errorColor, other.errorColor, t)!,
      heroGradient: LinearGradient.lerp(heroGradient, other.heroGradient, t)!,
      scrimGradient: LinearGradient.lerp(scrimGradient, other.scrimGradient, t)!,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t)!,
    );
  }
}

/// ----------------------------------------------------------------------------
/// 7. BUILD CONTEXT EXTENSION HELPER
/// ----------------------------------------------------------------------------
/// Enables writing `context.tokens.primaryAccent` or `context.tokens.surfaceCard`
/// anywhere in your Flutter widget tree cleanly and safely.
/// ----------------------------------------------------------------------------
extension AppThemeContextExtension on BuildContext {
  AppDesignTokens get tokens {
    final themeTokens = Theme.of(this).extension<AppDesignTokens>();
    return themeTokens ?? AppDefaultTokens.value;
  }
}

class AppDefaultTokens {
  AppDefaultTokens._();

  static const AppDesignTokens value = AppDesignTokens(
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
}

typedef AppTokens = AppDesignTokens;
