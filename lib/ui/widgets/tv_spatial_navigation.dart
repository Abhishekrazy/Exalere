import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TV-grade 2D spatial navigation engine for Android TV / Leanback D-Pad navigation.
///
/// Scans on-screen focusable candidates in the requested direction (Up, Down, Left, Right).
/// Only navigates if a valid candidate physically exists on screen in that direction.
/// If nothing is available in that direction, it does nothing and consumes the key event
/// to prevent Flutter from falling back to arbitrary reading-order / tab traversal jumps.
class TvSpatialNavigation {
  /// Handles a directional D-Pad key event for [currentNode].
  ///
  /// Returns [KeyEventResult.handled] for all directional keys to strictly enforce
  /// spatial navigation and prevent erratic reading-order jumps.
  /// Returns [KeyEventResult.ignored] for non-directional keys so other handlers
  /// (e.g. Select / Enter / Back) can process them.
  static KeyEventResult handleKeyEvent(
    FocusNode currentNode,
    KeyEvent event, {
    bool handleSelection = false,
    VoidCallback? onSelect,
  }) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (handleSelection && onSelect != null) {
      if (key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.gameButtonA) {
        onSelect();
        return KeyEventResult.handled;
      }
    }

    final TraversalDirection? direction;
    if (key == LogicalKeyboardKey.arrowDown) {
      direction = TraversalDirection.down;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      direction = TraversalDirection.up;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      direction = TraversalDirection.right;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      direction = TraversalDirection.left;
    } else {
      return KeyEventResult.ignored;
    }

    // Attempt spatial movement
    moveFocus(currentNode, direction);

    // Strictly consume all directional keys to block Flutter's reading-order fallback
    return KeyEventResult.handled;
  }

  /// Scans the screen for the best candidate in [direction] and moves focus to it.
  /// Returns true if focus was successfully moved, false if nothing was available in that direction.
  static bool moveFocus(FocusNode currentNode, TraversalDirection direction) {
    final context = currentNode.context;
    if (context == null || !context.mounted) return false;

    final RenderObject? currentRender = context.findRenderObject();
    if (currentRender is! RenderBox || !currentRender.hasSize) return false;

    final Rect currentRect =
        currentRender.localToGlobal(Offset.zero) & currentRender.size;

    final mediaQuery = MediaQuery.maybeOf(context);
    final Size screenSize =
        mediaQuery?.size ??
        (View.maybeOf(context) != null
            ? (View.of(context).physicalSize /
                  View.of(context).devicePixelRatio)
            : const Size(1920, 1080));

    // Visible viewport inflated slightly to allow adjacent cards in scroll views to be detected
    final Rect visibleBounds = (Offset.zero & screenSize).inflate(280.0);

    final FocusScopeNode scope = FocusScope.of(context);
    final Iterable<FocusNode> allDescendants = scope.traversalDescendants;

    FocusNode? bestCandidate;
    double bestScore = double.infinity;

    for (final candidate in allDescendants) {
      if (candidate == currentNode) continue;
      if (!candidate.canRequestFocus || candidate.skipTraversal) continue;
      final candContext = candidate.context;
      if (candContext == null || !candContext.mounted) continue;

      final RenderObject? candRender = candContext.findRenderObject();
      if (candRender is! RenderBox || !candRender.hasSize) continue;
      if (candRender.size.width <= 0 || candRender.size.height <= 0) continue;

      final Rect targetRect =
          candRender.localToGlobal(Offset.zero) & candRender.size;

      // Must be within visible bounds
      if (!visibleBounds.overlaps(targetRect)) continue;

      // Calculate directional candidate score
      final double? score = _calculateDirectionalScore(
        currentRect,
        targetRect,
        direction,
      );

      if (score != null && score < bestScore) {
        bestScore = score;
        bestCandidate = candidate;
      }
    }

    if (bestCandidate != null) {
      bestCandidate.requestFocus();
      final candContext = bestCandidate.context;
      if (candContext != null && candContext.mounted) {
        Scrollable.ensureVisible(
          candContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
        );
      }
      return true;
    }

    // Nothing available in that direction on screen -> do nothing
    return false;
  }

  static double? _calculateDirectionalScore(
    Rect current,
    Rect target,
    TraversalDirection direction,
  ) {
    // Overlaps along axes
    final double hOverlap = max(
      0.0,
      min(current.right, target.right) - max(current.left, target.left),
    );
    final double vOverlap = max(
      0.0,
      min(current.bottom, target.bottom) - max(current.top, target.top),
    );

    switch (direction) {
      case TraversalDirection.right:
        // Must be to the right of current
        if (target.center.dx <= current.center.dx + 4 ||
            target.left < current.left + 4) {
          return null;
        }

        // Horizontal navigation must strictly remain in the same row / shelf,
        // EXCEPT when navigating out of the persistent TV sidebar docked at the screen's left edge (x=0..72).
        final bool isSidebarCurrent = current.left <= 8 && current.right <= 80;
        if (vOverlap == 0 && !isSidebarCurrent) {
          final double vGap = target.top > current.bottom
              ? (target.top - current.bottom)
              : (current.top - target.bottom);
          if (vGap > 20) {
            return null;
          }
        }

        final double primaryDist;
        if (target.left >= current.right) {
          primaryDist = target.left - current.right;
        } else {
          primaryDist = (target.center.dx - current.center.dx);
        }

        final double orthogonalDist;
        if (vOverlap > 0) {
          orthogonalDist = (target.center.dy - current.center.dy).abs();
        } else {
          final double vGap = target.top > current.bottom
              ? (target.top - current.bottom)
              : (current.top - target.bottom);
          if (vGap > 20 && !isSidebarCurrent) {
            return null;
          }
          orthogonalDist = vGap * 3.0;
        }

        final double bonus = vOverlap > 0 ? 60.0 : 0.0;
        return (primaryDist * 2.5) + (orthogonalDist * 1.0) - bonus;

      case TraversalDirection.left:
        // Must be to the left of current
        if (target.center.dx >= current.center.dx - 4 ||
            target.right > current.right - 4) {
          return null;
        }

        // Horizontal navigation must strictly remain in the same row / shelf,
        // EXCEPT when navigating into the persistent TV sidebar docked at the screen's left edge (x=0..72).
        final bool isSidebarTarget =
            target.left <= 8 && target.right <= 80 && current.left >= 60;
        if (vOverlap == 0 && !isSidebarTarget) {
          final double vGap = target.top > current.bottom
              ? (target.top - current.bottom)
              : (current.top - target.bottom);
          if (vGap > 15) {
            return null;
          }
        }

        final double primaryDist;
        if (target.right <= current.left) {
          primaryDist = current.left - target.right;
        } else {
          primaryDist = (current.center.dx - target.center.dx);
        }

        final double orthogonalDist;
        if (vOverlap > 0) {
          orthogonalDist = (target.center.dy - current.center.dy).abs();
        } else {
          final double vGap = target.top > current.bottom
              ? (target.top - current.bottom)
              : (current.top - target.bottom);
          if (vGap > 15 && !isSidebarTarget) {
            return null;
          }
          orthogonalDist = vGap * 3.0;
        }

        final double bonus = vOverlap > 0 ? 60.0 : 0.0;
        return (primaryDist * 2.5) + (orthogonalDist * 1.0) - bonus;

      case TraversalDirection.down:
        // Must be below current
        if (target.center.dy <= current.center.dy + 4 ||
            target.top < current.top + 4) {
          return null;
        }

        // Never jump vertically between the docked TV sidebar (x <= 72) and main content body!
        final bool isCurrentInSidebarDown =
            current.left <= 8 && current.right <= 80;
        final bool isTargetInSidebarDown =
            target.left <= 8 && target.right <= 80;
        if (isCurrentInSidebarDown != isTargetInSidebarDown) {
          return null;
        }

        // Prevent column-jumping: if target is completely in a different column (like the sidebar
        // vs content body) without horizontal overlap or reasonable horizontal proximity, reject it.
        if (hOverlap == 0) {
          final double centerDeltaX = (target.center.dx - current.center.dx)
              .abs();
          final double maxAllowedDeltaX =
              max(current.width, target.width) * 1.35 + 40;
          if (centerDeltaX > maxAllowedDeltaX) {
            return null;
          }
        }

        final double primaryDist;
        if (target.top >= current.bottom) {
          primaryDist = target.top - current.bottom;
        } else {
          primaryDist = (target.center.dy - current.center.dy);
        }

        final double orthogonalDist;
        if (hOverlap > 0) {
          orthogonalDist = (target.center.dx - current.center.dx).abs();
        } else {
          final double hGap = target.left > current.right
              ? (target.left - current.right)
              : (current.left - target.right);
          if (hGap > primaryDist * 1.0 + 35) {
            return null;
          }
          orthogonalDist = hGap * 3.0;
        }

        final double bonus = hOverlap > 0 ? 60.0 : 0.0;
        return (primaryDist * 2.5) + (orthogonalDist * 1.0) - bonus;

      case TraversalDirection.up:
        // Must be above current
        if (target.center.dy >= current.center.dy - 4 ||
            target.bottom > current.bottom - 4) {
          return null;
        }

        // Never jump vertically between the docked TV sidebar (x <= 72) and main content body!
        final bool isCurrentInSidebarUp =
            current.left <= 8 && current.right <= 80;
        final bool isTargetInSidebarUp = target.left <= 8 && target.right <= 80;
        if (isCurrentInSidebarUp != isTargetInSidebarUp) {
          return null;
        }

        // Prevent column-jumping: cannot jump laterally to distant column on UP
        if (hOverlap == 0) {
          final double centerDeltaX = (target.center.dx - current.center.dx)
              .abs();
          final double maxAllowedDeltaX =
              max(current.width, target.width) * 1.35 + 40;
          if (centerDeltaX > maxAllowedDeltaX) {
            return null;
          }
        }

        final double primaryDist;
        if (target.bottom <= current.top) {
          primaryDist = current.top - target.bottom;
        } else {
          primaryDist = (current.center.dy - target.center.dy);
        }

        final double orthogonalDist;
        if (hOverlap > 0) {
          orthogonalDist = (target.center.dx - current.center.dx).abs();
        } else {
          final double hGap = target.left > current.right
              ? (target.left - current.right)
              : (current.left - target.right);
          if (hGap > primaryDist * 1.0 + 35) {
            return null;
          }
          orthogonalDist = hGap * 3.0;
        }

        final double bonus = hOverlap > 0 ? 60.0 : 0.0;
        return (primaryDist * 2.5) + (orthogonalDist * 1.0) - bonus;
    }
  }
}
