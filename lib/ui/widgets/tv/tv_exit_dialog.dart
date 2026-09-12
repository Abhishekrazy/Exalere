import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';
import 'tv_popup_scope.dart';

/// Exit confirmation dialog for TV and desktop interface.
/// Displays exactly two buttons: "Cancel" and "Exit".
class TvExitDialog extends StatelessWidget {
  const TvExitDialog({super.key});

  /// Shows the TV exit confirmation dialog.
  static Future<bool?> show(BuildContext context) {
    final tokens = context.tokens;
    return showDialog<bool>(
      context: context,
      barrierColor: tokens.shadowColor.withValues(alpha: 0.7),
      builder: (ctx) => const TvExitDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return TvPopupScope(
      child: Dialog(
        backgroundColor: tokens.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: tokens.borderRadiusMd,
          side: BorderSide(color: tokens.borderSubtle, width: 1),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title with Icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tokens.primaryAccent.withValues(alpha: 0.15),
                      borderRadius: tokens.borderRadiusSm,
                    ),
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      color: tokens.primaryAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Exit Exalere',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Are you sure you want to exit the application?',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Two Action Buttons: Cancel and Exit
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 1. Cancel (Autofocused for safety)
                  TvFocusable(
                    autofocus: true,
                    scaleFactor: 1.05,
                    borderRadius: tokens.borderRadiusSm,
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceCard,
                        borderRadius: tokens.borderRadiusSm,
                        border: Border.all(
                          color: tokens.borderSubtle,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 2. Exit Button
                  TvFocusable(
                    scaleFactor: 1.05,
                    borderRadius: tokens.borderRadiusSm,
                    onTap: () {
                      Navigator.of(context).pop(true);
                      SystemNavigator.pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.primaryAccent,
                        borderRadius: tokens.borderRadiusSm,
                        boxShadow: [
                          BoxShadow(
                            color: tokens.primaryAccent.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.exit_to_app_rounded,
                            size: 16,
                            color: theme.colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Exit',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
