import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/library_provider.dart';
import '../../services/moviebox_provider.dart';
import '../screens/player_screen.dart';
import '../screens/tv_details_screen.dart';
import 'tv_focusable.dart';

/// Helper to launch movies and series directly on TV with zero cast/crew clutter.
class TvPlayHelper {
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
            backgroundColor: const Color(0xFF14171E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white12),
            ),
            child: Container(
              padding: const EdgeInsets.all(28),
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You previously paused at $timeStr.\nWould you like to resume watching?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
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
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Navigator.of(ctx).pop('resume'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Resume ($timeStr)',
                                style: const TextStyle(
                                  color: Colors.black,
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
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Navigator.of(ctx).pop('start_over'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.replay_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Start Over',
                                style: TextStyle(
                                  color: Colors.white,
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
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF14171E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Starting movie...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final streams = await MovieBoxProvider().getStreams(subjectId: item.id);
      if (!context.mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop(); // dismiss loading dialog

      if (streams.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active streams found for this movie.'),
            backgroundColor: Colors.redAccent,
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load movie: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
