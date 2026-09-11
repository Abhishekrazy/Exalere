import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
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
    return FocusNode(
      canRequestFocus: widget.canRequestFocus,
      onKeyEvent: _handleKey,
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (widget.onKeyEvent != null) {
      final customResult = widget.onKeyEvent!(node, event);
      if (customResult != KeyEventResult.ignored) {
        return customResult;
      }
    }
    return KeyEventResult.ignored;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = widget.focusedBorderColor ?? theme.colorScheme.primary;
    final radius = widget.borderRadius ?? context.tokens.borderRadiusSm;

    Widget content = DpadFocusable(
      focusNode: _effectiveNode,
      autofocus: widget.autofocus,
      enabled: widget.canRequestFocus,
      onSelect: widget.onTap,
      onLongSelect: widget.onLongPress,
      onFocusChange: widget.onFocusChange,
      onDirection: (direction) {
        if (widget.onDirection != null) {
          return widget.onDirection!(direction);
        }
        if (widget.onKeyEvent != null) {
          return false;
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
        return AnimatedScale(
          scale: state.pressed
              ? (widget.scaleFactor * 0.96)
              : (isFocused ? widget.scaleFactor : 1.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: isFocused ? borderColor : Colors.transparent,
                width: isFocused ? 2.5 : 0.0,
              ),
              boxShadow: isFocused
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

    if (widget.onKeyEvent != null) {
      content = Focus(
        canRequestFocus: false,
        onKeyEvent: widget.onKeyEvent,
        child: content,
      );
    }

    return content;
  }
}
