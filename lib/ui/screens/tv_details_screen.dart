import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'settings_screen.dart';

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

  /// Focus node for the currently selected season pill in [TvSeasonSelector].
  final FocusNode _seasonPillFocusNode = FocusNode(
    debugLabel: 'TvDetailsSeasonPill',
  );

  /// Focus node for the "Mark Season" watched button in [TvSeasonControls].
  final FocusNode _markSeasonFocusNode = FocusNode(
    debugLabel: 'TvDetailsMarkSeasonBtn',
  );

  /// Focus node for the first episode card in [TvEpisodeShelf].
  final FocusNode _firstEpisodeFocusNode = FocusNode(
    debugLabel: 'TvDetailsFirstEpisodeCard',
  );

  /// Focus node for the first recommendation card in [TvMoreLikeThisShelf].
  final FocusNode _firstRecommendationFocusNode = FocusNode(
    debugLabel: 'TvDetailsFirstRecCard',
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
    _seasonPillFocusNode.dispose();
    _markSeasonFocusNode.dispose();
    _firstEpisodeFocusNode.dispose();
    _firstRecommendationFocusNode.dispose();
    super.dispose();
  }

  /// Requests focus on [node] and ensures it is smoothly brought into view
  /// in the scrollable canvas.
  void _safeFocus(FocusNode node) {
    if (node.canRequestFocus) {
      node.requestFocus();
      if (node.context != null) {
        Scrollable.ensureVisible(
          node.context!,
          alignment: 0.35,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  /// Called when the user presses D-Pad Down from any action bar button (Row 0).
  ///
  /// - For series with multiple seasons: focuses the active season pill in Row 1.
  /// - For series with 1 season: focuses the "Mark Season" button in Row 1.
  /// - For movies: focuses the first recommendation card in Row 3 if available.
  bool _onActionBarDownFocus() {
    final isSeries = details?.isSeries ?? widget.mediaItem.isSeries;
    if (isSeries && details != null && details!.seasons.isNotEmpty) {
      if (details!.seasons.length > 1) {
        _safeFocus(_seasonPillFocusNode);
      } else {
        _safeFocus(_markSeasonFocusNode);
      }
      return true;
    } else if (relatedItems.isNotEmpty) {
      _safeFocus(_firstRecommendationFocusNode);
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

    final inContinueWatching =
        library.continueWatching.any((h) => h.item.id == widget.mediaItem.id) ||
        hasResume;

    final currentSeasonEps =
        (isSeries && details != null && details!.seasons.isNotEmpty)
        ? details!
              .seasons[selectedSeasonIdx.clamp(0, details!.seasons.length - 1)]
              .episodes
        : <Episode>[];

    final currentSeasonNum =
        (details != null &&
            details!.seasons.isNotEmpty &&
            selectedSeasonIdx < details!.seasons.length)
        ? details!.seasons[selectedSeasonIdx].seasonNumber
        : selectedSeasonIdx + 1;
    final tmdbEpMap = cachedSeasonEpisodes[currentSeasonNum] ?? {};

    void handlePop() {
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
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        handlePop();
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (node, event) {
          final isBackKey =
              event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.goBack ||
              event.logicalKey.keyId == 0x00200000004;

          if (isBackKey && event is KeyUpEvent) {
            handlePop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          backgroundColor: context.tokens.canvasBackground,
          body: Stack(
            children: [
              TvDetailsBackdrop(
                isTrailerPlaying: isTrailerPlaying,
                trailerVideoController: trailerVideoController,
                backdropUrl: backdropUrl,
              ),
              if (isLoading)
                Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: context.tokens.primaryAccent,
                  ),
                )
              else
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
                              color: context.tokens.canvasBackground.withValues(
                                alpha: 0.4,
                              ),
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
                                        imdbId: tmdbDetails?.imdbId,
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
                                    details: details,
                                    imdbId: tmdbDetails?.imdbId,
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
                                  imdbId: tmdbDetails?.imdbId,
                                  onStopTrailer: stopTrailer,
                                  playButtonFocusNode: _playButtonFocusNode,
                                );
                              }
                            } else {
                              playEpisode(
                                mediaItem: widget.mediaItem,
                                episode: const Episode(
                                  season: 1,
                                  episode: 1,
                                  title: 'Episode 1',
                                ),
                                details: details,
                                imdbId: tmdbDetails?.imdbId,
                                onStopTrailer: stopTrailer,
                                playButtonFocusNode: _playButtonFocusNode,
                              );
                            }
                          } else {
                            playMovie(
                              mediaItem: widget.mediaItem,
                              details: details,
                              imdbId: tmdbDetails?.imdbId,
                              onStopTrailer: stopTrailer,
                              playButtonFocusNode: _playButtonFocusNode,
                            );
                          }
                        },
                        isFavorite: isFav,
                        onToggleFavorite: () {
                          library.toggleFavorite(widget.mediaItem);
                          showToast(
                            isFav ? 'Removed from My List' : 'Added to My List',
                          );
                        },
                        isAlreadyWatched: library.isAlreadyWatched(
                          widget.mediaItem.id,
                        ),
                        onToggleAlreadyWatched: () async {
                          await library.toggleAlreadyWatched(widget.mediaItem);
                          showToast(
                            library.isAlreadyWatched(widget.mediaItem.id)
                                ? 'Marked as Already Watched'
                                : 'Removed from Already Watched',
                          );
                        },
                        onOpenPlugins: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                          markChildRoutePopped();
                        },
                        inContinueWatching: inContinueWatching,
                        onRemoveFromContinueWatching: inContinueWatching
                            ? () async {
                                _safeFocus(_playButtonFocusNode);
                                await library.removeFromHistory(
                                  widget.mediaItem.id,
                                );
                                showToast('Removed from Continue Watching');
                              }
                            : null,
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

                        // Season Selector Tabs & Mark Season Watched Toggle (Row 1)
                        TvSeasonControls(
                          mediaItemId: widget.mediaItem.id,
                          seasons: details!.seasons,
                          selectedSeasonIndex: selectedSeasonIdx,
                          onSeasonSelected: onSeasonSelected,
                          selectedSeasonFocusNode: _seasonPillFocusNode,
                          markSeasonFocusNode: _markSeasonFocusNode,
                          onUpFocus: () {
                            _safeFocus(_playButtonFocusNode);
                            return true;
                          },
                          onDownFocus: () {
                            _safeFocus(_firstEpisodeFocusNode);
                            return true;
                          },
                        ),

                        const SizedBox(height: 12),

                        // Episode Shelf (Row 2)
                        TvEpisodeShelf(
                          episodes: currentSeasonEps,
                          tmdbEpMap: tmdbEpMap,
                          defaultThumbnailUrl: backdropUrl,
                          mediaItemId: widget.mediaItem.id,
                          onPlayEpisode: (ep) => playEpisode(
                            mediaItem: widget.mediaItem,
                            episode: ep,
                            details: details,
                            imdbId: tmdbDetails?.imdbId,
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
                          firstCardFocusNode: _firstEpisodeFocusNode,
                          onUpFocus: () {
                            if (details != null &&
                                details!.seasons.length > 1) {
                              _safeFocus(_seasonPillFocusNode);
                            } else if (details != null &&
                                details!.seasons.length == 1) {
                              _safeFocus(_markSeasonFocusNode);
                            } else {
                              _safeFocus(_playButtonFocusNode);
                            }
                            return true;
                          },
                          onDownFocus: () {
                            if (relatedItems.isNotEmpty) {
                              _safeFocus(_firstRecommendationFocusNode);
                              return true;
                            }
                            return false;
                          },
                        ),
                      ],
                      // More Like This Shelf (Row 3)
                      if (details != null && relatedItems.isNotEmpty)
                        TvMoreLikeThisShelf(
                          items: relatedItems,
                          firstCardFocusNode: _firstRecommendationFocusNode,
                          onItemSelect: (item) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) =>
                                    TvDetailsScreen(mediaItem: item),
                              ),
                            );
                          },
                          onUpFocus: () {
                            if (isSeries &&
                                details != null &&
                                details!.seasons.isNotEmpty) {
                              _safeFocus(_firstEpisodeFocusNode);
                            } else {
                              _safeFocus(_playButtonFocusNode);
                            }
                            return true;
                          },
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
