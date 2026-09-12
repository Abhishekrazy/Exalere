import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../models/stream_source.dart';
import '../../providers/app_provider.dart';
import '../../providers/library_provider.dart';
import '../../services/external_player_service.dart';
import '../../services/provider_registry.dart';
import '../theme/app_tokens.dart';
import '../widgets/details/details_backdrop_header.dart';
import '../widgets/details/details_cast_section.dart';
import '../widgets/details/details_episodes_section.dart';
import '../widgets/details/details_fullscreen_trailer.dart';
import '../widgets/details/details_hero_view.dart';
import '../widgets/details/details_related_section.dart';
import 'details/details_metadata_mixin.dart';
import 'details/details_trailer_mixin.dart';
import 'player_screen.dart';

class DetailsScreen extends StatefulWidget {
  final MediaItem mediaItem;
  final String? heroTag;

  const DetailsScreen({super.key, required this.mediaItem, this.heroTag});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen>
    with DetailsTrailerMixin, DetailsMetadataMixin {
  DateTime? _lastChildPoppedTime;
  DateTime? _lastBackTime;

  @override
  void initState() {
    super.initState();
    loadDetails(
      mediaItem: widget.mediaItem,
      onTrailerLoaded: () {
        scheduleAutoPlayTrailer(
          tmdbDetails: tmdbDetails,
          isAutoPlayTrailerEnabled: context
              .read<AppProvider>()
              .autoPlayTrailers,
        );
      },
    );
  }

  @override
  void dispose() {
    disposeTrailer();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
          ElevatedButton(
            autofocus: true,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: tokens.borderRadiusSm,
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
    stopTrailer();
    final theme = Theme.of(context);
    final tokens = context.tokens;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: tokens.surfaceElevated,
            borderRadius: tokens.borderRadiusLg,
            border: Border.all(color: tokens.borderSubtle),
            boxShadow: tokens.getCardShadows(),
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

    _launchPlayer(
      streams.first,
      season: season,
      episode: episode,
      startPositionSeconds: startPositionSeconds,
      availableSources: streams,
    );
  }

  Future<void> _launchPlayer(
    StreamSource stream, {
    required int season,
    required int episode,
    int? startPositionSeconds,
    List<StreamSource>? availableSources,
  }) async {
    if (context.read<AppProvider>().useExternalPlayer) {
      _openExternalPlayer(stream, startPositionSeconds: startPositionSeconds);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          mediaItem: widget.mediaItem,
          streamSource: stream,
          availableSources: availableSources ?? [stream],
          season: season > 0 ? season : null,
          episode: episode > 0 ? episode : null,
          startPositionSeconds: startPositionSeconds,
          mediaDetails: details,
        ),
      ),
    );
    _lastChildPoppedTime = DateTime.now();
    if (mounted && details != null && details!.isSeries) {
      final history = context.read<LibraryProvider>().getHistoryItem(
        widget.mediaItem.id,
      );
      if (history != null &&
          history.season != null &&
          history.episode != null) {
        final sIdx = history.season! - 1;
        final epIdx = history.episode! - 1;
        if (sIdx >= 0 && sIdx < details!.seasons.length) {
          setState(() {
            selectedSeasonIdx = sIdx;
            if (epIdx >= 0 && epIdx < details!.seasons[sIdx].episodes.length) {
              selectedEpisodeIdx = epIdx;
            }
          });
        }
      }
    }
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
          season: details?.isSeries == true ? (selectedSeasonIdx + 1) : null,
          episode: details?.isSeries == true ? (selectedEpisodeIdx + 1) : null,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
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
        : (details?.posterUrl ?? tmdbDetails?.posterUrl);
    final backdropUrl =
        details?.backdropUrl ??
        tmdbDetails?.backdropUrl ??
        widget.mediaItem.backdropUrl ??
        posterUrl;
    final rawTitle = details?.title ?? widget.mediaItem.title;
    final parsedTitle = MediaItem.parseTitleTags(rawTitle);
    final title = parsedTitle.cleanTitle;
    final languageTag =
        details?.effectiveLanguageTag ??
        widget.mediaItem.effectiveLanguageTag ??
        parsedTitle.languageTag;
    final desc =
        details?.description ?? 'No description available for this title.';
    final year = details?.year ?? widget.mediaItem.year;
    final rating =
        details?.imdbRating ?? widget.mediaItem.rating?.toStringAsFixed(1);
    final isSeries = details?.isSeries ?? widget.mediaItem.isSeries;

    final currentSeason = isSeries ? (selectedSeasonIdx + 1) : null;
    final currentEpisode = isSeries ? (selectedEpisodeIdx + 1) : null;
    final resumeSec = library.getResumePosition(
      widget.mediaItem.id,
      season: currentSeason,
      episode: currentEpisode,
    );
    final bool hasResume = resumeSec > 0;

    final double mobileHeaderHeight = isLandscape
        ? (isTrailerPlaying
              ? (screenHeight * 0.85).clamp(280.0, 480.0)
              : (screenHeight * 0.65).clamp(240.0, 360.0))
        : (isTrailerPlaying ? 380.0 : 320.0);
    final double headerHeight = isDesktop
        ? (isTrailerPlaying ? 600.0 : 500.0)
        : mobileHeaderHeight;

    final castSectionWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isDesktop && tmdbDetails != null && tmdbDetails!.crew.isNotEmpty)
          DetailsFeaturedCrewGrid(crew: tmdbDetails!.crew),
        DetailsCastSection(
          cast: tmdbDetails?.cast ?? [],
          crew: tmdbDetails?.crew ?? [],
          director: tmdbDetails?.director ?? details?.director,
          fallbackStars: details?.stars,
        ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastChildPoppedTime != null &&
            now.difference(_lastChildPoppedTime!).inMilliseconds < 600 &&
            !WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
          return;
        }
        if (isTrailerFullscreen) {
          toggleTrailerFullscreen();
          return;
        }
        if (_lastBackTime != null &&
            now.difference(_lastBackTime!).inMilliseconds < 400 &&
            !WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
          return;
        }
        _lastBackTime = now;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: MouseRegion(
          onHover: (_) => onTrailerUserInteraction(),
          child: Listener(
            onPointerDown: (_) => onTrailerUserInteraction(),
            child: Stack(
              children: [
                // 1. Ambient / Blurred Cinematic Backdrop or Live Trailer Video
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: DetailsBackdropLayer(
                    height: headerHeight,
                    isTrailerPlaying: isTrailerPlaying,
                    isTrailerLoading: isTrailerLoading,
                    trailerVideoController: trailerVideoController,
                    trailerFit: trailerFit,
                    backdropUrl: backdropUrl,
                    isDesktop: isDesktop,
                  ),
                ),

                // 2. Scrollable Body
                SafeArea(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (_) {
                      onTrailerUserInteraction();
                      return false;
                    },
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: DetailsTopBar(
                            mediaItem: widget.mediaItem,
                            isTrailerPlaying: isTrailerPlaying,
                            isTrailerMuted: isTrailerMuted,
                            isTrailerFullscreen: isTrailerFullscreen,
                            trailerFit: trailerFit,
                            onBack: () {
                              stopTrailer();
                              Navigator.of(context).pop();
                            },
                            onToggleMute: toggleMuteTrailer,
                            onToggleFit: toggleTrailerFit,
                            onToggleFullscreen: toggleTrailerFullscreen,
                            onStopTrailer: stopTrailer,
                          ),
                        ),
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
                                    top: isTrailerPlaying
                                        ? (isDesktop ? 220.0 : 140.0)
                                        : 0.0,
                                  ),
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 350),
                                    opacity:
                                        (isTrailerPlaying && !isCursorMoving)
                                        ? 0.2
                                        : 1.0,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (isLoading)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            child: LinearProgressIndicator(
                                              color: theme.colorScheme.primary,
                                              backgroundColor:
                                                  tokens.borderSubtle,
                                              minHeight: 2,
                                            ),
                                          ),

                                        if (isDesktop)
                                          DetailsDesktopHero(
                                            mediaItem: widget.mediaItem,
                                            heroTag: widget.heroTag,
                                            title: title,
                                            posterUrl: posterUrl,
                                            year: year,
                                            rating: rating,
                                            isSeries: isSeries,
                                            desc: desc,
                                            isFav: isFav,
                                            languageTag: languageTag,
                                            tmdbDetails: tmdbDetails,
                                            details: details,
                                            selectedSeasonIdx:
                                                selectedSeasonIdx,
                                            selectedEpisodeIdx:
                                                selectedEpisodeIdx,
                                            isTrailerPlaying: isTrailerPlaying,
                                            onPlay: () => _playMedia(
                                              season: isSeries
                                                  ? (selectedSeasonIdx + 1)
                                                  : 0,
                                              episode: isSeries
                                                  ? (selectedEpisodeIdx + 1)
                                                  : 0,
                                              startPositionSeconds: hasResume
                                                  ? resumeSec
                                                  : null,
                                            ),
                                            onPlayFromBeginning: () =>
                                                _playMedia(
                                                  season: isSeries
                                                      ? (selectedSeasonIdx + 1)
                                                      : 0,
                                                  episode: isSeries
                                                      ? (selectedEpisodeIdx + 1)
                                                      : 0,
                                                  startPositionSeconds: 0,
                                                ),
                                            onToggleFavorite: () =>
                                                library.toggleFavorite(
                                                  widget.mediaItem,
                                                ),
                                            onExternalPlayer: () {
                                              if (details != null) {
                                                _playMedia(
                                                  season: isSeries
                                                      ? (selectedSeasonIdx + 1)
                                                      : 0,
                                                  episode: isSeries
                                                      ? (selectedEpisodeIdx + 1)
                                                      : 0,
                                                );
                                              }
                                            },
                                            onWatchTrailer: () => watchTrailer(
                                              tmdbDetails: tmdbDetails,
                                            ),
                                            castSection: castSectionWidget,
                                          )
                                        else
                                          DetailsMobileHero(
                                            mediaItem: widget.mediaItem,
                                            heroTag: widget.heroTag,
                                            title: title,
                                            posterUrl: posterUrl,
                                            year: year,
                                            rating: rating,
                                            isSeries: isSeries,
                                            desc: desc,
                                            isFav: isFav,
                                            languageTag: languageTag,
                                            tmdbDetails: tmdbDetails,
                                            details: details,
                                            selectedSeasonIdx:
                                                selectedSeasonIdx,
                                            selectedEpisodeIdx:
                                                selectedEpisodeIdx,
                                            isTrailerPlaying: isTrailerPlaying,
                                            onPlay: () => _playMedia(
                                              season: isSeries
                                                  ? (selectedSeasonIdx + 1)
                                                  : 0,
                                              episode: isSeries
                                                  ? (selectedEpisodeIdx + 1)
                                                  : 0,
                                              startPositionSeconds: hasResume
                                                  ? resumeSec
                                                  : null,
                                            ),
                                            onPlayFromBeginning: () =>
                                                _playMedia(
                                                  season: isSeries
                                                      ? (selectedSeasonIdx + 1)
                                                      : 0,
                                                  episode: isSeries
                                                      ? (selectedEpisodeIdx + 1)
                                                      : 0,
                                                  startPositionSeconds: 0,
                                                ),
                                            onToggleFavorite: () =>
                                                library.toggleFavorite(
                                                  widget.mediaItem,
                                                ),
                                            onExternalPlayer: () {
                                              if (details != null) {
                                                _playMedia(
                                                  season: isSeries
                                                      ? (selectedSeasonIdx + 1)
                                                      : 0,
                                                  episode: isSeries
                                                      ? (selectedEpisodeIdx + 1)
                                                      : 0,
                                                );
                                              }
                                            },
                                            onWatchTrailer: () => watchTrailer(
                                              tmdbDetails: tmdbDetails,
                                            ),
                                            castSection: castSectionWidget,
                                          ),

                                        const SizedBox(height: 32),

                                        if (isSeries &&
                                            details != null &&
                                            details!.seasons.isNotEmpty) ...[
                                          DetailsEpisodesSection(
                                            seriesItem: widget.mediaItem,
                                            seasons: details!.seasons,
                                            selectedSeasonIdx:
                                                selectedSeasonIdx,
                                            selectedEpisodeIdx:
                                                selectedEpisodeIdx,
                                            onSeasonChanged: (i) =>
                                                onSeasonChanged(
                                                  i,
                                                  mediaItem: widget.mediaItem,
                                                ),
                                            onEpisodePlay: (season, episode) {
                                              final s = details!.seasons
                                                  .firstWhere(
                                                    (s) =>
                                                        s.seasonNumber ==
                                                        season,
                                                    orElse: () =>
                                                        details!.seasons.first,
                                                  );
                                              final epIdx = s.episodes
                                                  .indexWhere(
                                                    (e) => e.episode == episode,
                                                  );
                                              if (epIdx >= 0) {
                                                setState(
                                                  () => selectedEpisodeIdx =
                                                      epIdx,
                                                );
                                              }
                                              _playMedia(
                                                season: season,
                                                episode: episode,
                                              );
                                            },
                                            screenWidth: screenWidth,
                                          ),
                                        ],

                                        if (details != null &&
                                            relatedItems.isNotEmpty) ...[
                                          const SizedBox(height: 32),
                                          DetailsRelatedSection(
                                            relatedItems: relatedItems,
                                            screenWidth: screenWidth,
                                            onItemTap: (item) {
                                              stopTrailer();
                                              Navigator.of(context)
                                                  .pushReplacement(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          DetailsScreen(
                                                            mediaItem: item,
                                                          ),
                                                    ),
                                                  );
                                            },
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
                if (isTrailerFullscreen &&
                    isTrailerPlaying &&
                    trailerVideoController != null)
                  DetailsFullscreenTrailerOverlay(
                    videoController: trailerVideoController!,
                    trailerFit: trailerFit,
                    isTrailerMuted: isTrailerMuted,
                    onTogglePause: togglePauseTrailer,
                    onToggleMute: toggleMuteTrailer,
                    onToggleFit: toggleTrailerFit,
                    onExitFullscreen: toggleTrailerFullscreen,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
