import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../../providers/library_provider.dart';
import '../theme/app_themes.dart';
import '../widgets/media_card.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_play_helper.dart';
import 'details_screen.dart';
import 'tv_details_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final PageController _pageController;
  int _selectedPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedPageIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
        shape: RoundedRectangleBorder(
          borderRadius: tokens.borderRadiusMd,
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
      child: Padding(
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
              ),
              const SizedBox(width: 4),
              _buildToggleButton(
                context: context,
                index: 1,
                label: 'Continue Watching',
                count: library.continueWatching.length,
                icon: Icons.play_circle_rounded,
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
  }) {
    final isSelected = _selectedPageIndex == index;
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return TvFocusable(
      scaleFactor: 1.05,
      borderRadius: tokens.borderRadiusPill,
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
        return MediaCard(
          item: item,
          heroTag: heroTag,
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
          child: TvFocusable(
            scaleFactor: 1.02,
            borderRadius: BorderRadius.circular(
              (tokens.cardRadius * 0.65).clamp(4.0, 10.0),
            ),
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
                            clipper: ShapeBorderClipper(shape: thumbShape),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Season ${h.season} • Episode ${h.episode}',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          TvFocusable(
                            borderRadius: tokens.borderRadiusPill,
                            onTap: () =>
                                TvPlayHelper.resumePlayback(context, h),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                color: tokens.primaryAccent,
                                size: 24,
                              ),
                            ),
                          ),
                          TvFocusable(
                            borderRadius: tokens.borderRadiusPill,
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
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.check_circle_outline_rounded,
                                color: tokens.textSecondary,
                                size: 20,
                              ),
                            ),
                          ),
                          TvFocusable(
                            borderRadius: tokens.borderRadiusPill,
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
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: tokens.textMuted,
                                size: 20,
                              ),
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
        );
      },
    );
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
        ],
      ),
    );
  }
}
