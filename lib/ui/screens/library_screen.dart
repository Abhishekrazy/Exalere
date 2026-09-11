import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../../providers/library_provider.dart';
import '../theme/app_themes.dart';
import '../widgets/media_card.dart';
import '../widgets/tv_play_helper.dart';
import 'details_screen.dart';
import 'tv_details_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = context.watch<LibraryProvider>();
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = (width / 160).floor().clamp(2, 8);
    final isDesktop = width >= 800;
    final bottomPad = isDesktop ? 24.0 : 100.0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          title: const Text(
            'My Space',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: -0.3,
            ),
          ),
          actions: [
            if (library.continueWatching.isNotEmpty)
              IconButton(
                icon: Icon(
                  Icons.delete_sweep_rounded,
                  color: context.tokens.textSecondary,
                ),
                tooltip: 'Clear Watch History',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: theme.colorScheme.surface,
                      title: Text(
                        'Clear Watch History?',
                        style: TextStyle(color: context.tokens.textPrimary),
                      ),
                      content: Text(
                        'This will remove all items from Continue Watching.',
                        style: TextStyle(color: context.tokens.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: context.tokens.textMuted),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            library.clearHistory();
                          },
                          child: Text(
                            'Clear All',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
          bottom: TabBar(
            indicatorColor: theme.colorScheme.primary,
            indicatorWeight: 3,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: context.tokens.textMuted,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'Watchlist'),
              Tab(text: 'Continue Watching'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 1. Favorites / Watchlist Tab
            library.favorites.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bookmark_border_rounded,
                          size: 56,
                          color: context.tokens.textMuted.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Your Watchlist is empty',
                          style: TextStyle(
                            color: context.tokens.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap + on any movie or series to save it for later',
                          style: TextStyle(
                            color: context.tokens.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
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
                  ),

            // 2. Continue Watching Tab
            library.continueWatching.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_circle_outline_rounded,
                          size: 56,
                          color: context.tokens.textMuted.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No active playback history',
                          style: TextStyle(
                            color: context.tokens.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Movies and episodes in progress will appear here',
                          style: TextStyle(
                            color: context.tokens.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(14, 10, 14, bottomPad),
                    itemCount: library.continueWatching.length,
                    itemBuilder: (context, index) {
                      final h = library.continueWatching[index];
                      final imageUrl = h.item.backdropUrl ?? h.item.posterUrl;
                      final cardShape = context.tokens.shapeSm;
                      final thumbShape = context.tokens.shapeXs;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: context.tokens.getShapeDecoration(
                          color: context.tokens.surfaceCard,
                          radius: (context.tokens.cardRadius * 0.65).clamp(
                            4.0,
                            10.0,
                          ),
                          side: BorderSide(color: context.tokens.borderSubtle),
                        ),
                        child: ClipPath(
                          clipper: ShapeBorderClipper(shape: cardShape),
                          child: InkWell(
                            onTap: () => _openDetails(context, h.item),
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
                                                errorBuilder: (_, _, _) =>
                                                    Container(
                                                      width: 80,
                                                      height: 48,
                                                      color: context
                                                          .tokens
                                                          .surfaceElevated,
                                                      child: Icon(
                                                        Icons.movie,
                                                        color: context
                                                            .tokens
                                                            .textMuted,
                                                      ),
                                                    ),
                                              )
                                            : Container(
                                                width: 80,
                                                height: 48,
                                                color: context
                                                    .tokens
                                                    .surfaceElevated,
                                                child: Icon(
                                                  Icons.movie,
                                                  color:
                                                      context.tokens.textMuted,
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
                                                color:
                                                    context.tokens.textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (h.season != null &&
                                                h.episode != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                ),
                                                child: Text(
                                                  'Season ${h.season} • Episode ${h.episode}',
                                                  style: TextStyle(
                                                    color: theme
                                                        .colorScheme
                                                        .primary,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.play_circle_fill_rounded,
                                          color: context.tokens.primaryAccent,
                                          size: 24,
                                        ),
                                        tooltip: 'Resume Playback',
                                        onPressed: () =>
                                            TvPlayHelper.resumePlayback(
                                              context,
                                              h,
                                            ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.check_circle_outline_rounded,
                                          color: context.tokens.textSecondary,
                                          size: 20,
                                        ),
                                        tooltip: 'Mark as Watched',
                                        onPressed: () {
                                          library.markAsWatched(
                                            h.item.id,
                                            season: h.season,
                                            episode: h.episode,
                                            isWatched: true,
                                            item: h.item,
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Marked "${h.item.cleanTitle}" as watched',
                                                style: TextStyle(
                                                  color: context
                                                      .tokens
                                                      .textPrimary,
                                                ),
                                              ),
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                              backgroundColor:
                                                  theme.colorScheme.surface,
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          color: context.tokens.textMuted,
                                          size: 20,
                                        ),
                                        tooltip: 'Remove from history',
                                        onPressed: () {
                                          library.removeFromHistory(
                                            h.item.id,
                                            season: h.season,
                                            episode: h.episode,
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Removed "${h.item.cleanTitle}" from history',
                                                style: TextStyle(
                                                  color: context
                                                      .tokens
                                                      .textPrimary,
                                                ),
                                              ),
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                              backgroundColor:
                                                  theme.colorScheme.surface,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: context.tokens.textPrimary
                                              .withValues(alpha: 0.08),
                                        ),
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          color: context.tokens.textPrimary,
                                          size: 22,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Pinned Progress Bar Driven by Active Theme
                                LinearProgressIndicator(
                                  value: h.progress,
                                  backgroundColor: context.tokens.borderSubtle,
                                  color: context.tokens.primaryAccent,
                                  minHeight: 3,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
