import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// Fallback error screen displayed when a stream cannot be loaded or played.
class PlayerErrorView extends StatelessWidget {
  final String errorMessage;
  final bool hasAnotherSource;
  final String? nextSourceLabel;
  final VoidCallback? onNextSource;
  final VoidCallback onOpenExternal;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const PlayerErrorView({
    super.key,
    required this.errorMessage,
    required this.hasAnotherSource,
    this.nextSourceLabel,
    this.onNextSource,
    required this.onOpenExternal,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: tokens.canvasBackground,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: tokens.getShapeDecoration(
            color: tokens.surfaceElevated,
            radius: tokens.cardRadius + 4,
            side: BorderSide(color: tokens.borderSubtle),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.errorColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: tokens.errorColor,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Stream Playback Issue',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  if (hasAnotherSource &&
                      nextSourceLabel != null &&
                      onNextSource != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: tokens.shapeSm,
                      ),
                      icon: const Icon(Icons.skip_next_rounded, size: 18),
                      label: Text(
                        nextSourceLabel!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: onNextSource,
                    ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.primaryAccent,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: tokens.shapeSm,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text(
                      'Open in VLC / External Player',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: onOpenExternal,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.textSecondary,
                      side: BorderSide(color: tokens.borderSubtle),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: tokens.shapeSm,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                    onPressed: onRetry,
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.textMuted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: tokens.shapeSm,
                    ),
                    onPressed: onBack,
                    child: const Text('Go Back'),
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
