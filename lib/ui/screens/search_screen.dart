import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../theme/app_themes.dart';
import '../widgets/tv_focusable.dart';
import 'details_screen.dart';
import 'tv_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  late final FocusNode _searchFocusNode = FocusNode(
    debugLabel: 'SearchScreenInput',
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          final moved = node.focusInDirection(TraversalDirection.down);
          if (moved) return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            _controller.selection.baseOffset <= 0) {
          final moved = node.focusInDirection(TraversalDirection.left);
          if (moved) return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    },
  );
  bool _isSearchFocused = false;

  final List<String> _trendingGenres = [
    'Action',
    'Sci-Fi',
    'Anime',
    'Marvel',
    'Bollywood',
    'Thriller',
    'Comedy',
    'Horror',
    'Romance',
    'Documentary',
  ];

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    _controller.text = app.searchQuery;
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  void _onSearchFocusChanged() {
    if (mounted) {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleItemSelect(MediaItem item) {
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

  void _searchGenre(String genre) {
    _controller.text = genre;
    context.read<AppProvider>().searchCategory(genre);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;

    // Responsive grid columns (spacious, non-cramped)
    int crossAxisCount;
    if (width < 600) {
      crossAxisCount = 2;
    } else if (width < 960) {
      crossAxisCount = 3;
    } else if (width < 1400) {
      crossAxisCount = 4;
    } else {
      crossAxisCount = 5;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Frosted Glass Search Input Bar with TV focus glow and D-Pad downward escape
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: context.tokens.surfaceElevated,
                  borderRadius: context.tokens.borderRadiusMd,
                  border: Border.all(
                    color: _isSearchFocused
                        ? context.tokens.borderFocus
                        : context.tokens.borderSubtle,
                    width: _isSearchFocused ? 1.8 : 1.0,
                  ),
                  boxShadow: [
                    if (_isSearchFocused)
                      BoxShadow(
                        color: context.tokens.primaryAccent.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      )
                    else
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: TextField(
                  focusNode: _searchFocusNode,
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (query) {
                    app.search(query);
                    _searchFocusNode.unfocus();
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search movies, TV shows, anime across all providers...',
                    hintStyle: const TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white60,
                    ),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: Colors.white60,
                            ),
                            onPressed: () {
                              _controller.clear();
                              app.clearSearch();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),

            // Trending Searches & Quick Genre Chips with TvFocusable
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _trendingGenres.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final genre = _trendingGenres[index];
                    final isCurrent =
                        app.searchQuery.toLowerCase() == genre.toLowerCase();
                    return TvFocusable(
                      scaleFactor: 1.08,
                      borderRadius: context.tokens.borderRadiusPill,
                      onTap: () => _searchGenre(genre),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? context.tokens.primaryAccent.withValues(
                                  alpha: 0.25,
                                )
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: context.tokens.borderRadiusPill,
                          border: Border.all(
                            color: isCurrent
                                ? context.tokens.primaryAccent
                                : Colors.white.withValues(alpha: 0.12),
                            width: isCurrent ? 1.4 : 1.0,
                          ),
                        ),
                        child: Text(
                          genre,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isCurrent
                                ? theme.colorScheme.primary
                                : Colors.white70,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Results / Loading / Empty state
            Expanded(
              child: app.isSearching
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Scanning catalogue across all providers...',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : app.searchResults.isNotEmpty
                  ? GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      // ignore: deprecated_member_use
                      cacheExtent: 2000,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 18,
                      ),
                      itemCount: app.searchResults.length,
                      itemBuilder: (context, index) {
                        final item = app.searchResults[index];
                        return _SearchMediaCard(
                          item: item,
                          onTap: () => _handleItemSelect(item),
                        );
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.movie_filter_rounded,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            app.searchQuery.isEmpty
                                ? 'Discover movies & series across MovieBox & 4KHDHub'
                                : 'No safe results found for "${app.searchQuery}"',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (app.searchQuery.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Try another title or pick a category above',
                                style: TextStyle(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontSize: 12,
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
    );
  }
}

class _SearchMediaCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _SearchMediaCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final is4K =
        item.provider == ProviderType.fourKHdHub ||
        item.title.contains('4K') ||
        (item.year?.contains('4K') ?? false);

    return TvFocusable(
      scaleFactor: 1.06,
      borderRadius: context.tokens.borderRadiusMd,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.tokens.surfaceCard,
          borderRadius: context.tokens.borderRadiusMd,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: context.tokens.borderRadiusMd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // High-Res Poster
              if (item.posterUrl != null && item.posterUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: item.posterUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    color: theme.colorScheme.surface,
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (_, _, _) => Container(
                    color: theme.colorScheme.surface,
                    child: const Icon(
                      Icons.movie_rounded,
                      size: 48,
                      color: Colors.white24,
                    ),
                  ),
                )
              else
                Container(
                  color: theme.colorScheme.surface,
                  child: const Icon(
                    Icons.movie_rounded,
                    size: 48,
                    color: Colors.white24,
                  ),
                ),

              // Bottom Gradient
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 110,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.65),
                        Colors.black.withValues(alpha: 0.95),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

              // Series / Format Pill (Top Left)
              if (item.isSeries)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.tokens.secondaryAccent,
                      borderRadius: context.tokens.borderRadiusXs,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Text(
                      'SERIES',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: Colors.black,
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: context.tokens.borderRadiusXs,
                      border: Border.all(color: Colors.white24, width: 0.6),
                    ),
                    child: Text(
                      is4K ? '4K UHD' : 'HD',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),

              // Rating Badge (Top Right)
              if (item.rating != null && item.rating! > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: context.tokens.borderRadiusXs,
                      border: Border.all(
                        color: context.tokens.vipColor.withValues(alpha: 0.7),
                        width: 0.7,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          item.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom Title & Metadata Overlay
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (item.year != null) ...[
                          Text(
                            item.year!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '•',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (item.genre != null)
                          Expanded(
                            child: Text(
                              item.genre!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
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
