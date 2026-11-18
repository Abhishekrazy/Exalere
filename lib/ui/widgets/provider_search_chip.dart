import 'package:flutter/material.dart';

import '../../models/provider_search_section.dart';
import '../theme/app_tokens.dart';
import 'dpad/dpad.dart';
import 'tv_focusable.dart';

/// One provider's filter chip on the global search screen.
///
/// The chip is the "where is this title?" control: it names the provider and
/// reports that provider's own state — a result count, "searching", "none", or
/// "failed" — so a dead provider is visible instead of silently contributing
/// nothing to a merged list. Passing a `null` [status] renders the aggregate
/// "All providers" chip.
class ProviderSearchChip extends StatelessWidget {
  const ProviderSearchChip({
    super.key,
    required this.label,
    required this.statusLabel,
    this.status,
    this.isSelected = false,
    this.focusNode,
    this.onTap,
    this.onDirection,
  });

  final String label;

  /// Short state text: a count, "searching", "none" or "failed".
  final String statusLabel;

  /// `null` for the aggregate chip that stands for every provider.
  final ProviderSearchStatus? status;

  final bool isSelected;
  final FocusNode? focusNode;
  final VoidCallback? onTap;
  final DpadDirectionCallback? onDirection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    final foreground = isSelected
        ? theme.colorScheme.onPrimary
        : tokens.textPrimary;
    final secondary = isSelected
        ? theme.colorScheme.onPrimary.withValues(alpha: 0.8)
        : tokens.textSecondary;

    return TvFocusable(
      focusNode: focusNode,
      onTap: onTap,
      onDirection: onDirection,
      scaleFactor: 1.06,
      borderRadius: tokens.borderRadiusPill,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : tokens.surfaceElevated,
          borderRadius: tokens.borderRadiusPill,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : tokens.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : tokens.shadowColor.withValues(alpha: 0.12),
              blurRadius: isSelected ? 8 : 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _leadingIcon(context, foreground, secondary),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: foreground,
              ),
            ),
            const SizedBox(width: 6),
            _statusBadge(context, foreground, secondary),
          ],
        ),
      ),
    );
  }

  Widget _leadingIcon(BuildContext context, Color foreground, Color secondary) {
    switch (status) {
      case ProviderSearchStatus.searching:
        return SizedBox(
          width: 11,
          height: 11,
          child: CircularProgressIndicator(strokeWidth: 1.6, color: secondary),
        );
      case ProviderSearchStatus.failed:
        return Icon(
          Icons.error_outline_rounded,
          size: 13,
          color: isSelected ? foreground : Theme.of(context).colorScheme.error,
        );
      case ProviderSearchStatus.empty:
        return Icon(Icons.search_off_rounded, size: 13, color: secondary);
      case ProviderSearchStatus.loaded:
      case null:
        return Icon(Icons.live_tv_rounded, size: 13, color: secondary);
    }
  }

  Widget _statusBadge(BuildContext context, Color foreground, Color secondary) {
    final tokens = context.tokens;

    // The spinner already communicates "searching"; a badge next to it would be
    // noise on a 10-foot UI.
    if (status == ProviderSearchStatus.searching) {
      return const SizedBox.shrink();
    }

    final isFailure = status == ProviderSearchStatus.failed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.18)
            : tokens.surfaceCard,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        statusLabel,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: isFailure && !isSelected
              ? Theme.of(context).colorScheme.error
              : foreground,
        ),
      ),
    );
  }
}
