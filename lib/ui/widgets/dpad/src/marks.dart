import 'package:flutter/widgets.dart';

/// Internal per-[FocusNode] annotations shared between [DpadFocusable] and
/// the traversal engine, without coupling them to each other.
abstract final class DpadMarks {
  /// Nodes owned by a `DpadFocusable`. Those handle their own auto-scroll,
  /// so the traversal policy must not scroll for them.
  static final Expando<bool> managed = Expando<bool>('dpad.managed');

  /// Nodes flagged as the entry item of their region
  /// (`DpadFocusable(entry: true)`).
  static final Expando<bool> entry = Expando<bool>('dpad.entry');

  /// Returns the geometry of [node] in global coordinates, or `null` when
  /// the node is not attached to a laid-out render object.
  static Rect? rectOf(FocusNode node) {
    final BuildContext? context = node.context;
    if (context == null || !context.mounted) {
      return null;
    }
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }
    return MatrixUtils.transformRect(
      renderObject.getTransformTo(null),
      Offset.zero & renderObject.size,
    );
  }

  /// Whether [node] can be focused right now.
  ///
  /// A node must be attached to the focus tree ([FocusNode.parent] set):
  /// after a `Focus` widget hands an externally owned node back, the node's
  /// `context` can keep pointing at a still-mounted (reused) element, so
  /// the context alone is not proof of life.
  static bool isUsable(FocusNode? node) {
    if (node == null || node.parent == null) {
      return false;
    }
    final BuildContext? context = node.context;
    return context != null && context.mounted && node.canRequestFocus;
  }

  /// Picks the item that should receive focus when nothing better is known:
  /// the first entry-marked node, otherwise the top-left-most one.
  static FocusNode? initialCandidate(Iterable<FocusNode> candidates) {
    FocusNode? topLeft;
    Rect? topLeftRect;
    for (final FocusNode node in candidates) {
      if (entry[node] ?? false) {
        return node;
      }
      final Rect? rect = rectOf(node);
      if (rect == null) {
        continue;
      }
      if (topLeftRect == null ||
          rect.top < topLeftRect.top - 0.01 ||
          (rect.top <= topLeftRect.top + 0.01 &&
              rect.left < topLeftRect.left)) {
        topLeft = node;
        topLeftRect = rect;
      }
    }
    return topLeft;
  }
}
