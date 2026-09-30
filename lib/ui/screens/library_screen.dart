import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../models/stream_source.dart';
import '../../providers/app_provider.dart';
import '../../providers/library_provider.dart';
import '../../services/direct_stream_service.dart';
import '../theme/app_themes.dart';
import '../widgets/media_card.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_play_helper.dart';
import 'details_screen.dart';
import 'player_screen.dart';
import 'tv_details_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final PageController _pageController;
  int _selectedPageIndex = 0;

  final FocusNode _watchlistToggleFocusNode = FocusNode(
    debugLabel: 'LibWatchlistToggle',
  );
  final FocusNode _historyToggleFocusNode = FocusNode(
    debugLabel: 'LibHistoryToggle',
  );
  final FocusNode _alreadyWatchedToggleFocusNode = FocusNode(
    debugLabel: 'LibAlreadyWatchedToggle',
  );
  final FocusNode _downloadsToggleFocusNode = FocusNode(
    debugLabel: 'LibDownloadsToggle',
  );
  final FocusNode _firstWatchlistCardFocusNode = FocusNode(
    debugLabel: 'LibFirstWatchlistCard',
  );
  final FocusNode _firstHistoryCardFocusNode = FocusNode(
    debugLabel: 'LibFirstHistoryCard',
  );
  final FocusNode _firstAlreadyWatchedCardFocusNode = FocusNode(
    debugLabel: 'LibFirstAlreadyWatchedCard',
  );
  final FocusNode _firstDownloadsCardFocusNode = FocusNode(
    debugLabel: 'LibFirstDownloadsCard',
  );

  List<DownloadedVideoFile> _downloadedFiles = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedPageIndex);
    _loadDownloadedFiles();
    DirectStreamService.instance.addListener(_onDirectStreamServiceUpdate);
  }

  void _onDirectStreamServiceUpdate() {
    if (mounted) {
      _loadDownloadedFiles();
      setState(() {});
    }
  }

  Future<void> _loadDownloadedFiles() async {
    final files = await DirectStreamService.instance.getDownloadedFiles();
    if (mounted) {
      setState(() {
        _downloadedFiles = files;
      });
    }
  }

  @override
  void dispose() {
    DirectStreamService.instance.removeListener(_onDirectStreamServiceUpdate);
    _pageController.dispose();
    _watchlistToggleFocusNode.dispose();
    _historyToggleFocusNode.dispose();
    _alreadyWatchedToggleFocusNode.dispose();
    _downloadsToggleFocusNode.dispose();
    _firstWatchlistCardFocusNode.dispose();
    _firstHistoryCardFocusNode.dispose();
    _firstAlreadyWatchedCardFocusNode.dispose();
    _firstDownloadsCardFocusNode.dispose();
    super.dispose();
  }

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

  void _openDetails(BuildContext context, MediaItem item, [String? heroTag]) {
    final isTv = context.read<AppProvider>().isTvMode;
    if (isTv) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TvDetailsScreen(mediaItem: item)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DetailsScreen(mediaItem: item, heroTag: heroTag),
        ),
      );
    }
  }

  void _showClearHistoryDialog(BuildContext context, LibraryProvider library) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surfaceElevated,
        shape: tokens.getShapeBorder(
          radius: tokens.cardRadius,
          side: BorderSide(color: tokens.borderSubtle),
        ),
        title: Text(
          'Clear Watch History?',
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will remove all items from Continue Watching.',
          style: TextStyle(color: tokens.textSecondary),
        ),
        actions: [
          TvFocusable(
            borderRadius: tokens.borderRadiusSm,
            onTap: () => Navigator.of(ctx).pop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text('Cancel', style: TextStyle(color: tokens.textMuted)),
            ),
          ),
          TvFocusable(
            autofocus: true,
            borderRadius: tokens.borderRadiusSm,
            onTap: () {
              Navigator.of(ctx).pop();
              library.clearHistory();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                'Clear All',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageToggle(BuildContext context, LibraryProvider library) {
    final tokens = context.tokens;

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: tokens.surfaceElevated,
            borderRadius: tokens.borderRadiusPill,
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToggleButton(
                context: context,
                index: 0,
                label: 'Watchlist',
                count: library.favorites.length,
                icon: Icons.bookmark_rounded,
                library: library,
              ),
              const SizedBox(width: 4),
              _buildToggleButton(
                context: context,
                index: 1,
                label: 'Continue Watching',
                count: library.continueWatching.length,
                icon: Icons.play_circle_rounded,
                library: library,
              ),
              const SizedBox(width: 4),
              _buildToggleButton(
                context: context,
                index: 2,
                label: 'Already Watched',
                count: library.alreadyWatched.length,
                icon: Icons.check_circle_rounded,
                library: library,
              ),
              const SizedBox(width: 4),
              _buildToggleButton(
                context: context,
                index: 3,
                label: 'Downloads',
                count:
                    DirectStreamService
                        .instance
                        .inProgressAndQueuedTasks
                        .length +
                    _downloadedFiles.length,
                icon: Icons.download_rounded,
                library: library,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required BuildContext context,
    required int index,
    required String label,
    required int count,
    required IconData icon,
    required LibraryProvider library,
  }) {
    final isSelected = _selectedPageIndex == index;
    final theme = Theme.of(context);
    final tokens = context.tokens;

    final focusNode = index == 0
        ? _watchlistToggleFocusNode
        : (index == 1
              ? _historyToggleFocusNode
              : (index == 2
                    ? _alreadyWatchedToggleFocusNode
                    : _downloadsToggleFocusNode));

    return TvFocusable(
      focusNode: focusNode,
      scaleFactor: 1.05,
      borderRadius: tokens.borderRadiusPill,
      onDirection: (direction) {
        if (index == 0) {
          if (direction == TraversalDirection.right) {
            _historyToggleFocusNode.requestFocus();
            return true;
          }
          if (direction == TraversalDirection.left) {
            return true; // Clamped at left
          }
          if (direction == TraversalDirection.down) {
            if (library.favorites.isNotEmpty) {
              _safeFocus(_firstWatchlistCardFocusNode);
              return true;
            }
          }
        } else if (index == 1) {
          if (direction == TraversalDirection.left) {
            _watchlistToggleFocusNode.requestFocus();
            return true;
          }
          if (direction == TraversalDirection.right) {
            _alreadyWatchedToggleFocusNode.requestFocus();
            return true;
          }
          if (direction == TraversalDirection.down) {
            if (library.continueWatching.isNotEmpty) {
              _safeFocus(_firstHistoryCardFocusNode);
              return true;
            }
          }
        } else if (index == 2) {
          if (direction == TraversalDirection.left) {
            _historyToggleFocusNode.requestFocus();
            return true;
          }
          if (direction == TraversalDirection.right) {
            _downloadsToggleFocusNode.requestFocus();
            return true;
          }
          if (direction == TraversalDirection.down) {
            if (library.alreadyWatched.isNotEmpty) {
              _safeFocus(_firstAlreadyWatchedCardFocusNode);
              return true;
            }
          }
        } else if (index == 3) {
          if (direction == TraversalDirection.left) {
            _alreadyWatchedToggleFocusNode.requestFocus();
            return true;
          }
          if (direction == TraversalDirection.right) {
            return true; // Clamped at right
          }
          if (direction == TraversalDirection.down) {
            if (DirectStreamService
                    .instance
                    .inProgressAndQueuedTasks
                    .isNotEmpty ||
                _downloadedFiles.isNotEmpty) {
              _safeFocus(_firstDownloadsCardFocusNode);
              return true;
            }
          }
        }
        return false;
      },
      onTap: () {
        if (_selectedPageIndex != index) {
          setState(() => _selectedPageIndex = index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : null,
          borderRadius: tokens.borderRadiusPill,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : tokens.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              count > 0 ? '$label ($count)' : label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchlistPage(
    LibraryProvider library,
    int crossAxisCount,
    double bottomPad,
  ) {
    final tokens = context.tokens;

    if (library.favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 56,
              color: tokens.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              'Your Watchlist is empty',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + on any movie or series to save it for later',
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPad),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.58,
        crossAxisSpacing: 8,
        mainAxisSpacing: 12,
      ),
      itemCount: library.favorites.length,
      itemBuilder: (context, index) {
        final item = library.favorites[index];
        final heroTag = 'library_${item.id}_$index';
        final isTopRow = index < crossAxisCount;
        final isFirstCol = index % crossAxisCount == 0;
        final isLastCol =
            (index + 1) % crossAxisCount == 0 ||
            index == library.favorites.length - 1;

        return MediaCard(
          item: item,
          heroTag: heroTag,
          focusNode: index == 0 ? _firstWatchlistCardFocusNode : null,
          isFirstCard: isFirstCol,
          isLastCard: isLastCol,
          onUp: isTopRow
              ? () {
                  _safeFocus(_watchlistToggleFocusNode);
                  return true;
                }
              : null,
          onTap: () => _openDetails(context, item, heroTag),
        );
      },
    );
  }

  Widget _buildContinueWatchingPage(
    LibraryProvider library,
    ThemeData theme,
    double bottomPad,
  ) {
    final tokens = context.tokens;

    if (library.continueWatching.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              size: 56,
              color: tokens.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              'No active playback history',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Movies and episodes in progress will appear here',
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(14, 10, 14, bottomPad),
      itemCount: library.continueWatching.length,
      itemBuilder: (context, index) {
        final h = library.continueWatching[index];
        final imageUrl = h.item.backdropUrl ?? h.item.posterUrl;
        final cardShape = tokens.shapeSm;
        final thumbShape = tokens.shapeXs;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TvFocusable(
                  focusNode: index == 0 ? _firstHistoryCardFocusNode : null,
                  scaleFactor: 1.02,
                  borderRadius: BorderRadius.circular(
                    (tokens.cardRadius * 0.65).clamp(4.0, 10.0),
                  ),
                  onDirection: (direction) {
                    if (direction == TraversalDirection.up && index == 0) {
                      _safeFocus(_historyToggleFocusNode);
                      return true;
                    }
                    if (direction == TraversalDirection.left) {
                      return true; // Clamped on left
                    }
                    return false;
                  },
                  onTap: () => _openDetails(context, h.item),
                  child: Container(
                    decoration: tokens.getShapeDecoration(
                      color: tokens.surfaceCard,
                      radius: (tokens.cardRadius * 0.65).clamp(4.0, 10.0),
                      side: BorderSide(color: tokens.borderSubtle),
                    ),
                    child: ClipPath(
                      clipper: ShapeBorderClipper(shape: cardShape),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipPath(
                                  clipper: ShapeBorderClipper(
                                    shape: thumbShape,
                                  ),
                                  child: imageUrl != null
                                      ? Image.network(
                                          imageUrl,
                                          width: 80,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            width: 80,
                                            height: 48,
                                            color: tokens.surfaceElevated,
                                            child: Icon(
                                              Icons.movie,
                                              color: tokens.textMuted,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          width: 80,
                                          height: 48,
                                          color: tokens.surfaceElevated,
                                          child: Icon(
                                            Icons.movie,
                                            color: tokens.textMuted,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        h.item.cleanTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: tokens.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (h.season != null && h.episode != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            'Season ${h.season} • Episode ${h.episode}',
                                            style: TextStyle(
                                              color: tokens.primaryAccent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Progress Bar
                          LinearProgressIndicator(
                            value: h.progress,
                            backgroundColor: tokens.borderSubtle,
                            color: tokens.primaryAccent,
                            minHeight: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Action 1: Resume Play
              TvFocusable(
                scaleFactor: 1.08,
                borderRadius: tokens.borderRadiusPill,
                onDirection: (direction) {
                  if (direction == TraversalDirection.up && index == 0) {
                    _safeFocus(_historyToggleFocusNode);
                    return true;
                  }
                  return false;
                },
                onTap: () => TvPlayHelper.resumePlayback(context, h),
                child: Tooltip(
                  message: 'Resume Playback',
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: tokens.getShapeDecoration(
                      color: tokens.surfaceCard,
                      radius: 22,
                      side: BorderSide(color: tokens.borderSubtle, width: 0.8),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: tokens.primaryAccent,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Action 2: Mark as Watched
              TvFocusable(
                scaleFactor: 1.08,
                borderRadius: tokens.borderRadiusPill,
                onDirection: (direction) {
                  if (direction == TraversalDirection.up && index == 0) {
                    _safeFocus(_historyToggleFocusNode);
                    return true;
                  }
                  return false;
                },
                onTap: () {
                  library.markAsWatched(
                    h.item.id,
                    season: h.season,
                    episode: h.episode,
                    isWatched: true,
                    item: h.item,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Marked "${h.item.cleanTitle}" as watched',
                        style: TextStyle(color: tokens.textPrimary),
                      ),
                      duration: const Duration(seconds: 2),
                      backgroundColor: tokens.surfaceElevated,
                    ),
                  );
                },
                child: Tooltip(
                  message: 'Mark as Watched',
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: tokens.getShapeDecoration(
                      color: tokens.surfaceCard,
                      radius: 22,
                      side: BorderSide(color: tokens.borderSubtle, width: 0.8),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      color: tokens.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Action 3: Remove from History
              TvFocusable(
                scaleFactor: 1.08,
                borderRadius: tokens.borderRadiusPill,
                onDirection: (direction) {
                  if (direction == TraversalDirection.up && index == 0) {
                    _safeFocus(_historyToggleFocusNode);
                    return true;
                  }
                  if (direction == TraversalDirection.right) {
                    return true; // Clamped on far right
                  }
                  return false;
                },
                onTap: () {
                  library.removeFromHistory(
                    h.item.id,
                    season: h.season,
                    episode: h.episode,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Removed "${h.item.cleanTitle}" from history',
                        style: TextStyle(color: tokens.textPrimary),
                      ),
                      duration: const Duration(seconds: 2),
                      backgroundColor: tokens.surfaceElevated,
                    ),
                  );
                },
                child: Tooltip(
                  message: 'Remove from History',
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: tokens.getShapeDecoration(
                      color: tokens.surfaceCard,
                      radius: 22,
                      side: BorderSide(color: tokens.borderSubtle, width: 0.8),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: tokens.textMuted,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlreadyWatchedPage(
    LibraryProvider library,
    int crossAxisCount,
    double bottomPad,
  ) {
    final tokens = context.tokens;

    if (library.alreadyWatched.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: tokens.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              'No watched titles yet',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mark movies and shows as Already Watched to track your viewing history',
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPad),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.58,
        crossAxisSpacing: 8,
        mainAxisSpacing: 12,
      ),
      itemCount: library.alreadyWatched.length,
      itemBuilder: (context, index) {
        final item = library.alreadyWatched[index];
        final heroTag = 'already_watched_${item.id}_$index';
        final isTopRow = index < crossAxisCount;
        final isFirstCol = index % crossAxisCount == 0;
        final isLastCol =
            (index + 1) % crossAxisCount == 0 ||
            index == library.alreadyWatched.length - 1;

        return Stack(
          children: [
            MediaCard(
              item: item,
              heroTag: heroTag,
              focusNode: index == 0 ? _firstAlreadyWatchedCardFocusNode : null,
              isFirstCard: isFirstCol,
              isLastCard: isLastCol,
              onUp: isTopRow
                  ? () {
                      _safeFocus(_alreadyWatchedToggleFocusNode);
                      return true;
                    }
                  : null,
              onTap: () => _openDetails(context, item, heroTag),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: tokens.primaryAccent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteDownloadedFile(DownloadedVideoFile file) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surfaceElevated,
        shape: tokens.getShapeBorder(
          radius: tokens.cardRadius,
          side: BorderSide(color: tokens.borderSubtle),
        ),
        title: Text(
          'Delete Downloaded Video?',
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${file.fileName}" (${file.formattedSize}) from your device?',
          style: TextStyle(color: tokens.textSecondary),
        ),
        actions: [
          TvFocusable(
            autofocus: true,
            borderRadius: tokens.borderRadiusSm,
            onTap: () => Navigator.of(ctx).pop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text('Cancel', style: TextStyle(color: tokens.textMuted)),
            ),
          ),
          TvFocusable(
            borderRadius: tokens.borderRadiusSm,
            onTap: () async {
              Navigator.of(ctx).pop();
              await DirectStreamService.instance.deleteDownloadedFile(
                file.path,
              );
              _loadDownloadedFiles();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                'Delete',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _playOfflineVideo(DownloadedVideoFile file) {
    final mediaItem = DirectStreamService.instance.createMediaItem(
      file.path,
      file.fileName,
    );
    final streamSource = StreamSource(
      quality: 'Offline',
      resolution: '1080p',
      format: 'MP4',
      url: file.path,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          mediaItem: mediaItem,
          streamSource: streamSource,
          availableSources: [streamSource],
        ),
      ),
    );
  }

  Widget _buildDownloadsPage(double bottomPad) {
    final tokens = context.tokens;
    final service = DirectStreamService.instance;

    final inProgressAndQueued = service.inProgressAndQueuedTasks;
    final downloaded = _downloadedFiles;

    if (inProgressAndQueued.isEmpty && downloaded.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_for_offline_rounded,
              size: 56,
              color: tokens.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              'No Downloads Yet',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Downloaded movies and episodes will be stored here for offline viewing.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
      children: [
        if (inProgressAndQueued.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'In Progress & Queue (${inProgressAndQueued.length})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: tokens.textPrimary,
                  ),
                ),
                TvFocusable(
                  borderRadius: tokens.borderRadiusSm,
                  onTap: () => service.clearCompletedTasks(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      'Clear Finished',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...inProgressAndQueued.asMap().entries.map((entry) {
            final idx = entry.key;
            final task = entry.value;
            final isFirst = idx == 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildDownloadTaskCard(
                task,
                focusNode: isFirst ? _firstDownloadsCardFocusNode : null,
                isTopCard: isFirst,
              ),
            );
          }),
          const SizedBox(height: 14),
        ],

        if (downloaded.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Downloaded Videos (${downloaded.length})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: tokens.textPrimary,
                  ),
                ),
                Text(
                  _calculateTotalDownloadedSize(downloaded),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ...downloaded.asMap().entries.map((entry) {
            final idx = entry.key;
            final file = entry.value;
            final isFirst = inProgressAndQueued.isEmpty && idx == 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildDownloadedFileCard(
                file,
                focusNode: isFirst ? _firstDownloadsCardFocusNode : null,
                isTopCard: isFirst,
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildDownloadTaskCard(
    VideoDownloadTask task, {
    FocusNode? focusNode,
    bool isTopCard = false,
  }) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final isDownloading = task.status == DownloadTaskStatus.downloading;
    final isPaused = task.status == DownloadTaskStatus.paused;
    final isFailed = task.status == DownloadTaskStatus.failed;
    final isQueued = task.status == DownloadTaskStatus.queued;

    Color statusColor;
    String statusLabel;
    if (isDownloading) {
      statusColor = theme.colorScheme.primary;
      statusLabel = 'Downloading';
    } else if (isPaused) {
      statusColor = tokens.vipColor;
      statusLabel = 'Paused';
    } else if (isFailed) {
      statusColor = theme.colorScheme.error;
      statusLabel = 'Failed';
    } else {
      statusColor = tokens.textSecondary;
      statusLabel = 'Queued';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: tokens.borderRadiusSm,
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tokens.surfaceCard,
                  borderRadius: tokens.borderRadiusXs,
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Icon(
                  isDownloading
                      ? Icons.downloading_rounded
                      : (isPaused
                            ? Icons.pause_rounded
                            : (isFailed
                                  ? Icons.error_outline_rounded
                                  : Icons.schedule_rounded)),
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: tokens.borderRadiusXs,
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                        if (task.quality != null &&
                            task.quality!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            task.quality!,
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isDownloading) ...[
                TvFocusable(
                  borderRadius: tokens.borderRadiusSm,
                  focusNode: focusNode,
                  onDirection: isTopCard
                      ? (direction) {
                          if (direction == TraversalDirection.up) {
                            _safeFocus(_downloadsToggleFocusNode);
                            return true;
                          }
                          return false;
                        }
                      : null,
                  onTap: () =>
                      DirectStreamService.instance.pauseDownload(task.id),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.pause_rounded,
                      color: tokens.textPrimary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                TvFocusable(
                  borderRadius: tokens.borderRadiusSm,
                  onTap: () =>
                      DirectStreamService.instance.cancelDownload(task.id),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.close_rounded,
                      color: tokens.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ] else if (isPaused || isQueued) ...[
                TvFocusable(
                  borderRadius: tokens.borderRadiusSm,
                  focusNode: focusNode,
                  onDirection: isTopCard
                      ? (direction) {
                          if (direction == TraversalDirection.up) {
                            _safeFocus(_downloadsToggleFocusNode);
                            return true;
                          }
                          return false;
                        }
                      : null,
                  onTap: () =>
                      DirectStreamService.instance.resumeDownload(task.id),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                TvFocusable(
                  borderRadius: tokens.borderRadiusSm,
                  onTap: () =>
                      DirectStreamService.instance.cancelDownload(task.id),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.close_rounded,
                      color: tokens.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ] else if (isFailed) ...[
                TvFocusable(
                  borderRadius: tokens.borderRadiusSm,
                  focusNode: focusNode,
                  onDirection: isTopCard
                      ? (direction) {
                          if (direction == TraversalDirection.up) {
                            _safeFocus(_downloadsToggleFocusNode);
                            return true;
                          }
                          return false;
                        }
                      : null,
                  onTap: () =>
                      DirectStreamService.instance.retryDownload(task.id),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                TvFocusable(
                  borderRadius: tokens.borderRadiusSm,
                  onTap: () => DirectStreamService.instance.removeTask(task.id),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: tokens.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: tokens.borderRadiusPill,
              child: LinearProgressIndicator(
                value: task.progress > 0 ? task.progress : null,
                minHeight: 5,
                backgroundColor: tokens.borderSubtle.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${task.formattedProgress} • ${task.formattedSpeed}',
                  style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                ),
                Text(
                  task.formattedSize,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ] else if (isFailed && task.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              task.errorMessage!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadedFileCard(
    DownloadedVideoFile file, {
    FocusNode? focusNode,
    bool isTopCard = false,
  }) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: tokens.borderRadiusSm,
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tokens.surfaceElevated,
              borderRadius: tokens.borderRadiusXs,
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Icon(
              Icons.movie_rounded,
              color: theme.colorScheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${file.formattedSize} • ${_formatFileDate(file.modifiedAt)}',
                  style: TextStyle(fontSize: 11.5, color: tokens.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TvFocusable(
            borderRadius: tokens.borderRadiusSm,
            focusNode: focusNode,
            onDirection: isTopCard
                ? (direction) {
                    if (direction == TraversalDirection.up) {
                      _safeFocus(_downloadsToggleFocusNode);
                      return true;
                    }
                    return false;
                  }
                : null,
            onTap: () => _playOfflineVideo(file),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: tokens.borderRadiusSm,
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    color: theme.colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Play',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          TvFocusable(
            borderRadius: tokens.borderRadiusSm,
            onTap: () => _confirmDeleteDownloadedFile(file),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.delete_outline_rounded,
                color: tokens.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateTotalDownloadedSize(List<DownloadedVideoFile> files) {
    int total = 0;
    for (final f in files) {
      total += f.sizeBytes;
    }
    if (total >= 1024 * 1024 * 1024) {
      return '${(total / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB total';
    }
    if (total >= 1024 * 1024) {
      return '${(total / (1024 * 1024)).toStringAsFixed(1)} MB total';
    }
    return '${(total / 1024).toStringAsFixed(0)} KB total';
  }

  String _formatFileDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final library = context.watch<LibraryProvider>();
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = (width / 160).floor().clamp(2, 8);
    final isDesktop = width >= 800;
    final bottomPad = isDesktop ? 24.0 : 100.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'My List',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.3,
            color: tokens.textPrimary,
          ),
        ),
        actions: [
          if (_selectedPageIndex == 1 && library.continueWatching.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TvFocusable(
                borderRadius: tokens.borderRadiusPill,
                onTap: () => _showClearHistoryDialog(context, library),
                child: Tooltip(
                  message: 'Clear Watch History',
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.delete_sweep_rounded,
                      color: tokens.textSecondary,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          if (_selectedPageIndex == 3 &&
              DirectStreamService.instance.tasks.any(
                (t) =>
                    t.status == DownloadTaskStatus.completed ||
                    t.status == DownloadTaskStatus.failed ||
                    t.status == DownloadTaskStatus.cancelled,
              ))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TvFocusable(
                borderRadius: tokens.borderRadiusPill,
                onTap: () => DirectStreamService.instance.clearCompletedTasks(),
                child: Tooltip(
                  message: 'Clear Finished Tasks',
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.cleaning_services_rounded,
                      color: tokens.textSecondary,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildPageToggle(context, library),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (idx) {
          if (_selectedPageIndex != idx) {
            setState(() => _selectedPageIndex = idx);
          }
        },
        children: [
          _buildWatchlistPage(library, crossAxisCount, bottomPad),
          _buildContinueWatchingPage(library, theme, bottomPad),
          _buildAlreadyWatchedPage(library, crossAxisCount, bottomPad),
          _buildDownloadsPage(bottomPad),
        ],
      ),
    );
  }
}
