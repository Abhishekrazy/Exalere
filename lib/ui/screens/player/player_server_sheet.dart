import 'package:flutter/material.dart';

import '../../../models/stream_source.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tv_focusable.dart';

/// Modal bottom sheet for switching streaming servers and video quality tiers.
class PlayerServerSheet extends StatelessWidget {
  final List<StreamSource> sources;
  final int currentSourceIndex;
  final ValueChanged<int> onSourceSelected;

  const PlayerServerSheet({
    super.key,
    required this.sources,
    required this.currentSourceIndex,
    required this.onSourceSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required List<StreamSource> sources,
    required int currentSourceIndex,
    required ValueChanged<int> onSourceSelected,
  }) {
    final tokens = context.tokens;
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final isLandscape = screenWidth > screenHeight;
    final modalHeight = isLandscape
        ? (screenHeight * 0.85).clamp(240.0, 360.0)
        : (screenHeight * 0.45).clamp(240.0, 380.0);

    return showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surfaceElevated,
      shape: tokens.getShapeBorder(radius: tokens.cardRadius + 8),
      isScrollControlled: true,
      builder: (ctx) {
        return SizedBox(
          height: modalHeight,
          child: PlayerServerSheet(
            sources: sources,
            currentSourceIndex: currentSourceIndex,
            onSourceSelected: onSourceSelected,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final isCompact = screenHeight < 550 || screenWidth < 500;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 14 : 20,
          vertical: isCompact ? 10 : 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.dns_rounded,
                      color: theme.colorScheme.primary,
                      size: isCompact ? 18 : 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Streaming Servers & Quality',
                      style: TextStyle(
                        fontSize: isCompact ? 15 : 18,
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: tokens.textSecondary,
                    size: isCompact ? 20 : 24,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            SizedBox(height: isCompact ? 8 : 12),
            Expanded(
              child: ListView.separated(
                itemCount: sources.length,
                separatorBuilder: (context, index) =>
                    SizedBox(height: isCompact ? 6 : 8),
                itemBuilder: (context, idx) {
                  final src = sources[idx];
                  final isSelected = idx == currentSourceIndex;
                  final detailsList = [
                    if (src.formattedSize.isNotEmpty) src.formattedSize,
                    if (src.codec != null && src.codec!.isNotEmpty) src.codec!,
                  ];

                  return TvFocusable(
                    autofocus: isSelected,
                    scaleFactor: 1.04,
                    shape: tokens.shapeSm,
                    borderRadius: tokens.borderRadiusSm,
                    onTap: () {
                      Navigator.of(context).pop();
                      if (idx != currentSourceIndex) {
                        onSourceSelected(idx);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 10 : 14,
                        vertical: isCompact ? 8 : 12,
                      ),
                      decoration: tokens.getShapeDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : tokens.surfaceCard.withValues(alpha: 0.5),
                        radius: tokens.cardRadius * 0.7,
                        side: BorderSide(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : tokens.borderSubtle,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : tokens.textMuted,
                            size: isCompact ? 18 : 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Server ${idx + 1}',
                                      style: TextStyle(
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : tokens.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: isCompact ? 13 : 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: tokens.getShapeDecoration(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.2),
                                        radius: tokens.cardRadius * 0.4,
                                      ),
                                      child: Text(
                                        src.quality,
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontSize: isCompact ? 10 : 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (src.format.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: tokens.getShapeDecoration(
                                          color: tokens.surfaceCard,
                                          radius: tokens.cardRadius * 0.4,
                                        ),
                                        child: Text(
                                          src.format,
                                          style: TextStyle(
                                            color: tokens.textSecondary,
                                            fontSize: isCompact ? 9 : 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (detailsList.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      detailsList.join(' • '),
                                      style: TextStyle(
                                        color: tokens.textMuted,
                                        fontSize: isCompact ? 11 : 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
