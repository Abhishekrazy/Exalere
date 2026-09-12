import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/tv/tv_popup_scope.dart';
import '../../widgets/tv_focusable.dart';

/// Modal bottom sheet allowing users to pick playback speed.
class PlayerSpeedSheet extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedSelected;

  const PlayerSpeedSheet({
    super.key,
    required this.currentSpeed,
    required this.onSpeedSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required double currentSpeed,
    required ValueChanged<double> onSpeedSelected,
  }) {
    final tokens = context.tokens;
    return showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surfaceElevated,
      shape: tokens.getShapeBorder(radius: tokens.cardRadius + 8),
      builder: (ctx) => PlayerSpeedSheet(
        currentSpeed: currentSpeed,
        onSpeedSelected: onSpeedSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return TvPopupScope(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Playback Speed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((rate) {
                  final isSel = (currentSpeed - rate).abs() < 0.05;
                  return TvFocusable(
                    autofocus: isSel,
                    onTap: () {
                      Navigator.of(context).pop();
                      onSpeedSelected(rate);
                    },
                    shape: tokens.shapePill,
                    borderRadius: tokens.borderRadiusPill,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: tokens.getShapeDecoration(
                        color: isSel
                            ? theme.colorScheme.primary
                            : tokens.borderSubtle.withValues(alpha: 0.3),
                        radius: tokens.cardRadius * 2,
                        side: BorderSide(
                          color: isSel
                              ? theme.colorScheme.primary
                              : tokens.borderSubtle,
                        ),
                      ),
                      child: Text(
                        '${rate}x',
                        style: TextStyle(
                          color: isSel
                              ? theme.colorScheme.onPrimary
                              : tokens.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
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
    );
  }
}
