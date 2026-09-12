import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/media_details.dart';
import '../../../models/media_item.dart';
import '../../../providers/library_provider.dart';
import '../../../services/provider_registry.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tv/tv_episode_options_dialog.dart';
import '../../widgets/tv/tv_popup_scope.dart';
import '../../widgets/tv_focusable.dart';
import '../player_screen.dart';

/// Mixin managing TV movie/episode playback resolution, loading overlays,
/// error handling dialogs, and episode options actions.
mixin TvDetailsPlaybackMixin<T extends StatefulWidget> on State<T> {
  void showLoadingDialog() {
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
              color: ctx.tokens.primaryAccent,
            ),
          ),
        ),
      ),
    );
  }

  void showErrorDialog(String message) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    showDialog(
      context: context,
      builder: (ctx) => TvPopupScope(
        child: AlertDialog(
          backgroundColor: tokens.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: tokens.borderRadiusMd,
            side: BorderSide(color: tokens.borderSubtle),
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
                  color: tokens.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          actions: [
            TvFocusable(
              autofocus: true,
              onTap: () => Navigator.of(ctx).pop(),
              borderRadius: tokens.borderRadiusSm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: tokens.primaryAccent,
                  borderRadius: tokens.borderRadiusSm,
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
      ),
    );
  }

  void showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.tokens.errorColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> playEpisode({
    required MediaItem mediaItem,
    required Episode episode,
    required MediaDetails? details,
    required VoidCallback onStopTrailer,
    required FocusNode playButtonFocusNode,
    bool startOver = false,
  }) async {
    showLoadingDialog();
    try {
      final streams = await ProviderRegistry().resolveStreams(
        subjectId: mediaItem.id,
        season: episode.season,
        episode: episode.episode,
        preferredProviderId: 'moviebox',
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

      if (streams.isEmpty) {
        showErrorDialog(
          'No active stream found for this episode. Try another title or provider.',
        );
        return;
      }

      final library = context.read<LibraryProvider>();
      final resumePos = startOver
          ? 0
          : library.getResumePosition(
              mediaItem.id,
              season: episode.season,
              episode: episode.episode,
            );

      onStopTrailer();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            mediaItem: mediaItem,
            streamSource: streams.first,
            availableSources: streams,
            season: episode.season,
            episode: episode.episode,
            startPositionSeconds: resumePos > 0 ? resumePos : null,
            mediaDetails: details,
          ),
        ),
      );
      if (mounted) {
        FocusScope.of(context).requestFocus(playButtonFocusNode);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      showErrorDialog('Failed to load episode: $e');
    }
  }

  Future<void> playMovie({
    required MediaItem mediaItem,
    required VoidCallback onStopTrailer,
    required FocusNode playButtonFocusNode,
    bool startOver = false,
  }) async {
    final library = context.read<LibraryProvider>();
    final history = library.getHistoryItem(mediaItem.id);
    final resumePos =
        (history != null &&
            !startOver &&
            history.positionSeconds > 15 &&
            (history.totalSeconds <= 0 ||
                history.positionSeconds < history.totalSeconds * 0.95))
        ? history.positionSeconds
        : 0;

    showLoadingDialog();
    try {
      final preferred = mediaItem.provider == ProviderType.fourKHdHub
          ? 'fourkhdhub'
          : 'moviebox';
      final streams = await ProviderRegistry().resolveStreams(
        subjectId: mediaItem.id,
        preferredProviderId: preferred,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

      if (streams.isEmpty) {
        showErrorDialog(
          'No active stream found for this movie. Try another title or provider.',
        );
        return;
      }

      onStopTrailer();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            mediaItem: mediaItem,
            streamSource: streams.first,
            availableSources: streams,
            startPositionSeconds: resumePos > 0 ? resumePos : null,
          ),
        ),
      );
      if (mounted) {
        FocusScope.of(context).requestFocus(playButtonFocusNode);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      showErrorDialog('Failed to load movie: $e');
    }
  }

  void showEpisodeOptionsDialog({
    required MediaItem seriesItem,
    required Episode episode,
    required String title,
    required int resumeSeconds,
    required bool isWatched,
    required VoidCallback onStopTrailer,
    required FocusNode playButtonFocusNode,
  }) {
    TvEpisodeOptionsDialog.show(
      context,
      episode: episode,
      title: title,
      resumePositionSeconds: resumeSeconds,
      isWatched: isWatched,
      onResume: resumeSeconds > 15
          ? () => playEpisode(
              mediaItem: seriesItem,
              episode: episode,
              details: null,
              onStopTrailer: onStopTrailer,
              playButtonFocusNode: playButtonFocusNode,
              startOver: false,
            )
          : null,
      onPlayFromStart: () => playEpisode(
        mediaItem: seriesItem,
        episode: episode,
        details: null,
        onStopTrailer: onStopTrailer,
        playButtonFocusNode: playButtonFocusNode,
        startOver: true,
      ),
      onToggleWatched: () async {
        final library = context.read<LibraryProvider>();
        await library.toggleEpisodeWatched(
          series: seriesItem,
          season: episode.season,
          episode: episode.episode,
        );
      },
    );
  }
}
