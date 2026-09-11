import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';

/// A D-Pad focusable switch tile for Android TV and desktop settings.
/// Pressing Select / Enter on the D-Pad or clicking triggers [onChanged].
class TvSettingSwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool autofocus;
  final FocusNode? focusNode;

  const TvSettingSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.value,
    required this.onChanged,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return TvFocusable(
      autofocus: autofocus,
      focusNode: focusNode,
      scaleFactor: 1.02,
      borderRadius: tokens.borderRadiusSm,
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.surfaceElevated.withValues(alpha: 0.4),
          borderRadius: tokens.borderRadiusSm,
          border: Border.all(color: tokens.borderSubtle, width: 0.8),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: value ? tokens.primaryAccent : tokens.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            IgnorePointer(
              child: Switch(
                value: value,
                activeThumbColor: theme.colorScheme.onPrimary,
                activeTrackColor: tokens.primaryAccent,
                inactiveThumbColor: tokens.textMuted,
                inactiveTrackColor: tokens.surfaceCard,
                onChanged: null, // Tap is handled by the enclosing TvFocusable
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A D-Pad focusable action tile for settings navigation, triggers, and dialogs.
class TvSettingActionTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool autofocus;
  final FocusNode? focusNode;

  const TvSettingActionTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return TvFocusable(
      autofocus: autofocus,
      focusNode: focusNode,
      scaleFactor: 1.02,
      borderRadius: tokens.borderRadiusSm,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.surfaceElevated.withValues(alpha: 0.4),
          borderRadius: tokens.borderRadiusSm,
          border: Border.all(color: tokens.borderSubtle, width: 0.8),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: tokens.textSecondary, size: 22),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: tokens.textSecondary,
                  size: 22,
                ),
          ],
        ),
      ),
    );
  }
}
