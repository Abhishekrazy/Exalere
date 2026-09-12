import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dpad/dpad.dart';
import '../dpad/src/marks.dart';

/// A universal focus isolation and trapping boundary for popups, dialogs,
/// bottom sheets, and context menus on Android TV, Desktop, and Mobile.
///
/// Features:
/// 1. **Focus Trapping**: Encloses content in an isolated [FocusScope] and
///    a [DpadRegion] with [DpadEdgeBehavior.stop], preventing D-Pad navigation
///    from escaping outside the popup boundaries.
/// 2. **Tab & Shift+Tab Trapping**: Cycles focus strictly within the focusable
///    buttons of the popup without letting Tab escape to background elements.
/// 3. **Automatic Fallback Autofocus**: Guarantees that the first or marked
///    entry button in the popup receives focus on presentation even if individual
///    buttons forgot `autofocus: true`.
/// 4. **Dismiss Interception**: Handles `Escape` and TV remote back button
///    cleanly to dismiss the modal route safely.
class TvPopupScope extends StatefulWidget {
  final Widget child;

  /// Whether the popup scope automatically focuses its primary child upon appearance.
  final bool autofocus;

  /// Optional callback invoked when Escape or back is triggered.
  /// If null, defaults to `Navigator.of(context).maybePop()`.
  final VoidCallback? onDismiss;

  const TvPopupScope({
    super.key,
    required this.child,
    this.autofocus = true,
    this.onDismiss,
  });

  @override
  State<TvPopupScope> createState() => _TvPopupScopeState();
}

class _TvPopupScopeState extends State<TvPopupScope> {
  late final FocusScopeNode _scopeNode;
  bool _initialFocusScheduled = false;

  @override
  void initState() {
    super.initState();
    _scopeNode = FocusScopeNode(debugLabel: 'TvPopupScope');
    if (widget.autofocus) {
      _scheduleInitialFocus();
    }
  }

  @override
  void dispose() {
    _scopeNode.dispose();
    super.dispose();
  }

  void _scheduleInitialFocus() {
    if (_initialFocusScheduled) return;
    _initialFocusScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialFocusScheduled = false;
      if (!mounted) return;
      _ensureFocusInsideScope();
    });
  }

  void _ensureFocusInsideScope() {
    final primary = FocusManager.instance.primaryFocus;
    // If a descendant inside our scope is already focused, nothing to do.
    if (primary != null &&
        primary is! FocusScopeNode &&
        _scopeNode.descendants.contains(primary)) {
      return;
    }

    // Otherwise, find the best initial candidate in this scope.
    final candidates = _scopeNode.traversalDescendants
        .where((node) => node.canRequestFocus && node is! FocusScopeNode)
        .toList();

    if (candidates.isNotEmpty) {
      final target = DpadMarks.initialCandidate(candidates) ?? candidates.first;
      DpadRegion.ofNode(target)?.noteFocus(target);
      target.requestFocus();
    } else {
      // If candidates aren't built yet (e.g. async/animated layout), retry once on next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final currentPrimary = FocusManager.instance.primaryFocus;
        if (currentPrimary == null ||
            !_scopeNode.descendants.contains(currentPrimary)) {
          final delayedCandidates = _scopeNode.traversalDescendants
              .where((node) => node.canRequestFocus && node is! FocusScopeNode)
              .toList();
          if (delayedCandidates.isNotEmpty) {
            final target =
                DpadMarks.initialCandidate(delayedCandidates) ??
                delayedCandidates.first;
            DpadRegion.ofNode(target)?.noteFocus(target);
            target.requestFocus();
          }
        }
      });
    }
  }

  KeyEventResult _handleScopeKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    // Intercept Escape key for desktop / TV dismissal
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (widget.onDismiss != null) {
        widget.onDismiss!();
      } else {
        Navigator.of(context).maybePop();
      }
      return KeyEventResult.handled;
    }

    // Intercept Tab / Shift+Tab to cycle strictly within the popup scope
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      final isShift = HardwareKeyboard.instance.isShiftPressed;
      final candidates = _scopeNode.traversalDescendants
          .where((node) => node.canRequestFocus && node is! FocusScopeNode)
          .toList();

      if (candidates.isEmpty) {
        return KeyEventResult.handled;
      }

      final primary = FocusManager.instance.primaryFocus;
      final currentIndex = primary != null ? candidates.indexOf(primary) : -1;

      final int nextIndex;
      if (isShift) {
        // Shift+Tab: move backward or wrap to end
        nextIndex = currentIndex <= 0
            ? candidates.length - 1
            : currentIndex - 1;
      } else {
        // Tab: move forward or wrap to start
        nextIndex = currentIndex >= candidates.length - 1
            ? 0
            : currentIndex + 1;
      }

      final target = candidates[nextIndex];
      DpadRegion.ofNode(target)?.noteFocus(target);
      target.requestFocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: _scopeNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleScopeKey,
      child: DpadRegion(
        horizontalEdge: DpadEdgeBehavior.stop,
        verticalEdge: DpadEdgeBehavior.stop,
        child: widget.child,
      ),
    );
  }
}
