import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/tv/tv_popup_scope.dart';
import '../../widgets/tv_focusable.dart';

/// Predefined picture tuning profiles for quick video calibration.
enum PicturePreset {
  standard('Standard', 0, 0, 0, 0, Icons.tv_rounded),
  cinema('Cinema Warm', 0, 6, 8, 0, Icons.movie_filter_rounded),
  vivid('Vivid OLED', 4, 14, 18, -2, Icons.auto_awesome_rounded),
  shadowBoost('Shadow Boost', 14, 6, 0, 16, Icons.brightness_medium_rounded),
  highContrast('High Contrast', -6, 16, 4, -6, Icons.contrast_rounded);

  final String label;
  final int brightness;
  final int contrast;
  final int saturation;
  final int gamma;
  final IconData icon;

  const PicturePreset(
    this.label,
    this.brightness,
    this.contrast,
    this.saturation,
    this.gamma,
    this.icon,
  );
}

/// Semi-transparent in-player picture tuner bottom sheet allowing real-time
/// adjustment of video brightness, contrast, saturation, and gamma.
class PlayerPictureTunerSheet extends StatefulWidget {
  final int initialBrightness;
  final int initialContrast;
  final int initialSaturation;
  final int initialGamma;
  final void Function(int brightness, int contrast, int saturation, int gamma)
  onChanged;

  const PlayerPictureTunerSheet({
    super.key,
    required this.initialBrightness,
    required this.initialContrast,
    required this.initialSaturation,
    required this.initialGamma,
    required this.onChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required int initialBrightness,
    required int initialContrast,
    required int initialSaturation,
    required int initialGamma,
    required void Function(
      int brightness,
      int contrast,
      int saturation,
      int gamma,
    )
    onChanged,
  }) {
    final tokens = context.tokens;
    final isTv = MediaQuery.of(context).size.width > 900;

    if (isTv) {
      return showDialog<void>(
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
              child: PlayerPictureTunerSheet(
                initialBrightness: initialBrightness,
                initialContrast: initialContrast,
                initialSaturation: initialSaturation,
                initialGamma: initialGamma,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      );
    }

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => TvPopupScope(
        child: PlayerPictureTunerSheet(
          initialBrightness: initialBrightness,
          initialContrast: initialContrast,
          initialSaturation: initialSaturation,
          initialGamma: initialGamma,
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  State<PlayerPictureTunerSheet> createState() =>
      _PlayerPictureTunerSheetState();
}

class _PlayerPictureTunerSheetState extends State<PlayerPictureTunerSheet> {
  late int _brightness;
  late int _contrast;
  late int _saturation;
  late int _gamma;

  @override
  void initState() {
    super.initState();
    _brightness = widget.initialBrightness;
    _contrast = widget.initialContrast;
    _saturation = widget.initialSaturation;
    _gamma = widget.initialGamma;
  }

  PicturePreset? get _currentPreset {
    for (final p in PicturePreset.values) {
      if (_brightness == p.brightness &&
          _contrast == p.contrast &&
          _saturation == p.saturation &&
          _gamma == p.gamma) {
        return p;
      }
    }
    return null;
  }

  void _apply(int b, int c, int s, int g) {
    setState(() {
      _brightness = b.clamp(-100, 100);
      _contrast = c.clamp(-100, 100);
      _saturation = s.clamp(-100, 100);
      _gamma = g.clamp(-100, 100);
    });
    widget.onChanged(_brightness, _contrast, _saturation, _gamma);
  }

  void _applyPreset(PicturePreset preset) {
    _apply(preset.brightness, preset.contrast, preset.saturation, preset.gamma);
  }

  void _resetAll() {
    _apply(0, 0, 0, 0);
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
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: tokens.surfaceElevated.withValues(alpha: 0.95),
              borderRadius: isTv
                  ? tokens.borderRadiusLg
                  : const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(
                color: tokens.borderFocus.withValues(alpha: 0.5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: tokens.shadowColor.withValues(alpha: 0.5),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
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
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: tokens.primaryAccent.withValues(
                                    alpha: 0.15,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  color: tokens.primaryAccent,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'Video Picture Tuner',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: tokens.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TvFocusable(
                              borderRadius: tokens.borderRadiusPill,
                              onTap: _resetAll,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.surfaceElevated,
                                  borderRadius: tokens.borderRadiusPill,
                                  border: Border.all(
                                    color: tokens.borderSubtle,
                                  ),
                                ),
                                child: Text(
                                  'Reset All',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: tokens.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TvFocusable(
                              borderRadius: tokens.borderRadiusPill,
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: tokens.surfaceElevated,
                                  shape: BoxShape.circle,
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
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Presets Shelf
                    SizedBox(
                      height: 48,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: Row(
                          children: [
                            for (
                              int index = 0;
                              index < PicturePreset.values.length;
                              index++
                            ) ...[
                              if (index > 0) const SizedBox(width: 8),
                              Builder(
                                builder: (context) {
                                  final preset = PicturePreset.values[index];
                                  final isSelected =
                                      _brightness == preset.brightness &&
                                      _contrast == preset.contrast &&
                                      _saturation == preset.saturation &&
                                      _gamma == preset.gamma;
                                  final isDefaultFocus =
                                      isSelected ||
                                      (_currentPreset == null &&
                                          preset == PicturePreset.standard);

                                  return TvFocusable(
                                    autofocus: isDefaultFocus,
                                    borderRadius: tokens.borderRadiusPill,
                                    onTap: () => _applyPreset(preset),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : tokens.surfaceElevated,
                                        borderRadius: tokens.borderRadiusPill,
                                        border: Border.all(
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : tokens.borderSubtle,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            preset.icon,
                                            size: 15,
                                            color: isSelected
                                                ? theme.colorScheme.onPrimary
                                                : tokens.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            preset.label,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? theme.colorScheme.onPrimary
                                                  : tokens.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sliders & Steppers
                    _buildControlRow(
                      context,
                      label: 'Brightness',
                      value: _brightness,
                      min: -50,
                      max: 50,
                      icon: Icons.light_mode_rounded,
                      onDecrease: () => _apply(
                        _brightness - 5,
                        _contrast,
                        _saturation,
                        _gamma,
                      ),
                      onIncrease: () => _apply(
                        _brightness + 5,
                        _contrast,
                        _saturation,
                        _gamma,
                      ),
                      onReset: () => _apply(0, _contrast, _saturation, _gamma),
                    ),
                    const SizedBox(height: 10),
                    _buildControlRow(
                      context,
                      label: 'Contrast',
                      value: _contrast,
                      min: -50,
                      max: 50,
                      icon: Icons.contrast_rounded,
                      onDecrease: () => _apply(
                        _brightness,
                        _contrast - 5,
                        _saturation,
                        _gamma,
                      ),
                      onIncrease: () => _apply(
                        _brightness,
                        _contrast + 5,
                        _saturation,
                        _gamma,
                      ),
                      onReset: () =>
                          _apply(_brightness, 0, _saturation, _gamma),
                    ),
                    const SizedBox(height: 10),
                    _buildControlRow(
                      context,
                      label: 'Saturation',
                      value: _saturation,
                      min: -50,
                      max: 50,
                      icon: Icons.palette_outlined,
                      onDecrease: () => _apply(
                        _brightness,
                        _contrast,
                        _saturation - 5,
                        _gamma,
                      ),
                      onIncrease: () => _apply(
                        _brightness,
                        _contrast,
                        _saturation + 5,
                        _gamma,
                      ),
                      onReset: () => _apply(_brightness, _contrast, 0, _gamma),
                    ),
                    const SizedBox(height: 10),
                    _buildControlRow(
                      context,
                      label: 'Gamma (Shadows)',
                      value: _gamma,
                      min: -50,
                      max: 50,
                      icon: Icons.tonality_rounded,
                      onDecrease: () => _apply(
                        _brightness,
                        _contrast,
                        _saturation,
                        _gamma - 5,
                      ),
                      onIncrease: () => _apply(
                        _brightness,
                        _contrast,
                        _saturation,
                        _gamma + 5,
                      ),
                      onReset: () =>
                          _apply(_brightness, _contrast, _saturation, 0),
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

  Widget _buildControlRow(
    BuildContext context, {
    required String label,
    required int value,
    required int min,
    required int max,
    required IconData icon,
    required VoidCallback onDecrease,
    required VoidCallback onIncrease,
    required VoidCallback onReset,
  }) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final isModified = value != 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated.withValues(alpha: 0.5),
        borderRadius: tokens.borderRadiusSm,
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isModified
                ? theme.colorScheme.primary
                : tokens.textSecondary,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
          ),
          Text(
            value > 0 ? '+$value' : '$value',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isModified
                  ? theme.colorScheme.primary
                  : tokens.textSecondary,
            ),
          ),
          const Spacer(),
          // Stepper Buttons: [-5] [Reset] [+5]
          TvFocusable(
            borderRadius: tokens.borderRadiusXs,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                onDecrease();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            onTap: onDecrease,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: tokens.borderRadiusXs,
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Text(
                '-5',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: tokens.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          TvFocusable(
            borderRadius: tokens.borderRadiusXs,
            onTap: onReset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: tokens.borderRadiusXs,
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Icon(
                Icons.refresh_rounded,
                size: 14,
                color: isModified
                    ? theme.colorScheme.primary
                    : tokens.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 6),
          TvFocusable(
            borderRadius: tokens.borderRadiusXs,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                onIncrease();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            onTap: onIncrease,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: tokens.borderRadiusXs,
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Text(
                '+5',
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
    );
  }
}
