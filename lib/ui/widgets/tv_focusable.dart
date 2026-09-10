import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A TV-optimized focusable widget that handles Android TV D-Pad navigation,
/// remote 'OK' / 'Select' button activation, and renders high-contrast glowing
/// focus borders with a smooth scale-up animation.
class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFocusChange;
  final double scaleFactor;
  final BorderRadius? borderRadius;
  final Color? focusedBorderColor;
  final Color? focusedShadowColor;
  final bool autofocus;
  final bool canRequestFocus;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;

  const TvFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.onFocusChange,
    this.scaleFactor = 1.06,
    this.borderRadius,
    this.focusedBorderColor,
    this.focusedShadowColor,
    this.autofocus = false,
    this.canRequestFocus = true,
    this.focusNode,
    this.onKeyEvent,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  late FocusNode _node;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _node =
        widget.focusNode ?? FocusNode(canRequestFocus: widget.canRequestFocus);
    _node.addListener(_handleFocusChange);
    if (widget.autofocus && widget.canRequestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.canRequestFocus) {
          _node.requestFocus();
        }
      });
    }
  }

  @override
  void didUpdateWidget(TvFocusable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_node.canRequestFocus != widget.canRequestFocus) {
      _node.canRequestFocus = widget.canRequestFocus;
    }
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode?.removeListener(_handleFocusChange);
      _node =
          widget.focusNode ??
          FocusNode(canRequestFocus: widget.canRequestFocus);
      _node.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _node.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _node.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() => _isFocused = _node.hasFocus);
      if (_node.hasFocus) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
        );
      }
      widget.onFocusChange?.call(_node.hasFocus);
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (widget.onKeyEvent != null) {
      final customResult = widget.onKeyEvent!(node, event);
      if (customResult != KeyEventResult.ignored) {
        return customResult;
      }
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      final moved = node.focusInDirection(TraversalDirection.down);
      if (moved) return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      final moved = node.focusInDirection(TraversalDirection.up);
      if (moved) return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      final moved = node.focusInDirection(TraversalDirection.right);
      if (moved) return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      final moved = node.focusInDirection(TraversalDirection.left);
      if (moved) return KeyEventResult.handled;
    }

    // TV Remote OK / Select button or Enter / Space / Gamepad A
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA) {
      widget.onTap?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = widget.focusedBorderColor ?? theme.colorScheme.primary;
    final radius = widget.borderRadius ?? BorderRadius.circular(10);

    return Focus(
      focusNode: _node,
      canRequestFocus: widget.canRequestFocus,
      autofocus: widget.autofocus && widget.canRequestFocus,
      onKeyEvent: _handleKey,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isFocused ? widget.scaleFactor : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: _isFocused ? borderColor : Colors.transparent,
                width: _isFocused ? 2.5 : 0.0,
              ),
              boxShadow: _isFocused
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
            child: SelectionContainer.disabled(child: widget.child),
          ),
        ),
      ),
    );
  }
}
