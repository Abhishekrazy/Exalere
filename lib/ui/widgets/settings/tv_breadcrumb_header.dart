import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// Compact breadcrumb used at the top of every TV settings subpage.
///
/// Replaces the old title row (a 20–24 pt heading plus a description line) with
/// chips, which returns roughly 60–100 px of vertical space to the content and
/// still says where the user is: `Back  Settings › Add-ons`.
class TvBreadcrumbHeader extends StatelessWidget {
  const TvBreadcrumbHeader({super.key, required this.crumbs, this.trailing});

  /// Path labels, root first; the last one is highlighted.
  final List<String> crumbs;

  /// Optional badge after the last crumb (counts, status pills).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    Widget chip({required String label, required bool highlighted}) {
      final background = highlighted
          ? tokens.primaryAccent.withValues(alpha: 0.18)
          : tokens.surfaceElevated.withValues(alpha: 0.55);
      final border = highlighted
          ? tokens.primaryAccent.withValues(alpha: 0.55)
          : tokens.borderSubtle;

      final content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: tokens.getShapeDecoration(
          color: background,
          radius: tokens.cardRadius * 2,
          side: BorderSide(color: border, width: 0.8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: highlighted ? tokens.primaryAccent : tokens.textSecondary,
            fontSize: highlighted ? 13 : 12,
            fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: highlighted ? -0.2 : 0,
          ),
        ),
      );

      return content;
    }

    return Row(
      children: [
        for (var index = 0; index < crumbs.length; index++) ...[
          if (index > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: tokens.textMuted,
              ),
            ),
          chip(label: crumbs[index], highlighted: index == crumbs.length - 1),
        ],
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}
