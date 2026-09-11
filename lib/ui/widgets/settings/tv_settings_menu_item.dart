import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';

/// A 10-foot D-Pad focusable settings list item for Android TV.
/// Shows an icon, title, current value pill/badge, and chevron indicator.
class TvSettingsMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? valueText;
  final VoidCallback onTap;
  final bool autofocus;
  final FocusNode? focusNode;

  const TvSettingsMenuItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.valueText,
    required this.onTap,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: tokens.surfaceElevated.withValues(alpha: 0.45),
          borderRadius: tokens.borderRadiusSm,
          border: Border.all(color: tokens.borderSubtle, width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tokens.primaryAccent.withValues(alpha: 0.12),
                borderRadius: tokens.borderRadiusXs,
              ),
              child: Icon(icon, color: tokens.primaryAccent, size: 20),
            ),
            const SizedBox(width: 14),
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
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (valueText != null && valueText!.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: tokens.surfaceCard,
                  borderRadius: tokens.borderRadiusXs,
                  border: Border.all(color: tokens.borderSubtle, width: 0.8),
                ),
                child: Text(
                  valueText!,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: tokens.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
