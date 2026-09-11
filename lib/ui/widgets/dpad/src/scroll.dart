import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// TV-aware "ensure visible" scrolling.
///
/// Unlike [Scrollable.ensureVisible], this helper:
///
/// * keeps a configurable [padding] between the item and the viewport edge,
///   so focus glows, borders and scale effects are never clipped;
/// * walks **all** scrollable ancestors, handling rows nested inside
///   vertically scrolling pages in one call;
/// * respects reversed scrollables;
/// * centers items that are larger than the viewport.
abstract final class DpadScroll {
  /// Scrolls every scrollable ancestor of [node] so the node's render box is
  /// fully visible with [padding] around it.
  ///
  /// Does nothing if [node] is not attached to a laid-out render object.
  static void ensureVisible(
    FocusNode node, {
    double padding = 48.0,
    Duration duration = const Duration(milliseconds: 220),
    Curve curve = Curves.easeOutCubic,
  }) {
    final BuildContext? context = node.context;
    if (context == null || !context.mounted) {
      return;
    }
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return;
    }

    final List<ScrollableState> scrollables = <ScrollableState>[];
    context.visitAncestorElements((Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        scrollables.add(element.state as ScrollableState);
      }
      return true;
    });

    for (final ScrollableState scrollable in scrollables) {
      _revealIn(
        scrollable,
        renderObject,
        padding: padding,
        duration: duration,
        curve: curve,
      );
    }
  }

  static void _revealIn(
    ScrollableState scrollable,
    RenderBox target, {
    required double padding,
    required Duration duration,
    required Curve curve,
  }) {
    final RenderObject? viewportObject = scrollable.context.findRenderObject();
    if (viewportObject is! RenderBox || !viewportObject.hasSize) {
      return;
    }
    if (!scrollable.position.hasPixels ||
        !scrollable.position.hasContentDimensions) {
      return;
    }

    final ScrollPosition position = scrollable.position;
    final AxisDirection axisDirection = scrollable.axisDirection;
    final bool horizontal =
        axisDirectionToAxis(axisDirection) == Axis.horizontal;

    final Rect bounds = MatrixUtils.transformRect(
      target.getTransformTo(viewportObject),
      Offset.zero & target.size,
    );

    final double targetStart = horizontal ? bounds.left : bounds.top;
    final double targetEnd = horizontal ? bounds.right : bounds.bottom;
    final double viewportExtent = horizontal
        ? viewportObject.size.width
        : viewportObject.size.height;
    final double targetExtent = targetEnd - targetStart;

    // Effective padding never exceeds the leftover viewport space, so large
    // items are still handled sensibly.
    final double pad = math.max(
      0.0,
      math.min(padding, (viewportExtent - targetExtent) / 2),
    );

    double geometricDelta;
    if (targetExtent + pad * 2 > viewportExtent) {
      // Larger than the viewport: center it.
      geometricDelta = (targetStart + targetEnd) / 2 - viewportExtent / 2;
    } else if (targetStart < pad) {
      geometricDelta = targetStart - pad;
    } else if (targetEnd > viewportExtent - pad) {
      geometricDelta = targetEnd - (viewportExtent - pad);
    } else {
      return; // Already fully visible with padding.
    }

    // A positive geometric delta means content must move towards the start,
    // which increases pixels on forward axes and decreases it on reversed
    // ones.
    final bool reversed =
        axisDirection == AxisDirection.up ||
        axisDirection == AxisDirection.left;
    final double pixelsDelta = reversed ? -geometricDelta : geometricDelta;

    final double offset = (position.pixels + pixelsDelta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((offset - position.pixels).abs() < 0.5) {
      return;
    }
    if (duration == Duration.zero) {
      position.jumpTo(offset);
    } else {
      position.animateTo(offset, duration: duration, curve: curve);
    }
  }
}
