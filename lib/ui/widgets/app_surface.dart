import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'tv_focusable.dart';

/// ============================================================================
/// APP SURFACE & UNIVERSAL CARD COMPONENT
/// ============================================================================
/// A centralized surface container that dynamically adapts to the active:
/// 1. Corner Style: Rounded, Sharp, or Cut (Beveled/Chamfered).
/// 2. Surface Morphism: Standard, Apple Glassmorphic, Neomorphic, or 3D Clay.
///
/// Use [AppSurface] or [AppCard] everywhere in place of manual Containers with
/// hardcoded BoxDecorations. Changing tokens in `app_tokens.dart` immediately
/// transforms every card in the application!
/// ============================================================================
class AppSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double? radius;
  final Color? color;
  final BorderSide? border;
  final List<BoxShadow>? shadows;
  final Gradient? gradient;
  final SurfaceMorphism? morphism;
  final CornerStyle? cornerStyle;
  final VoidCallback? onTap;
  final bool enableFocusScale;
  final FocusNode? focusNode;
  final Clip clipBehavior;
  final AlignmentGeometry? alignment;

  const AppSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.radius,
    this.color,
    this.border,
    this.shadows,
    this.gradient,
    this.morphism,
    this.cornerStyle,
    this.onTap,
    this.enableFocusScale = true,
    this.focusNode,
    this.clipBehavior = Clip.antiAlias,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final activeMorphism = morphism ?? tokens.surfaceMorphism;
    final activeCornerStyle = cornerStyle ?? tokens.cornerStyle;

    // Build the shape based on the active or overridden corner style
    final effectiveRadius = activeCornerStyle == CornerStyle.sharp
        ? 0.0
        : (radius ?? tokens.cardRadius);

    final shapeBorder = _getShape(activeCornerStyle, effectiveRadius, border);

    // Build shape decoration for morphism
    final decoration = _buildDecoration(
      tokens: tokens,
      morphism: activeMorphism,
      shape: shapeBorder,
      effectiveRadius: effectiveRadius,
    );

    Widget innerContent = child;
    if (padding != null) {
      innerContent = Padding(padding: padding!, child: innerContent);
    }
    if (alignment != null) {
      innerContent = Align(alignment: alignment!, child: innerContent);
    }
    if (activeMorphism == SurfaceMorphism.glass) {
      innerContent = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: innerContent,
      );
    }
    innerContent = ClipPath(
      clipper: ShapeBorderClipper(shape: shapeBorder),
      clipBehavior: clipBehavior,
      child: innerContent,
    );

    Widget content = Container(
      width: width,
      height: height,
      decoration: decoration,
      child: innerContent,
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    // Wrap in TvFocusable if tap is enabled
    if (onTap != null) {
      return TvFocusable(
        onTap: onTap,
        focusNode: focusNode,
        scaleFactor: enableFocusScale ? AppMotion.tvFocusScale : 1.0,
        borderRadius: activeCornerStyle == CornerStyle.sharp
            ? BorderRadius.zero
            : BorderRadius.circular(effectiveRadius),
        child: content,
      );
    }

    return content;
  }

  ShapeBorder _getShape(
    CornerStyle style,
    double effectiveRadius,
    BorderSide? borderSide,
  ) {
    final side = borderSide ?? BorderSide.none;
    switch (style) {
      case CornerStyle.sharp:
        return RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: side,
        );
      case CornerStyle.cut:
        return BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(effectiveRadius),
          side: side,
        );
      case CornerStyle.rounded:
        return RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(effectiveRadius),
          side: side,
        );
    }
  }

  ShapeDecoration _buildDecoration({
    required AppDesignTokens tokens,
    required SurfaceMorphism morphism,
    required ShapeBorder shape,
    required double effectiveRadius,
  }) {
    final baseColor = color ?? tokens.surfaceCard;
    final effShadows = shadows ?? tokens.getCardShadows();

    switch (morphism) {
      case SurfaceMorphism.glass:
        return ShapeDecoration(
          shape: border != null
              ? shape
              : _getShape(
                  cornerStyle ?? tokens.cornerStyle,
                  effectiveRadius,
                  BorderSide(
                    color: tokens.textPrimary.withValues(alpha: 0.18),
                    width: 1.2,
                  ),
                ),
          shadows: effShadows,
          gradient:
              gradient ??
              LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  baseColor.withValues(alpha: 0.70),
                  baseColor.withValues(alpha: 0.45),
                ],
              ),
        );

      case SurfaceMorphism.neomorphic:
        return ShapeDecoration(
          color: gradient != null ? null : baseColor,
          shape: border != null
              ? shape
              : _getShape(
                  cornerStyle ?? tokens.cornerStyle,
                  effectiveRadius,
                  BorderSide(
                    color: tokens.textPrimary.withValues(alpha: 0.08),
                    width: 1.0,
                  ),
                ),
          shadows: effShadows,
          gradient: gradient,
        );

      case SurfaceMorphism.clay:
        return ShapeDecoration(
          color: gradient != null ? null : baseColor,
          shape: border != null
              ? shape
              : _getShape(
                  cornerStyle ?? tokens.cornerStyle,
                  effectiveRadius,
                  BorderSide(
                    color: tokens.textPrimary.withValues(alpha: 0.16),
                    width: 2.0,
                  ),
                ),
          shadows: effShadows,
          gradient: gradient,
        );

      case SurfaceMorphism.standard:
        return ShapeDecoration(
          color: gradient != null ? null : baseColor,
          shape: border != null
              ? shape
              : _getShape(
                  cornerStyle ?? tokens.cornerStyle,
                  effectiveRadius,
                  BorderSide(color: tokens.borderSubtle, width: 1.0),
                ),
          shadows: effShadows,
          gradient: gradient,
        );
    }
  }
}

/// Convenience alias for cards
typedef AppCard = AppSurface;
