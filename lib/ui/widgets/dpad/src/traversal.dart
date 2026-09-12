import 'package:flutter/widgets.dart';

import 'marks.dart';
import 'region.dart';
import 'scroll.dart';

/// A [FocusTraversalPolicy] that navigates the way TV platforms do.
///
/// Flutter's stock directional policy picks the geometrically closest node,
/// which breaks down in real TV layouts (focus "jumping lanes" between a
/// sidebar and content, skipping rows, escaping carousels). This policy
/// implements the model used by Android's `FocusFinder` and Leanback:
///
/// 1. **Region first** — candidates inside the current [DpadRegion] always
///    win over outside candidates, regardless of raw distance.
/// 2. **Beam preference** — candidates that overlap the focused item on the
///    cross axis ("in the beam") beat diagonal candidates.
/// 3. **Edge behaviors** — at a region boundary, focus leaves, stops or
///    wraps according to the region's [DpadEdgeBehavior].
/// 4. **Enter behaviors** — when focus crosses into a region, the region
///    decides the landing item (restore memory / entry item / nearest).
/// 5. **Lazy-list awareness** — when no candidate exists but a scrollable
///    can still scroll in that direction, the policy scrolls and retries,
///    so `ListView.builder` rows beyond the cache are reachable.
///
/// [Dpad] and [DpadRegion] install this policy automatically; you rarely
/// construct it yourself. To use it manually:
///
/// ```dart
/// FocusTraversalGroup(
///   policy: DpadTraversalPolicy(),
///   child: ...,
/// )
/// ```
///
/// Tab / readers order falls back to [ReadingOrderTraversalPolicy].
class DpadTraversalPolicy extends ReadingOrderTraversalPolicy {
  /// Creates a TV traversal policy.
  DpadTraversalPolicy();

  static const double _kAxisEpsilon = 0.01;

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    // No real focus yet: land on a sensible initial item.
    if (currentNode is FocusScopeNode) {
      final FocusNode? inner = currentNode.focusedChild;
      if (inner != null) {
        return inDirection(inner, direction);
      }
      return _focusInitial(currentNode, direction);
    }

    final FocusScopeNode? scope = currentNode.nearestScope;
    final Rect? currentRect = DpadMarks.rectOf(currentNode);
    if (scope == null || currentRect == null) {
      return super.inDirection(currentNode, direction);
    }

    final ModalRoute<dynamic>? currentRoute =
        (currentNode.context != null && currentNode.context!.mounted)
        ? ModalRoute.of(currentNode.context!)
        : null;

    final List<FocusNode> candidates = scope.traversalDescendants.where((
      FocusNode node,
    ) {
      if (identical(node, currentNode) || !node.canRequestFocus) return false;
      final BuildContext? nodeContext = node.context;
      if (nodeContext == null || !nodeContext.mounted) return false;
      final ModalRoute<dynamic>? nodeRoute = ModalRoute.of(nodeContext);
      if (currentRoute != null && nodeRoute != currentRoute) return false;
      return nodeRoute == null || nodeRoute.isCurrent;
    }).toList();
    final DpadRegionState? region = DpadRegion.ofNode(currentNode);

    if (region != null) {
      final List<FocusNode> inRegion = candidates
          .where((FocusNode node) => identical(DpadRegion.ofNode(node), region))
          .toList();

      final FocusNode? within = _bestCandidate(
        currentRect,
        inRegion,
        direction,
      );
      if (within != null) {
        return _focusNode(within, direction);
      }

      // The region might have more content that simply is not built yet.
      if (_scrollForMore(currentNode, direction, boundary: region.context)) {
        return true;
      }

      switch (region.edgeBehaviorFor(direction)) {
        case DpadEdgeBehavior.stop:
          region.notifyEdge(direction);
          return true;
        case DpadEdgeBehavior.wrap:
          final FocusNode? wrapped = _wrapCandidate(
            currentRect,
            inRegion,
            direction,
          );
          if (wrapped != null) {
            return _focusNode(wrapped, direction);
          }
          region.notifyEdge(direction);
          return true;
        case DpadEdgeBehavior.leave:
          break;
      }
    }

    // Cross-region / global search.
    final List<FocusNode> outside = region == null
        ? candidates
        : candidates
              .where(
                (FocusNode node) => !identical(DpadRegion.ofNode(node), region),
              )
              .toList();

    final FocusNode? nearest = _bestCandidate(currentRect, outside, direction);
    if (nearest == null) {
      // Nothing anywhere — maybe an enclosing page scrollable can reveal
      // more content (lazily built rows, grids, etc.).
      if (_scrollForMore(currentNode, direction)) {
        return true;
      }
      // If we are inside a modal route (e.g. dialog/sheet), stop at boundary.
      if (currentRoute != null && !currentRoute.isFirst) {
        return true;
      }
      return false;
    }

    FocusNode target = nearest;
    final DpadRegionState? targetRegion = DpadRegion.ofNode(nearest);
    if (targetRegion != null && !identical(targetRegion, region)) {
      final List<FocusNode> targetCandidates = outside
          .where(
            (FocusNode node) =>
                identical(DpadRegion.ofNode(node), targetRegion),
          )
          .toList();
      target = targetRegion.resolveEnter(nearest, targetCandidates);
    }
    return _focusNode(target, direction);
  }

  // ---------------------------------------------------------------------
  // Focus + initial placement
  // ---------------------------------------------------------------------

  bool _focusNode(FocusNode node, TraversalDirection direction) {
    DpadRegion.ofNode(node)?.noteFocus(node);
    node.requestFocus();
    // DpadFocusable nodes run their own padded auto-scroll on focus; plain
    // Focus nodes still get a basic reveal so they never stay clipped.
    if (DpadMarks.managed[node] != true) {
      DpadScroll.ensureVisible(node);
    }
    return true;
  }

  bool _focusInitial(FocusScopeNode scope, TraversalDirection direction) {
    final FocusNode? target = DpadMarks.initialCandidate(
      scope.traversalDescendants,
    );
    if (target == null) {
      return false;
    }
    return _focusNode(target, direction);
  }

  // ---------------------------------------------------------------------
  // Geometry — modeled on Android FocusFinder
  // ---------------------------------------------------------------------

  /// Whether [candidate] counts as "in [direction]" from [source].
  ///
  /// Edge-based, so candidates that partially overlap the source (large
  /// tiles, banners) are still considered.
  static bool _isCandidate(
    Rect source,
    Rect candidate,
    TraversalDirection direction,
  ) {
    switch (direction) {
      case TraversalDirection.left:
        return (source.right > candidate.right ||
                source.left >= candidate.right) &&
            source.left > candidate.left;
      case TraversalDirection.right:
        return (source.left < candidate.left ||
                source.right <= candidate.left) &&
            source.right < candidate.right;
      case TraversalDirection.up:
        return (source.bottom > candidate.bottom ||
                source.top >= candidate.bottom) &&
            source.top > candidate.top;
      case TraversalDirection.down:
        return (source.top < candidate.top ||
                source.bottom <= candidate.bottom) &&
            source.bottom < candidate.bottom;
    }
  }

  /// Distance from the source's leading edge to the candidate's trailing
  /// edge along the navigation axis, clamped at zero for overlaps.
  static double _majorDistance(
    Rect source,
    Rect candidate,
    TraversalDirection direction,
  ) {
    final double distance;
    switch (direction) {
      case TraversalDirection.left:
        distance = source.left - candidate.right;
      case TraversalDirection.right:
        distance = candidate.left - source.right;
      case TraversalDirection.up:
        distance = source.top - candidate.bottom;
      case TraversalDirection.down:
        distance = candidate.top - source.bottom;
    }
    return distance < 0 ? 0 : distance;
  }

  /// Distance between centers on the cross axis.
  static double _minorDistance(
    Rect source,
    Rect candidate,
    TraversalDirection direction,
  ) {
    switch (direction) {
      case TraversalDirection.left:
      case TraversalDirection.right:
        return (candidate.center.dy - source.center.dy).abs();
      case TraversalDirection.up:
      case TraversalDirection.down:
        return (candidate.center.dx - source.center.dx).abs();
    }
  }

  /// Whether [candidate] overlaps [source] on the cross axis.
  static bool _inBeam(
    Rect source,
    Rect candidate,
    TraversalDirection direction,
  ) {
    switch (direction) {
      case TraversalDirection.left:
      case TraversalDirection.right:
        return candidate.bottom > source.top && candidate.top < source.bottom;
      case TraversalDirection.up:
      case TraversalDirection.down:
        return candidate.right > source.left && candidate.left < source.right;
    }
  }

  /// Android's weighted distance: progress along the major axis dominates,
  /// but cross-axis drift still discriminates.
  static double _weightedDistance(double major, double minor) {
    return 13 * major * major + minor * minor;
  }

  FocusNode? _bestCandidate(
    Rect source,
    List<FocusNode> candidates,
    TraversalDirection direction,
  ) {
    FocusNode? best;
    bool bestInBeam = false;
    double bestScore = double.infinity;

    for (final FocusNode node in candidates) {
      final Rect? rect = DpadMarks.rectOf(node);
      if (rect == null || rect == source) {
        continue;
      }
      if (!_isCandidate(source, rect, direction)) {
        continue;
      }
      final bool inBeam = _inBeam(source, rect, direction);
      final double score = _weightedDistance(
        _majorDistance(source, rect, direction),
        _minorDistance(source, rect, direction),
      );
      // In-beam candidates categorically beat out-of-beam candidates.
      if (best == null ||
          (inBeam && !bestInBeam) ||
          (inBeam == bestInBeam && score < bestScore)) {
        best = node;
        bestInBeam = inBeam;
        bestScore = score;
      }
    }
    return best;
  }

  /// The wrap-around target: the in-region item furthest *behind* the
  /// source along the navigation axis, preferring the source's beam.
  FocusNode? _wrapCandidate(
    Rect source,
    List<FocusNode> candidates,
    TraversalDirection direction,
  ) {
    final TraversalDirection reverse = _reverseOf(direction);
    FocusNode? best;
    bool bestInBeam = false;
    double bestMajor = -1;
    double bestMinor = double.infinity;

    for (final FocusNode node in candidates) {
      final Rect? rect = DpadMarks.rectOf(node);
      if (rect == null || rect == source) {
        continue;
      }
      if (!_isCandidate(source, rect, reverse)) {
        continue;
      }
      final bool inBeam = _inBeam(source, rect, direction);
      final double major = _majorDistance(source, rect, reverse);
      final double minor = _minorDistance(source, rect, reverse);

      final bool better;
      if (best == null) {
        better = true;
      } else if (inBeam != bestInBeam) {
        better = inBeam;
      } else if ((major - bestMajor).abs() > _kAxisEpsilon) {
        better = major > bestMajor;
      } else {
        better = minor < bestMinor;
      }
      if (better) {
        best = node;
        bestInBeam = inBeam;
        bestMajor = major;
        bestMinor = minor;
      }
    }
    return best;
  }

  static TraversalDirection _reverseOf(TraversalDirection direction) {
    switch (direction) {
      case TraversalDirection.up:
        return TraversalDirection.down;
      case TraversalDirection.down:
        return TraversalDirection.up;
      case TraversalDirection.left:
        return TraversalDirection.right;
      case TraversalDirection.right:
        return TraversalDirection.left;
    }
  }

  // ---------------------------------------------------------------------
  // Lazy-content scrolling
  // ---------------------------------------------------------------------

  /// When no candidate exists, scrolls the nearest matching-axis scrollable
  /// (between the node and [boundary]) one step further and re-runs the
  /// search once the new content is laid out.
  ///
  /// Returns `true` when a scroll was started, which consumes the key press.
  bool _scrollForMore(
    FocusNode node,
    TraversalDirection direction, {
    BuildContext? boundary,
  }) {
    final BuildContext? context = node.context;
    if (context == null || !context.mounted) {
      return false;
    }

    final ModalRoute<dynamic>? currentRoute = ModalRoute.of(context);

    ScrollableState? match;
    context.visitAncestorElements((Element element) {
      if (boundary != null && identical(element, boundary)) {
        return false;
      }
      if (currentRoute != null && ModalRoute.of(element) != currentRoute) {
        return false;
      }
      if (element is StatefulElement && element.state is ScrollableState) {
        final ScrollableState scrollable = element.state as ScrollableState;
        if (_canScrollToward(scrollable, direction)) {
          match = scrollable;
          return false;
        }
      }
      return true;
    });

    final ScrollableState? scrollable = match;
    if (scrollable == null) {
      return false;
    }

    final ScrollPosition position = scrollable.position;
    final bool forward = _isForward(scrollable.axisDirection, direction);
    final double step = position.viewportDimension * 0.8;
    final double offset = (position.pixels + (forward ? step : -step)).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    position
        .animateTo(
          offset,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
        )
        .then((_) {
          // Retry once the newly built content is in place.
          if (!node.hasPrimaryFocus || node.context == null) {
            return;
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (node.hasPrimaryFocus && node.context != null) {
              inDirection(node, direction);
            }
          });
        });
    return true;
  }

  static bool _canScrollToward(
    ScrollableState scrollable,
    TraversalDirection direction,
  ) {
    final Axis axis = axisDirectionToAxis(scrollable.axisDirection);
    final bool horizontal =
        direction == TraversalDirection.left ||
        direction == TraversalDirection.right;
    if (horizontal != (axis == Axis.horizontal)) {
      return false;
    }
    final ScrollPosition position = scrollable.position;
    if (!position.hasPixels || !position.hasContentDimensions) {
      return false;
    }
    final bool forward = _isForward(scrollable.axisDirection, direction);
    return forward
        ? position.pixels < position.maxScrollExtent - 1.0
        : position.pixels > position.minScrollExtent + 1.0;
  }

  /// Whether moving in [direction] corresponds to increasing scroll pixels
  /// for the given [axisDirection].
  static bool _isForward(
    AxisDirection axisDirection,
    TraversalDirection direction,
  ) {
    switch (axisDirection) {
      case AxisDirection.down:
        return direction == TraversalDirection.down;
      case AxisDirection.up:
        return direction == TraversalDirection.up;
      case AxisDirection.right:
        return direction == TraversalDirection.right;
      case AxisDirection.left:
        return direction == TraversalDirection.left;
    }
  }
}
