import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/libmpv_helper.dart';
import '../../../services/tmdb_service.dart';

/// Mixin providing full trailer player state management, responsive auto-play,
/// in-app/external trailer playback, and controls handling for details screens.
mixin DetailsTrailerMixin<T extends StatefulWidget> on State<T> {
  Player? trailerPlayer;
  VideoController? trailerVideoController;
  Timer? autoPlayTrailerTimer;
  Timer? cursorDimTimer;

  bool isTrailerPlaying = false;
  bool isTrailerPaused = false;
  bool isTrailerMuted = false;
  bool isTrailerLoading = false;
  bool isTrailerFullscreen = false;
  bool isCursorMoving = true;
  BoxFit trailerFit = BoxFit.cover;

  void scheduleAutoPlayTrailer({
    required TmdbEnrichedDetails? tmdbDetails,
    required bool isAutoPlayTrailerEnabled,
  }) {
    autoPlayTrailerTimer?.cancel();
    if (!isAutoPlayTrailerEnabled) return;
    if (tmdbDetails?.trailerYoutubeKey == null ||
        tmdbDetails!.trailerYoutubeKey!.isEmpty) {
      return;
    }

    // Schedule auto-play after 2.5s of hovering / browsing details
    autoPlayTrailerTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && !isTrailerPlaying) {
        startTrailerPlayback(tmdbDetails: tmdbDetails, isAutoPlay: true);
      }
    });
  }

  Future<void> startTrailerPlayback({
    required TmdbEnrichedDetails? tmdbDetails,
    bool isAutoPlay = false,
  }) async {
    final key = tmdbDetails?.trailerYoutubeKey;
    if (key == null || key.isEmpty) {
      if (!isAutoPlay && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No trailer available for this title.')),
        );
      }
      return;
    }

    autoPlayTrailerTimer?.cancel();
    LibMpvHelper.ensureCriticalSectionsInitialized();

    if (trailerPlayer == null) {
      trailerPlayer = Player(
        configuration: const PlayerConfiguration(title: 'Exalere Trailer'),
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

      trailerPlayer!.stream.position.listen((pos) {
        if (!mounted || !isTrailerPlaying) return;
        final dur = trailerPlayer?.state.duration ?? Duration.zero;
        if (dur > const Duration(seconds: 2) &&
            pos >= dur - const Duration(milliseconds: 500)) {
          stopTrailer();
        }
      });

      trailerPlayer!.stream.playing.listen((playing) {
        if (!mounted ||
            !isTrailerPlaying ||
            isTrailerPaused ||
            isTrailerLoading) {
          return;
        }
        if (!playing) {
          final pos = trailerPlayer?.state.position ?? Duration.zero;
          final dur = trailerPlayer?.state.duration ?? Duration.zero;
          if (dur > const Duration(seconds: 2) &&
              pos >= dur - const Duration(seconds: 2)) {
            stopTrailer();
          }
        }
      });

      trailerPlayer!.stream.error.listen((err) {
        debugPrint('Trailer player error: $err');
        if (mounted) {
          stopTrailer();
          if (!isAutoPlay) {
            final externalUrl = tmdbDetails?.trailerUrl;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Failed to play trailer in-app.'),
                action: externalUrl != null
                    ? SnackBarAction(
                        label: 'Play in External',
                        onPressed: () => openExternalTrailer(externalUrl),
                      )
                    : null,
              ),
            );
          }
        }
      });
    }

    setState(() {
      isTrailerLoading = true;
    });

    try {
      final streamUrl = await TmdbService().resolveTrailerDirectUrl(key);
      if (!mounted) return;

      final bool isPlayableDirectStream =
          streamUrl.startsWith('http') &&
          !streamUrl.contains('youtube.com') &&
          !streamUrl.contains('youtu.be');

      if (!isPlayableDirectStream) {
        if (mounted) {
          setState(() {
            isTrailerLoading = false;
          });
          if (!isAutoPlay) {
            final externalUrl = tmdbDetails?.trailerUrl;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Trailer direct stream is currently unavailable in-app.',
                ),
                action: externalUrl != null
                    ? SnackBarAction(
                        label: 'Play in External',
                        onPressed: () => openExternalTrailer(externalUrl),
                      )
                    : null,
              ),
            );
          }
        }
        return;
      }

      await trailerPlayer!.setPlaylistMode(PlaylistMode.none);
      await trailerPlayer!.open(Media(streamUrl));
      if (isAutoPlay) {
        // Start muted for subtle preview
        await trailerPlayer!.setVolume(0.0);
        isTrailerMuted = true;
      } else {
        await trailerPlayer!.setVolume(isTrailerMuted ? 0.0 : 100.0);
      }
      await trailerPlayer!.play();

      if (mounted) {
        setState(() {
          isTrailerPlaying = true;
          isTrailerPaused = false;
          isTrailerLoading = false;
          isCursorMoving = true;
        });
        resetCursorDimTimer();
      }
    } catch (e) {
      debugPrint('Error starting trailer: $e');
      if (mounted) {
        setState(() {
          isTrailerLoading = false;
          isTrailerPlaying = false;
        });
        if (!isAutoPlay) {
          final externalUrl = tmdbDetails?.trailerUrl;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error playing trailer: $e'),
              action: externalUrl != null
                  ? SnackBarAction(
                      label: 'Play in External',
                      onPressed: () => openExternalTrailer(externalUrl),
                    )
                  : null,
            ),
          );
        }
      }
    }
  }

  Future<void> openExternalTrailer(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching external trailer: $e');
    }
  }

  void toggleTrailerFullscreen() {
    setState(() {
      isTrailerFullscreen = !isTrailerFullscreen;
    });
    if (isTrailerFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  void togglePauseTrailer() {
    if (trailerPlayer == null || !isTrailerPlaying) return;
    if (isTrailerPaused) {
      trailerPlayer!.play();
      setState(() => isTrailerPaused = false);
      resetCursorDimTimer();
    } else {
      trailerPlayer!.pause();
      setState(() => isTrailerPaused = true);
    }
  }

  void toggleMuteTrailer() {
    if (trailerPlayer == null) return;
    if (isTrailerMuted) {
      trailerPlayer!.setVolume(100.0);
      setState(() => isTrailerMuted = false);
    } else {
      trailerPlayer!.setVolume(0.0);
      setState(() => isTrailerMuted = true);
    }
    resetCursorDimTimer();
  }

  void toggleTrailerFit() {
    setState(() {
      trailerFit = trailerFit == BoxFit.cover ? BoxFit.contain : BoxFit.cover;
    });
    resetCursorDimTimer();
  }

  void stopTrailer() {
    if (isTrailerFullscreen) {
      isTrailerFullscreen = false;
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
    autoPlayTrailerTimer?.cancel();
    cursorDimTimer?.cancel();
    trailerPlayer?.stop();
    if (mounted) {
      setState(() {
        isTrailerPlaying = false;
        isTrailerPaused = false;
        isTrailerLoading = false;
        isCursorMoving = true;
      });
    }
  }

  void onTrailerUserInteraction() {
    if (!isTrailerPlaying) return;
    if (!isCursorMoving) {
      setState(() => isCursorMoving = true);
    }
    resetCursorDimTimer();
  }

  void resetCursorDimTimer() {
    cursorDimTimer?.cancel();
    if (!isTrailerPlaying) return;
    cursorDimTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && isTrailerPlaying && !isTrailerPaused) {
        setState(() => isCursorMoving = false);
      }
    });
  }

  Future<void> watchTrailer({required TmdbEnrichedDetails? tmdbDetails}) async {
    if (isTrailerPlaying) {
      togglePauseTrailer();
      return;
    }
    await startTrailerPlayback(tmdbDetails: tmdbDetails);
  }

  void disposeTrailer() {
    if (isTrailerFullscreen) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
    autoPlayTrailerTimer?.cancel();
    cursorDimTimer?.cancel();
    trailerPlayer?.dispose();
  }
}
