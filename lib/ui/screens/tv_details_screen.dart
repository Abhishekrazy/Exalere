import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/media_item.dart';
import '../../models/media_details.dart';
import '../../providers/library_provider.dart';
import '../../services/moviebox_provider.dart';
import '../../services/fourkhdhub_provider.dart';
import '../../services/tmdb_service.dart';
import '../../services/provider_registry.dart';
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

  final FocusNode _playButtonFocusNode = FocusNode(
    debugLabel: 'TvDetailsPlayBtn',
  );

  @override
  void initState() {
    super.initState();
    _loadAllDetails();
  }

  @override
  void dispose() {
    _playButtonFocusNode.dispose();
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
            if (_details != null && _details!.isSeries) {
              _loadSeasonEpisodes(tmdb.id, _selectedSeasonIdx + 1);
            }
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
      }
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

  Future<void> _playEpisode(Episode episode) async {
    _showLoadingDialog('Starting S${episode.season} E${episode.episode}...');
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
        _showToast('No active stream found for this episode.');
        return;
      }

      final library = context.read<LibraryProvider>();
      final resumePos = library.getResumePosition(
        widget.mediaItem.id,
        season: episode.season,
        episode: episode.episode,
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            mediaItem: widget.mediaItem,
            streamSource: streams.first,
            availableSources: streams,
            season: episode.season,
            episode: episode.episode,
            startPositionSeconds: resumePos > 0 ? resumePos : null,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showToast('Failed to load episode: $e');
    }
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

    _showLoadingDialog('Starting movie...');
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
        _showToast('No active stream found for this movie.');
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            mediaItem: widget.mediaItem,
            streamSource: streams.first,
            availableSources: streams,
            startPositionSeconds: resumePos > 0 ? resumePos : null,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showToast('Failed to load movie: $e');
    }
  }

  void _showLoadingDialog(String message) {
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
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFFE50914),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
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
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSeries = _details?.isSeries ?? widget.mediaItem.isSeries;
    final backdropUrl =
        _details?.backdropUrl ??
        widget.mediaItem.backdropUrl ??
        widget.mediaItem.posterUrl;
    final title = _details?.title ?? widget.mediaItem.title;
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
        backgroundColor: const Color(0xFF0B0D13),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFFE50914),
                ),
              )
            : Stack(
                children: [
                  // 1. Full-Screen Cinematic Backdrop with Multi-Stop Vignette
                  if (backdropUrl != null && backdropUrl.isNotEmpty)
                    Positioned.fill(
                      child: ShaderMask(
                        shaderCallback: (rect) {
                          return const LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.4, 0.95],
                          ).createShader(rect);
                        },
                        blendMode: BlendMode.dstIn,
                        child: CachedNetworkImage(
                          imageUrl: backdropUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.topRight,
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),

                  // Ambient Gradient Layers for 100% Readability
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFF0B0D13),
                            Color(0xFA0B0D13),
                            Color(0xC00B0D13),
                            Color(0x300B0D13),
                          ],
                          stops: [0.0, 0.45, 0.75, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Color(0x800B0D13),
                            Color(0xFF0B0D13),
                          ],
                          stops: [0.35, 0.65, 1.0],
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
                        // Back Icon Indicator
                        TvFocusable(
                          scaleFactor: 1.12,
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white24,
                                width: 0.8,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_back_rounded,
                                  size: 14,
                                  color: Colors.white70,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Back',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Title
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.4,
                              height: 1.15,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Metadata Chips Row
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (year != null && year.isNotEmpty)
                              Text(
                                year,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 0.6,
                                ),
                              ),
                              child: Text(
                                ageCert,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (rating != null && rating.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 15,
                                    color: Color(0xFFFFB800),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    rating,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE50914)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: const Color(0xFFE50914),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                isSeries ? 'SERIES' : 'MOVIE',
                                style: const TextStyle(
                                  color: Color(0xFFE50914),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                widget.mediaItem.provider ==
                                        ProviderType.fourKHdHub
                                    ? '4K ULTRA HD'
                                    : 'FULL HD',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Overview / Synopsis
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Text(
                            overview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.white70,
                              height: 1.35,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Action Bar: Play / Resume (Autofocused) + My List + Trailer
                        Row(
                          children: [
                            // 1. Primary Play / Resume Button (Autofocused!)
                            TvFocusable(
                              focusNode: _playButtonFocusNode,
                              autofocus: true,
                              scaleFactor: 1.08,
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
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
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE50914),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFE50914)
                                          .withValues(alpha: 0.45),
                                      blurRadius: 12,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      playButtonLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(width: 10),

                            // 2. Add / Remove from My List
                            TvFocusable(
                              scaleFactor: 1.08,
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                library.toggleFavorite(widget.mediaItem);
                                _showToast(
                                  isFav
                                      ? 'Removed from My List'
                                      : 'Added to My List',
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white24,
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isFav
                                          ? Icons.check_rounded
                                          : Icons.add_rounded,
                                      color: isFav
                                          ? const Color(0xFF46D369)
                                          : Colors.white,
                                      size: 17,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isFav ? 'In My List' : 'My List',
                                      style: TextStyle(
                                        color: isFav
                                            ? const Color(0xFF46D369)
                                            : Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // 3. Trailer Button (if available)
                            if (_tmdbDetails?.trailerYoutubeKey != null &&
                                _tmdbDetails!
                                    .trailerYoutubeKey!
                                    .isNotEmpty) ...[
                              const SizedBox(width: 10),
                              TvFocusable(
                                scaleFactor: 1.08,
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  final url = Uri.parse(
                                    'https://www.youtube.com/watch?v=${_tmdbDetails!.trailerYoutubeKey}',
                                  );
                                  launchUrl(
                                    url,
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white24,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.movie_outlined,
                                        color: Colors.white,
                                        size: 17,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Trailer',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        // 3. TV Series: Seasons Selector & Horizontal Episodes Row
                        if (isSeries &&
                            _details != null &&
                            _details!.seasons.isNotEmpty) ...[
                          const SizedBox(height: 20),

                          // Season Selector Tabs
                          const Text(
                            'Episodes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 8),

                          SizedBox(
                            height: 32,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              clipBehavior: Clip.none,
                              itemCount: _details!.seasons.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, sIdx) {
                                final isSelected = _selectedSeasonIdx == sIdx;
                                return TvFocusable(
                                  scaleFactor: 1.08,
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _onSeasonSelected(sIdx),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFE50914)
                                          : Colors.white.withValues(
                                              alpha: 0.08,
                                            ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFE50914)
                                            : Colors.white12,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Text(
                                      'Season ${sIdx + 1}',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                        fontSize: 11.5,
                                        fontWeight: isSelected
                                            ? FontWeight.w900
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Horizontal Episodes Row with 16:9 Stills, synopses, and progress
                          SizedBox(
                            height: 195,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              clipBehavior: Clip.none,
                              itemCount: currentSeasonEps.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 14),
                              itemBuilder: (context, epIdx) {
                                final ep = currentSeasonEps[epIdx];
                                final tmdbEp = tmdbEpMap[ep.episode];
                                final epThumbnail =
                                    tmdbEp?.stillUrl ?? backdropUrl;
                                final epTitle = tmdbEp?.name?.isNotEmpty == true
                                    ? tmdbEp!.name!
                                    : (ep.title.isNotEmpty
                                          ? ep.title
                                          : 'Episode ${ep.episode}');
                                final epOverview =
                                    tmdbEp?.overview?.isNotEmpty == true
                                    ? tmdbEp!.overview!
                                    : (ep.overview ?? '');

                                final epResume = library.getResumePosition(
                                  widget.mediaItem.id,
                                  season: ep.season,
                                  episode: ep.episode,
                                );

                                return _TvEpisodeCard(
                                  episode: ep,
                                  thumbnailUrl: epThumbnail,
                                  title: epTitle,
                                  overview: epOverview,
                                  resumePositionSeconds: epResume,
                                  onTap: () => _playEpisode(ep),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TvEpisodeCard extends StatelessWidget {
  final Episode episode;
  final String? thumbnailUrl;
  final String title;
  final String overview;
  final int resumePositionSeconds;
  final VoidCallback onTap;

  const _TvEpisodeCard({
    required this.episode,
    required this.thumbnailUrl,
    required this.title,
    required this.overview,
    required this.resumePositionSeconds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      scaleFactor: 1.06,
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 230,
        decoration: BoxDecoration(
          color: const Color(0xFF14171E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 16:9 Thumbnail Still
              SizedBox(
                height: 108,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          color: const Color(0xFF1C2029),
                          child: const Icon(
                            Icons.movie_rounded,
                            size: 30,
                            color: Colors.white24,
                          ),
                        ),
                      )
                    else
                      Container(
                        color: const Color(0xFF1C2029),
                        child: const Icon(
                          Icons.movie_rounded,
                          size: 30,
                          color: Colors.white24,
                        ),
                      ),

                    // Dark overlay vignette
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                            stops: const [0.5, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Episode Number Badge
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: Text(
                          'E${episode.episode}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                    // Play Center Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white38, width: 1.0),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),

                    // Resume progress bar (if watched)
                    if (resumePositionSeconds > 15)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: 0.5,
                          minHeight: 2.5,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFE50914),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Title & Synopsis Snippet
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${episode.episode}. $title',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      overview.isNotEmpty
                          ? overview
                          : 'Episode ${episode.episode}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
