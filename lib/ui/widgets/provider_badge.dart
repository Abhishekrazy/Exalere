import 'package:flutter/material.dart';

import '../../models/media_item.dart';
import '../theme/app_tokens.dart';

class ProviderBadge extends StatelessWidget {
  final ProviderType provider;
  final bool isSelected;
  final VoidCallback? onTap;

  const ProviderBadge({
    super.key,
    required this.provider,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return InkWell(
      onTap: onTap,
      borderRadius: tokens.borderRadiusPill,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: tokens.borderRadiusPill,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : tokens.borderSubtle,
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getProviderIcon(provider),
              size: 15,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : tokens.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              provider.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : tokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getProviderIcon(ProviderType p) {
    switch (p) {
      case ProviderType.movieBox:
        return Icons.movie_filter_rounded;
      case ProviderType.fourKHdHub:
        return Icons.high_quality_rounded;
      case ProviderType.liveTv:
        return Icons.live_tv_rounded;
      case ProviderType.addons:
        return Icons.extension_rounded;
    }
  }
}
