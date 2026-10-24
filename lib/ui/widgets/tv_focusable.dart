import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'dpad/dpad.dart';
import 'tv_spatial_navigation.dart';

/// Hands focus back to the control a popup took it from.
///
/// Pushing a route makes every [TvFocusable] underneath un-focusable, which drops
/// the focus they were holding. Flutter then restores focus to the route's
/// [FocusScope] - but that only puts focus somewhere in the scope, not back on
/// the button the user pressed, and in some layouts it lands on nothing at all.
/// So the control that had focus is remembered when a popup opens and asked for
/// focus again when the popup closes.
///
/// A list, not a single slot: popups stack (a dialog can open another dialog),
/// and each close has to restore the layer underneath it.
class TvFocusReturn {
  TvFocusReturn._();

  static final List<FocusNode> _parked = [];

  /// Remembers [node] as the control to give focus back to.
  static void park(FocusNode node) {
    _parked.remove(node);
    _parked.add(node);
  }

  /// Requests focus for [node] if it is the outermost parked control.
  ///
  /// Runs in a post-frame callback so the popup's route transition has finished;
  /// requesting focus during the pop's rebuild is immediately overwritten by the
  /// focus restoration Flutter does for the route.
  static void restore(FocusNode node, {required bool canFocus}) {
    if (_parked.isEmpty || !_parked.contains(node)) return;
    _parked.remove(node);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!node.canRequestFocus || !canFocus) return;
      // The widget may have been disposed with the popup's route.
      if (node.context == null) return;
      node.requestFocus();
    });
  }

  @visibleForTesting
  static int get parkedCount => _parked.length;

  @visibleForTesting
  static void clear() => _parked.clear();
}

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
  final bool? entry;
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
    this.entry,
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

  /// Route currency on the previous build, used to detect a popup opening or
  /// closing over this control.
  bool? _routeWasCurrent;

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

  ShapeBorder _resolveShape({
    required ShapeBorder? widgetShape,
    required BorderRadius? widgetBorderRadius,
    required AppDesignTokens tokens,
    BorderSide borderSide = BorderSide.none,
  }) {
    if (widgetShape is CircleBorder) {
      return CircleBorder(side: borderSide);
    }

    final double radius;
    if (tokens.cornerStyle == CornerStyle.sharp) {
      radius = 0.0;
    } else if (widgetBorderRadius != null) {
      radius = widgetBorderRadius.topLeft.x;
    } else if (widgetShape is RoundedRectangleBorder) {
      radius = widgetShape.borderRadius.resolve(TextDirection.ltr).topLeft.x;
    } else if (widgetShape is BeveledRectangleBorder) {
      radius = widgetShape.borderRadius.resolve(TextDirection.ltr).topLeft.x;
    } else if (widgetShape is StadiumBorder) {
      return tokens.getShapePill(side: borderSide);
    } else {
      radius = tokens.cardRadius;
    }

    return tokens.getShapeBorder(radius: radius, side: borderSide);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // Focus is a bright neutral cursor ring, not the accent used to mark a
    // selected item - otherwise "focused" and "selected" look identical.
    final borderColor = widget.focusedBorderColor ?? tokens.focusRing;

    final route = ModalRoute.of(context);
    final isRouteCurrent = route == null || route.isCurrent;
    final bool canFocus = widget.canRequestFocus && isRouteCurrent;

    // A popup covering this route makes the control un-focusable, which drops the
    // focus it was holding. Flutter restores the route's FocusScope when the popup
    // closes, but not the individual control - so on TV the remote would land on
    // nothing and the user has to D-Pad back from the start.
    if (_routeWasCurrent == true &&
        !isRouteCurrent &&
        _effectiveNode.hasFocus) {
      TvFocusReturn.park(_effectiveNode);
    }
    _routeWasCurrent = isRouteCurrent;

    _effectiveNode.canRequestFocus = canFocus;

    if (isRouteCurrent) {
      TvFocusReturn.restore(_effectiveNode, canFocus: canFocus);
    }

    return DpadFocusable(
      focusNode: _effectiveNode,
      autofocus: widget.autofocus && isRouteCurrent,
      entry: widget.entry ?? (widget.autofocus && isRouteCurrent),
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
        final isFocused = state.focused && isRouteCurrent;
        final baseShape = _resolveShape(
          widgetShape: widget.shape,
          widgetBorderRadius: widget.borderRadius,
          tokens: tokens,
          borderSide: BorderSide.none,
        );
        final focusShape = isFocused
            ? _resolveShape(
                widgetShape: widget.shape,
                widgetBorderRadius: widget.borderRadius,
                tokens: tokens,
                borderSide: BorderSide(color: borderColor, width: 2.5),
              )
            : null;

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
              shape: baseShape,
              shadows: isFocused
                  ? [
                      // A tight halo: enough to lift the focused item off the
                      // background, not enough to wash out its neighbours.
                      BoxShadow(
                        color: (widget.focusedShadowColor ?? borderColor)
                            .withValues(alpha: 0.22),
                        blurRadius: 9,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            foregroundDecoration: isFocused
                ? ShapeDecoration(shape: focusShape!)
                : null,
            child: ClipPath(
              clipper: ShapeBorderClipper(shape: baseShape),
              clipBehavior: Clip.antiAlias,
              child: SelectionContainer.disabled(child: child),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
