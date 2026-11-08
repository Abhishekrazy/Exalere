import 'package:flutter/material.dart';

import '../../../services/sleep_timer_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tv/tv_popup_scope.dart';
import '../../widgets/tv_focusable.dart';

/// The "Video" door on the TV player bar.
///
/// Every adjustment that shapes the picture — aspect, calibration, speed and the
/// stats HUD — used to be its own pill, which made the bar an eleven-pill
/// horizontal scroller where anything past the sixth was unreachable with a
/// D-pad. One row per adjustment keeps them discoverable in two presses.
class PlayerVideoSheet extends StatelessWidget {
  const PlayerVideoSheet({
    super.key,
    required this.videoFit,
    required this.playbackSpeed,
    required this.isStatsVisible,
    required this.onToggleAspectRatio,
    this.onOpenPictureTuner,
    this.onSelectSpeed,
    this.onToggleStatsOverlay,
    this.isLive = false,
  });

  final BoxFit videoFit;
  final double playbackSpeed;
  final bool isStatsVisible;
  final VoidCallback onToggleAspectRatio;
  final VoidCallback? onOpenPictureTuner;
  final VoidCallback? onSelectSpeed;
  final VoidCallback? onToggleStatsOverlay;
  final bool isLive;

  static Future<void> show(
    BuildContext context, {
    required BoxFit videoFit,
    required double playbackSpeed,
    required bool isStatsVisible,
    required VoidCallback onToggleAspectRatio,
    VoidCallback? onOpenPictureTuner,
    VoidCallback? onSelectSpeed,
    VoidCallback? onToggleStatsOverlay,
    bool isLive = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PlayerVideoSheet(
        videoFit: videoFit,
        playbackSpeed: playbackSpeed,
        isStatsVisible: isStatsVisible,
        onToggleAspectRatio: onToggleAspectRatio,
        onOpenPictureTuner: onOpenPictureTuner,
        onSelectSpeed: onSelectSpeed,
        onToggleStatsOverlay: onToggleStatsOverlay,
        isLive: isLive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isCover = videoFit == BoxFit.cover;
    final speedLabel =
        '${playbackSpeed.toStringAsFixed(playbackSpeed.truncateToDouble() == playbackSpeed ? 1 : 2)}x';

    return TvPopupScope(
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          decoration: tokens.getShapeDecoration(
            color: tokens.surfaceElevated,
            radius: tokens.cardRadius + 8,
            side: BorderSide(color: tokens.borderSubtle),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    color: tokens.primaryAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Video',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _VideoSheetRow(
                      icon: isCover
                          ? Icons.fit_screen_rounded
                          : Icons.aspect_ratio_rounded,
                      title: 'Aspect ratio',
                      value: isCover ? 'Cover' : 'Fit',
                      autofocus: true,
                      onTap: onToggleAspectRatio,
                    ),
                    if (onOpenPictureTuner != null)
                      _VideoSheetRow(
                        icon: Icons.photo_filter_rounded,
                        title: 'Picture tuner',
                        value: 'Open',
                        onTap: onOpenPictureTuner!,
                      ),
                    if (!isLive && onSelectSpeed != null)
                      _VideoSheetRow(
                        icon: Icons.speed_rounded,
                        title: 'Playback speed',
                        value: speedLabel,
                        onTap: onSelectSpeed!,
                      ),
                    if (onToggleStatsOverlay != null)
                      _VideoSheetRow(
                        icon: Icons.query_stats_rounded,
                        title: 'Stats for nerds',
                        value: isStatsVisible ? 'On' : 'Off',
                        onTap: onToggleStatsOverlay!,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Extras" door on the TV player bar.
///
/// Session-level actions that are useful occasionally and never urgent: a sleep
/// timer and a watch party. Both were pills; neither needs to be on the bar.
class PlayerExtrasSheet extends StatelessWidget {
  const PlayerExtrasSheet({
    super.key,
    this.onOpenSleepTimer,
    this.onOpenWatchParty,
    this.onOpenAudioTuner,
    this.onToggleAudioOnly,
    this.isAudioOnly = false,
  });

  final VoidCallback? onOpenSleepTimer;
  final VoidCallback? onOpenWatchParty;
  final VoidCallback? onOpenAudioTuner;
  final VoidCallback? onToggleAudioOnly;
  final bool isAudioOnly;

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onOpenSleepTimer,
    VoidCallback? onOpenWatchParty,
    VoidCallback? onOpenAudioTuner,
    VoidCallback? onToggleAudioOnly,
    bool isAudioOnly = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PlayerExtrasSheet(
        onOpenSleepTimer: onOpenSleepTimer,
        onOpenWatchParty: onOpenWatchParty,
        onOpenAudioTuner: onOpenAudioTuner,
        onToggleAudioOnly: onToggleAudioOnly,
        isAudioOnly: isAudioOnly,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return TvPopupScope(
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          decoration: tokens.getShapeDecoration(
            color: tokens.surfaceElevated,
            radius: tokens.cardRadius + 8,
            side: BorderSide(color: tokens.borderSubtle),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.more_horiz_rounded,
                    color: tokens.primaryAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Extras',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (onOpenSleepTimer != null)
                      AnimatedBuilder(
                        animation: SleepTimerService(),
                        builder: (context, _) {
                          final active = SleepTimerService().isActive;
                          return _VideoSheetRow(
                            icon: active
                                ? Icons.bedtime_rounded
                                : Icons.bedtime_outlined,
                            title: 'Sleep timer',
                            value: active
                                ? SleepTimerService().formattedRemaining
                                : 'Off',
                            autofocus: true,
                            highlighted: active,
                            onTap: onOpenSleepTimer!,
                          );
                        },
                      ),
                    if (onOpenWatchParty != null)
                      _VideoSheetRow(
                        icon: Icons.groups_rounded,
                        title: 'Watch party',
                        value: 'LAN',
                        autofocus: onOpenSleepTimer == null,
                        onTap: onOpenWatchParty!,
                      ),
                    // Audio output adjustments live here until the Audio sheet
                    // grows its own rows (tracked in Kanban task 3). They must
                    // not go back to being pills on the bar.
                    if (onOpenAudioTuner != null ||
                        onToggleAudioOnly != null) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'AUDIO OUTPUT',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                    if (onOpenAudioTuner != null)
                      _VideoSheetRow(
                        icon: Icons.equalizer_rounded,
                        title: 'Equalizer & clarity',
                        value: 'Open',
                        autofocus:
                            onOpenSleepTimer == null &&
                            onOpenWatchParty == null,
                        onTap: onOpenAudioTuner!,
                      ),
                    if (onToggleAudioOnly != null)
                      _VideoSheetRow(
                        icon: Icons.music_note_rounded,
                        title: 'Audio-only mode',
                        value: isAudioOnly ? 'On' : 'Off',
                        highlighted: isAudioOnly,
                        onTap: onToggleAudioOnly!,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row inside a category sheet: icon, title, current value, and a chevron.
class _VideoSheetRow extends StatelessWidget {
  const _VideoSheetRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.autofocus = false,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool autofocus;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final accent = highlighted ? tokens.primaryAccent : tokens.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TvFocusable(
        autofocus: autofocus,
        borderRadius: tokens.borderRadiusSm,
        scaleFactor: 1.02,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: tokens.getShapeDecoration(
            color: tokens.surfaceCard.withValues(alpha: 0.6),
            radius: tokens.cardRadius * 0.6,
            side: BorderSide(color: tokens.borderSubtle),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: highlighted ? tokens.primaryAccent : tokens.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
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
  }
}
