import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/libmpv_helper.dart';

import '../../models/media_item.dart';
import '../../models/media_details.dart';
import '../../models/stream_source.dart';
import '../../providers/app_provider.dart';
import '../../providers/library_provider.dart';
import '../../services/moviebox_provider.dart';
import '../../services/fourkhdhub_provider.dart';
import '../../services/tmdb_service.dart';
import '../../services/provider_registry.dart';
import '../theme/app_themes.dart';
import '../widgets/tv/tv_details_action_bar.dart';
import '../widgets/tv/tv_details_header.dart';
import '../widgets/tv/tv_episode_options_dialog.dart';
import '../widgets/tv/tv_episode_shelf.dart';
import '../widgets/tv/tv_more_like_this_shelf.dart';
import '../widgets/tv/tv_season_controls.dart';
import '../widgets/tv_focusable.dart';
import 'player_screen.dart';

/// A Netflix-like 10-foot UI Details Screen for Android TV.
/// Provides rich hero backdrop, metadata, season selector tabs,
/// and horizontal episode preview cards with TMDB stills and synopses.
class TvDetailsScreen extends StatefulWidget {
  final MediaItem mediaItem;

  const TvDetailsScreen({super.key, required this.mediaItem});

  @override
  State<TvDetailsScreen> createState() => _TvDetailsScreenState();
}

class _TvDetailsScreenState extends State<TvDetailsScreen> {
  final MovieBoxProvider _movieBoxProvider = MovieBoxProvider();
  final FourKHdHubProvider _fourKHdHubProvider = FourKHdHubProvider();
  final TmdbService _tmdbService = TmdbService();

  MediaDetails? _details;
  TmdbEnrichedDetails? _tmdbDetails;
  bool _isLoading = true;
  int _selectedSeasonIdx = 0;
  final Map<int, Map<int, TmdbEpisodeInfo>> _cachedSeasonEpisodes = {};

  List<MediaItem> _relatedItems = [];
  bool _isLoadingRelated = false;

  // TV Background trailer auto-play state
  Player? _trailerPlayer;
  VideoController? _trailerVideoController;
  Timer? _autoPlayTrailerTimer;
  bool _isTrailerPlaying = false;

  final FocusNode _playButtonFocusNode = FocusNode(
    debugLabel: 'TvDetailsPlayBtn',
  );

  /// Focus node for the first episode card in [TvEpisodeShelf].
  /// Used by [_onActionBarDownFocus] to explicitly move focus into the shelf
  /// when the user presses D-Pad Down from the action bar row, bypassing the
  /// lazy ListView rendering issue where cards may not have a RenderBox yet.
  final FocusNode _firstEpisodeFocusNode = FocusNode(
    debugLabel: 'TvDetailsFirstEpisodeCard',
  );

  @override
  void initState() {
    super.initState();
    _loadAllDetails();
  }

  @override
  void dispose() {
    _autoPlayTrailerTimer?.cancel();
    _stopTrailer();
    _playButtonFocusNode.dispose();
    _firstEpisodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAllDetails() async {
    setState(() => _isLoading = true);

    // 1. Fetch TMDB enrichment in parallel
    _tmdbService
        .getEnrichedDetails(
          title: widget.mediaItem.title,
          year: widget.mediaItem.year,
          isSeries: widget.mediaItem.isSeries,
        )
        .then((tmdb) {
          if (mounted && tmdb != null) {
            setState(() => _tmdbDetails = tmdb);
            if (!_isLoading &&
                tmdb.trailerYoutubeKey != null &&
                tmdb.trailerYoutubeKey!.isNotEmpty) {
              _scheduleAutoPlayTrailer();
            }
            if (_details != null && _details!.isSeries) {
              _loadSeasonEpisodes(tmdb.id, _selectedSeasonIdx + 1);
            }
            _loadRelatedItems(tmdb.id);
          }
        });

    // 2. Fetch Provider Details (MovieBox or 4KHDHub)
    try {
      if (widget.mediaItem.provider == ProviderType.fourKHdHub) {
        _details = await _fourKHdHubProvider.getDetails(widget.mediaItem.id);
      } else {
        _details = await _movieBoxProvider.getDetails(widget.mediaItem.id);
      }

      if (!mounted) return;

      // Check watch history for smart season/episode selection
      if (_details != null &&
          _details!.isSeries &&
          _details!.seasons.isNotEmpty) {
        final history = context.read<LibraryProvider>().getHistoryItem(
          widget.mediaItem.id,
        );
        if (history != null && history.season != null && history.season! > 0) {
          final sIdx = (history.season! - 1).clamp(
            0,
            _details!.seasons.length - 1,
          );
          _selectedSeasonIdx = sIdx;
        }

        if (_tmdbDetails != null) {
          _loadSeasonEpisodes(_tmdbDetails!.id, _selectedSeasonIdx + 1);
        }
      }
    } catch (e) {
      debugPrint('TvDetailsScreen load error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        if (_tmdbDetails?.trailerYoutubeKey != null &&
            _tmdbDetails!.trailerYoutubeKey!.isNotEmpty) {
          _scheduleAutoPlayTrailer();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _playButtonFocusNode.canRequestFocus) {
            FocusScope.of(context).requestFocus(_playButtonFocusNode);
          }
        });
        if (_relatedItems.isEmpty) {
          try {
            final app = context.read<AppProvider>();
            final candidates = widget.mediaItem.isSeries
                ? app.seriesFeed
                : app.moviesFeed;
            if (candidates.isNotEmpty && _details != null) {
              setState(() {
                _relatedItems = candidates
                    .where((m) => m.id != widget.mediaItem.id)
                    .take(12)
                    .toList();
              });
            }
          } catch (_) {}
        }
      }
    }
  }

  Future<void> _loadRelatedItems(int tmdbId) async {
    if (_isLoadingRelated) return;
    _isLoadingRelated = true;
    try {
      final app = context.read<AppProvider>();
      final candidates = widget.mediaItem.isSeries
          ? app.seriesFeed
          : app.moviesFeed;

      final currentGenres = (_details?.genres ?? [])
          .map((g) => g.toLowerCase().trim())
          .toSet();
      if (widget.mediaItem.genre != null &&
          widget.mediaItem.genre!.isNotEmpty) {
        currentGenres.add(widget.mediaItem.genre!.toLowerCase().trim());
      }

      final List<MediaItem> verifiedItems = [];
      final Set<String> seenIds = {widget.mediaItem.id};

      // 1. Fetch TMDB recommendation titles and search/match for playable MovieBox sources
      try {
        final tmdbRecs = await _tmdbService.getRecommendationsOrSimilar(
          tmdbId: tmdbId,
          isSeries: widget.mediaItem.isSeries,
        );

        for (final rec in tmdbRecs) {
          if (verifiedItems.length >= 10) break;
          final recClean = rec.cleanTitle.toLowerCase().trim();

          // Check if in active feed
          MediaItem? feedMatch;
          for (final c in candidates) {
            if (!seenIds.contains(c.id) &&
                c.cleanTitle.toLowerCase().trim() == recClean) {
              feedMatch = c;
              break;
            }
          }
          if (feedMatch != null) {
            seenIds.add(feedMatch.id);
            verifiedItems.add(feedMatch);
            continue;
          }

          // Search MovieBox with resource availability check
          if (verifiedItems.length < 5 && recClean.isNotEmpty) {
            try {
              final searchResults = await _movieBoxProvider.search(
                rec.cleanTitle,
              );
              for (final res in searchResults) {
                if (res.id.isNotEmpty && !seenIds.contains(res.id)) {
                  seenIds.add(res.id);
                  verifiedItems.add(res);
                  break;
                }
              }
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('TvDetailsScreen TMDB recommendations search error: $e');
      }

      // 2. Supplement with genre-matched playable items from verified provider feed
      if (currentGenres.isNotEmpty) {
        for (final c in candidates) {
          if (seenIds.contains(c.id)) continue;
          final g = c.genre?.toLowerCase() ?? '';
          if (currentGenres.any((cg) => g.contains(cg) || cg.contains(g))) {
            seenIds.add(c.id);
            verifiedItems.add(c);
            if (verifiedItems.length >= 12) break;
          }
        }
      }

      // 3. Fill remaining from provider feed
      for (final c in candidates) {
        if (!seenIds.contains(c.id)) {
          seenIds.add(c.id);
          verifiedItems.add(c);
          if (verifiedItems.length >= 12) break;
        }
      }

      if (mounted) {
        setState(() {
          _relatedItems = verifiedItems.take(12).toList();
        });
      }
    } catch (e) {
      debugPrint('TvDetailsScreen related items error: $e');
    } finally {
      _isLoadingRelated = false;
    }
  }

  Future<void> _loadSeasonEpisodes(int tmdbId, int seasonNumber) async {
    if (_cachedSeasonEpisodes.containsKey(seasonNumber)) return;
    try {
      final eps = await _tmdbService.getSeasonEpisodes(
        tvId: tmdbId,
        seasonNumber: seasonNumber,
      );
      if (mounted && eps.isNotEmpty) {
        setState(() {
          _cachedSeasonEpisodes[seasonNumber] = eps;
        });
      }
    } catch (e) {
      debugPrint('Error loading TMDB season episodes: $e');
    }
  }

  void _onSeasonSelected(int index) {
    if (_selectedSeasonIdx == index) return;
    setState(() => _selectedSeasonIdx = index);
    if (_tmdbDetails != null) {
      _loadSeasonEpisodes(_tmdbDetails!.id, index + 1);
    }
  }

  Future<void> _playEpisode(Episode episode, {bool startOver = false}) async {
    _showLoadingDialog();
    try {
      final streams = await ProviderRegistry().resolveStreams(
        subjectId: widget.mediaItem.id,
        season: episode.season,
        episode: episode.episode,
        preferredProviderId: 'moviebox',
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

      if (streams.isEmpty) {
        _showErrorDialog(
          'No active stream found for this episode. Try another title or provider.',
        );
        return;
      }

      final library = context.read<LibraryProvider>();
      final resumePos = startOver
          ? 0
          : library.getResumePosition(
              widget.mediaItem.id,
              season: episode.season,
              episode: episode.episode,
            );

      _stopTrailer();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            mediaItem: widget.mediaItem,
            streamSource: streams.first,
            availableSources: streams,
            season: episode.season,
            episode: episode.episode,
            startPositionSeconds: resumePos > 0 ? resumePos : null,
            mediaDetails: _details,
          ),
        ),
      );
      if (mounted) {
        FocusScope.of(context).requestFocus(_playButtonFocusNode);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showErrorDialog('Failed to load episode: $e');
    }
  }

  void _showEpisodeOptionsDialog(
    Episode episode,
    String title,
    int resumeSeconds,
    bool isWatched,
  ) {
    TvEpisodeOptionsDialog.show(
      context,
      episode: episode,
      title: title,
      resumePositionSeconds: resumeSeconds,
      isWatched: isWatched,
      onResume: resumeSeconds > 15
          ? () => _playEpisode(episode, startOver: false)
          : null,
      onPlayFromStart: () => _playEpisode(episode, startOver: true),
      onToggleWatched: () async {
        final library = context.read<LibraryProvider>();
        await library.toggleEpisodeWatched(
          series: widget.mediaItem,
          season: episode.season,
          episode: episode.episode,
        );
      },
    );
  }

  Future<void> _playMovie({bool startOver = false}) async {
    final library = context.read<LibraryProvider>();
    final history = library.getHistoryItem(widget.mediaItem.id);
    final resumePos =
        (history != null &&
            !startOver &&
            history.positionSeconds > 15 &&
            (history.totalSeconds <= 0 ||
                history.positionSeconds < history.totalSeconds * 0.95))
        ? history.positionSeconds
        : 0;

    _showLoadingDialog();
    try {
      final preferred = widget.mediaItem.provider == ProviderType.fourKHdHub
          ? 'fourkhdhub'
          : 'moviebox';
      final streams = await ProviderRegistry().resolveStreams(
        subjectId: widget.mediaItem.id,
        preferredProviderId: preferred,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

      if (streams.isEmpty) {
        _showErrorDialog(
          'No active stream found for this movie. Try another title or provider.',
        );
        return;
      }

      _stopTrailer();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            mediaItem: widget.mediaItem,
            streamSource: streams.first,
            availableSources: streams,
            startPositionSeconds: resumePos > 0 ? resumePos : null,
          ),
        ),
      );
      if (mounted) {
        FocusScope.of(context).requestFocus(_playButtonFocusNode);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showErrorDialog('Failed to load movie: $e');
    }
  }

  void _showLoadingDialog() {
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
              color: context.tokens.primaryAccent,
            ),
          ),
        ),
      ),
    );
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
          TvFocusable(
            autofocus: true,
            onTap: () => Navigator.of(ctx).pop(),
            borderRadius: context.tokens.borderRadiusSm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: context.tokens.primaryAccent,
                borderRadius: context.tokens.borderRadiusSm,
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

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.tokens.errorColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Called when the user presses D-Pad Down from any action bar button.
  ///
  /// For series with episodes: explicitly requests focus on the first episode
  /// card, which guarantees the focus lands even if the lazy ListView hasn't
  /// fully rendered yet. Returns true to consume the D-Pad Down event.
  ///
  /// For movies: returns false so TvSpatialNavigation handles it via normal
  /// scanning (the "More Like This" shelf will be scanned instead).
  bool _onActionBarDownFocus() {
    final isSeries = _details?.isSeries ?? widget.mediaItem.isSeries;
    final hasEpisodes =
        isSeries && _details != null && _details!.seasons.isNotEmpty;

    if (hasEpisodes && _firstEpisodeFocusNode.canRequestFocus) {
      _firstEpisodeFocusNode.requestFocus();
      return true;
    }
    return false;
  }

  void _scheduleAutoPlayTrailer({
    Duration delay = const Duration(milliseconds: 2500),
  }) {
    _autoPlayTrailerTimer?.cancel();
    final appProvider = context.read<AppProvider>();
    if (!appProvider.autoPlayTrailers) return;

    final key = _tmdbDetails?.trailerYoutubeKey;
    if (key == null || key.isEmpty) return;

    _autoPlayTrailerTimer = Timer(delay, () {
      if (mounted && !_isTrailerPlaying && !_isLoading) {
        _startTrailerPlayback();
      }
    });
  }

  Future<void> _startTrailerPlayback() async {
    final key = _tmdbDetails?.trailerYoutubeKey;
    if (key == null || key.isEmpty) return;

    _autoPlayTrailerTimer?.cancel();
    LibMpvHelper.ensureCriticalSectionsInitialized();

    if (_trailerPlayer == null) {
      _trailerPlayer = Player(
        configuration: const PlayerConfiguration(title: 'Exalere TV Trailer'),
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

      _trailerPlayer!.stream.error.listen((err) {
        debugPrint('TV Trailer player error: $err');
        if (mounted) {
          _stopTrailer();
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

      await _trailerPlayer!.setPlaylistMode(PlaylistMode.none);
      await _trailerPlayer!.open(Media(streamUrl));
      // TV backdrop trailer plays muted for unobtrusive ambient experience
      await _trailerPlayer!.setVolume(0.0);
      await _trailerPlayer!.play();

      if (mounted) {
        setState(() {
          _isTrailerPlaying = true;
        });
      }
    } catch (e) {
      debugPrint('TV Trailer playback error: $e');
      if (mounted) {
        setState(() {
          _isTrailerPlaying = false;
        });
      }
    }
  }

  void _stopTrailer() {
    _autoPlayTrailerTimer?.cancel();
    _trailerPlayer?.stop();
    _trailerPlayer?.dispose();
    _trailerPlayer = null;
    _trailerVideoController = null;
    if (mounted) {
      setState(() {
        _isTrailerPlaying = false;
      });
    }
  }

  Future<void> _playTrailer() async {
    final key = _tmdbDetails?.trailerYoutubeKey;
    if (key == null || key.isEmpty) {
      _showToast('No trailer available for this title.');
      return;
    }

    _stopTrailer();

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
              color: ctx.tokens.primaryAccent,
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
          id: 'trailer_${widget.mediaItem.id}_$key',
          title: '${widget.mediaItem.cleanTitle} - Official Trailer',
          mediaType: MediaType.movie,
          posterUrl: widget.mediaItem.posterUrl,
          backdropUrl: widget.mediaItem.backdropUrl,
          provider: widget.mediaItem.provider,
        );

        final source = StreamSource(
          quality: 'Trailer',
          resolution: 'Auto',
          format: streamUrl.contains('.m3u8') ? 'HLS' : 'MP4',
          url: streamUrl,
        );

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
          _showErrorDialog(
            'Unable to stream trailer in-app, and no web browser or YouTube app was found on this TV.',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showErrorDialog('Failed to load trailer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSeries = _details?.isSeries ?? widget.mediaItem.isSeries;
    final backdropUrl =
        _details?.backdropUrl ??
        widget.mediaItem.backdropUrl ??
        widget.mediaItem.posterUrl;
    final rawTitle = _details?.title ?? widget.mediaItem.title;
    final parsedTitle = MediaItem.parseTitleTags(rawTitle);
    final title = parsedTitle.cleanTitle;
    final languageTag =
        _details?.effectiveLanguageTag ??
        widget.mediaItem.effectiveLanguageTag ??
        parsedTitle.languageTag;
    final overview =
        _tmdbDetails?.overview ??
        _details?.description ??
        'No synopsis available.';
    final year = _details?.year ?? widget.mediaItem.year;
    final rating = _tmdbDetails?.rating != null
        ? _tmdbDetails!.rating!.toStringAsFixed(1)
        : (_details?.imdbRating ?? widget.mediaItem.rating?.toStringAsFixed(1));
    final ageCert = _tmdbDetails?.certification ?? 'PG-13';

    final library = context.watch<LibraryProvider>();
    final isFav = library.isFavorite(widget.mediaItem.id);
    final history = library.getHistoryItem(widget.mediaItem.id);

    // Compute smart primary button label
    String playButtonLabel = 'Play';
    if (isSeries) {
      if (history != null &&
          history.season != null &&
          history.episode != null) {
        playButtonLabel = 'Resume S${history.season} E${history.episode}';
      } else {
        playButtonLabel = 'Play S1 E1';
      }
    } else {
      if (history != null && history.positionSeconds > 15) {
        final min = (history.positionSeconds / 60).floor();
        playButtonLabel = 'Resume (${min}m)';
      }
    }

    final currentSeasonEps =
        (isSeries && _details != null && _details!.seasons.isNotEmpty)
        ? _details!
              .seasons[_selectedSeasonIdx.clamp(
                0,
                _details!.seasons.length - 1,
              )]
              .episodes
        : <Episode>[];

    final tmdbEpMap = _cachedSeasonEpisodes[_selectedSeasonIdx + 1] ?? {};

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: context.tokens.canvasBackground,
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: context.tokens.primaryAccent,
                ),
              )
            : Stack(
                children: [
                  // 1. Full-Screen Cinematic Backdrop with Multi-Stop Vignette
                  Positioned.fill(
                    child: ShaderMask(
                      shaderCallback: (rect) {
                        return LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            context.tokens.textPrimary,
                            context.tokens.textPrimary,
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.4, 0.95],
                        ).createShader(rect);
                      },
                      blendMode: BlendMode.dstIn,
                      child:
                          _isTrailerPlaying && _trailerVideoController != null
                          ? Video(
                              controller: _trailerVideoController!,
                              controls: NoVideoControls,
                              fit: BoxFit.cover,
                            )
                          : (backdropUrl != null && backdropUrl.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: backdropUrl,
                              fit: BoxFit.cover,
                              alignment: Alignment.topRight,
                              errorWidget: (_, _, _) => const SizedBox.shrink(),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),

                  // Ambient Gradient Layers for 100% Readability
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            context.tokens.canvasBackground,
                            context.tokens.canvasBackground.withValues(
                              alpha: 0.98,
                            ),
                            context.tokens.canvasBackground.withValues(
                              alpha: 0.75,
                            ),
                            context.tokens.canvasBackground.withValues(
                              alpha: 0.19,
                            ),
                          ],
                          stops: const [0.0, 0.45, 0.75, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            context.tokens.canvasBackground.withValues(
                              alpha: 0.5,
                            ),
                            context.tokens.canvasBackground,
                          ],
                          stops: const [0.35, 0.65, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // 2. Scrollable 10-Foot Content Canvas
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(36, 18, 36, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back Icon Indicator (Only on Windows/desktop, removed on Android TV)
                        if (Platform.isWindows ||
                            Platform.isLinux ||
                            Platform.isMacOS) ...[
                          TvFocusable(
                            scaleFactor: 1.12,
                            borderRadius: context.tokens.borderRadiusPill,
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: context.tokens.canvasBackground
                                    .withValues(alpha: 0.4),
                                borderRadius: context.tokens.borderRadiusPill,
                                border: Border.all(
                                  color: context.tokens.borderSubtle,
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_back_rounded,
                                    size: 14,
                                    color: context.tokens.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Back',
                                    style: TextStyle(
                                      color: context.tokens.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Header (Title, Chips, Overview)
                        TvDetailsHeader(
                          title: title,
                          year: year,
                          ageCert: ageCert,
                          rating: rating,
                          isSeries: isSeries,
                          isCam: widget.mediaItem.isCam,
                          qualityTag: widget.mediaItem.qualityTag,
                          languageTag: languageTag,
                          overview: overview,
                        ),

                        const SizedBox(height: 16),

                        // Action Bar: Play / Resume (Autofocused) + My List + Trailer
                        TvDetailsActionBar(
                          playButtonFocusNode: _playButtonFocusNode,
                          playButtonLabel: playButtonLabel,
                          onPlay: () {
                            if (isSeries) {
                              if (currentSeasonEps.isNotEmpty) {
                                final epToPlay =
                                    (history != null &&
                                        history.episode != null &&
                                        history.episode! <=
                                            currentSeasonEps.length)
                                    ? currentSeasonEps[history.episode! - 1]
                                    : currentSeasonEps.first;
                                _playEpisode(epToPlay);
                              }
                            } else {
                              _playMovie();
                            }
                          },
                          isFavorite: isFav,
                          onToggleFavorite: () {
                            library.toggleFavorite(widget.mediaItem);
                            _showToast(
                              isFav
                                  ? 'Removed from My List'
                                  : 'Added to My List',
                            );
                          },
                          trailerYoutubeKey: _tmdbDetails?.trailerYoutubeKey,
                          onOpenTrailer: _playTrailer,
                          // Explicitly moves focus into the episode shelf on
                          // D-Pad Down, bypassing the lazy ListView render issue.
                          onDownFocus: _onActionBarDownFocus,
                        ),

                        // 3. TV Series: Seasons Selector & Horizontal Episodes Row
                        if (isSeries &&
                            _details != null &&
                            _details!.seasons.isNotEmpty) ...[
                          const SizedBox(height: 20),

                          // Season Selector Tabs & Mark Season Watched Toggle
                          TvSeasonControls(
                            mediaItemId: widget.mediaItem.id,
                            seasons: _details!.seasons,
                            selectedSeasonIndex: _selectedSeasonIdx,
                            onSeasonSelected: _onSeasonSelected,
                          ),

                          const SizedBox(height: 12),

                          TvEpisodeShelf(
                            episodes: currentSeasonEps,
                            tmdbEpMap: tmdbEpMap,
                            defaultThumbnailUrl: backdropUrl,
                            mediaItemId: widget.mediaItem.id,
                            onPlayEpisode: _playEpisode,
                            onEpisodeLongPress: _showEpisodeOptionsDialog,
                            // Provides the parent with direct focus control
                            // over the first episode card (see _onActionBarDownFocus).
                            firstCardFocusNode: _firstEpisodeFocusNode,
                          ),
                        ],
                        if (_details != null && _relatedItems.isNotEmpty)
                          TvMoreLikeThisShelf(
                            items: _relatedItems,
                            onItemSelect: (item) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TvDetailsScreen(mediaItem: item),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
