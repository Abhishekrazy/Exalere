import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'dpad/dpad.dart';
import 'tv_spatial_navigation.dart';

/// A TV-optimized focusable widget that handles Android TV D-Pad navigation,
/// remote 'OK' / 'Select' button activation, and renders high-contrast glowing
/// focus borders with a smooth scale-up animation.
///
/// Backed by the production-grade [DpadFocusable] engine.
class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onFocusChange;
  final double scaleFactor;
  final ShapeBorder? shape;
  final BorderRadius? borderRadius;
  final Color? focusedBorderColor;
  final Color? focusedShadowColor;
  final bool autofocus;
  final bool canRequestFocus;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;
  final DpadDirectionCallback? onDirection;

  const TvFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onFocusChange,
    this.scaleFactor = 1.06,
    this.shape,
    this.borderRadius,
    this.focusedBorderColor,
    this.focusedShadowColor,
    this.autofocus = false,
    this.canRequestFocus = true,
    this.focusNode,
    this.onKeyEvent,
    this.onDirection,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  FocusNode? _internalNode;

  FocusNode get _effectiveNode =>
      widget.focusNode ?? (_internalNode ??= _createFocusNode());

  FocusNode _createFocusNode() {
    return FocusNode(canRequestFocus: widget.canRequestFocus);
  }

  @override
  void didUpdateWidget(TvFocusable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      if (oldWidget.focusNode == null) {
        _internalNode?.dispose();
        _internalNode = null;
      }
    }
  }

  @override
  void dispose() {
    _internalNode?.dispose();
    super.dispose();
  }

  ShapeBorder _addBorderToShape(
    ShapeBorder original,
    Color color,
    double width,
  ) {
    if (original is BeveledRectangleBorder) {
      return BeveledRectangleBorder(
        borderRadius: original.borderRadius,
        side: BorderSide(color: color, width: width),
      );
    }
    if (original is RoundedRectangleBorder) {
      return RoundedRectangleBorder(
        borderRadius: original.borderRadius,
        side: BorderSide(color: color, width: width),
      );
    }
    return original;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final borderColor = widget.focusedBorderColor ?? theme.colorScheme.primary;
    final effRadius = widget.borderRadius != null
        ? widget.borderRadius!.topLeft.x
        : (tokens.cornerStyle == CornerStyle.sharp
              ? 0.0
              : (tokens.cardRadius * 0.65).clamp(4.0, 10.0));

    final route = ModalRoute.of(context);
    final isRouteCurrent = route == null || route.isCurrent;
    final bool canFocus = widget.canRequestFocus && isRouteCurrent;

    _effectiveNode.canRequestFocus = canFocus;

    Widget content = DpadFocusable(
      focusNode: _effectiveNode,
      autofocus: widget.autofocus && isRouteCurrent,
      enabled: canFocus,
      onSelect: widget.onTap,
      onLongSelect: widget.onLongPress,
      onFocusChange: widget.onFocusChange,
      onKeyEvent: widget.onKeyEvent,
      onDirection: (direction) {
        if (widget.onDirection != null) {
          return widget.onDirection!(direction);
        }
        final region = DpadRegion.maybeOf(context);
        if (region == null) {
          if (TvSpatialNavigation.moveFocus(_effectiveNode, direction)) {
            return true;
          }
          return true; // Stop at boundary when not in region
        }
        return false;
      },
      builder: (context, state, child) {
        final isFocused = state.focused;
        final ShapeBorder effectiveShape;
        if (widget.shape != null) {
          effectiveShape = isFocused
              ? _addBorderToShape(widget.shape!, borderColor, 2.5)
              : widget.shape!;
        } else {
          effectiveShape = tokens.getShapeBorder(
            radius: effRadius,
            side: isFocused
                ? BorderSide(color: borderColor, width: 2.5)
                : BorderSide.none,
          );
        }

        return AnimatedScale(
          scale: state.pressed
              ? (widget.scaleFactor * 0.96)
              : (isFocused ? widget.scaleFactor : 1.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: ShapeDecoration(
              shape: effectiveShape,
              shadows: isFocused
                  ? [
                      BoxShadow(
                        color: (widget.focusedShadowColor ?? borderColor)
                            .withValues(alpha: 0.45),
                        blurRadius: 18,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: SelectionContainer.disabled(child: child),
          ),
        );
      },
      child: widget.child,
    );

    return content;
  }
}
