import 'package:flutter/material.dart';

import '../../models/media_item.dart';

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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : Colors.white.withValues(alpha: 0.12),
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
              color: isSelected ? Colors.black : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              provider.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.black : Colors.white,
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
