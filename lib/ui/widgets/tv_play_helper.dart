import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/library_provider.dart';
import '../../services/provider_registry.dart';
import '../../services/storage_service.dart';
import '../screens/player_screen.dart';
import '../screens/tv_details_screen.dart';
import '../theme/app_tokens.dart';
import 'tv_focusable.dart';

/// Helper to launch movies and series directly on TV with zero cast/crew clutter.
class TvPlayHelper {
  /// Directly resumes playback for a [WatchHistoryItem] (movie or series episode) into [PlayerScreen].
  static Future<void> resumePlayback(
    BuildContext context,
    WatchHistoryItem historyItem,
  ) async {
    final item = historyItem.item;
    final season = historyItem.season;
    final episode = historyItem.episode;
    final positionSeconds = historyItem.positionSeconds;

    // Show clean loading spinner dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: ctx.tokens.surfaceElevated,
            borderRadius: ctx.tokens.borderRadiusLg,
            border: Border.all(color: ctx.tokens.borderSubtle),
            boxShadow: ctx.tokens.getCardShadows(),
          ),
          child: SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );

    try {
      final preferred = item.provider == ProviderType.fourKHdHub
          ? 'fourkhdhub'
          : 'moviebox';
      final streams = await ProviderRegistry().resolveStreams(
        subjectId: item.id,
        season: season,
        episode: episode,
        preferredProviderId: preferred,
      );

      if (!context.mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop(); // dismiss loading dialog

      if (streams.isEmpty) {
        _showTvErrorDialog(
          context,
          'No active stream found for "${item.cleanTitle}". Try another title or provider.',
        );
        return;
      }

      final resumePos = positionSeconds > 15 ? positionSeconds : null;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            mediaItem: item,
            streamSource: streams.first,
            availableSources: streams,
            season: season,
            episode: episode,
            startPositionSeconds: resumePos,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showTvErrorDialog(context, 'Failed to resume playback: $e');
    }
  }

  static Future<void> playItem(BuildContext context, MediaItem item) async {
    // If it's a TV series, open the 10-foot Netflix-like TV Details page
    if (item.isSeries) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TvDetailsScreen(mediaItem: item)),
      );
      return;
    }

    // For movies: check if there is existing watch progress
    final library = context.read<LibraryProvider>();
    final history = library.getHistoryItem(item.id);
    final resumePos =
        (history != null &&
            history.positionSeconds > 15 &&
            (history.totalSeconds <= 0 ||
                history.positionSeconds < history.totalSeconds * 0.95))
        ? history.positionSeconds
        : 0;

    if (resumePos > 0) {
      // Prompt Resume vs Start Over
      if (!context.mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          final minutes = (resumePos / 60).floor();
          final seconds = resumePos % 60;
          final timeStr =
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

          return Dialog(
            backgroundColor: ctx.tokens.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: ctx.tokens.borderRadiusLg,
              side: BorderSide(color: ctx.tokens.borderSubtle),
            ),
            child: Container(
              padding: const EdgeInsets.all(28),
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.cleanTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: ctx.tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You previously paused at $timeStr.\nWould you like to resume watching?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ctx.tokens.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TvFocusable(
                        autofocus: true,
                        scaleFactor: 1.08,
                        borderRadius: ctx.tokens.borderRadiusSm,
                        onTap: () => Navigator.of(ctx).pop('resume'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: ctx.tokens.borderRadiusSm,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                color: theme.colorScheme.onPrimary,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Resume ($timeStr)',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      TvFocusable(
                        scaleFactor: 1.08,
                        borderRadius: ctx.tokens.borderRadiusSm,
                        onTap: () => Navigator.of(ctx).pop('start_over'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: ctx.tokens.surfaceElevated,
                            borderRadius: ctx.tokens.borderRadiusSm,
                            border: Border.all(color: ctx.tokens.borderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.replay_rounded,
                                color: ctx.tokens.textPrimary,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Start Over',
                                style: TextStyle(
                                  color: ctx.tokens.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (choice == null) return;
      if (!context.mounted) return;
      await _launchMovie(
        context,
        item,
        startPosition: choice == 'resume' ? resumePos : 0,
      );
    } else {
      await _launchMovie(context, item, startPosition: 0);
    }
  }

  static Future<void> _launchMovie(
    BuildContext context,
    MediaItem item, {
    required int startPosition,
  }) async {
    // Show a lightweight loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: ctx.tokens.surfaceElevated,
            borderRadius: ctx.tokens.borderRadiusLg,
            border: Border.all(color: ctx.tokens.borderSubtle),
            boxShadow: ctx.tokens.getCardShadows(),
          ),
          child: SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );

    try {
      final streams = await ProviderRegistry().resolveStreams(
        subjectId: item.id,
      );
      if (!context.mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop(); // dismiss loading dialog

      if (streams.isEmpty) {
        _showTvErrorDialog(
          context,
          'No active streams found for this movie. Try another title or provider.',
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            mediaItem: item,
            streamSource: streams.first,
            availableSources: streams,
            startPositionSeconds: startPosition > 0 ? startPosition : null,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop(); // dismiss loading dialog
      _showTvErrorDialog(context, 'Failed to load movie: $e');
    }
  }

  static void _showTvErrorDialog(BuildContext context, String message) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.tokens.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: ctx.tokens.borderRadiusMd,
          side: BorderSide(color: ctx.tokens.borderSubtle),
        ),
        title: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: theme.colorScheme.error,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              'Playback Error',
              style: TextStyle(
                color: ctx.tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: ctx.tokens.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TvFocusable(
            autofocus: true,
            onTap: () => Navigator.of(ctx).pop(),
            borderRadius: ctx.tokens.borderRadiusSm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: ctx.tokens.primaryAccent,
                borderRadius: ctx.tokens.borderRadiusSm,
              ),
              child: Text(
                'OK',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
