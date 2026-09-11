import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/app_provider.dart';
import '../../theme/app_tokens.dart';

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onExplore;

  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTv = context.read<AppProvider>().isTvMode;
    final tokens = context.tokens;

    Widget? exploreButton;
    if (onExplore != null && !isTv) {
      final child = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            Text(
              'Explore All',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      );

      exploreButton = InkWell(
        canRequestFocus: false,
        onTap: onExplore,
        borderRadius: tokens.borderRadiusSm,
        child: child,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isTv ? 6 : 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: isTv ? 15 : 18,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: tokens.primaryAccent,
                  borderRadius: tokens.borderRadiusXs,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: isTv ? 15 : 18,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          ?exploreButton,
        ],
      ),
    );
  }
}
