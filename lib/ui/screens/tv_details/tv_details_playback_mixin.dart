import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/media_details.dart';
import '../../../models/media_item.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/library_provider.dart';
import '../../../providers/plugin_provider.dart';
import '../../../services/external_player_service.dart';
import '../../../services/provider_registry.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tv/tv_episode_options_dialog.dart';
import '../../widgets/tv/tv_popup_scope.dart';
import '../../widgets/tv_focusable.dart';
import '../player_screen.dart';

/// Mixin managing TV movie/episode playback resolution, loading overlays,
/// error handling dialogs, and episode options actions.
mixin TvDetailsPlaybackMixin<T extends StatefulWidget> on State<T> {
  DateTime? lastChildPoppedTime;

  void markChildRoutePopped() {
    lastChildPoppedTime = DateTime.now();
  }

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
          shape: tokens.getShapeBorder(
            radius: tokens.cardRadius,
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
    String? imdbId,
    required VoidCallback onStopTrailer,
    required FocusNode playButtonFocusNode,
    bool startOver = false,
  }) async {
    final hasActivePlugins = context.read<PluginProvider>().hasActivePlugins;
    if (!hasActivePlugins) {
      showErrorDialog('No streams available for this episode.');
      return;
    }
    showLoadingDialog();
    try {
      final resolvedImdbId =
          imdbId ?? (mediaItem.id.startsWith('tt') ? mediaItem.id : null);
      final library = context.read<LibraryProvider>();
      final lastStream = library.getLastUsedStream(mediaItem.id);
      final preferred =
          lastStream?.effectiveProviderId ??
          ProviderRegistry().defaultProviderId ??
          mediaItem.providerId ??
          (mediaItem.provider != ProviderType.plugins
              ? mediaItem.provider.shortId
              : null);
      final streams = await ProviderRegistry().resolveStreams(
        subjectId: mediaItem.id,
        title: mediaItem.title,
        year: mediaItem.year,
        imdbId: resolvedImdbId,
        season: episode.season,
        episode: episode.episode,
        preferredProviderId: preferred,
        originProviderId: mediaItem.effectiveProviderId,
        isSeries: true,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

      if (streams.isEmpty) {
        showErrorDialog(
          'No active stream found for this episode. Try another title or provider.',
        );
        return;
      }

      final resumePos = startOver
          ? 0
          : library.getResumePosition(
              mediaItem.id,
              season: episode.season,
              episode: episode.episode,
            );

      final selected = library.pickBestMatchingStream(
        streams,
        preferredStream: lastStream,
        preferredProviderId: ProviderRegistry().defaultProviderId ?? preferred,
      );

      onStopTrailer();
      if (context.read<AppProvider>().useExternalPlayer) {
        final launched = await ExternalPlayerService().launch(
          url: selected.url,
          title: '${mediaItem.title} - S${episode.season}E${episode.episode}',
          headers: selected.headers,
          startSeconds: resumePos > 0 ? resumePos : null,
        );
        if (!launched && mounted) {
          showErrorDialog(
            'Could not launch external player. Make sure VLC or Just Player is installed.',
          );
        }
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            mediaItem: mediaItem,
            streamSource: selected,
            availableSources: streams,
            season: episode.season,
            episode: episode.episode,
            startPositionSeconds: resumePos > 0 ? resumePos : null,
            mediaDetails: details,
            imdbId: resolvedImdbId,
          ),
        ),
      );
      markChildRoutePopped();
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
    MediaDetails? details,
    String? imdbId,
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

    final hasActivePlugins = context.read<PluginProvider>().hasActivePlugins;
    if (!hasActivePlugins) {
      showErrorDialog('No streams available for this title.');
      return;
    }

    showLoadingDialog();
    try {
      final lastStream = library.getLastUsedStream(mediaItem.id);
      final preferred =
          lastStream?.effectiveProviderId ??
          ProviderRegistry().defaultProviderId ??
          mediaItem.providerId ??
          (mediaItem.provider != ProviderType.plugins
              ? mediaItem.provider.shortId
              : null);
      final resolvedImdbId =
          imdbId ?? (mediaItem.id.startsWith('tt') ? mediaItem.id : null);
      final streams = await ProviderRegistry().resolveStreams(
        subjectId: mediaItem.id,
        title: mediaItem.title,
        year: mediaItem.year,
        imdbId: resolvedImdbId,
        preferredProviderId: preferred,
        originProviderId: mediaItem.effectiveProviderId,
        isSeries: mediaItem.isSeries,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

      if (streams.isEmpty) {
        showErrorDialog(
          'No active stream found for this movie. Try another title or provider.',
        );
        return;
      }

      final selected = library.pickBestMatchingStream(
        streams,
        preferredStream: lastStream,
        preferredProviderId: ProviderRegistry().defaultProviderId ?? preferred,
      );

      onStopTrailer();
      if (context.read<AppProvider>().useExternalPlayer) {
        final launched = await ExternalPlayerService().launch(
          url: selected.url,
          title: mediaItem.title,
          headers: selected.headers,
          startSeconds: resumePos > 0 ? resumePos : null,
        );
        if (!launched && mounted) {
          showErrorDialog(
            'Could not launch external player. Make sure VLC or Just Player is installed.',
          );
        }
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            mediaItem: mediaItem,
            streamSource: selected,
            availableSources: streams,
            startPositionSeconds: resumePos > 0 ? resumePos : null,
            mediaDetails: details,
            imdbId: resolvedImdbId,
          ),
        ),
      );
      markChildRoutePopped();
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
  }) async {
    await TvEpisodeOptionsDialog.show(
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
    markChildRoutePopped();
  }
}
