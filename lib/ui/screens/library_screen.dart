import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../../providers/library_provider.dart';
import '../theme/app_themes.dart';
import '../widgets/media_card.dart';
import 'details_screen.dart';
import 'tv_details_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  void _openDetails(BuildContext context, MediaItem item) {
    final isTv = context.read<AppProvider>().isTvMode;
    if (isTv) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TvDetailsScreen(mediaItem: item)),
      );
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => DetailsScreen(mediaItem: item)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = context.watch<LibraryProvider>();
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = (width / 160).floor().clamp(2, 8);

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
            if (library.history.isNotEmpty)
              IconButton(
                icon: const Icon(
                  Icons.delete_sweep_rounded,
                  color: Colors.white60,
                ),
                tooltip: 'Clear Watch History',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: theme.colorScheme.surface,
                      title: const Text(
                        'Clear Watch History?',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        'This will remove all items from Continue Watching.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.white60),
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
            unselectedLabelColor: Colors.white54,
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
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bookmark_border_rounded,
                          size: 56,
                          color: Colors.white24,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Your Watchlist is empty',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Tap + on any movie or series to save it for later',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.58,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: library.favorites.length,
                    itemBuilder: (context, index) {
                      final item = library.favorites[index];
                      return MediaCard(
                        item: item,
                        onTap: () => _openDetails(context, item),
                      );
                    },
                  ),

            // 2. Continue Watching Tab
            library.history.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_circle_outline_rounded,
                          size: 56,
                          color: Colors.white24,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'No active playback history',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Movies and episodes in progress will appear here',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    itemCount: library.history.length,
                    itemBuilder: (context, index) {
                      final h = library.history[index];
                      final imageUrl = h.item.backdropUrl ?? h.item.posterUrl;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: context.tokens.surfaceCard,
                          borderRadius: context.tokens.borderRadiusSm,
                          border: Border.all(
                            color: context.tokens.borderSubtle,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: context.tokens.borderRadiusSm,
                          child: InkWell(
                            onTap: () => _openDetails(context, h.item),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: context.tokens.borderRadiusXs,
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
                                                      color: Colors.white12,
                                                      child: const Icon(
                                                        Icons.movie,
                                                        color: Colors.white38,
                                                      ),
                                                    ),
                                              )
                                            : Container(
                                                width: 80,
                                                height: 48,
                                                color: Colors.white12,
                                                child: const Icon(
                                                  Icons.movie,
                                                  color: Colors.white38,
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
                                              h.item.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
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
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.white38,
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
                                                'Removed "${h.item.title}" from history',
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
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Pinned Progress Bar Driven by Active Theme
                                LinearProgressIndicator(
                                  value: h.progress,
                                  backgroundColor: Colors.white12,
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
