import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dpad/dpad.dart';

import '../../../providers/app_provider.dart';
import '../../theme/app_tokens.dart';

/// Card positioned at the end of a horizontal [HomeMediaShelf].
/// Navigates to the full category view when tapped or selected via TV D-Pad.
class HomeExploreAllCard extends StatefulWidget {
  final VoidCallback onTap;
  final String categoryTitle;
  final FocusNode? focusNode;
  final bool autofocus;

  const HomeExploreAllCard({
    super.key,
    required this.onTap,
    this.categoryTitle = 'Explore All',
    this.focusNode,
    this.autofocus = false,
  });

  @override
  State<HomeExploreAllCard> createState() => _HomeExploreAllCardState();
}

class _HomeExploreAllCardState extends State<HomeExploreAllCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final isActive = _isHovered || _isFocused;

    bool isTv = false;
    double uiScale = 1.0;
    try {
      final app = context.watch<AppProvider>();
      isTv = app.isTvMode;
      uiScale = app.uiScale;
    } catch (_) {}

    final scaleMultiplier = uiScale < 0.92
        ? 0.92
        : (uiScale > 1.08 ? 1.08 : 1.0);
    final defaultWidth = isTv ? 115.0 : 140.0;
    final defaultHeight = isTv ? 158.0 : 196.0;
    final cardWidth = defaultWidth * scaleMultiplier;
    final cardHeight = defaultHeight * scaleMultiplier;

    final cardRadius = tokens.borderRadiusSm.topLeft.x;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: DpadFocusable(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onSelect: widget.onTap,
        onDirection: (direction) {
          // Edge guard: consume D-Pad Right so focus stays on this terminal card
          if (direction == TraversalDirection.right) {
            return true;
          }
          return false;
        },
        onFocusChange: (focused) {
          if (!mounted) return;
          setState(() => _isFocused = focused);
        },
        builder: (context, state, child) {
          final isFocused = state.focused;
          final isCardActive = isFocused || _isHovered;
          return AnimatedScale(
            scale: state.pressed ? 0.98 : (isCardActive ? 1.06 : 1.0),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: child,
          );
        },
        child: InkWell(
          canRequestFocus: false,
          onTap: widget.onTap,
          borderRadius: tokens.borderRadiusSm,
          child: Container(
            width: cardWidth,
            margin: EdgeInsets.symmetric(horizontal: isTv ? 4 : 6, vertical: 4),
            child: ClipRect(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: cardWidth,
                    height: cardHeight,
                    decoration: tokens.getShapeDecoration(
                      color: tokens.surfaceCard,
                      radius: cardRadius,
                      side: BorderSide(
                        color: isActive
                            ? theme.colorScheme.primary
                            : tokens.borderSubtle,
                        width: isActive ? 2.0 : 1.0,
                      ),
                      shadows: isActive
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.5,
                                ),
                                blurRadius: 14,
                                spreadRadius: 1,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : tokens.getCardShadows(),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: isTv ? 40 : 46,
                              height: isTv ? 40 : 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tokens.primaryAccent.withValues(
                                  alpha: 0.15,
                                ),
                                border: Border.all(
                                  color: tokens.primaryAccent.withValues(
                                    alpha: 0.35,
                                  ),
                                  width: 1.0,
                                ),
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: tokens.primaryAccent,
                                size: isTv ? 20 : 24,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Explore All',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: isTv ? 11 : 12.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'See full list',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: isTv ? 8.5 : 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: cardWidth,
                    child: Text(
                      widget.categoryTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isTv ? 10.5 : 12.0,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    'More titles',
                    style: TextStyle(
                      fontSize: isTv ? 8.5 : 10.0,
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
