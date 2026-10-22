import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/video_decoder_mode.dart';
import '../../../providers/app_provider.dart';
import '../../theme/app_tokens.dart';
import '../tv/tv_popup_scope.dart';
import '../tv_focusable.dart';

/// Picker for the player's video decoder.
///
/// Every option applies the moment it is tapped — there is no Apply button, so a
/// mis-tap is corrected by picking the other option rather than by confirming.
class MediaDecoderDialog extends StatelessWidget {
  const MediaDecoderDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const MediaDecoderDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final app = context.watch<AppProvider>();
    final current = app.videoDecoderMode;

    return TvPopupScope(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceElevated,
              radius: tokens.cardRadius,
              side: BorderSide(color: tokens.borderSubtle, width: 1.5),
              shadows: tokens.getCardShadows(),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.memory_rounded,
                      size: 22,
                      color: tokens.primaryAccent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Video Decoder',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Applies to the next video you open.',
                  style: TextStyle(fontSize: 12.5, color: tokens.textSecondary),
                ),
                const SizedBox(height: 16),
                for (final mode in VideoDecoderMode.values) ...[
                  _DecoderOption(
                    mode: mode,
                    selected: mode == current,
                    onTap: () async {
                      await app.setVideoDecoderMode(mode);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  if (mode != VideoDecoderMode.values.last)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DecoderOption extends StatelessWidget {
  const _DecoderOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final VideoDecoderMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return TvFocusable(
      // Exactly one autofocus: the current choice, so D-Pad Select confirms
      // rather than moving somewhere unexpected.
      autofocus: selected,
      borderRadius: tokens.borderRadiusSm,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? tokens.primaryAccent.withValues(alpha: 0.14)
              : tokens.surfaceCard,
          borderRadius: tokens.borderRadiusSm,
          border: Border.all(
            color: selected ? tokens.borderFocus : tokens.borderSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? tokens.primaryAccent : tokens.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode.description,
                    style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
