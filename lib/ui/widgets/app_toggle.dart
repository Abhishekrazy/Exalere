import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'tv_focusable.dart';

/// Pure visual toggle that honours the active corner style.
///
/// The track is a pill and the thumb a small chamfered square, so Cut renders
/// eight-corner bevels, Sharp renders squares and Rounded renders pills.
class AppToggleTrack extends StatelessWidget {
  const AppToggleTrack({
    super.key,
    required this.value,
    this.enabled = true,
    this.width = 44,
    this.height = 24,
  });

  final bool value;
  final bool enabled;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final thumbSize = height - 8;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: width,
        height: height,
        padding: const EdgeInsets.all(4),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: ShapeDecoration(
          shape: tokens.getShapePill(
            side: BorderSide(
              color: value ? tokens.primaryAccent : tokens.borderSubtle,
              width: AppStroke.border,
            ),
          ),
          color: value
              ? tokens.primaryAccent.withValues(alpha: 0.85)
              : tokens.surfaceCard,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          width: thumbSize,
          height: thumbSize,
          decoration: ShapeDecoration(
            shape: tokens.getShapeBorder(radius: thumbSize * 0.3),
            color: value ? tokens.canvasBackground : tokens.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Focusable toggle: D-pad select (or tap) flips it.
class AppToggle extends StatelessWidget {
  const AppToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.focusNode,
    this.autofocus = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      scaleFactor: enabled ? 1.06 : 1.0,
      borderRadius: context.tokens.borderRadiusPill,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: AppToggleTrack(value: value, enabled: enabled),
    );
  }
}
