import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/tv/tv_popup_scope.dart';
import '../../widgets/tv_focusable.dart';

/// Pre-configured audio filter presets for MPV.
enum AudioFilterPreset {
  flat(
    label: 'Flat / Original',
    description: 'Direct audio pass-through without filtering',
    mpvFilter: '',
    icon: Icons.music_note_rounded,
  ),
  nightMode(
    label: 'Night Mode (Dynamic Normalizer)',
    description: 'Compresses loud spikes & elevates whispers',
    mpvFilter: 'lavfi=[dynaudnorm=f=150:g=15]',
    icon: Icons.nightlight_round,
  ),
  dialogBoost(
    label: 'Dialog Clarity Boost',
    description: 'Elevates center-channel vocal frequencies (2.5 kHz)',
    mpvFilter: 'lavfi=[equalizer=f=2500:t=q:w=1:g=8,highpass=f=200]',
    icon: Icons.record_voice_over_rounded,
  ),
  bassBoost(
    label: 'Cinematic Bass Boost',
    description: 'Enriches low-end rumble for action & music',
    mpvFilter: 'lavfi=[bass=g=7]',
    icon: Icons.speaker_rounded,
  ),
  lateNightWhisper(
    label: 'Late Night Whisper',
    description: 'Maximum vocal compression with gentle boost',
    mpvFilter: 'lavfi=[dynaudnorm=f=100:g=25,volume=volume=1.6]',
    icon: Icons.hearing_rounded,
  );

  final String label;
  final String description;
  final String mpvFilter;
  final IconData icon;

  const AudioFilterPreset({
    required this.label,
    required this.description,
    required this.mpvFilter,
    required this.icon,
  });
}

/// Modal bottom sheet or dialog offering audio EQ presets and volume pre-amp boost.
class PlayerAudioTunerSheet extends StatefulWidget {
  final AudioFilterPreset initialPreset;
  final double initialVolumeBoost; // 100% to 200%
  final Function(AudioFilterPreset preset, double volumeBoost) onApply;

  const PlayerAudioTunerSheet({
    super.key,
    required this.initialPreset,
    required this.initialVolumeBoost,
    required this.onApply,
  });

  static Future<void> show({
    required BuildContext context,
    required AudioFilterPreset currentPreset,
    required double currentVolumeBoost,
    required Function(AudioFilterPreset preset, double volumeBoost) onApply,
  }) {
    final tokens = context.tokens;
    final isTv = MediaQuery.of(context).size.width > 900;

    if (isTv) {
      return showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: tokens.shadowColor.withValues(alpha: 0.85),
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: SizedBox(
            width: 580,
            child: TvPopupScope(
              child: PlayerAudioTunerSheet(
                initialPreset: currentPreset,
                initialVolumeBoost: currentVolumeBoost,
                onApply: onApply,
              ),
            ),
          ),
        ),
      );
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TvPopupScope(
        child: PlayerAudioTunerSheet(
          initialPreset: currentPreset,
          initialVolumeBoost: currentVolumeBoost,
          onApply: onApply,
        ),
      ),
    );
  }

  @override
  State<PlayerAudioTunerSheet> createState() => _PlayerAudioTunerSheetState();
}

class _PlayerAudioTunerSheetState extends State<PlayerAudioTunerSheet> {
  late AudioFilterPreset _selectedPreset;
  late double _volumeBoost;

  @override
  void initState() {
    super.initState();
    _selectedPreset = widget.initialPreset;
    _volumeBoost = widget.initialVolumeBoost;
  }

  void _selectPreset(AudioFilterPreset preset) {
    setState(() => _selectedPreset = preset);
    widget.onApply(_selectedPreset, _volumeBoost);
  }

  void _updateVolumeBoost(double boost) {
    final clamped = boost.clamp(100.0, 200.0);
    setState(() => _volumeBoost = clamped);
    widget.onApply(_selectedPreset, _volumeBoost);
  }

  void _increaseBoost() {
    _updateVolumeBoost((_volumeBoost + 10.0).clamp(100.0, 200.0));
  }

  void _decreaseBoost() {
    _updateVolumeBoost((_volumeBoost - 10.0).clamp(100.0, 200.0));
  }

  void _resetBoost() {
    _updateVolumeBoost(100.0);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final isTv = MediaQuery.of(context).size.width > 900;

    return TvPopupScope(
      child: ClipRRect(
        borderRadius: isTv
            ? tokens.borderRadiusLg
            : const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceElevated.withValues(alpha: 0.95),
              radius: tokens.cardRadius * 1.5,
              side: BorderSide(
                color: tokens.borderFocus.withValues(alpha: 0.5),
                width: 1.2,
              ),
              shadows: [
                BoxShadow(
                  color: tokens.shadowColor.withValues(alpha: 0.5),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.graphic_eq_rounded,
                                color: tokens.primaryAccent,
                                size: 26,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'Audio Equalizer & Clarity',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TvFocusable(
                          onTap: () => Navigator.of(context).pop(),
                          scaleFactor: 1.1,
                          borderRadius: tokens.borderRadiusSm,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: tokens.surfaceCard,
                              borderRadius: tokens.borderRadiusSm,
                              border: Border.all(color: tokens.borderSubtle),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: tokens.textSecondary,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Volume Pre-Amp Boost Slider & Steppers
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: tokens.surfaceCard,
                        borderRadius: tokens.borderRadiusMd,
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.volume_up_rounded,
                                      size: 18,
                                      color: tokens.primaryAccent,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Pre-Amp Volume Booster',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: tokens.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${_volumeBoost.round()}%',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: tokens.primaryAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: theme.colorScheme.primary,
                              inactiveTrackColor: tokens.borderSubtle,
                              thumbColor: theme.colorScheme.primary,
                            ),
                            child: Slider(
                              value: _volumeBoost,
                              min: 100.0,
                              max: 200.0,
                              divisions: 10,
                              label: '${_volumeBoost.round()}%',
                              onChanged: _updateVolumeBoost,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Remote D-Pad Stepper Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TvFocusable(
                                borderRadius: tokens.borderRadiusXs,
                                onKeyEvent: (node, event) {
                                  if (event is! KeyDownEvent) {
                                    return KeyEventResult.ignored;
                                  }
                                  if (event.logicalKey ==
                                      LogicalKeyboardKey.arrowLeft) {
                                    _decreaseBoost();
                                    return KeyEventResult.handled;
                                  }
                                  return KeyEventResult.ignored;
                                },
                                onTap: _decreaseBoost,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.surfaceElevated,
                                    borderRadius: tokens.borderRadiusXs,
                                    border: Border.all(
                                      color: tokens.borderSubtle,
                                    ),
                                  ),
                                  child: Text(
                                    '-10%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TvFocusable(
                                borderRadius: tokens.borderRadiusXs,
                                onTap: _resetBoost,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.surfaceElevated,
                                    borderRadius: tokens.borderRadiusXs,
                                    border: Border.all(
                                      color: tokens.borderSubtle,
                                    ),
                                  ),
                                  child: Text(
                                    'Reset (100%)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _volumeBoost > 100.0
                                          ? theme.colorScheme.primary
                                          : tokens.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TvFocusable(
                                borderRadius: tokens.borderRadiusXs,
                                onKeyEvent: (node, event) {
                                  if (event is! KeyDownEvent) {
                                    return KeyEventResult.ignored;
                                  }
                                  if (event.logicalKey ==
                                      LogicalKeyboardKey.arrowRight) {
                                    _increaseBoost();
                                    return KeyEventResult.handled;
                                  }
                                  return KeyEventResult.ignored;
                                },
                                onTap: _increaseBoost,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.surfaceElevated,
                                    borderRadius: tokens.borderRadiusXs,
                                    border: Border.all(
                                      color: tokens.borderSubtle,
                                    ),
                                  ),
                                  child: Text(
                                    '+10%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // EQ Presets List
                    Text(
                      'Acoustic Profiles',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Column(
                      children: AudioFilterPreset.values.map((preset) {
                        final isSelected = _selectedPreset == preset;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TvFocusable(
                            autofocus: isSelected,
                            scaleFactor: 1.02,
                            borderRadius: tokens.borderRadiusSm,
                            onTap: () => _selectPreset(preset),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.18,
                                      )
                                    : tokens.surfaceCard,
                                borderRadius: tokens.borderRadiusSm,
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : tokens.borderSubtle,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    preset.icon,
                                    size: 20,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : tokens.textSecondary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          preset.label,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? tokens.textPrimary
                                                : tokens.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          preset.description,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: tokens.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                      color: theme.colorScheme.primary,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
