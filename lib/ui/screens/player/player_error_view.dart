import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/tv_focusable.dart';

/// Fallback error screen displayed when a stream cannot be loaded or played.
class PlayerErrorView extends StatelessWidget {
  final String errorMessage;
  final bool hasAnotherSource;
  final String? nextSourceLabel;
  final VoidCallback? onNextSource;
  final VoidCallback? onSelectServer;
  final VoidCallback onOpenExternal;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const PlayerErrorView({
    super.key,
    required this.errorMessage,
    required this.hasAnotherSource,
    this.nextSourceLabel,
    this.onNextSource,
    this.onSelectServer,
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
                  // 1. Next Source Button
                  if (hasAnotherSource &&
                      nextSourceLabel != null &&
                      onNextSource != null)
                    TvFocusable(
                      scaleFactor: 1.05,
                      shape: tokens.shapeSm,
                      borderRadius: tokens.borderRadiusSm,
                      onTap: onNextSource!,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: tokens.getShapeDecoration(
                          color: theme.colorScheme.primary,
                          radius: tokens.cardRadius * 0.7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.skip_next_rounded,
                              size: 18,
                              color: theme.colorScheme.onPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              nextSourceLabel!,
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 2. Change Server Button
                  if (onSelectServer != null)
                    TvFocusable(
                      scaleFactor: 1.05,
                      shape: tokens.shapeSm,
                      borderRadius: tokens.borderRadiusSm,
                      onTap: onSelectServer!,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: tokens.getShapeDecoration(
                          color: tokens.surfaceCard,
                          radius: tokens.cardRadius * 0.7,
                          side: BorderSide(color: tokens.borderSubtle),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.dns_rounded,
                              size: 18,
                              color: tokens.textPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Change Server',
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 3. Retry Button (Autofocused)
                  TvFocusable(
                    autofocus: true,
                    scaleFactor: 1.05,
                    shape: tokens.shapeSm,
                    borderRadius: tokens.borderRadiusSm,
                    onTap: onRetry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: tokens.getShapeDecoration(
                        color: hasAnotherSource
                            ? tokens.surfaceCard
                            : theme.colorScheme.primary,
                        radius: tokens.cardRadius * 0.7,
                        side: BorderSide(color: tokens.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: hasAnotherSource
                                ? tokens.textPrimary
                                : theme.colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Retry',
                            style: TextStyle(
                              color: hasAnotherSource
                                  ? tokens.textPrimary
                                  : theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. External Player Button
                  TvFocusable(
                    scaleFactor: 1.05,
                    shape: tokens.shapeSm,
                    borderRadius: tokens.borderRadiusSm,
                    onTap: onOpenExternal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: tokens.getShapeDecoration(
                        color: tokens.surfaceCard,
                        radius: tokens.cardRadius * 0.7,
                        side: BorderSide(color: tokens.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 18,
                            color: tokens.textPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Open in VLC / External Player',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. Back Button
                  TvFocusable(
                    scaleFactor: 1.05,
                    shape: tokens.shapeSm,
                    borderRadius: tokens.borderRadiusSm,
                    onTap: onBack,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: tokens.getShapeDecoration(
                        color: tokens.surfaceCard,
                        radius: tokens.cardRadius * 0.7,
                        side: BorderSide(color: tokens.borderSubtle),
                      ),
                      child: Text(
                        'Go Back',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
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
