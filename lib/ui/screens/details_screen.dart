import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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
import 'package:url_launcher/url_launcher.dart';
import '../widgets/cast_dialog.dart';
import '../widgets/episode_tile.dart';
import 'player_screen.dart';

class DetailsScreen extends StatefulWidget {
  final MediaItem mediaItem;

  const DetailsScreen({super.key, required this.mediaItem});

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
  bool _isCursorMoving = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  @override
  void dispose() {
    _autoPlayTrailerTimer?.cancel();
    _cursorDimTimer?.cancel();
    _trailerPlayer?.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);

    // Fetch TMDB enriched metadata in parallel (trailer, cast photos, age certification)
    TmdbService().getEnrichedDetails(
      title: widget.mediaItem.title,
      year: widget.mediaItem.year,
      isSeries: widget.mediaItem.isSeries,
    ).then((tmdb) {
      if (mounted && tmdb != null) {
        setState(() => _tmdbDetails = tmdb);
        if (tmdb.trailerYoutubeKey != null && tmdb.trailerYoutubeKey!.isNotEmpty) {
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
        final history = context.read<LibraryProvider>().getHistoryItem(widget.mediaItem.id);
        if (history != null && history.season != null && history.episode != null) {
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

  Future<void> _enrichSeasonEpisodesWithTmdb({int? tmdbId, int? seasonIdx}) async {
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
      final hasMissing = s.episodes.any((e) => e.thumbnail == null || e.thumbnail!.trim().isEmpty);
      if (hasMissing) {
        TmdbService().getSeasonEpisodes(tvId: tvId, seasonNumber: s.seasonNumber).then((epMap) {
          if (!mounted || epMap.isEmpty) return;
          _applyTmdbToSeason(seasonIdx: i, tmdbEpisodes: epMap);
        });
      }
    }
  }

  void _applyTmdbToSeason({required int seasonIdx, required Map<int, TmdbEpisodeInfo> tmdbEpisodes}) {
    if (_details == null || seasonIdx < 0 || seasonIdx >= _details!.seasons.length) return;
    final targetSeason = _details!.seasons[seasonIdx];
    bool hasChanges = false;
    final updatedEpisodes = targetSeason.episodes.map((ep) {
      final tmdbEp = tmdbEpisodes[ep.episode];
      if (tmdbEp == null) return ep;

      // If episode thumbnail is not available, get it from tmdb
      final bool needsThumb = (ep.thumbnail == null || ep.thumbnail!.trim().isEmpty) &&
          (tmdbEp.stillUrl != null && tmdbEp.stillUrl!.isNotEmpty);
      final bool isGenericTitle = ep.title.isEmpty || RegExp(r'^Episode \d+$', caseSensitive: false).hasMatch(ep.title.trim());
      final bool needsTitle = isGenericTitle && (tmdbEp.name != null && tmdbEp.name!.trim().isNotEmpty);
      final bool needsOverview = (ep.overview == null || ep.overview!.trim().isEmpty) &&
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
      updatedSeasons[seasonIdx] = targetSeason.copyWith(episodes: updatedEpisodes);
      setState(() {
        _details = _details!.copyWith(seasons: updatedSeasons);
      });
    }
  }

  void _scheduleAutoPlayTrailer() {
    _autoPlayTrailerTimer?.cancel();
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
        configuration: const PlayerConfiguration(
          title: 'Exalere Trailer',
        ),
      );
      _trailerVideoController = VideoController(
        _trailerPlayer!,
        configuration: const VideoControllerConfiguration(
          hwdec: 'auto-safe',
        ),
      );

      _trailerPlayer!.stream.completed.listen((completed) {
        if (completed && mounted) {
          _stopTrailer();
        }
      });

      _trailerPlayer!.stream.error.listen((err) {
        debugPrint('Trailer player error: $err');
        if (mounted) {
          _stopTrailer();
        }
      });
    }

    setState(() {
      _isTrailerLoading = true;
    });

    try {
      final streamUrl = await TmdbService().resolveTrailerDirectUrl(key);
      if (!mounted) return;

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
        // Fallback to external application
        final trailerUrl = _tmdbDetails?.trailerUrl;
        if (trailerUrl != null) {
          final uri = Uri.parse(trailerUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      }
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

  Future<void> _playMedia({int season = 0, int episode = 0, int? startPositionSeconds}) async {
    _stopTrailer();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 18),
              const Text(
                'Resolving streaming sources...',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 6),
              const Text(
                'Decrypting tokens and CloudFront policy',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );

    List<StreamSource> streams = [];
    try {
      if (widget.mediaItem.provider == ProviderType.fourKHdHub) {
        streams = await _fourKHdHubProvider.getStreams(widget.mediaItem.id);
      } else {
        streams = await _movieBoxProvider.getStreams(
          subjectId: widget.mediaItem.id,
          season: season,
          episode: episode,
        );
      }
    } catch (e) {
      debugPrint('Stream resolution error: $e');
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog

    if (streams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No active streams found. Try another title or provider.'),
          backgroundColor: theme.colorScheme.error,
        ),
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
        ),
      ),
    );
  }

  Future<void> _openExternalPlayer(StreamSource stream, {int? startPositionSeconds}) async {
    final library = context.read<LibraryProvider>();
    final resumeSec = startPositionSeconds ?? library.getResumePosition(
      widget.mediaItem.id,
      season: _details?.isSeries == true ? (_selectedSeasonIdx + 1) : null,
      episode: _details?.isSeries == true ? (_selectedEpisodeIdx + 1) : null,
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
          content: const Text('Could not launch external player. Make sure MPV or VLC is installed.'),
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
    final isDesktop = screenWidth >= 800;

    final posterUrl = _details?.posterUrl ?? widget.mediaItem.posterUrl;
    final backdropUrl = _details?.backdropUrl ?? widget.mediaItem.backdropUrl ?? posterUrl;
    final title = _details?.title ?? widget.mediaItem.title;
    final desc = _details?.description ?? 'No description available for this title.';
    final year = _details?.year ?? widget.mediaItem.year;
    final rating = _details?.imdbRating ?? widget.mediaItem.rating?.toStringAsFixed(1);
    final isSeries = _details?.isSeries ?? widget.mediaItem.isSeries;

    final currentSeasonEps = (isSeries && _details != null && _details!.seasons.isNotEmpty)
        ? _details!.seasons[_selectedSeasonIdx.clamp(0, _details!.seasons.length - 1)].episodes
        : <Episode>[];

    return Scaffold(
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
                height: isDesktop
                    ? (_isTrailerPlaying ? 600 : 500)
                    : (_isTrailerPlaying ? 420 : 340),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_isTrailerPlaying && _trailerVideoController != null) ...[
                      // Dark ambient scaffold background
                      Container(color: theme.scaffoldBackgroundColor),
                      // Ambient dimmed backdrop beneath the trailer
                      if (backdropUrl != null && backdropUrl.isNotEmpty)
                        Opacity(
                          opacity: 0.16,
                          child: CachedNetworkImage(
                            imageUrl: backdropUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorWidget: (_, _, _) => Container(color: theme.scaffoldBackgroundColor),
                          ),
                        ),
                      // Centered uncropped 16:9 trailer with soft 4-edge feathered blend
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: isDesktop ? 580 : 400,
                            maxWidth: isDesktop ? 1032 : screenWidth,
                          ),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: ShaderMask(
                              shaderCallback: (rect) {
                                return const LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black,
                                    Colors.black,
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.10, 0.90, 1.0],
                                ).createShader(rect);
                              },
                              blendMode: BlendMode.dstIn,
                              child: ShaderMask(
                                shaderCallback: (rect) {
                                  return const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black,
                                      Colors.black,
                                      Colors.transparent,
                                    ],
                                    stops: [0.0, 0.08, 0.82, 1.0],
                                  ).createShader(rect);
                                },
                                blendMode: BlendMode.dstIn,
                                child: Video(
                                  controller: _trailerVideoController!,
                                  controls: NoVideoControls,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else if (backdropUrl != null && backdropUrl.isNotEmpty) ...[
                      CachedNetworkImage(
                        imageUrl: backdropUrl,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorWidget: (_, _, _) => Container(color: theme.scaffoldBackgroundColor),
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
                            Colors.black.withValues(alpha: _isTrailerPlaying ? 0.3 : 0.5),
                            Colors.transparent,
                            theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
                            theme.scaffoldBackgroundColor,
                          ],
                          stops: const [0.0, 0.25, 0.75, 1.0],
                        ),
                      ),
                    ),
                    if (!_isTrailerPlaying)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              theme.scaffoldBackgroundColor.withValues(alpha: 0.9),
                              theme.scaffoldBackgroundColor.withValues(alpha: 0.4),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 0.9],
                          ),
                        ),
                      ),

                    if (_isTrailerLoading)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Loading Official Trailer...',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
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
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      _stopTrailer();
                                      Navigator.of(context).pop();
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                      ),
                                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                                    ),
                                  ),
                                  if (_isTrailerPlaying)
                                    AnimatedOpacity(
                                      duration: const Duration(milliseconds: 300),
                                      opacity: _isCursorMoving ? 1.0 : 0.0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.8),
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(color: Colors.white24, width: 0.8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.5),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE50914),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'TRAILER',
                                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            IconButton(
                                              icon: Icon(
                                                _isTrailerPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              tooltip: _isTrailerPaused ? 'Resume Trailer' : 'Pause Trailer',
                                              onPressed: _togglePauseTrailer,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                _isTrailerMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              tooltip: _isTrailerMuted ? 'Unmute' : 'Mute',
                                              onPressed: _toggleMuteTrailer,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                                              tooltip: 'Stop Trailer',
                                              onPressed: _stopTrailer,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      Consumer<CastProvider>(
                                        builder: (context, cast, _) {
                                          final isCasting = cast.isConnected;
                                          return InkWell(
                                            onTap: () {
                                              CastDialog.show(context, mediaItem: widget.mediaItem);
                                            },
                                            borderRadius: BorderRadius.circular(20),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: isCasting
                                                    ? theme.colorScheme.primary.withValues(alpha: 0.25)
                                                    : Colors.black.withValues(alpha: 0.6),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: isCasting
                                                      ? theme.colorScheme.primary
                                                      : Colors.white.withValues(alpha: 0.15),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isCasting ? Icons.cast_connected_rounded : Icons.cast_rounded,
                                                    color: isCasting ? theme.colorScheme.primary : Colors.white,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    isCasting ? (cast.connectedDevice?.name ?? 'Casting') : 'Cast',
                                                    style: TextStyle(
                                                      color: isCasting ? theme.colorScheme.primary : Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 10),
                                      InkWell(
                                        onTap: () => library.toggleFavorite(widget.mediaItem),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.6),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isFav
                                                  ? theme.colorScheme.primary.withValues(alpha: 0.8)
                                                  : Colors.white.withValues(alpha: 0.15),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isFav ? Icons.check_rounded : Icons.bookmark_border_rounded,
                                                color: isFav ? theme.colorScheme.primary : Colors.white,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                isFav ? 'In Watchlist' : 'Add to Watchlist',
                                                style: TextStyle(
                                                  color: isFav ? theme.colorScheme.primary : Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
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
                          ),
                        ),
                      ),

                      // Hero & Media Info Section (Animates downward & dims when trailer is playing)
                      SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1240),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOutCubic,
                                margin: EdgeInsets.only(
                                  top: _isTrailerPlaying ? (isDesktop ? 220 : 130) : 0,
                                ),
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 350),
                                  opacity: (_isTrailerPlaying && !_isCursorMoving) ? 0.2 : 1.0,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (_isLoading)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 16),
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
                                        ),

                                      const SizedBox(height: 32),

                                      // TV Series Season Selector & Episodes Grid/List
                                      if (isSeries && _details != null && _details!.seasons.isNotEmpty) ...[
                                        _buildSeasonHeader(context),
                                        const SizedBox(height: 16),
                                        _buildEpisodesSection(context, currentSeasonEps, screenWidth),
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
            ],
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
    final cert = _tmdbDetails?.certification ?? (isSeries ? 'TV-14' : 'U/A 13+');
    final releaseDateStr = _tmdbDetails?.releaseDateWithCountry ?? (_tmdbDetails?.releaseDate ?? year);
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
              borderRadius: BorderRadius.circular(4),
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
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.white38, width: 0.8),
          ),
          child: Text(
            cert,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
        ),

        // Release Date with Country (e.g. "07/30/2026 (IN)")
        if (releaseDateStr != null && releaseDateStr.isNotEmpty)
          Text(
            releaseDateStr,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),

        // Genres
        if (genresList.isNotEmpty) ...[
          const Text('•', style: TextStyle(color: Colors.white38)),
          Text(
            genresList.join(', '),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],

        // Duration / Episodes
        if (runtimeStr != null && runtimeStr.isNotEmpty) ...[
          const Text('•', style: TextStyle(color: Colors.white38)),
          Text(
            runtimeStr,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ] else if (isSeries && _details != null && _details!.seasons.isNotEmpty) ...[
          const Text('•', style: TextStyle(color: Colors.white38)),
          Text(
            '${_details!.seasons.fold(0, (sum, s) => sum + s.episodes.length)} Episodes',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],

        // Dubs count
        if (_details != null && _details!.dubs.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.record_voice_over_rounded, size: 12, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  '${_details!.dubs.length} Audios',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white70),
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
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fast_forward_rounded, size: 12, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Skip Intro Enabled',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
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
        ? const Color(0xFF21D07A) // Vibrant Green
        : (score >= 40
            ? const Color(0xFFD2D531) // Yellow-lime
            : const Color(0xFFDB2360)); // Coral Pink
    final Color trackColor = score >= 70
        ? const Color(0xFF204529)
        : (score >= 40
            ? const Color(0xFF423D0F)
            : const Color(0xFF571435));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF081C22),
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
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

  /// Desktop 2-Column Hero: Left Poster Card + Right Details Column
  Widget _buildDesktopHero(
    BuildContext context, {
    required String title,
    required String? posterUrl,
    required String? year,
    required String? rating,
    required bool isSeries,
    required String desc,
    required bool isFav,
  }) {
    final theme = Theme.of(context);
    final library = context.read<LibraryProvider>();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Poster Card (Elevated with Drop Shadow)
        Container(
          width: 210,
          height: 315,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (posterUrl != null && posterUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: posterUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: theme.colorScheme.surface),
                    errorWidget: (_, _, _) => Container(
                      color: theme.colorScheme.surface,
                      child: const Icon(Icons.movie, size: 48, color: Colors.white30),
                    ),
                  )
                else
                  Container(
                    color: theme.colorScheme.surface,
                    child: const Icon(Icons.movie, size: 48, color: Colors.white30),
                  ),

                // Quality Badge Pill (Bottom-Left)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white24, width: 0.6),
                    ),
                    child: const Text(
                      '4K ULTRA HD',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 28),

        // Right Column: Title, Metadata, Action Buttons, Synopsis, Cast
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Format Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSeries
                      ? const Color(0xFF00D2FF).withValues(alpha: 0.15)
                      : const Color(0xFFE50914).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSeries
                        ? const Color(0xFF00D2FF).withValues(alpha: 0.6)
                        : const Color(0xFFE50914).withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  isSeries ? 'TV SERIES' : 'FEATURE FILM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: isSeries ? const Color(0xFF00D2FF) : const Color(0xFFE50914),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Colors.white,
                  shadows: [
                    Shadow(blurRadius: 12, color: Colors.black),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // TMDB-Style Subheader (Certification, Country Release Date, Genres, Runtime)
              _buildTmdbSubheader(context, isSeries: isSeries, year: year, rating: rating),
              const SizedBox(height: 18),

              // Action Buttons Row (Compact & Ergonomic - NOT Stretched!)
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
                  final userScore = _tmdbDetails?.userScore ??
                      (_tmdbDetails?.rating != null ? (_tmdbDetails!.rating! * 10).round() : null);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (userScore != null && userScore > 0) ...[
                            _buildUserScoreBadge(userScore),
                            const SizedBox(width: 20),
                          ],
                          // Solid White Play / Resume Button
                          SizedBox(
                            height: 44,
                            child: ElevatedButton.icon(
                              autofocus: true,
                              onPressed: () => _playMedia(
                                season: isSeries ? (_selectedSeasonIdx + 1) : 0,
                                episode: isSeries ? (_selectedEpisodeIdx + 1) : 0,
                              ),
                              icon: const Icon(Icons.play_arrow_rounded, size: 24, color: Colors.black),
                              label: Text(
                                hasResume
                                    ? (isSeries
                                        ? 'Resume S${_selectedSeasonIdx + 1}:E${_selectedEpisodeIdx + 1}'
                                        : 'Resume')
                                    : (isSeries
                                        ? 'Play S${_selectedSeasonIdx + 1}:E${_selectedEpisodeIdx + 1}'
                                        : 'Watch Movie'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 4,
                              ),
                            ),
                          ),
                          if (hasResume) ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Watch from beginning',
                              child: SizedBox(
                                height: 44,
                                width: 44,
                                child: OutlinedButton(
                                  onPressed: () => _playMedia(
                                    season: isSeries ? currentSeason! : 0,
                                    episode: isSeries ? currentEpisode! : 0,
                                    startPositionSeconds: 0,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Icon(Icons.replay_rounded, color: Colors.white70, size: 20),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 12),

                          // Watchlist Button
                          SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: () => library.toggleFavorite(widget.mediaItem),
                              icon: Icon(
                                isFav ? Icons.check_rounded : Icons.add_rounded,
                                color: isFav ? theme.colorScheme.primary : Colors.white,
                                size: 20,
                              ),
                              label: Text(
                                isFav ? 'In Watchlist' : 'Watchlist',
                                style: TextStyle(
                                  color: isFav ? theme.colorScheme.primary : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.08),
                                side: BorderSide(
                                  color: isFav
                                      ? theme.colorScheme.primary.withValues(alpha: 0.8)
                                      : Colors.white.withValues(alpha: 0.2),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // External Player Button
                          Tooltip(
                            message: 'Open in External Player (VLC / MPV)',
                            child: SizedBox(
                              height: 44,
                              width: 44,
                              child: OutlinedButton(
                                onPressed: () => _playMedia(
                                  season: isSeries ? (_selectedSeasonIdx + 1) : 0,
                                  episode: isSeries ? (_selectedEpisodeIdx + 1) : 0,
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 20),
                              ),
                            ),
                          ),

                          // TMDB Watch Trailer / Pause Trailer Button
                          if (_tmdbDetails?.trailerUrl != null) ...[
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: _watchTrailer,
                                icon: Icon(
                                  _isTrailerPlaying
                                      ? (_isTrailerPaused ? Icons.play_arrow_rounded : Icons.pause_rounded)
                                      : Icons.play_circle_outline_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                label: Text(
                                  _isTrailerPlaying
                                      ? (_isTrailerPaused ? 'Resume Trailer' : 'Pause Trailer')
                                      : 'Watch Trailer',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isTrailerPlaying
                                      ? (_isTrailerPaused ? const Color(0xFFD97706) : Colors.white24)
                                      : const Color(0xFFE50914), // Netflix Red
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 3,
                                ),
                              ),
                            ),
                            if (_isTrailerPlaying) ...[
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'Stop Trailer',
                                child: SizedBox(
                                  height: 44,
                                  width: 44,
                                  child: OutlinedButton(
                                    onPressed: _stopTrailer,
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Icon(Icons.stop_rounded, color: Colors.white70, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                      if (hasResume && history != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            SizedBox(
                              width: 160,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: history.progress,
                                  minHeight: 4,
                                  backgroundColor: Colors.white24,
                                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              history.totalSeconds > 0
                                  ? '${_formatRemaining(history.totalSeconds - history.positionSeconds)} left'
                                  : 'Resumed at ${_formatDuration(Duration(seconds: history.positionSeconds))}',
                              style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
              // TMDB Tagline
              if (_tmdbDetails?.tagline != null && _tmdbDetails!.tagline!.trim().isNotEmpty) ...[
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (_tmdbDetails?.overview != null && _tmdbDetails!.overview!.isNotEmpty)
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
  }) {
    final theme = Theme.of(context);
    final library = context.read<LibraryProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),

        // TMDB Subheader
        _buildTmdbSubheader(context, isSeries: isSeries, year: year, rating: rating),
        const SizedBox(height: 14),

        // TMDB Circular User Score Badge
        Builder(
          builder: (context) {
            final userScore = _tmdbDetails?.userScore ??
                (_tmdbDetails?.rating != null ? (_tmdbDetails!.rating! * 10).round() : null);
            if (userScore != null && userScore > 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildUserScoreBadge(userScore),
              );
            }
            return const SizedBox.shrink();
          },
        ),

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
                          icon: const Icon(Icons.play_arrow_rounded, size: 24, color: Colors.black),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: const Icon(Icons.replay_rounded, color: Colors.white70, size: 20),
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => library.toggleFavorite(widget.mediaItem),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isFav
                                ? theme.colorScheme.primary.withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Icon(
                          isFav ? Icons.check_rounded : Icons.add_rounded,
                          color: isFav ? theme.colorScheme.primary : Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_tmdbDetails?.trailerUrl != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ElevatedButton.icon(
                            onPressed: _watchTrailer,
                            icon: Icon(
                              _isTrailerPlaying
                                  ? (_isTrailerPaused ? Icons.play_arrow_rounded : Icons.pause_rounded)
                                  : Icons.play_circle_outline_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: Text(
                              _isTrailerPlaying
                                  ? (_isTrailerPaused ? 'Resume Trailer' : 'Pause Trailer')
                                  : 'Watch Official Trailer',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isTrailerPlaying
                                  ? (_isTrailerPaused ? const Color(0xFFD97706) : Colors.white24)
                                  : const Color(0xFFE50914),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ),
                      if (_isTrailerPlaying) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _stopTrailer,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: const Icon(Icons.stop_rounded, color: Colors.white70, size: 20),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                if (hasResume && history != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: history.progress,
                            minHeight: 4,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        history.totalSeconds > 0
                            ? '${_formatRemaining(history.totalSeconds - history.positionSeconds)} left'
                            : 'Resumed at ${_formatDuration(Duration(seconds: history.positionSeconds))}',
                        style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
        // TMDB Tagline
        if (_tmdbDetails?.tagline != null && _tmdbDetails!.tagline!.trim().isNotEmpty) ...[
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
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          (_tmdbDetails?.overview != null && _tmdbDetails!.overview!.isNotEmpty)
              ? _tmdbDetails!.overview!
              : desc,
          style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.5),
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
        if (director != null && director.isNotEmpty && (_tmdbDetails == null || _tmdbDetails!.crew.isEmpty))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.white70),
                children: [
                  const TextSpan(text: 'Director: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  TextSpan(text: director),
                ],
              ),
            ),
          ),

        if (cast.isNotEmpty) ...[
          const Text(
            'Top Cast',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 114,
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
                                  placeholder: (_, _) => Container(color: theme.colorScheme.surface),
                                  errorWidget: (_, _, _) => Container(
                                    color: theme.colorScheme.surface,
                                    child: const Icon(Icons.person, color: Colors.white38),
                                  ),
                                )
                              : Container(
                                  color: theme.colorScheme.surface,
                                  child: const Icon(Icons.person, color: Colors.white38),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      if (member.character != null && member.character!.isNotEmpty)
                        Text(
                          member.character!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9.5, color: Colors.white54),
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
                const TextSpan(text: 'Starring: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                TextSpan(text: _details!.stars!),
              ],
            ),
          ),
      ],
    );
  }

  /// Season selector header
  Widget _buildSeasonHeader(BuildContext context) {
    final theme = Theme.of(context);
    final seasons = _details!.seasons;
    final currentSeason = seasons[_selectedSeasonIdx.clamp(0, seasons.length - 1)];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            const Text(
              'Episodes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${currentSeason.episodes.length} Episodes',
                style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),

        // Season Choice Chips
        if (seasons.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                seasons.length,
                (i) {
                  final s = seasons[i];
                  final isSelected = _selectedSeasonIdx == i;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text('Season ${s.seasonNumber}'),
                      selected: isSelected,
                      onSelected: (sel) {
                        if (sel) {
                          setState(() {
                            _selectedSeasonIdx = i;
                            _selectedEpisodeIdx = 0;
                          });
                          _enrichSeasonEpisodesWithTmdb(seasonIdx: i);
                        }
                      },
                      selectedColor: theme.colorScheme.primary,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      side: BorderSide(
                        color: isSelected ? theme.colorScheme.primary : Colors.white.withValues(alpha: 0.1),
                      ),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isSelected ? Colors.black : Colors.white70,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  /// Responsive Episodes Section: Grid on Desktop, Cards on Mobile
  Widget _buildEpisodesSection(BuildContext context, List<Episode> episodes, double screenWidth) {
    if (episodes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('No episode details available for this season.', style: TextStyle(color: Colors.white54)),
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
          final epHistory = context.watch<LibraryProvider>().getHistoryItem(
            widget.mediaItem.id,
            season: ep.season,
            episode: ep.episode,
          );
          return EpisodeGridCard(
            episode: ep,
            isSelected: isSelected,
            progress: epHistory?.progress,
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
        final epHistory = context.watch<LibraryProvider>().getHistoryItem(
          widget.mediaItem.id,
          season: ep.season,
          episode: ep.episode,
        );
        return EpisodeTile(
          episode: ep,
          isSelected: isSelected,
          progress: epHistory?.progress,
          onTap: () {
            setState(() => _selectedEpisodeIdx = epIdx);
            _playMedia(season: ep.season, episode: ep.episode);
          },
        );
      },
    );
  }
}
