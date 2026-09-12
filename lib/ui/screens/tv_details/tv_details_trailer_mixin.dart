import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/media_item.dart';
import '../../../models/stream_source.dart';
import '../../../services/libmpv_helper.dart';
import '../../../services/tmdb_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tv/tv_popup_scope.dart';
import '../player_screen.dart';

/// Mixin handling ambient TV backdrop trailer auto-playback and full trailer streaming.
mixin TvDetailsTrailerMixin<T extends StatefulWidget> on State<T> {
  Player? trailerPlayer;
  VideoController? trailerVideoController;
  Timer? autoPlayTrailerTimer;
  bool isTrailerPlaying = false;

  void scheduleAutoPlayTrailer({
    required String? trailerKey,
    required bool autoPlayEnabled,
    Duration delay = const Duration(milliseconds: 2500),
  }) {
    autoPlayTrailerTimer?.cancel();
    if (!autoPlayEnabled) return;
    if (trailerKey == null || trailerKey.isEmpty) return;

    autoPlayTrailerTimer = Timer(delay, () {
      if (mounted && !isTrailerPlaying) {
        startTrailerPlayback(trailerKey);
      }
    });
  }

  Future<void> startTrailerPlayback(String? trailerKey) async {
    final key = trailerKey;
    if (key == null || key.isEmpty) return;

    autoPlayTrailerTimer?.cancel();
    LibMpvHelper.ensureCriticalSectionsInitialized();

    if (trailerPlayer == null) {
      trailerPlayer = Player(
        configuration: const PlayerConfiguration(title: 'Exalere TV Trailer'),
      );
      trailerVideoController = VideoController(
        trailerPlayer!,
        configuration: const VideoControllerConfiguration(hwdec: 'auto-safe'),
      );

      trailerPlayer!.stream.completed.listen((completed) {
        if (completed && mounted && isTrailerPlaying) {
          stopTrailer();
        }
      });

      trailerPlayer!.stream.error.listen((err) {
        debugPrint('TV Trailer player error: $err');
        if (mounted) {
          stopTrailer();
        }
      });
    }

    try {
      final streamUrl = await TmdbService().resolveTrailerDirectUrl(key);
      if (!mounted) return;

      final bool isPlayableDirectStream =
          streamUrl.startsWith('http') &&
          !streamUrl.contains('youtube.com') &&
          !streamUrl.contains('youtu.be');

      if (!isPlayableDirectStream) {
        return;
      }

      await trailerPlayer!.setPlaylistMode(PlaylistMode.none);
      await trailerPlayer!.open(Media(streamUrl));
      // TV backdrop trailer plays muted for unobtrusive ambient experience
      await trailerPlayer!.setVolume(0.0);
      await trailerPlayer!.play();

      if (mounted) {
        setState(() {
          isTrailerPlaying = true;
        });
      }
    } catch (e) {
      debugPrint('TV Trailer playback error: $e');
      if (mounted) {
        setState(() {
          isTrailerPlaying = false;
        });
      }
    }
  }

  void stopTrailer() {
    autoPlayTrailerTimer?.cancel();
    trailerPlayer?.stop();
    trailerPlayer?.dispose();
    trailerPlayer = null;
    trailerVideoController = null;
    if (mounted) {
      setState(() {
        isTrailerPlaying = false;
      });
    }
  }

  void disposeTrailer() {
    autoPlayTrailerTimer?.cancel();
    stopTrailer();
  }

  Future<void> playTrailer({
    required MediaItem mediaItem,
    required String? trailerKey,
    required void Function(String) showError,
    required void Function(String) showToastMessage,
  }) async {
    final key = trailerKey;
    if (key == null || key.isEmpty) {
      showToastMessage('No trailer available for this title.');
      return;
    }

    stopTrailer();

    // Show clean loading spinner dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TvPopupScope(
        child: Center(
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
      ),
    );

    try {
      final streamUrl = await TmdbService().resolveTrailerDirectUrl(key);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final isDirectPlayable =
          streamUrl.startsWith('http') &&
          !streamUrl.contains('youtube.com') &&
          !streamUrl.contains('youtu.be');

      if (isDirectPlayable) {
        final trailerMediaItem = MediaItem(
          id: 'trailer_${mediaItem.id}_$key',
          title: '${mediaItem.cleanTitle} - Official Trailer',
          mediaType: MediaType.movie,
          posterUrl: mediaItem.posterUrl,
          backdropUrl: mediaItem.backdropUrl,
          provider: mediaItem.provider,
        );

        final source = StreamSource(
          quality: 'Trailer',
          resolution: 'Auto',
          format: streamUrl.contains('.m3u8') ? 'HLS' : 'MP4',
          url: streamUrl,
        );

        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              mediaItem: trailerMediaItem,
              streamSource: source,
              availableSources: [source],
            ),
          ),
        );
      } else {
        // Direct stream unavailable: attempt external launch safely if supported
        final externalUrl = Uri.parse('https://www.youtube.com/watch?v=$key');
        if (await canLaunchUrl(externalUrl)) {
          await launchUrl(externalUrl, mode: LaunchMode.externalApplication);
        } else {
          showError(
            'Unable to stream trailer in-app, and no web browser or YouTube app was found on this TV.',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      showError('Failed to load trailer: $e');
    }
  }
}
