import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'tv_focusable.dart';

/// ============================================================================
/// UNIVERSAL VARIABLE BUTTON COMPONENT
/// ============================================================================
/// Controls all button aesthetics from a single place. Changing button tokens
/// or variants here automatically applies across every button in the entire app!
///
/// Fully compatible with:
/// - Android TV D-Pad remote navigation & focus glow (`TvFocusable`)
/// - Corner styles (Rounded, Sharp, or Cut/Beveled)
/// - Surface morphisms (Standard, Apple Glass, Neomorphic, 3D Clay)
/// ============================================================================

enum AppButtonVariant {
  /// Primary theme accent fill (e.g. Red, Cyan, Gold) with high contrast text
  primary,

  /// Elevated dark surface fill with primary text
  secondary,

  /// Transparent with subtle border
  outline,

  /// Flat transparent button with hover/focus highlight
  ghost,

  /// Error/Destructive action button
  danger,

  /// Apple VisionOS inspired translucent liquid glass capsule button
  glass,
}

enum AppButtonSize {
  /// Compact button for dialogs, pills, and table rows
  sm,

  /// Standard default button for forms, modal actions, and bars
  md,

  /// Prominent call-to-action button for hero headers and playback
  lg,
}

class AppButton extends StatelessWidget {
  final String? label;
  final Widget? icon;
  final Widget? trailingIcon;
  final VoidCallback? onTap;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final bool expanded;
  final double? radius;
  final FocusNode? focusNode;
  final bool autofocus;
  final Color? customColor;
  final Color? customTextColor;

  const AppButton({
    super.key,
    this.label,
    this.icon,
    this.trailingIcon,
    this.onTap,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.expanded = false,
    this.radius,
    this.focusNode,
    this.autofocus = false,
    this.customColor,
    this.customTextColor,
  });

  /// Factory helper for Primary Call-To-Action Button
  factory AppButton.primary({
    Key? key,
    required String label,
    Widget? icon,
    Widget? trailingIcon,
    VoidCallback? onTap,
    AppButtonSize size = AppButtonSize.md,
    bool isLoading = false,
    bool expanded = false,
    FocusNode? focusNode,
    bool autofocus = false,
  }) => AppButton(
    key: key,
    label: label,
    icon: icon,
    trailingIcon: trailingIcon,
    onTap: onTap,
    variant: AppButtonVariant.primary,
    size: size,
    isLoading: isLoading,
    expanded: expanded,
    focusNode: focusNode,
    autofocus: autofocus,
  );

  /// Factory helper for Secondary Button
  factory AppButton.secondary({
    Key? key,
    required String label,
    Widget? icon,
    Widget? trailingIcon,
    VoidCallback? onTap,
    AppButtonSize size = AppButtonSize.md,
    bool isLoading = false,
    bool expanded = false,
    FocusNode? focusNode,
    bool autofocus = false,
  }) => AppButton(
    key: key,
    label: label,
    icon: icon,
    trailingIcon: trailingIcon,
    onTap: onTap,
    variant: AppButtonVariant.secondary,
    size: size,
    isLoading: isLoading,
    expanded: expanded,
    focusNode: focusNode,
    autofocus: autofocus,
  );

  /// Factory helper for Apple VisionOS Liquid Glass Capsule Button
  factory AppButton.glass({
    Key? key,
    required String label,
    Widget? icon,
    Widget? trailingIcon,
    VoidCallback? onTap,
    AppButtonSize size = AppButtonSize.md,
    bool isLoading = false,
    bool expanded = false,
    FocusNode? focusNode,
    bool autofocus = false,
  }) => AppButton(
    key: key,
    label: label,
    icon: icon,
    trailingIcon: trailingIcon,
    onTap: onTap,
    variant: AppButtonVariant.glass,
    size: size,
    isLoading: isLoading,
    expanded: expanded,
    focusNode: focusNode,
    autofocus: autofocus,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    // Dynamic Sizing Tokens
    final double minHeight;
    final EdgeInsets padding;
    final double fontSize;
    final double iconSize;

    switch (size) {
      case AppButtonSize.sm:
        minHeight = 34.0;
        padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
        fontSize = 12.0;
        iconSize = 16.0;
        break;
      case AppButtonSize.md:
        minHeight = 44.0;
        padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 10);
        fontSize = 14.0;
        iconSize = 18.0;
        break;
      case AppButtonSize.lg:
        minHeight = 52.0;
        padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
        fontSize = 16.0;
        iconSize = 22.0;
        break;
    }

    // Dynamic Color & Surface Resolution
    final Color bgColor;
    final Color textColor;
    BorderSide borderSide = BorderSide.none;
    Gradient? gradient;

    switch (variant) {
      case AppButtonVariant.primary:
        bgColor = customColor ?? theme.colorScheme.primary;
        textColor = customTextColor ?? theme.colorScheme.onPrimary;
        gradient = tokens.heroGradient;
        break;
      case AppButtonVariant.secondary:
        bgColor = customColor ?? tokens.surfaceElevated;
        textColor = customTextColor ?? tokens.textPrimary;
        borderSide = BorderSide(color: tokens.borderSubtle, width: 1.0);
        break;
      case AppButtonVariant.outline:
        bgColor = Colors.transparent;
        textColor = customTextColor ?? tokens.textPrimary;
        borderSide = BorderSide(
          color: customColor ?? tokens.borderSubtle,
          width: 1.2,
        );
        break;
      case AppButtonVariant.ghost:
        bgColor = Colors.transparent;
        textColor = customTextColor ?? tokens.textSecondary;
        break;
      case AppButtonVariant.danger:
        bgColor = customColor ?? tokens.errorColor;
        textColor = customTextColor ?? theme.colorScheme.onError;
        break;
      case AppButtonVariant.glass:
        bgColor = (customColor ?? tokens.surfaceElevated).withValues(
          alpha: 0.55,
        );
        textColor = customTextColor ?? tokens.textPrimary;
        borderSide = BorderSide(
          color: tokens.textPrimary.withValues(alpha: 0.22),
          width: 1.2,
        );
        gradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.textPrimary.withValues(alpha: 0.18),
            tokens.textPrimary.withValues(alpha: 0.04),
          ],
        );
        break;
    }

    // Dynamic Corner Geometry
    final effectiveRadius = tokens.cornerStyle == CornerStyle.sharp
        ? 0.0
        : (radius ?? tokens.borderRadiusSm.topLeft.x);

    final ShapeBorder shapeBorder = tokens.getShapeBorder(
      radius: effectiveRadius,
      side: borderSide,
    );

    // Button Contents
    Widget content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isLoading)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: iconSize,
              height: iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: textColor,
              ),
            ),
          )
        else if (icon != null)
          Padding(
            padding: EdgeInsets.only(right: label != null ? 8 : 0),
            child: IconTheme(
              data: IconThemeData(color: textColor, size: iconSize),
              child: icon!,
            ),
          ),
        if (label != null)
          Text(
            label!,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              fontFamily: tokens.fontFamily,
            ),
          ),
        if (trailingIcon != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: IconTheme(
              data: IconThemeData(color: textColor, size: iconSize),
              child: trailingIcon!,
            ),
          ),
      ],
    );

    // Container with ShapeDecoration
    Widget buttonWidget = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: padding,
      decoration: ShapeDecoration(
        color: gradient != null ? null : bgColor,
        shape: shapeBorder,
        gradient: gradient,
        shadows: variant == AppButtonVariant.primary
            ? [
                BoxShadow(
                  color: tokens.shadowColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: content,
    );

    // Apply BackdropFilter blur if Glass variant
    if (variant == AppButtonVariant.glass) {
      buttonWidget = ClipPath(
        clipper: ShapeBorderClipper(shape: shapeBorder),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: buttonWidget,
        ),
      );
    }

    // Wrap in TV Remote D-Pad Navigation & tactile interaction
    return TvFocusable(
      onTap: isLoading ? null : onTap,
      focusNode: focusNode,
      autofocus: autofocus,
      shape: shapeBorder,
      borderRadius: tokens.cornerStyle == CornerStyle.sharp
          ? BorderRadius.zero
          : BorderRadius.circular(effectiveRadius),
      scaleFactor: AppMotion.buttonPressScale < 1.0 ? 1.05 : 1.0,
      child: buttonWidget,
    );
  }
}
