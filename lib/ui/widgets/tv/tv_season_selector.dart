import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';

/// Horizontal season pill selector for Android TV series screens.
class TvSeasonSelector extends StatelessWidget {
  final int seasonCount;
  final int selectedSeasonIndex;
  final ValueChanged<int> onSeasonSelected;
  final FocusNode? selectedSeasonFocusNode;
  final bool Function()? onRightFromLast;
  final bool Function()? onUpFocus;
  final bool Function()? onDownFocus;

  const TvSeasonSelector({
    super.key,
    required this.seasonCount,
    required this.selectedSeasonIndex,
    required this.onSeasonSelected,
    this.selectedSeasonFocusNode,
    this.onRightFromLast,
    this.onUpFocus,
    this.onDownFocus,
  });

  @override
  Widget build(BuildContext context) {
    if (seasonCount <= 1) return const SizedBox.shrink();

    final tokens = context.tokens;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int sIdx = 0; sIdx < seasonCount; sIdx++) ...[
            if (sIdx > 0) const SizedBox(width: 8),
            Builder(
              builder: (context) {
                final isSelected = selectedSeasonIndex == sIdx;
                final isFirst = sIdx == 0;
                final isLast = sIdx == seasonCount - 1;

                return TvFocusable(
                  focusNode: isSelected ? selectedSeasonFocusNode : null,
                  focusedBorderColor: isSelected ? tokens.textPrimary : null,
                  focusedShadowColor: isSelected
                      ? tokens.textPrimary.withValues(alpha: 0.65)
                      : null,
                  scaleFactor: 1.08,
                  shape: tokens.shapePill,
                  borderRadius: tokens.borderRadiusPill,
                  onTap: () => onSeasonSelected(sIdx),
                  onDirection: (direction) {
                    if (direction == TraversalDirection.up &&
                        onUpFocus != null) {
                      return onUpFocus!();
                    }
                    if (direction == TraversalDirection.down &&
                        onDownFocus != null) {
                      return onDownFocus!();
                    }
                    if (direction == TraversalDirection.left && isFirst) {
                      return true; // Clamp at left edge
                    }
                    if (direction == TraversalDirection.right &&
                        isLast &&
                        onRightFromLast != null) {
                      return onRightFromLast!();
                    }
                    return false;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: ShapeDecoration(
                      color: isSelected
                          ? tokens.primaryAccent
                          : tokens.surfaceElevated.withValues(alpha: 0.4),
                      shape: tokens.getShapePill(
                        side: BorderSide(
                          color: isSelected
                              ? tokens.primaryAccent
                              : tokens.borderSubtle,
                          width: 1.0,
                        ),
                      ),
                    ),
                    child: Text(
                      'Season ${sIdx + 1}',
                      style: TextStyle(
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : tokens.textSecondary,
                        fontSize: 11.5,
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
