import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../services/sleep_timer_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tv_focusable.dart';

/// Interactive modal sheet allowing the user to select or cancel a sleep timer.
class PlayerSleepTimerSheet extends StatelessWidget {
  final Duration currentPosition;
  final Duration totalDuration;
  final void Function(Duration duration, String label) onSetTimer;
  final VoidCallback onCancelTimer;

  const PlayerSleepTimerSheet({
    super.key,
    required this.currentPosition,
    required this.totalDuration,
    required this.onSetTimer,
    required this.onCancelTimer,
  });

  static Future<void> show({
    required BuildContext context,
    required Duration currentPosition,
    required Duration totalDuration,
    required void Function(Duration duration, String label) onSetTimer,
    required VoidCallback onCancelTimer,
  }) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: context.tokens.shadowColor.withValues(alpha: 0.85),
        pageBuilder: (ctx, animation, secondaryAnimation) {
          return PlayerSleepTimerSheet(
            currentPosition: currentPosition,
            totalDuration: totalDuration,
            onSetTimer: onSetTimer,
            onCancelTimer: onCancelTimer,
          );
        },
        transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final sleepService = SleepTimerService();
    final isTimerActive = sleepService.isActive;

    final remainingMedia = totalDuration - currentPosition;
    final hasValidRemainingMedia =
        totalDuration > Duration.zero &&
        remainingMedia > const Duration(minutes: 1);

    final presets = <_SleepPreset>[
      const _SleepPreset(label: '15 Minutes', duration: Duration(minutes: 15)),
      const _SleepPreset(label: '30 Minutes', duration: Duration(minutes: 30)),
      const _SleepPreset(label: '45 Minutes', duration: Duration(minutes: 45)),
      const _SleepPreset(label: '60 Minutes', duration: Duration(minutes: 60)),
      const _SleepPreset(label: '90 Minutes', duration: Duration(minutes: 90)),
      if (hasValidRemainingMedia)
        _SleepPreset(
          label: 'End of Media (${remainingMedia.inMinutes}m left)',
          duration: remainingMedia,
          isEndOfMedia: true,
        ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dismiss on backdrop tap
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: const SizedBox.expand(),
          ),

          Center(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: 440,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: tokens.getShapeDecoration(
                  color: tokens.canvasBackground.withValues(alpha: 0.92),
                  radius: tokens.cardRadius * 1.5,
                  side: BorderSide(
                    color: tokens.borderSubtle.withValues(alpha: 0.8),
                    width: 1.2,
                  ),
                  shadows: [
                    BoxShadow(
                      color: tokens.shadowColor.withValues(alpha: 0.6),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: tokens.borderRadiusSm,
                            ),
                            child: Icon(
                              Icons.bedtime_rounded,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SLEEP TIMER',
                                  style: TextStyle(
                                    color: tokens.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                AnimatedBuilder(
                                  animation: sleepService,
                                  builder: (context, _) {
                                    if (isTimerActive) {
                                      return Text(
                                        'Active: ${sleepService.formattedRemaining} remaining',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      );
                                    }
                                    return Text(
                                      'Automatically pause playback when time ends',
                                      style: TextStyle(
                                        color: tokens.textSecondary,
                                        fontSize: 12,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: tokens.textSecondary,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),

                    Divider(
                      height: 1,
                      thickness: 1,
                      color: tokens.borderSubtle.withValues(alpha: 0.4),
                    ),

                    // Presets List
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...presets.map((preset) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TvFocusable(
                                scaleFactor: 1.04,
                                borderRadius: tokens.borderRadiusSm,
                                onTap: () {
                                  onSetTimer(preset.duration, preset.label);
                                  Navigator.of(context).pop();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 13,
                                  ),
                                  decoration: tokens.getShapeDecoration(
                                    color: tokens.surfaceCard.withValues(
                                      alpha: 0.6,
                                    ),
                                    radius: tokens.cardRadius * 0.9,
                                    side: BorderSide(
                                      color: tokens.borderSubtle.withValues(
                                        alpha: 0.7,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        preset.isEndOfMedia
                                            ? Icons.skip_next_rounded
                                            : Icons.timer_outlined,
                                        color: preset.isEndOfMedia
                                            ? theme.colorScheme.tertiary
                                            : tokens.textSecondary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          preset.label,
                                          style: TextStyle(
                                            color: tokens.textPrimary,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: tokens.textMuted,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),

                          // Cancel Option (if active)
                          if (isTimerActive) ...[
                            const SizedBox(height: 4),
                            TvFocusable(
                              scaleFactor: 1.04,
                              borderRadius: tokens.borderRadiusSm,
                              onTap: () {
                                onCancelTimer();
                                Navigator.of(context).pop();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: tokens.getShapeDecoration(
                                  color: theme.colorScheme.error.withValues(
                                    alpha: 0.12,
                                  ),
                                  radius: tokens.cardRadius * 0.9,
                                  side: BorderSide(
                                    color: theme.colorScheme.error.withValues(
                                      alpha: 0.4,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.timer_off_rounded,
                                      color: theme.colorScheme.error,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Turn Off Sleep Timer',
                                      style: TextStyle(
                                        color: theme.colorScheme.error,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepPreset {
  final String label;
  final Duration duration;
  final bool isEndOfMedia;

  const _SleepPreset({
    required this.label,
    required this.duration,
    this.isEndOfMedia = false,
  });
}
