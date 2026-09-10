import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/media_item.dart';
import '../../models/media_details.dart';
import '../../models/stream_source.dart';
import '../../providers/app_provider.dart';
import '../../providers/cast_provider.dart';
import '../../providers/library_provider.dart';
import '../../services/libmpv_helper.dart';
import '../../services/moviebox_provider.dart';
import '../../services/fourkhdhub_provider.dart';
import '../../services/external_player_service.dart';
import '../../services/tmdb_service.dart';
import '../../services/provider_registry.dart';

import '../theme/app_themes.dart';
import '../widgets/cast_dialog.dart';
import '../widgets/episode_tile.dart';
import 'player_screen.dart';

class DetailsScreen extends StatefulWidget {
  final MediaItem mediaItem;
  final String? heroTag;

  const DetailsScreen({super.key, required this.mediaItem, this.heroTag});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final MovieBoxProvider _movieBoxProvider = MovieBoxProvider();
  final FourKHdHubProvider _fourKHdHubProvider = FourKHdHubProvider();

  MediaDetails? _details;
  TmdbEnrichedDetails? _tmdbDetails;
  bool _isLoading = true;
  int _selectedSeasonIdx = 0;
  int _selectedEpisodeIdx = 0;

  // Trailer player & responsive auto-play state
  Player? _trailerPlayer;
  VideoController? _trailerVideoController;
  Timer? _autoPlayTrailerTimer;
  Timer? _cursorDimTimer;
  bool _isTrailerPlaying = false;
  bool _isTrailerPaused = false;
  bool _isTrailerMuted = false;
  bool _isTrailerLoading = false;
  bool _isTrailerFullscreen = false;
  bool _isCursorMoving = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  @override
  void dispose() {
    if (_isTrailerFullscreen) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
    _autoPlayTrailerTimer?.cancel();
    _cursorDimTimer?.cancel();
    _trailerPlayer?.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);

    // Fetch TMDB enriched metadata in parallel (trailer, cast photos, age certification)
    TmdbService()
        .getEnrichedDetails(
          title: widget.mediaItem.title,
          year: widget.mediaItem.year,
          isSeries: widget.mediaItem.isSeries,
        )
        .then((tmdb) {
          if (mounted && tmdb != null) {
            setState(() => _tmdbDetails = tmdb);
            if (tmdb.trailerYoutubeKey != null &&
                tmdb.trailerYoutubeKey!.isNotEmpty) {
              _scheduleAutoPlayTrailer();
            }
            if (_details != null && _details!.isSeries) {
              _enrichSeasonEpisodesWithTmdb(tmdbId: tmdb.id);
            }
          }
        });

    try {
      if (widget.mediaItem.provider == ProviderType.fourKHdHub) {
        _details = await _fourKHdHubProvider.getDetails(widget.mediaItem.id);
      } else {
        _details = await _movieBoxProvider.getDetails(widget.mediaItem.id);
      }
      if (!mounted) return;

      if (_details != null && _details!.isSeries) {
        final history = context.read<LibraryProvider>().getHistoryItem(
          widget.mediaItem.id,
        );
        if (history != null &&
            history.season != null &&
            history.episode != null) {
          final sIdx = history.season! - 1;
          final epIdx = history.episode! - 1;
          if (sIdx >= 0 && sIdx < _details!.seasons.length) {
            _selectedSeasonIdx = sIdx;
            if (epIdx >= 0 && epIdx < _details!.seasons[sIdx].episodes.length) {
              _selectedEpisodeIdx = epIdx;
            }
          }
        }
        _enrichSeasonEpisodesWithTmdb(seasonIdx: _selectedSeasonIdx);
      }
    } catch (e) {
      debugPrint('Error loading details: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _enrichSeasonEpisodesWithTmdb({
    int? tmdbId,
    int? seasonIdx,
  }) async {
    if (_details == null || !_details!.isSeries) return;
    final sIdx = seasonIdx ?? _selectedSeasonIdx;
    if (sIdx < 0 || sIdx >= _details!.seasons.length) return;

    final targetSeason = _details!.seasons[sIdx];
    final id = tmdbId ?? _tmdbDetails?.id;

    Map<int, TmdbEpisodeInfo> tmdbEpisodes = {};
    if (id != null && id > 0) {
      tmdbEpisodes = await TmdbService().getSeasonEpisodes(
        tvId: id,
        seasonNumber: targetSeason.seasonNumber,
      );
    } else {
      tmdbEpisodes = await TmdbService().getSeasonEpisodesByTitle(
        title: widget.mediaItem.title,
        year: widget.mediaItem.year,
        seasonNumber: targetSeason.seasonNumber,
      );
    }

    if (!mounted || tmdbEpisodes.isEmpty) return;

    _applyTmdbToSeason(seasonIdx: sIdx, tmdbEpisodes: tmdbEpisodes);

    // Background prefetch remaining seasons for instant switching
    final finalTvId = id ?? _tmdbDetails?.id;
    if (finalTvId != null && finalTvId > 0) {
      _prefetchOtherSeasons(finalTvId, sIdx);
    }
  }

  void _prefetchOtherSeasons(int tvId, int currentIdx) {
    if (_details == null || !_details!.isSeries) return;
    for (int i = 0; i < _details!.seasons.length; i++) {
      if (i == currentIdx) continue;
      final s = _details!.seasons[i];
      final hasMissing = s.episodes.any(
        (e) => e.thumbnail == null || e.thumbnail!.trim().isEmpty,
      );
      if (hasMissing) {
        TmdbService()
            .getSeasonEpisodes(tvId: tvId, seasonNumber: s.seasonNumber)
            .then((epMap) {
              if (!mounted || epMap.isEmpty) return;
              _applyTmdbToSeason(seasonIdx: i, tmdbEpisodes: epMap);
            });
      }
    }
  }

  void _applyTmdbToSeason({
    required int seasonIdx,
    required Map<int, TmdbEpisodeInfo> tmdbEpisodes,
  }) {
    if (_details == null ||
        seasonIdx < 0 ||
        seasonIdx >= _details!.seasons.length) {
      return;
    }
    final targetSeason = _details!.seasons[seasonIdx];
    bool hasChanges = false;
    final updatedEpisodes = targetSeason.episodes.map((ep) {
      final tmdbEp = tmdbEpisodes[ep.episode];
      if (tmdbEp == null) return ep;

      // If episode thumbnail is not available, get it from tmdb
      final bool needsThumb =
          (ep.thumbnail == null || ep.thumbnail!.trim().isEmpty) &&
          (tmdbEp.stillUrl != null && tmdbEp.stillUrl!.isNotEmpty);
      final bool isGenericTitle =
          ep.title.isEmpty ||
          RegExp(
            r'^Episode \d+$',
            caseSensitive: false,
          ).hasMatch(ep.title.trim());
      final bool needsTitle =
          isGenericTitle &&
          (tmdbEp.name != null && tmdbEp.name!.trim().isNotEmpty);
      final bool needsOverview =
          (ep.overview == null || ep.overview!.trim().isEmpty) &&
          (tmdbEp.overview != null && tmdbEp.overview!.trim().isNotEmpty);

      if (needsThumb || needsTitle || needsOverview) {
        hasChanges = true;
        return ep.copyWith(
          thumbnail: needsThumb ? tmdbEp.stillUrl : ep.thumbnail,
          title: needsTitle ? tmdbEp.name! : ep.title,
          overview: needsOverview ? tmdbEp.overview : ep.overview,
        );
      }
      return ep;
    }).toList();

    if (hasChanges && mounted) {
      final updatedSeasons = List<Season>.from(_details!.seasons);
      updatedSeasons[seasonIdx] = targetSeason.copyWith(
        episodes: updatedEpisodes,
      );
      setState(() {
        _details = _details!.copyWith(seasons: updatedSeasons);
      });
    }
  }

  void _scheduleAutoPlayTrailer() {
    _autoPlayTrailerTimer?.cancel();
    // Do not autoplay trailers on mobile devices to conserve battery and bandwidth
    if (Platform.isAndroid || Platform.isIOS) return;

    final appProvider = context.read<AppProvider>();
    if (!appProvider.autoPlayTrailers) return;

    // Automatically trigger trailer playback after 10 seconds of viewing
    _autoPlayTrailerTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && !_isTrailerPlaying && !_isLoading) {
        _startTrailerPlayback();
      }
    });
  }

  Future<void> _startTrailerPlayback() async {
    final key = _tmdbDetails?.trailerYoutubeKey;
    if (key == null || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No trailer available for this title.')),
      );
      return;
    }

    _autoPlayTrailerTimer?.cancel();
    LibMpvHelper.ensureCriticalSectionsInitialized();

    if (_trailerPlayer == null) {
      _trailerPlayer = Player(
        configuration: const PlayerConfiguration(title: 'Exalere Trailer'),
      );
      _trailerVideoController = VideoController(
        _trailerPlayer!,
        configuration: const VideoControllerConfiguration(hwdec: 'auto-safe'),
      );

      _trailerPlayer!.stream.completed.listen((completed) {
        if (completed && mounted && _isTrailerPlaying) {
          _stopTrailer();
        }
      });

      _trailerPlayer!.stream.position.listen((pos) {
        if (!mounted || !_isTrailerPlaying) return;
        final dur = _trailerPlayer?.state.duration ?? Duration.zero;
        if (dur > const Duration(seconds: 2) &&
            pos >= dur - const Duration(milliseconds: 500)) {
          _stopTrailer();
        }
      });

      _trailerPlayer!.stream.playing.listen((playing) {
        if (!mounted ||
            !_isTrailerPlaying ||
            _isTrailerPaused ||
            _isTrailerLoading) {
          return;
        }
        if (!playing) {
          final pos = _trailerPlayer?.state.position ?? Duration.zero;
          final dur = _trailerPlayer?.state.duration ?? Duration.zero;
          if (dur > const Duration(seconds: 2) &&
              pos >= dur - const Duration(seconds: 2)) {
            _stopTrailer();
          }
        }
      });

      _trailerPlayer!.stream.error.listen((err) {
        debugPrint('Trailer player error: $err');
        if (mounted) {
          _stopTrailer();
          final externalUrl = _tmdbDetails?.trailerUrl;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to play trailer in-app.'),
              action: externalUrl != null
                  ? SnackBarAction(
                      label: 'Play in External',
                      onPressed: () => _openExternalTrailer(externalUrl),
                    )
                  : null,
            ),
          );
        }
      });
    }

    setState(() {
      _isTrailerLoading = true;
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
            _isTrailerLoading = false;
          });
          final externalUrl = _tmdbDetails?.trailerUrl;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Trailer direct stream is currently unavailable in-app.',
              ),
              action: externalUrl != null
                  ? SnackBarAction(
                      label: 'Play in External',
                      onPressed: () => _openExternalTrailer(externalUrl),
                    )
                  : null,
            ),
          );
        }
        return;
      }

      await _trailerPlayer!.setPlaylistMode(PlaylistMode.none);
      await _trailerPlayer!.open(Media(streamUrl));
      await _trailerPlayer!.play();

      if (mounted) {
        setState(() {
          _isTrailerPlaying = true;
          _isTrailerPaused = false;
          _isTrailerLoading = false;
          _isCursorMoving = true;
        });
        _resetCursorDimTimer();
      }
    } catch (e) {
      debugPrint('Error starting trailer: $e');
      if (mounted) {
        setState(() {
          _isTrailerLoading = false;
          _isTrailerPlaying = false;
        });
        final externalUrl = _tmdbDetails?.trailerUrl;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing trailer: $e'),
            action: externalUrl != null
                ? SnackBarAction(
                    label: 'Play in External',
                    onPressed: () => _openExternalTrailer(externalUrl),
                  )
                : null,
          ),
        );
      }
    }
  }

  Future<void> _openExternalTrailer(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching external trailer: $e');
    }
  }

  void _toggleTrailerFullscreen() {
    setState(() {
      _isTrailerFullscreen = !_isTrailerFullscreen;
    });
    if (_isTrailerFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  void _togglePauseTrailer() {
    if (_trailerPlayer == null || !_isTrailerPlaying) return;
    if (_isTrailerPaused) {
      _trailerPlayer!.play();
      setState(() => _isTrailerPaused = false);
      _resetCursorDimTimer();
    } else {
      _trailerPlayer!.pause();
      setState(() => _isTrailerPaused = true);
    }
  }

  void _toggleMuteTrailer() {
    if (_trailerPlayer == null) return;
    if (_isTrailerMuted) {
      _trailerPlayer!.setVolume(100.0);
      setState(() => _isTrailerMuted = false);
    } else {
      _trailerPlayer!.setVolume(0.0);
      setState(() => _isTrailerMuted = true);
    }
    _resetCursorDimTimer();
  }

  void _stopTrailer() {
    if (_isTrailerFullscreen) {
      _isTrailerFullscreen = false;
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
    _autoPlayTrailerTimer?.cancel();
    _cursorDimTimer?.cancel();
    _trailerPlayer?.stop();
    if (mounted) {
      setState(() {
        _isTrailerPlaying = false;
        _isTrailerPaused = false;
        _isTrailerLoading = false;
        _isCursorMoving = true;
      });
    }
  }

  void _onUserInteraction() {
    if (!_isTrailerPlaying) return;
    if (!_isCursorMoving) {
      setState(() => _isCursorMoving = true);
    }
    _resetCursorDimTimer();
  }

  void _resetCursorDimTimer() {
    _cursorDimTimer?.cancel();
    if (!_isTrailerPlaying) return;
    _cursorDimTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isTrailerPlaying && !_isTrailerPaused) {
        setState(() => _isCursorMoving = false);
      }
    });
  }

  Future<void> _watchTrailer() async {
    if (_isTrailerPlaying) {
      _togglePauseTrailer();
      return;
    }
    await _startTrailerPlayback();
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.tokens.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: context.tokens.borderRadiusMd,
          side: BorderSide(color: context.tokens.borderSubtle),
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
                color: context.tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: context.tokens.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            autofocus: true,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: context.tokens.borderRadiusSm,
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _playMedia({
    int season = 0,
    int episode = 0,
    int? startPositionSeconds,
  }) async {
    _stopTrailer();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: context.tokens.surfaceElevated,
            borderRadius: context.tokens.borderRadiusLg,
            border: Border.all(color: context.tokens.borderSubtle),
            boxShadow: context.tokens.getCardShadows(),
          ),
          child: SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );

    List<StreamSource> streams = [];
    String? resolutionError;
    try {
      final preferred = widget.mediaItem.provider == ProviderType.fourKHdHub
          ? 'fourkhdhub'
          : 'moviebox';
      streams = await ProviderRegistry().resolveStreams(
        subjectId: widget.mediaItem.id,
        season: season > 0 ? season : null,
        episode: episode > 0 ? episode : null,
        preferredProviderId: preferred,
      );
    } catch (e) {
      resolutionError = e.toString();
      debugPrint('Stream resolution error: $e');
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog

    if (streams.isEmpty) {
      _showErrorDialog(
        resolutionError != null
            ? 'Failed to resolve streaming sources: $resolutionError'
            : 'No active streams found. Try another title or streaming provider.',
      );
      return;
    }

    // Directly play stream without presenting quality dialog,
    // passing all available sources so user can switch servers directly inside the player
    _launchPlayer(
      streams.first,
      season: season,
      episode: episode,
      startPositionSeconds: startPositionSeconds,
      availableSources: streams,
    );
  }

  void _launchPlayer(
    StreamSource stream, {
    required int season,
    required int episode,
    int? startPositionSeconds,
    List<StreamSource>? availableSources,
  }) {
    if (context.read<AppProvider>().useExternalPlayer) {
      _openExternalPlayer(stream, startPositionSeconds: startPositionSeconds);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          mediaItem: widget.mediaItem,
          streamSource: stream,
          availableSources: availableSources ?? [stream],
          season: season > 0 ? season : null,
          episode: episode > 0 ? episode : null,
          startPositionSeconds: startPositionSeconds,
          mediaDetails: _details,
        ),
      ),
    );
  }

  Future<void> _openExternalPlayer(
    StreamSource stream, {
    int? startPositionSeconds,
  }) async {
    final library = context.read<LibraryProvider>();
    final resumeSec =
        startPositionSeconds ??
        library.getResumePosition(
          widget.mediaItem.id,
          season: _details?.isSeries == true ? (_selectedSeasonIdx + 1) : null,
          episode: _details?.isSeries == true
              ? (_selectedEpisodeIdx + 1)
              : null,
        );

    final launched = await ExternalPlayerService().launch(
      url: stream.url,
      title: widget.mediaItem.title,
      headers: stream.headers,
      startSeconds: resumeSec > 0 ? resumeSec : null,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not launch external player. Make sure MPV or VLC is installed.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  String _formatRemaining(int seconds) {
    final d = Duration(seconds: seconds);
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}m';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = context.watch<LibraryProvider>();
    final isFav = library.isFavorite(widget.mediaItem.id);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = screenWidth > screenHeight;
    final isDesktop =
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ||
        (screenWidth >= 900 && screenHeight >= 600);

    final posterUrl =
        (widget.mediaItem.posterUrl != null &&
            widget.mediaItem.posterUrl!.isNotEmpty)
        ? widget.mediaItem.posterUrl
        : (_details?.posterUrl ?? _tmdbDetails?.posterUrl);
    final backdropUrl =
        _details?.backdropUrl ??
        _tmdbDetails?.backdropUrl ??
        widget.mediaItem.backdropUrl ??
        posterUrl;
    final rawTitle = _details?.title ?? widget.mediaItem.title;
    final parsedTitle = MediaItem.parseTitleTags(rawTitle);
    final title = parsedTitle.cleanTitle;
    final languageTag =
        _details?.effectiveLanguageTag ??
        widget.mediaItem.effectiveLanguageTag ??
        parsedTitle.languageTag;
    final desc =
        _details?.description ?? 'No description available for this title.';
    final year = _details?.year ?? widget.mediaItem.year;
    final rating =
        _details?.imdbRating ?? widget.mediaItem.rating?.toStringAsFixed(1);
    final isSeries = _details?.isSeries ?? widget.mediaItem.isSeries;

    final currentSeasonEps =
        (isSeries && _details != null && _details!.seasons.isNotEmpty)
        ? _details!
              .seasons[_selectedSeasonIdx.clamp(
                0,
                _details!.seasons.length - 1,
              )]
              .episodes
        : <Episode>[];

    final double mobileHeaderHeight = isLandscape
        ? (_isTrailerPlaying
              ? (screenHeight * 0.85).clamp(280.0, 480.0)
              : (screenHeight * 0.65).clamp(240.0, 360.0))
        : (screenWidth * 9 / 16).clamp(220.0, 320.0);
    final double headerHeight = isDesktop
        ? (_isTrailerPlaying ? 600.0 : 500.0)
        : mobileHeaderHeight;

    return PopScope(
      canPop: !_isTrailerFullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isTrailerFullscreen) {
          _toggleTrailerFullscreen();
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: MouseRegion(
          onHover: (_) => _onUserInteraction(),
          child: Listener(
            onPointerDown: (_) => _onUserInteraction(),
            child: Stack(
              children: [
                // 1. Ambient / Blurred Cinematic Backdrop or Live Trailer Video (fills top area)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: headerHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_isTrailerPlaying &&
                          _trailerVideoController != null) ...[
                        // Full view trailer without padding or feathering, matching header image
                        Center(
                          child: Video(
                            controller: _trailerVideoController!,
                            controls: NoVideoControls,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ] else if (backdropUrl != null &&
                          backdropUrl.isNotEmpty) ...[
                        CachedNetworkImage(
                          imageUrl: backdropUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorWidget: (_, _, _) =>
                              Container(color: theme.scaffoldBackgroundColor),
                        ),
                      ] else ...[
                        Container(color: theme.scaffoldBackgroundColor),
                      ],

                      // Multi-stop gradients for seamless blend into obsidian background
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(
                                alpha: _isTrailerPlaying ? 0.35 : 0.45,
                              ),
                              Colors.transparent,
                              theme.scaffoldBackgroundColor.withValues(
                                alpha: 0.85,
                              ),
                              theme.scaffoldBackgroundColor,
                            ],
                            stops: const [0.0, 0.25, 0.75, 1.0],
                          ),
                        ),
                      ),
                      if (isDesktop && !_isTrailerPlaying)
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                theme.scaffoldBackgroundColor.withValues(
                                  alpha: 0.9,
                                ),
                                theme.scaffoldBackgroundColor.withValues(
                                  alpha: 0.4,
                                ),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 0.9],
                            ),
                          ),
                        ),

                      if (_isTrailerLoading)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: context.tokens.surfaceElevated.withValues(
                                alpha: 0.85,
                              ),
                              borderRadius: context.tokens.borderRadiusMd,
                              border: Border.all(
                                color: context.tokens.borderSubtle,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: context.tokens.primaryAccent,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Loading Official Trailer...',
                                  style: TextStyle(
                                    color: context.tokens.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 2. Scrollable Body inside Centered Max-Width Container
                SafeArea(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (_) {
                      _onUserInteraction();
                      return false;
                    },
                    child: CustomScrollView(
                      slivers: [
                        // Top App Bar Icons (Floating Back, Trailer Controls, and Watchlist)
                        SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1240),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                child: SizedBox(
                                  height: 44,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (Platform.isWindows ||
                                          Platform.isLinux ||
                                          Platform.isMacOS)
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: InkWell(
                                            onTap: () {
                                              _stopTrailer();
                                              Navigator.of(context).pop();
                                            },
                                            borderRadius:
                                                context.tokens.borderRadiusPill,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: context
                                                    .tokens
                                                    .surfaceCard
                                                    .withValues(alpha: 0.75),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: context
                                                      .tokens
                                                      .borderSubtle,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.arrow_back_rounded,
                                                color:
                                                    context.tokens.textPrimary,
                                                size: 22,
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (_isTrailerPlaying)
                                        Align(
                                          alignment: Alignment.center,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: _toggleMuteTrailer,
                                                borderRadius: context
                                                    .tokens
                                                    .borderRadiusPill,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: context
                                                        .tokens
                                                        .surfaceCard
                                                        .withValues(
                                                          alpha: 0.75,
                                                        ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: context
                                                          .tokens
                                                          .borderSubtle,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    _isTrailerMuted
                                                        ? Icons
                                                              .volume_off_rounded
                                                        : Icons
                                                              .volume_up_rounded,
                                                    color: context
                                                        .tokens
                                                        .textPrimary,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              InkWell(
                                                onTap: _toggleTrailerFullscreen,
                                                borderRadius: context
                                                    .tokens
                                                    .borderRadiusPill,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: context
                                                        .tokens
                                                        .surfaceCard
                                                        .withValues(
                                                          alpha: 0.75,
                                                        ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: context
                                                          .tokens
                                                          .borderSubtle,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    _isTrailerFullscreen
                                                        ? Icons
                                                              .fullscreen_exit_rounded
                                                        : Icons
                                                              .fullscreen_rounded,
                                                    color: context
                                                        .tokens
                                                        .textPrimary,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Consumer<CastProvider>(
                                              builder: (context, cast, _) {
                                                final isCasting =
                                                    cast.isConnected;
                                                return InkWell(
                                                  onTap: () {
                                                    CastDialog.show(
                                                      context,
                                                      mediaItem:
                                                          widget.mediaItem,
                                                    );
                                                  },
                                                  borderRadius: context
                                                      .tokens
                                                      .borderRadiusPill,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 14,
                                                          vertical: 8,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: isCasting
                                                          ? theme
                                                                .colorScheme
                                                                .primary
                                                                .withValues(
                                                                  alpha: 0.25,
                                                                )
                                                          : context
                                                                .tokens
                                                                .surfaceCard
                                                                .withValues(
                                                                  alpha: 0.75,
                                                                ),
                                                      borderRadius: context
                                                          .tokens
                                                          .borderRadiusPill,
                                                      border: Border.all(
                                                        color: isCasting
                                                            ? theme
                                                                  .colorScheme
                                                                  .primary
                                                            : context
                                                                  .tokens
                                                                  .borderSubtle,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          isCasting
                                                              ? Icons
                                                                    .cast_connected_rounded
                                                              : Icons
                                                                    .cast_rounded,
                                                          color: isCasting
                                                              ? theme
                                                                    .colorScheme
                                                                    .primary
                                                              : context
                                                                    .tokens
                                                                    .textPrimary,
                                                          size: 18,
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Text(
                                                          isCasting
                                                              ? (cast
                                                                        .connectedDevice
                                                                        ?.name ??
                                                                    'Casting')
                                                              : 'Cast',
                                                          style: TextStyle(
                                                            color: isCasting
                                                                ? theme
                                                                      .colorScheme
                                                                      .primary
                                                                : context
                                                                      .tokens
                                                                      .textPrimary,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            if (isDesktop &&
                                                screenWidth >= 1100) ...[
                                              const SizedBox(width: 10),
                                              InkWell(
                                                onTap: () =>
                                                    library.toggleFavorite(
                                                      widget.mediaItem,
                                                    ),
                                                borderRadius: context
                                                    .tokens
                                                    .borderRadiusPill,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: context
                                                        .tokens
                                                        .surfaceCard
                                                        .withValues(
                                                          alpha: 0.75,
                                                        ),
                                                    borderRadius: context
                                                        .tokens
                                                        .borderRadiusPill,
                                                    border: Border.all(
                                                      color: isFav
                                                          ? theme
                                                                .colorScheme
                                                                .primary
                                                                .withValues(
                                                                  alpha: 0.8,
                                                                )
                                                          : context
                                                                .tokens
                                                                .borderSubtle,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        isFav
                                                            ? Icons
                                                                  .check_rounded
                                                            : Icons
                                                                  .bookmark_border_rounded,
                                                        color: isFav
                                                            ? theme
                                                                  .colorScheme
                                                                  .primary
                                                            : context
                                                                  .tokens
                                                                  .textPrimary,
                                                        size: 18,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        isFav ? 'In Watchlist' : 'Add to Watchlist',
                                                        style: TextStyle(
                                                          color: isFav
                                                              ? theme
                                                                    .colorScheme
                                                                    .primary
                                                              : context
                                                                    .tokens
                                                                    .textPrimary,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Hero & Media Info Section (Animates downward & dims when trailer is playing)
                        SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1240),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  24,
                                  8,
                                  24,
                                  48 + MediaQuery.of(context).padding.bottom,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeInOutCubic,
                                  margin: EdgeInsets.only(
                                    top: isDesktop
                                        ? (_isTrailerPlaying ? 220.0 : 0.0)
                                        : (mobileHeaderHeight - 40.0),
                                  ),
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 350),
                                    opacity:
                                        (isDesktop &&
                                            _isTrailerPlaying &&
                                            !_isCursorMoving)
                                        ? 0.2
                                        : 1.0,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (_isLoading)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            child: LinearProgressIndicator(
                                              color: theme.colorScheme.primary,
                                              backgroundColor: Colors.white12,
                                              minHeight: 2,
                                            ),
                                          ),

                                        // Desktop 2-Column Hero / Mobile Stacked
                                        if (isDesktop)
                                          _buildDesktopHero(
                                            context,
                                            title: title,
                                            posterUrl: posterUrl,
                                            year: year,
                                            rating: rating,
                                            isSeries: isSeries,
                                            desc: desc,
                                            isFav: isFav,
                                            languageTag: languageTag,
                                          )
                                        else
                                          _buildMobileHero(
                                            context,
                                            title: title,
                                            posterUrl: posterUrl,
                                            year: year,
                                            rating: rating,
                                            isSeries: isSeries,
                                            desc: desc,
                                            isFav: isFav,
                                            languageTag: languageTag,
                                          ),

                                        const SizedBox(height: 32),

                                        // TV Series Season Selector & Episodes Grid/List
                                        if (isSeries &&
                                            _details != null &&
                                            _details!.seasons.isNotEmpty) ...[
                                          _buildSeasonHeader(context),
                                          const SizedBox(height: 16),
                                          _buildEpisodesSection(
                                            context,
                                            currentSeasonEps,
                                            screenWidth,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Fullscreen Trailer Overlay
                if (_isTrailerFullscreen &&
                    _isTrailerPlaying &&
                    _trailerVideoController != null)
                  Positioned.fill(
                    child: Container(
                      color: theme.scaffoldBackgroundColor,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            onTap: _togglePauseTrailer,
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: Video(
                                controller: _trailerVideoController!,
                                controls: NoVideoControls,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              child: SizedBox(
                                height: 44,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (Platform.isWindows ||
                                        Platform.isLinux ||
                                        Platform.isMacOS)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: InkWell(
                                          onTap: _toggleTrailerFullscreen,
                                          borderRadius:
                                              context.tokens.borderRadiusPill,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: context.tokens.surfaceCard
                                                  .withValues(alpha: 0.75),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color:
                                                    context.tokens.borderSubtle,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.arrow_back_rounded,
                                              color: context.tokens.textPrimary,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Align(
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: _toggleMuteTrailer,
                                            borderRadius:
                                                context.tokens.borderRadiusPill,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: context
                                                    .tokens
                                                    .surfaceCard
                                                    .withValues(alpha: 0.75),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: context
                                                      .tokens
                                                      .borderSubtle,
                                                ),
                                              ),
                                              child: Icon(
                                                _isTrailerMuted
                                                    ? Icons.volume_off_rounded
                                                    : Icons.volume_up_rounded,
                                                color:
                                                    context.tokens.textPrimary,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          InkWell(
                                            onTap: _toggleTrailerFullscreen,
                                            borderRadius:
                                                context.tokens.borderRadiusPill,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: context
                                                    .tokens
                                                    .surfaceCard
                                                    .withValues(alpha: 0.75),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: context
                                                      .tokens
                                                      .borderSubtle,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.fullscreen_exit_rounded,
                                                color:
                                                    context.tokens.textPrimary,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// TMDB-Style Subheader: Certification Badge, Release Date (Country), Genres, Runtime
  Widget _buildTmdbSubheader(
    BuildContext context, {
    required bool isSeries,
    required String? year,
    required String? rating,
  }) {
    final theme = Theme.of(context);
    final cert =
        _tmdbDetails?.certification ?? (isSeries ? 'TV-14' : 'U/A 13+');
    final releaseDateStr =
        _tmdbDetails?.releaseDateWithCountry ??
        (_tmdbDetails?.releaseDate ?? year);
    final genresList = (_tmdbDetails != null && _tmdbDetails!.genres.isNotEmpty)
        ? _tmdbDetails!.genres
        : (_details?.genres ?? []);
    final runtimeStr = _tmdbDetails?.formattedRuntime ?? _details?.duration;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        // IMDb Rating Badge (if available)
        if (rating != null && rating.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: context.tokens.borderRadiusXs,
              border: Border.all(color: Colors.amber.withValues(alpha: 0.7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                const SizedBox(width: 3),
                Text(
                  rating,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Certification Badge (e.g. U/A 13+ or PG-13)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: context.tokens.borderRadiusXs,
            border: Border.all(color: Colors.white38, width: 0.8),
          ),
          child: Text(
            cert,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
        ),

        // Release Date with Country (e.g. "07/30/2026 (IN)")
        if (releaseDateStr != null && releaseDateStr.isNotEmpty)
          Text(
            releaseDateStr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

        // Genres
        if (genresList.isNotEmpty) ...[
          const Text('•', style: TextStyle(color: Colors.white38)),
          Text(
            genresList.join(', '),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],

        // Duration / Episodes
        if (runtimeStr != null && runtimeStr.isNotEmpty) ...[
          const Text('•', style: TextStyle(color: Colors.white38)),
          Text(
            runtimeStr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ] else if (isSeries &&
            _details != null &&
            _details!.seasons.isNotEmpty) ...[
          const Text('•', style: TextStyle(color: Colors.white38)),
          Text(
            '${_details!.seasons.fold(0, (sum, s) => sum + s.episodes.length)} Episodes',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],

        // Dubs count
        if (_details != null && _details!.dubs.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: context.tokens.borderRadiusXs,
              border: Border.all(color: Colors.white24, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.record_voice_over_rounded,
                  size: 12,
                  color: Colors.white70,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_details!.dubs.length} Audios',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

        // Skip intro
        if (isSeries)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: context.tokens.borderRadiusXs,
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fast_forward_rounded,
                  size: 12,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Skip Intro Enabled',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// TMDB Circular User Score Badge (e.g. 79% User Score)
  Widget _buildUserScoreBadge(int score) {
    final double progress = (score.clamp(0, 100)) / 100.0;
    final Color ringColor = score >= 70
        ? context.tokens.liveColor
        : (score >= 40 ? context.tokens.vipColor : context.tokens.errorColor);
    final Color trackColor = ringColor.withValues(alpha: 0.25);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: context.tokens.surfaceElevated,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3.5,
                  backgroundColor: trackColor,
                  valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$score',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Text(
                      '%',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'User\nScore',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.15,
          ),
        ),
      ],
    );
  }

  /// TMDB Featured Crew Grid (e.g. Stan Lee - Characters, Destin Daniel Cretton - Director)
  Widget _buildFeaturedCrewGrid(List<TmdbCrewMember> crew) {
    if (crew.isEmpty) return const SizedBox.shrink();

    final displayCrew = crew.take(6).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Wrap(
        spacing: 36,
        runSpacing: 14,
        children: displayCrew.map((member) {
          return SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  member.role,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Desktop / Landscape 2-Column Hero: Left Poster Card + Right Details Column
  Widget _buildDesktopHero(
    BuildContext context, {
    required String title,
    required String? posterUrl,
    required String? year,
    required String? rating,
    required bool isSeries,
    required String desc,
    required bool isFav,
    String? languageTag,
  }) {
    final theme = Theme.of(context);
    final library = context.read<LibraryProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 1000;
    final double posterWidth = isCompact ? 150.0 : 210.0;
    final double posterHeight = isCompact ? 225.0 : 315.0;
    final double columnSpacing = isCompact ? 20.0 : 28.0;
    final double titleFontSize = isCompact ? 24.0 : 32.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Poster Card (Elevated with Drop Shadow)
        Container(
          width: posterWidth,
          height: posterHeight,
          decoration: context.tokens.getShapeDecoration(
            color: theme.colorScheme.surface,
            radius: context.tokens.borderRadiusMd.topLeft.x,
            side: BorderSide(color: context.tokens.borderSubtle),
          ),
          child: ClipPath(
            clipper: ShapeBorderClipper(
              shape: context.tokens.getShapeBorder(
                radius: context.tokens.borderRadiusMd.topLeft.x,
                side: BorderSide(color: context.tokens.borderSubtle),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (posterUrl != null && posterUrl.isNotEmpty)
                  (widget.heroTag != null
                      ? Hero(
                          tag: widget.heroTag!,
                          child: Material(
                            type: MaterialType.transparency,
                            child: ClipRRect(
                              borderRadius: context.tokens.borderRadiusMd,
                              child: CachedNetworkImage(
                                imageUrl: posterUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 320,
                                memCacheHeight: 460,
                                maxWidthDiskCache: 500,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                placeholder: (_, _) =>
                                    Container(color: theme.colorScheme.surface),
                                errorWidget: (_, _, _) => Container(
                                  color: theme.colorScheme.surface,
                                  child: Icon(
                                    Icons.movie,
                                    size: 48,
                                    color: context.tokens.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 320,
                          memCacheHeight: 460,
                          maxWidthDiskCache: 500,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          placeholder: (_, _) =>
                              Container(color: theme.colorScheme.surface),
                          errorWidget: (_, _, _) => Container(
                            color: theme.colorScheme.surface,
                            child: Icon(
                              Icons.movie,
                              size: 48,
                              color: context.tokens.textMuted,
                            ),
                          ),
                        ))
                else
                  Container(
                    color: theme.colorScheme.surface,
                    child: Icon(
                      Icons.movie,
                      size: 48,
                      color: context.tokens.textMuted,
                    ),
                  ),

                // Quality Badge Pill (Bottom-Left)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.tokens.surfaceCard.withValues(alpha: 0.85),
                      borderRadius: context.tokens.borderRadiusXs,
                      border: Border.all(
                        color: context.tokens.borderSubtle,
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      '4K ULTRA HD',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: context.tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: columnSpacing),

        // Right Column: Title, Metadata, Action Buttons, Synopsis, Cast
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Format Pill & Language Tag
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isSeries
                          ? context.tokens.secondaryAccent.withValues(
                              alpha: 0.15,
                            )
                          : context.tokens.primaryAccent.withValues(
                              alpha: 0.15,
                            ),
                      borderRadius: context.tokens.borderRadiusXs,
                      border: Border.all(
                        color: isSeries
                            ? context.tokens.secondaryAccent.withValues(
                                alpha: 0.6,
                              )
                            : context.tokens.primaryAccent.withValues(
                                alpha: 0.6,
                              ),
                      ),
                    ),
                    child: Text(
                      isSeries ? 'TV SERIES' : 'FEATURE FILM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: isSeries
                            ? context.tokens.secondaryAccent
                            : context.tokens.primaryAccent,
                      ),
                    ),
                  ),
                  if (languageTag != null && languageTag.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.tokens.surfaceElevated,
                        borderRadius: context.tokens.borderRadiusXs,
                        border: Border.all(color: context.tokens.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.translate_rounded,
                            size: 11,
                            color: context.tokens.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            languageTag.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: context.tokens.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: context.tokens.textPrimary,
                  shadows: [
                    Shadow(blurRadius: 12, color: context.tokens.shadowColor),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // TMDB-Style Subheader (Certification, Country Release Date, Genres, Runtime)
              _buildTmdbSubheader(
                context,
                isSeries: isSeries,
                year: year,
                rating: rating,
              ),
              const SizedBox(height: 16),

              // Action Buttons Row (Responsive Wrap - Never Overflows!)
              Builder(
                builder: (context) {
                  final currentSeason = isSeries
                      ? (_selectedSeasonIdx + 1)
                      : null;
                  final currentEpisode = isSeries
                      ? (_selectedEpisodeIdx + 1)
                      : null;
                  final history = library.getHistoryItem(
                    widget.mediaItem.id,
                    season: currentSeason,
                    episode: currentEpisode,
                  );
                  final resumeSec = library.getResumePosition(
                    widget.mediaItem.id,
                    season: currentSeason,
                    episode: currentEpisode,
                  );
                  final bool hasResume = resumeSec > 0;
                  final userScore =
                      _tmdbDetails?.userScore ??
                      (_tmdbDetails?.rating != null
                          ? (_tmdbDetails!.rating! * 10).round()
                          : null);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (userScore != null && userScore > 0)
                            _buildUserScoreBadge(userScore),

                          // Play / Resume Button
                          SizedBox(
                            height: 42,
                            child: ElevatedButton.icon(
                              autofocus: true,
                              onPressed: () => _playMedia(
                                season: isSeries ? (_selectedSeasonIdx + 1) : 0,
                                episode: isSeries
                                    ? (_selectedEpisodeIdx + 1)
                                    : 0,
                                startPositionSeconds: hasResume
                                    ? resumeSec
                                    : null,
                              ),
                              icon: Icon(
                                Icons.play_arrow_rounded,
                                size: 24,
                                color: theme.colorScheme.onPrimary,
                              ),
                              label: Text(
                                hasResume
                                    ? (isSeries
                                          ? 'Resume S${_selectedSeasonIdx + 1}:E${_selectedEpisodeIdx + 1}'
                                          : 'Resume')
                                    : (isSeries
                                          ? 'Play S${_selectedSeasonIdx + 1}:E${_selectedEpisodeIdx + 1}'
                                          : 'Watch Movie'),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.tokens.textPrimary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: context.tokens.borderRadiusSm,
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                          if (hasResume)
                            Tooltip(
                              message: 'Watch from beginning',
                              child: SizedBox(
                                height: 42,
                                width: 42,
                                child: OutlinedButton(
                                  onPressed: () => _playMedia(
                                    season: isSeries ? currentSeason! : 0,
                                    episode: isSeries ? currentEpisode! : 0,
                                    startPositionSeconds: 0,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: context.tokens.surfaceCard
                                        .withValues(alpha: 0.5),
                                    side: BorderSide(
                                      color: context.tokens.borderSubtle,
                                    ),
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          context.tokens.borderRadiusSm,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.replay_rounded,
                                    color: context.tokens.textSecondary,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),

                          // Watchlist Button
                          SizedBox(
                            height: 42,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  library.toggleFavorite(widget.mediaItem),
                              icon: Icon(
                                isFav ? Icons.check_rounded : Icons.add_rounded,
                                color: isFav
                                    ? theme.colorScheme.primary
                                    : context.tokens.textPrimary,
                                size: 19,
                              ),
                              label: Text(
                                isFav ? 'In Watchlist' : 'Watchlist',
                                style: TextStyle(
                                  color: isFav
                                      ? theme.colorScheme.primary
                                      : context.tokens.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: context.tokens.surfaceCard
                                    .withValues(alpha: 0.5),
                                side: BorderSide(
                                  color: isFav
                                      ? theme.colorScheme.primary.withValues(
                                          alpha: 0.8,
                                        )
                                      : context.tokens.borderSubtle,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: context.tokens.borderRadiusSm,
                                ),
                              ),
                            ),
                          ),

                          // External Player Button
                          Tooltip(
                            message: 'Open in External Player (VLC / MPV)',
                            child: SizedBox(
                              height: 42,
                              width: 42,
                              child: OutlinedButton(
                                onPressed: () => _playMedia(
                                  season: isSeries
                                      ? (_selectedSeasonIdx + 1)
                                      : 0,
                                  episode: isSeries
                                      ? (_selectedEpisodeIdx + 1)
                                      : 0,
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: context.tokens.surfaceCard
                                      .withValues(alpha: 0.5),
                                  side: BorderSide(
                                    color: context.tokens.borderSubtle,
                                  ),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: context.tokens.borderRadiusSm,
                                  ),
                                ),
                                child: Icon(
                                  Icons.open_in_new_rounded,
                                  color: context.tokens.textSecondary,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),

                          // TMDB Watch Trailer / Stop Trailer Button
                          if (_tmdbDetails?.trailerUrl != null ||
                              _tmdbDetails?.trailerYoutubeKey != null)
                            SizedBox(
                              height: 42,
                              child: ElevatedButton.icon(
                                onPressed: _isTrailerPlaying
                                    ? _stopTrailer
                                    : _watchTrailer,
                                icon: Icon(
                                  _isTrailerPlaying
                                      ? Icons.stop_circle_outlined
                                      : Icons.play_circle_outline_rounded,
                                  color: context.tokens.textPrimary,
                                  size: 19,
                                ),
                                label: Text(
                                  _isTrailerPlaying
                                      ? 'Stop Trailer'
                                      : 'Watch Trailer',
                                  style: TextStyle(
                                    color: context.tokens.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isTrailerPlaying
                                      ? context.tokens.surfaceElevated
                                      : context.tokens.primaryAccent,
                                  foregroundColor: context.tokens.textPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: context.tokens.borderRadiusSm,
                                  ),
                                  elevation: 3,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (hasResume && history != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            SizedBox(
                              width: 160,
                              child: ClipRRect(
                                borderRadius: context.tokens.borderRadiusXs,
                                child: LinearProgressIndicator(
                                  value: history.progress,
                                  minHeight: 4,
                                  backgroundColor: Colors.white24,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              history.totalSeconds > 0
                                  ? '${_formatRemaining(history.totalSeconds - history.positionSeconds)} left'
                                  : 'Resumed at ${_formatDuration(Duration(seconds: history.positionSeconds))}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
              // TMDB Tagline
              if (_tmdbDetails?.tagline != null &&
                  _tmdbDetails!.tagline!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _tmdbDetails!.tagline!,
                  style: TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Overview (Storyline)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (_tmdbDetails?.overview != null &&
                              _tmdbDetails!.overview!.isNotEmpty)
                          ? _tmdbDetails!.overview!
                          : desc,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Featured Crew Grid (TMDB Style)
              if (_tmdbDetails != null && _tmdbDetails!.crew.isNotEmpty)
                _buildFeaturedCrewGrid(_tmdbDetails!.crew),

              // Cast & Director section
              _buildCastSection(context),
            ],
          ),
        ),
      ],
    );
  }

  /// Mobile Stacked Hero
  Widget _buildMobileHero(
    BuildContext context, {
    required String title,
    required String? posterUrl,
    required String? year,
    required String? rating,
    required bool isSeries,
    required String desc,
    required bool isFav,
    String? languageTag,
  }) {
    final theme = Theme.of(context);
    final library = context.read<LibraryProvider>();

    final double posterWidth = 108;
    final double posterHeight = 156;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row: Poster Card (Hero) on Left + Metadata on Right
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster Card with Hero Animation
            Container(
              width: posterWidth,
              height: posterHeight,
              decoration: context.tokens.getShapeDecoration(
                color: theme.colorScheme.surface,
                radius: context.tokens.borderRadiusSm.topLeft.x,
                side: BorderSide(color: context.tokens.borderSubtle),
                shadows: context.tokens.getCardShadows(),
              ),
              child: ClipPath(
                clipper: ShapeBorderClipper(
                  shape: context.tokens.getShapeBorder(
                    radius: context.tokens.borderRadiusSm.topLeft.x,
                    side: BorderSide(color: context.tokens.borderSubtle),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (posterUrl != null && posterUrl.isNotEmpty)
                      (widget.heroTag != null
                          ? Hero(
                              tag: widget.heroTag!,
                              child: Material(
                                type: MaterialType.transparency,
                                child: ClipRRect(
                                  borderRadius: context.tokens.borderRadiusSm,
                                  child: CachedNetworkImage(
                                    imageUrl: posterUrl,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 320,
                                    memCacheHeight: 460,
                                    maxWidthDiskCache: 500,
                                    fadeInDuration: Duration.zero,
                                    fadeOutDuration: Duration.zero,
                                    placeholder: (_, _) => Container(
                                      color: theme.colorScheme.surface,
                                    ),
                                    errorWidget: (_, _, _) => Container(
                                      color: theme.colorScheme.surface,
                                      child: Icon(
                                        Icons.movie_outlined,
                                        size: 32,
                                        color: context.tokens.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: posterUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 320,
                              memCacheHeight: 460,
                              maxWidthDiskCache: 500,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              placeholder: (_, _) =>
                                  Container(color: theme.colorScheme.surface),
                              errorWidget: (_, _, _) => Container(
                                color: theme.colorScheme.surface,
                                child: Icon(
                                  Icons.movie_outlined,
                                  size: 32,
                                  color: context.tokens.textMuted,
                                ),
                              ),
                            ))
                    else
                      Container(
                        color: theme.colorScheme.surface,
                        child: Icon(
                          Icons.movie_outlined,
                          size: 32,
                          color: context.tokens.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Metadata Column (Format pill, Title, TMDB Subheader, User Score)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Format Pill & Language Tag
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: isSeries
                              ? context.tokens.secondaryAccent.withValues(
                                  alpha: 0.15,
                                )
                              : context.tokens.primaryAccent.withValues(
                                  alpha: 0.15,
                                ),
                          borderRadius: context.tokens.borderRadiusXs,
                          border: Border.all(
                            color: isSeries
                                ? context.tokens.secondaryAccent.withValues(
                                    alpha: 0.6,
                                  )
                                : context.tokens.primaryAccent.withValues(
                                    alpha: 0.6,
                                  ),
                          ),
                        ),
                        child: Text(
                          isSeries ? 'TV SERIES' : 'FEATURE FILM',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: isSeries
                                ? context.tokens.secondaryAccent
                                : context.tokens.primaryAccent,
                          ),
                        ),
                      ),
                      if (languageTag != null && languageTag.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: context.tokens.surfaceElevated,
                            borderRadius: context.tokens.borderRadiusXs,
                            border: Border.all(
                              color: context.tokens.borderSubtle,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.translate_rounded,
                                size: 10,
                                color: context.tokens.textSecondary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                languageTag.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: context.tokens.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: context.tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // TMDB Subheader
                  _buildTmdbSubheader(
                    context,
                    isSeries: isSeries,
                    year: year,
                    rating: rating,
                  ),
                  const SizedBox(height: 8),

                  // TMDB Circular User Score Badge
                  Builder(
                    builder: (context) {
                      final userScore =
                          _tmdbDetails?.userScore ??
                          (_tmdbDetails?.rating != null
                              ? (_tmdbDetails!.rating! * 10).round()
                              : null);
                      if (userScore != null && userScore > 0) {
                        return _buildUserScoreBadge(userScore);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Action Buttons Row (Play + Watchlist + External)
        Builder(
          builder: (context) {
            final currentSeason = isSeries ? (_selectedSeasonIdx + 1) : null;
            final currentEpisode = isSeries ? (_selectedEpisodeIdx + 1) : null;
            final history = library.getHistoryItem(
              widget.mediaItem.id,
              season: currentSeason,
              episode: currentEpisode,
            );
            final resumeSec = library.getResumePosition(
              widget.mediaItem.id,
              season: currentSeason,
              episode: currentEpisode,
            );
            final bool hasResume = resumeSec > 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () => _playMedia(
                            season: isSeries ? (_selectedSeasonIdx + 1) : 0,
                            episode: isSeries ? (_selectedEpisodeIdx + 1) : 0,
                          ),
                          icon: const Icon(
                            Icons.play_arrow_rounded,
                            size: 24,
                            color: Colors.black,
                          ),
                          label: Text(
                            hasResume
                                ? (isSeries
                                      ? 'Resume S${_selectedSeasonIdx + 1}:E${_selectedEpisodeIdx + 1}'
                                      : 'Resume')
                                : (isSeries
                                      ? 'Play S${_selectedSeasonIdx + 1}:E${_selectedEpisodeIdx + 1}'
                                      : 'Play Movie'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: context.tokens.borderRadiusSm,
                            ),
                            elevation: 3,
                          ),
                        ),
                      ),
                    ),
                    if (hasResume) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _playMedia(
                          season: isSeries ? currentSeason! : 0,
                          episode: isSeries ? currentEpisode! : 0,
                          startPositionSeconds: 0,
                        ),
                        borderRadius: context.tokens.borderRadiusSm,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: context.tokens.borderRadiusSm,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: const Icon(
                            Icons.replay_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => library.toggleFavorite(widget.mediaItem),
                      borderRadius: context.tokens.borderRadiusSm,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: context.tokens.surfaceElevated.withValues(
                            alpha: 0.8,
                          ),
                          borderRadius: context.tokens.borderRadiusSm,
                          border: Border.all(
                            color: isFav
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.8,
                                  )
                                : context.tokens.borderSubtle,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFav ? Icons.check_rounded : Icons.add_rounded,
                              color: isFav
                                  ? theme.colorScheme.primary
                                  : context.tokens.textPrimary,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isFav ? 'In List' : 'My List',
                              style: TextStyle(
                                color: isFav
                                    ? theme.colorScheme.primary
                                    : context.tokens.textPrimary,
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
                if (_tmdbDetails?.trailerUrl != null ||
                    _tmdbDetails?.trailerYoutubeKey != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: _isTrailerPlaying
                          ? _stopTrailer
                          : _watchTrailer,
                      icon: Icon(
                        _isTrailerPlaying
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_outline_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: Text(
                        _isTrailerPlaying
                            ? 'Stop Trailer'
                            : 'Watch Official Trailer',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTrailerPlaying
                            ? context.tokens.surfaceElevated
                            : context.tokens.primaryAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: context.tokens.borderRadiusSm,
                        ),
                      ),
                    ),
                  ),
                ],
                if (hasResume && history != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: context.tokens.borderRadiusXs,
                          child: LinearProgressIndicator(
                            value: history.progress,
                            minHeight: 4,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        history.totalSeconds > 0
                            ? '${_formatRemaining(history.totalSeconds - history.positionSeconds)} left'
                            : 'Resumed at ${_formatDuration(Duration(seconds: history.positionSeconds))}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
        // TMDB Tagline
        if (_tmdbDetails?.tagline != null &&
            _tmdbDetails!.tagline!.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            _tmdbDetails!.tagline!,
            style: TextStyle(
              fontSize: 13.5,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
        const SizedBox(height: 12),

        // Overview
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          (_tmdbDetails?.overview != null && _tmdbDetails!.overview!.isNotEmpty)
              ? _tmdbDetails!.overview!
              : desc,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),

        // Featured Crew Grid (TMDB Style)
        if (_tmdbDetails != null && _tmdbDetails!.crew.isNotEmpty)
          _buildFeaturedCrewGrid(_tmdbDetails!.crew),

        // Cast & Director
        _buildCastSection(context),
      ],
    );
  }

  /// TMDB Enriched Cast & Director Section (Interactive Avatar Carousel)
  Widget _buildCastSection(BuildContext context) {
    final theme = Theme.of(context);
    final cast = _tmdbDetails?.cast ?? [];
    final director = _tmdbDetails?.director ?? _details?.director;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (director != null &&
            director.isNotEmpty &&
            (_tmdbDetails == null || _tmdbDetails!.crew.isEmpty))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.white70),
                children: [
                  const TextSpan(
                    text: 'Director: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(text: director),
                ],
              ),
            ),
          ),

        if (cast.isNotEmpty) ...[
          const Text(
            'Top Cast',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 126,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cast.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, idx) {
                final member = cast[idx];
                return SizedBox(
                  width: 76,
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: member.profileUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: member.profileUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => Container(
                                    color: theme.colorScheme.surface,
                                  ),
                                  errorWidget: (_, _, _) => Container(
                                    color: theme.colorScheme.surface,
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white38,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: theme.colorScheme.surface,
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white38,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (member.character != null &&
                          member.character!.isNotEmpty)
                        Text(
                          member.character!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: Colors.white54,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ] else if (_details?.stars != null && _details!.stars!.isNotEmpty)
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.white70),
              children: [
                const TextSpan(
                  text: 'Starring: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextSpan(text: _details!.stars!),
              ],
            ),
          ),
      ],
    );
  }

  /// Season selector header with dropdown menu and clean episode count
  Widget _buildSeasonHeader(BuildContext context) {
    final theme = Theme.of(context);
    final seasons = _details!.seasons;
    final currentSeason =
        seasons[_selectedSeasonIdx.clamp(0, seasons.length - 1)];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Episodes title with secondary season & count label
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Episodes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: context.tokens.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Season ${currentSeason.seasonNumber} • ${currentSeason.episodes.length} Episodes',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // Season Actions & Selector Dropdown
        Consumer<LibraryProvider>(
          builder: (context, library, _) {
            final epNumbers = currentSeason.episodes
                .map((e) => e.episode)
                .toList();
            final isSeasonWatched = library.isSeasonWatched(
              widget.mediaItem.id,
              currentSeason.seasonNumber,
              epNumbers,
            );

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mark Whole Season as Watched Button
                Tooltip(
                  message: isSeasonWatched
                      ? 'Mark Season ${currentSeason.seasonNumber} as Unwatched'
                      : 'Mark Season ${currentSeason.seasonNumber} as Watched',
                  child: InkWell(
                    onTap: () async {
                      await library.toggleSeasonWatched(
                        seriesId: widget.mediaItem.id,
                        season: currentSeason.seasonNumber,
                        episodeNumbers: epNumbers,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isSeasonWatched
                                  ? 'Marked Season ${currentSeason.seasonNumber} as unwatched'
                                  : 'Marked Season ${currentSeason.seasonNumber} as watched',
                              style: TextStyle(
                                color: context.tokens.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            duration: const Duration(seconds: 2),
                            backgroundColor: context.tokens.surfaceElevated,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: context.tokens.borderRadiusSm,
                              side: BorderSide(
                                color: context.tokens.borderSubtle,
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    borderRadius: context.tokens.borderRadiusPill,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSeasonWatched
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : context.tokens.surfaceElevated,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSeasonWatched
                              ? theme.colorScheme.primary
                              : context.tokens.borderSubtle,
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.tokens.shadowColor.withValues(
                              alpha: 0.25,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isSeasonWatched
                            ? Icons.done_all_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 18,
                        color: isSeasonWatched
                            ? theme.colorScheme.primary
                            : context.tokens.textSecondary,
                      ),
                    ),
                  ),
                ),

                // Season Selector Dropdown (if multiple seasons)
                if (seasons.length > 1) ...[
                  const SizedBox(width: 8),
                  PopupMenuButton<int>(
                    tooltip: 'Select Season',
                    initialValue: _selectedSeasonIdx,
                    onSelected: (i) {
                      if (i != _selectedSeasonIdx) {
                        setState(() {
                          _selectedSeasonIdx = i;
                          _selectedEpisodeIdx = 0;
                        });
                        _enrichSeasonEpisodesWithTmdb(seasonIdx: i);
                      }
                    },
                    color: context.tokens.surfaceElevated,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: context.tokens.borderRadiusMd,
                      side: BorderSide(
                        color: context.tokens.borderSubtle,
                        width: 1,
                      ),
                    ),
                    itemBuilder: (context) {
                      return List.generate(seasons.length, (i) {
                        final s = seasons[i];
                        final isSelected = _selectedSeasonIdx == i;
                        return PopupMenuItem<int>(
                          value: i,
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                size: 18,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : context.tokens.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Season ${s.seasonNumber}',
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : context.tokens.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${s.episodes.length} eps',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.tokens.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.tokens.surfaceElevated,
                        borderRadius: context.tokens.borderRadiusPill,
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.4,
                          ),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.tokens.shadowColor.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.layers_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Season ${currentSeason.seasonNumber}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: context.tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  /// Responsive Episodes Section: Grid on Desktop, Cards on Mobile
  Widget _buildEpisodesSection(
    BuildContext context,
    List<Episode> episodes,
    double screenWidth,
  ) {
    if (episodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No episode details available for this season.',
            style: TextStyle(color: context.tokens.textMuted),
          ),
        ),
      );
    }

    // On screens >= 750px, use responsive 16:9 grid (Netflix Desktop Web Style)
    if (screenWidth >= 750) {
      final crossAxisCount = screenWidth >= 1150
          ? 4
          : (screenWidth >= 850 ? 3 : 2);

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: episodes.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1.25,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemBuilder: (context, epIdx) {
          final ep = episodes[epIdx];
          final isSelected = _selectedEpisodeIdx == epIdx;
          final library = context.watch<LibraryProvider>();
          final epHistory = library.getHistoryItem(
            widget.mediaItem.id,
            season: ep.season,
            episode: ep.episode,
          );
          final isWatched = library.isEpisodeWatched(
            widget.mediaItem.id,
            ep.season,
            ep.episode,
          );
          return EpisodeGridCard(
            episode: ep,
            isSelected: isSelected,
            progress: epHistory?.progress,
            isWatched: isWatched,
            onToggleWatched: () => library.toggleEpisodeWatched(
              series: widget.mediaItem,
              season: ep.season,
              episode: ep.episode,
            ),
            onTap: () {
              setState(() => _selectedEpisodeIdx = epIdx);
              _playMedia(season: ep.season, episode: ep.episode);
            },
          );
        },
      );
    }

    // On mobile screens (< 750px), use compact horizontal list cards
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: episodes.length,
      itemBuilder: (context, epIdx) {
        final ep = episodes[epIdx];
        final isSelected = _selectedEpisodeIdx == epIdx;
        final library = context.watch<LibraryProvider>();
        final epHistory = library.getHistoryItem(
          widget.mediaItem.id,
          season: ep.season,
          episode: ep.episode,
        );
        final isWatched = library.isEpisodeWatched(
          widget.mediaItem.id,
          ep.season,
          ep.episode,
        );
        return EpisodeTile(
          episode: ep,
          isSelected: isSelected,
          progress: epHistory?.progress,
          isWatched: isWatched,
          onToggleWatched: () => library.toggleEpisodeWatched(
            series: widget.mediaItem,
            season: ep.season,
            episode: ep.episode,
          ),
          onTap: () {
            setState(() => _selectedEpisodeIdx = epIdx);
            _playMedia(season: ep.season, episode: ep.episode);
          },
        );
      },
    );
  }
}
