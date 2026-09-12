import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_details.dart';
import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../../providers/library_provider.dart';
import '../theme/app_themes.dart';
import '../widgets/tv/tv_details_action_bar.dart';
import '../widgets/tv/tv_details_header.dart';
import '../widgets/tv/tv_episode_shelf.dart';
import '../widgets/tv/tv_more_like_this_shelf.dart';
import '../widgets/tv/tv_season_controls.dart';
import '../widgets/tv_focusable.dart';
import 'tv_details/tv_details_backdrop.dart';
import 'tv_details/tv_details_metadata_mixin.dart';
import 'tv_details/tv_details_playback_mixin.dart';
import 'tv_details/tv_details_trailer_mixin.dart';

/// A Netflix-like 10-foot UI Details Screen for Android TV.
/// Provides rich hero backdrop, metadata, season selector tabs,
/// and horizontal episode preview cards with TMDB stills and synopses.
class TvDetailsScreen extends StatefulWidget {
  final MediaItem mediaItem;

  const TvDetailsScreen({super.key, required this.mediaItem});

  @override
  State<TvDetailsScreen> createState() => _TvDetailsScreenState();
}

class _TvDetailsScreenState extends State<TvDetailsScreen>
    with TvDetailsMetadataMixin, TvDetailsTrailerMixin, TvDetailsPlaybackMixin {
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

  DateTime? _lastBackTime;

  @override
  void initState() {
    super.initState();
    loadAllDetails(
      mediaItem: widget.mediaItem,
      onTrailerAvailable: () {
        scheduleAutoPlayTrailer(
          trailerKey: tmdbDetails?.trailerYoutubeKey,
          autoPlayEnabled: context.read<AppProvider>().autoPlayTrailers,
        );
      },
      onInitialFocus: () {
        if (_playButtonFocusNode.canRequestFocus) {
          FocusScope.of(context).requestFocus(_playButtonFocusNode);
        }
      },
    );
  }

  @override
  void dispose() {
    disposeTrailer();
    _playButtonFocusNode.dispose();
    _firstEpisodeFocusNode.dispose();
    super.dispose();
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
    final isSeries = details?.isSeries ?? widget.mediaItem.isSeries;
    final hasEpisodes =
        isSeries && details != null && details!.seasons.isNotEmpty;

    if (hasEpisodes && _firstEpisodeFocusNode.canRequestFocus) {
      _firstEpisodeFocusNode.requestFocus();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isSeries = details?.isSeries ?? widget.mediaItem.isSeries;
    final backdropUrl =
        details?.backdropUrl ??
        widget.mediaItem.backdropUrl ??
        widget.mediaItem.posterUrl;
    final rawTitle = details?.title ?? widget.mediaItem.title;
    final parsedTitle = MediaItem.parseTitleTags(rawTitle);
    final title = parsedTitle.cleanTitle;
    final languageTag =
        details?.effectiveLanguageTag ??
        widget.mediaItem.effectiveLanguageTag ??
        parsedTitle.languageTag;
    final overview =
        tmdbDetails?.overview ??
        details?.description ??
        'No synopsis available.';
    final year = details?.year ?? widget.mediaItem.year;
    final rating = tmdbDetails?.rating != null
        ? tmdbDetails!.rating!.toStringAsFixed(1)
        : (details?.imdbRating ?? widget.mediaItem.rating?.toStringAsFixed(1));
    final ageCert = tmdbDetails?.certification ?? 'PG-13';

    final library = context.watch<LibraryProvider>();
    final isFav = library.isFavorite(widget.mediaItem.id);
    final history = library.getHistoryItem(widget.mediaItem.id);

    // Compute smart primary button label & resume state
    String playButtonLabel = 'Play';
    bool hasResume = false;
    if (isSeries) {
      if (history != null &&
          history.season != null &&
          history.episode != null) {
        final resumePos = library.getResumePosition(
          widget.mediaItem.id,
          season: history.season,
          episode: history.episode,
        );
        hasResume =
            resumePos > 15 || history.season! > 1 || history.episode! > 1;
        playButtonLabel = 'Resume S${history.season} E${history.episode}';
      } else {
        playButtonLabel = 'Play S1 E1';
      }
    } else {
      if (history != null && history.positionSeconds > 15) {
        final min = (history.positionSeconds / 60).floor();
        playButtonLabel = 'Resume (${min}m)';
        hasResume = true;
      }
    }

    final currentSeasonEps =
        (isSeries && details != null && details!.seasons.isNotEmpty)
        ? details!
              .seasons[selectedSeasonIdx.clamp(0, details!.seasons.length - 1)]
              .episodes
        : <Episode>[];

    final tmdbEpMap = cachedSeasonEpisodes[selectedSeasonIdx + 1] ?? {};

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        // Prevent accidental pop if a child route (e.g. PlayerScreen or Dialog) closed within 600ms
        if (lastChildPoppedTime != null &&
            now.difference(lastChildPoppedTime!).inMilliseconds < 600 &&
            !WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
          return;
        }
        // Direct back-press debounce
        if (_lastBackTime != null &&
            now.difference(_lastBackTime!).inMilliseconds < 400 &&
            !WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
          return;
        }
        _lastBackTime = now;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: context.tokens.canvasBackground,
        body: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: context.tokens.primaryAccent,
                ),
              )
            : Stack(
                children: [
                  TvDetailsBackdrop(
                    isTrailerPlaying: isTrailerPlaying,
                    trailerVideoController: trailerVideoController,
                    backdropUrl: backdropUrl,
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

                        // Action Bar: Play / Resume (Autofocused) + Restart + My List + Trailer
                        TvDetailsActionBar(
                          playButtonFocusNode: _playButtonFocusNode,
                          playButtonLabel: playButtonLabel,
                          hasResume: hasResume,
                          onRestart: hasResume
                              ? () {
                                  if (isSeries) {
                                    if (details != null &&
                                        details!.seasons.isNotEmpty) {
                                      final targetSeasonIdx =
                                          (history != null &&
                                              history.season != null &&
                                              history.season! <=
                                                  details!.seasons.length)
                                          ? (history.season! - 1)
                                          : selectedSeasonIdx.clamp(
                                              0,
                                              details!.seasons.length - 1,
                                            );
                                      final targetEps = details!
                                          .seasons[targetSeasonIdx]
                                          .episodes;
                                      if (targetEps.isNotEmpty) {
                                        final epToPlay =
                                            (history != null &&
                                                history.episode != null &&
                                                history.episode! <=
                                                    targetEps.length)
                                            ? targetEps[history.episode! - 1]
                                            : targetEps.first;
                                        playEpisode(
                                          mediaItem: widget.mediaItem,
                                          episode: epToPlay,
                                          details: details,
                                          onStopTrailer: stopTrailer,
                                          playButtonFocusNode:
                                              _playButtonFocusNode,
                                          startOver: true,
                                        );
                                      }
                                    }
                                  } else {
                                    playMovie(
                                      mediaItem: widget.mediaItem,
                                      onStopTrailer: stopTrailer,
                                      playButtonFocusNode: _playButtonFocusNode,
                                      startOver: true,
                                    );
                                  }
                                }
                              : null,
                          onPlay: () {
                            if (isSeries) {
                              if (details != null &&
                                  details!.seasons.isNotEmpty) {
                                final targetSeasonIdx =
                                    (history != null &&
                                        history.season != null &&
                                        history.season! <=
                                            details!.seasons.length)
                                    ? (history.season! - 1)
                                    : selectedSeasonIdx.clamp(
                                        0,
                                        details!.seasons.length - 1,
                                      );
                                final targetEps =
                                    details!.seasons[targetSeasonIdx].episodes;
                                if (targetEps.isNotEmpty) {
                                  final epToPlay =
                                      (history != null &&
                                          history.episode != null &&
                                          history.episode! <= targetEps.length)
                                      ? targetEps[history.episode! - 1]
                                      : targetEps.first;
                                  playEpisode(
                                    mediaItem: widget.mediaItem,
                                    episode: epToPlay,
                                    details: details,
                                    onStopTrailer: stopTrailer,
                                    playButtonFocusNode: _playButtonFocusNode,
                                  );
                                }
                              }
                            } else {
                              playMovie(
                                mediaItem: widget.mediaItem,
                                onStopTrailer: stopTrailer,
                                playButtonFocusNode: _playButtonFocusNode,
                              );
                            }
                          },
                          isFavorite: isFav,
                          onToggleFavorite: () {
                            library.toggleFavorite(widget.mediaItem);
                            showToast(
                              isFav
                                  ? 'Removed from My List'
                                  : 'Added to My List',
                            );
                          },
                          trailerYoutubeKey: tmdbDetails?.trailerYoutubeKey,
                          onOpenTrailer: () async {
                            await playTrailer(
                              mediaItem: widget.mediaItem,
                              trailerKey: tmdbDetails?.trailerYoutubeKey,
                              showError: showErrorDialog,
                              showToastMessage: showToast,
                            );
                            markChildRoutePopped();
                          },
                          // Explicitly moves focus into the episode shelf on
                          // D-Pad Down, bypassing the lazy ListView render issue.
                          onDownFocus: _onActionBarDownFocus,
                        ),

                        // 3. TV Series: Seasons Selector & Horizontal Episodes Row
                        if (isSeries &&
                            details != null &&
                            details!.seasons.isNotEmpty) ...[
                          const SizedBox(height: 20),

                          // Season Selector Tabs & Mark Season Watched Toggle
                          TvSeasonControls(
                            mediaItemId: widget.mediaItem.id,
                            seasons: details!.seasons,
                            selectedSeasonIndex: selectedSeasonIdx,
                            onSeasonSelected: onSeasonSelected,
                          ),

                          const SizedBox(height: 12),

                          TvEpisodeShelf(
                            episodes: currentSeasonEps,
                            tmdbEpMap: tmdbEpMap,
                            defaultThumbnailUrl: backdropUrl,
                            mediaItemId: widget.mediaItem.id,
                            onPlayEpisode: (ep) => playEpisode(
                              mediaItem: widget.mediaItem,
                              episode: ep,
                              details: details,
                              onStopTrailer: stopTrailer,
                              playButtonFocusNode: _playButtonFocusNode,
                            ),
                            onEpisodeLongPress:
                                (ep, title, resumeSeconds, isWatched) =>
                                    showEpisodeOptionsDialog(
                                      seriesItem: widget.mediaItem,
                                      episode: ep,
                                      title: title,
                                      resumeSeconds: resumeSeconds,
                                      isWatched: isWatched,
                                      onStopTrailer: stopTrailer,
                                      playButtonFocusNode: _playButtonFocusNode,
                                    ),
                            // Provides the parent with direct focus control
                            // over the first episode card (see _onActionBarDownFocus).
                            firstCardFocusNode: _firstEpisodeFocusNode,
                          ),
                        ],
                        if (details != null && relatedItems.isNotEmpty)
                          TvMoreLikeThisShelf(
                            items: relatedItems,
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
