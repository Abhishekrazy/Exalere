import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';

/// One destination in [AppBottomNavBar].
class AppNavItem {
  const AppNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Floating bottom navigation bar.
///
/// Replaces Material's [NavigationBar] because that lays out a fixed cell per
/// destination and starts truncating labels once a bar carries more than about
/// five. This app has seven, so labels are scaled to fit instead of being
/// clipped, and the selected destination is marked by an accent pill rather than
/// by colour alone — legible at a glance and on a small screen.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const Duration _animationDuration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration = reduceMotion ? Duration.zero : _animationDuration;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.surfaceCard.withValues(alpha: 0.82),
            border: Border(
              top: BorderSide(color: tokens.borderSubtle, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavCell(
                        item: items[i],
                        selected: i == currentIndex,
                        duration: duration,
                        onTap: () => onSelected(i),
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

class _NavCell extends StatelessWidget {
  const _NavCell({
    required this.item,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  final AppNavItem item;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = selected ? tokens.primaryAccent : tokens.textMuted;

    return TvFocusable(
      borderRadius: tokens.borderRadiusSm,
      scaleFactor: 1.0,
      onTap: onTap,
      child: Semantics(
        selected: selected,
        button: true,
        label: item.label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? tokens.primaryAccent.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: tokens.borderRadiusSm,
              border: Border.all(
                color: selected
                    ? tokens.primaryAccent.withValues(alpha: 0.38)
                    : Colors.transparent,
                width: 0.8,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  duration: duration,
                  curve: Curves.easeOut,
                  scale: selected ? 1.06 : 1.0,
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    size: 21,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                // Scale the label down rather than clipping it: seven labels
                // must all stay readable on a narrow phone.
                SizedBox(
                  width: double.infinity,
                  height: 12,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.1,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
