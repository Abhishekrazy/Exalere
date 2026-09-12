import 'package:flutter/material.dart';

import '../../../models/media_details.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tv_focusable.dart';

/// Floating Gesture HUD overlays (Brightness, Volume, Double-Tap Seek,
/// Skip Intro/Outro button, and Resume banner)
class PlayerGestureHud extends StatelessWidget {
  final bool isTv;
  final bool isControlsLocked;
  final bool showBrightnessIndicator;
  final double brightness;
  final bool showVolumeIndicator;
  final double volume;
  final int? doubleTapSeekDirection;
  final bool showControls;
  final SkipInterval? activeSkip;
  final VoidCallback onTriggerSkip;
  final bool showResumeBanner;
  final int resumedFromSeconds;
  final VoidCallback onRestartPlayback;
  final VoidCallback onDismissResumeBanner;
  final String Function(Duration) formatDuration;
  final bool showUnlockButton;
  final VoidCallback onUnlockControls;

  const PlayerGestureHud({
    super.key,
    required this.isTv,
    required this.isControlsLocked,
    required this.showBrightnessIndicator,
    required this.brightness,
    required this.showVolumeIndicator,
    required this.volume,
    this.doubleTapSeekDirection,
    required this.showControls,
    this.activeSkip,
    required this.onTriggerSkip,
    required this.showResumeBanner,
    required this.resumedFromSeconds,
    required this.onRestartPlayback,
    required this.onDismissResumeBanner,
    required this.formatDuration,
    required this.showUnlockButton,
    required this.onUnlockControls,
  });

  Widget _buildVerticalBarHud({
    required BuildContext context,
    required IconData icon,
    required double value,
    required String label,
    required ThemeData theme,
  }) {
    final tokens = context.tokens;
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: tokens.getShapeDecoration(
          color: tokens.surfaceElevated.withValues(alpha: 0.85),
          radius: tokens.cardRadius * 1.5,
          side: BorderSide(color: tokens.borderSubtle, width: 1),
          shadows: [
            BoxShadow(
              color: tokens.shadowColor.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(height: 10),
            Container(
              width: 5,
              height: 90,
              decoration: BoxDecoration(
                color: tokens.borderSubtle.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  FractionallySizedBox(
                    heightFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Stack(
      children: [
        // 1. Center Double-Tap Seek Pill Ripple
        if (doubleTapSeekDirection != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  decoration: tokens.getShapeDecoration(
                    color: tokens.canvasBackground.withValues(alpha: 0.85),
                    radius: tokens.cardRadius * 2,
                    side: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                    shadows: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.35,
                        ),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (doubleTapSeekDirection! < 0) ...[
                        Icon(
                          Icons.fast_rewind_rounded,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '10s',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ] else ...[
                        Text(
                          '10s',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.fast_forward_rounded,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 2. Brightness HUD (Left)
        if (!isTv && !isControlsLocked && showBrightnessIndicator)
          Positioned(
            left: 36,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildVerticalBarHud(
                context: context,
                icon: brightness > 0.6
                    ? Icons.wb_sunny_rounded
                    : (brightness > 0.25
                          ? Icons.brightness_medium_rounded
                          : Icons.brightness_low_rounded),
                value: brightness,
                label: '${(brightness * 100).round()}%',
                theme: theme,
              ),
            ),
          ),

        // 3. Volume HUD (Right)
        if (!isTv && !isControlsLocked && showVolumeIndicator)
          Positioned(
            right: 36,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildVerticalBarHud(
                context: context,
                icon: volume == 0
                    ? Icons.volume_off_rounded
                    : (volume < 0.5
                          ? Icons.volume_down_rounded
                          : Icons.volume_up_rounded),
                value: volume,
                label: '${(volume * 100).round()}%',
                theme: theme,
              ),
            ),
          ),

        // 4. Floating Unlock Controls Button (when locked)
        if (isControlsLocked && showUnlockButton && !isTv)
          Positioned.fill(
            child: Center(
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 200),
                tween: Tween<double>(begin: 0.8, end: 1.0),
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: InkWell(
                  onTap: onUnlockControls,
                  borderRadius: tokens.borderRadiusPill,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    decoration: tokens.getShapeDecoration(
                      color: tokens.canvasBackground.withValues(alpha: 0.9),
                      radius: tokens.cardRadius * 2,
                      side: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1.5,
                      ),
                      shadows: [
                        BoxShadow(
                          color: tokens.shadowColor.withValues(alpha: 0.6),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_open_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tap to Unlock Controls',
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
              ),
            ),
          ),

        // 5. Floating Skip Intro / Outro Button
        if (activeSkip != null)
          Positioned(
            bottom: showControls ? 116 : 42,
            right: 24,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Material(
                color: Colors.transparent,
                child: isTv
                    ? TvFocusable(
                        autofocus: true,
                        scaleFactor: 1.08,
                        shape: tokens.shapeSm,
                        borderRadius: tokens.borderRadiusSm,
                        onTap: onTriggerSkip,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: tokens.getShapeDecoration(
                            color: tokens.canvasBackground.withValues(
                              alpha: 0.88,
                            ),
                            radius: tokens.cardRadius * 0.7,
                            side: BorderSide(
                              color: tokens.textPrimary,
                              width: 1.5,
                            ),
                            shadows: [
                              BoxShadow(
                                color: tokens.shadowColor.withValues(
                                  alpha: 0.7,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                activeSkip!.label,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.fast_forward_rounded,
                                color: tokens.textPrimary,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      )
                    : InkWell(
                        onTap: onTriggerSkip,
                        borderRadius: tokens.borderRadiusSm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: tokens.getShapeDecoration(
                            color: tokens.canvasBackground.withValues(
                              alpha: 0.88,
                            ),
                            radius: tokens.cardRadius * 0.7,
                            side: BorderSide(
                              color: tokens.textPrimary,
                              width: 1.5,
                            ),
                            shadows: [
                              BoxShadow(
                                color: tokens.shadowColor.withValues(
                                  alpha: 0.7,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                activeSkip!.label,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.fast_forward_rounded,
                                color: tokens.textPrimary,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),

        // 6. Floating Resume Banner Toast
        if (showResumeBanner && resumedFromSeconds > 0)
          Positioned(
            bottom: showControls ? 110 : 36,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: tokens.getShapeDecoration(
                  color: tokens.canvasBackground.withValues(alpha: 0.85),
                  radius: tokens.cardRadius * 2,
                  side: BorderSide(color: tokens.borderSubtle),
                  shadows: [
                    BoxShadow(
                      color: tokens.shadowColor.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      color: tokens.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Resumed at ${formatDuration(Duration(seconds: resumedFromSeconds))}',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: onRestartPlayback,
                      borderRadius: tokens.borderRadiusPill,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: tokens.getShapeDecoration(
                          color: theme.colorScheme.primary,
                          radius: tokens.cardRadius * 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.replay_rounded,
                              size: 14,
                              color: theme.colorScheme.onPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Restart',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onDismissResumeBanner,
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: tokens.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
