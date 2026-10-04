import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../../services/tmdb_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/tv_focusable.dart';
import 'details_screen.dart';
import 'tv_details_screen.dart';

class DeepDiscoverScreen extends StatefulWidget {
  final String? initialGenre;

  const DeepDiscoverScreen({super.key, this.initialGenre});

  @override
  State<DeepDiscoverScreen> createState() => _DeepDiscoverScreenState();
}

class _DeepDiscoverScreenState extends State<DeepDiscoverScreen> {
  final TmdbService _tmdb = TmdbService();
  final ScrollController _scrollController = ScrollController();

  String _mediaType = 'all'; // 'all', 'movie', 'tv'
  int? _yearStart;
  int? _yearEnd;
  double? _minRating;
  String _sortBy = 'popularity.desc';
  final Set<int> _selectedGenreIds = {};

  final List<MediaItem> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  Timer? _debounceTimer;

  static const List<Map<String, dynamic>> _eras = [
    {'label': 'All Eras', 'start': null, 'end': null},
    {'label': '2020s', 'start': 2020, 'end': 2029},
    {'label': '2010s', 'start': 2010, 'end': 2019},
    {'label': '2000s', 'start': 2000, 'end': 2009},
    {'label': '1990s', 'start': 1990, 'end': 1999},
    {'label': 'Classics (<1990)', 'start': 1950, 'end': 1989},
  ];

  static const List<Map<String, dynamic>> _ratingPresets = [
    {'label': 'Any Score', 'rating': null},
    {'label': '★ 6.0+', 'rating': 6.0},
    {'label': '★ 7.0+', 'rating': 7.0},
    {'label': '★ 8.0+', 'rating': 8.0},
    {'label': '★ 8.5+', 'rating': 8.5},
  ];

  static const List<Map<String, String>> _sortOptions = [
    {'label': 'Popular', 'val': 'popularity.desc'},
    {'label': 'Top Rated', 'val': 'vote_average.desc'},
    {'label': 'Newest', 'val': 'primary_release_date.desc'},
  ];

  static const List<Map<String, dynamic>> _quickGenres = [
    {'name': 'Action', 'id': 28},
    {'name': 'Adventure', 'id': 12},
    {'name': 'Animation', 'id': 16},
    {'name': 'Comedy', 'id': 35},
    {'name': 'Crime', 'id': 80},
    {'name': 'Drama', 'id': 18},
    {'name': 'Fantasy', 'id': 14},
    {'name': 'Horror', 'id': 27},
    {'name': 'Mystery', 'id': 9648},
    {'name': 'Romance', 'id': 10749},
    {'name': 'Sci-Fi', 'id': 878},
    {'name': 'Thriller', 'id': 53},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialGenre != null) {
      final gId = TmdbService.genreMap[widget.initialGenre!.toLowerCase()];
      if (gId != null) {
        _selectedGenreIds.add(gId);
      }
    }
    _scrollController.addListener(_onScroll);
    _loadItems(reset: true);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 400 &&
        !_isLoading &&
        _hasMore) {
      _loadItems(reset: false);
    }
  }

  Future<void> _loadItems({bool reset = false}) async {
    if (_isLoading) return;
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMore = true;
        _items.clear();
      });
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final results = await _tmdb.discoverAdvanced(
        mediaType: _mediaType,
        genreIds: _selectedGenreIds.isNotEmpty
            ? _selectedGenreIds.toList()
            : null,
        releaseYearStart: _yearStart,
        releaseYearEnd: _yearEnd,
        minRating: _minRating,
        sortBy: _sortBy,
        page: _currentPage,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (results.isEmpty) {
            _hasMore = false;
          } else {
            _items.addAll(results);
            _currentPage++;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _triggerFilterUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _loadItems(reset: true);
    });
  }

  void _openDetails(MediaItem item) {
    final isTv = context.read<AppProvider>().isTvMode;
    if (isTv) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TvDetailsScreen(mediaItem: item),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DetailsScreen(mediaItem: item)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final isTv = context.watch<AppProvider>().isTvMode;

    return Scaffold(
      backgroundColor: tokens.canvasBackground,
      appBar: AppBar(
        backgroundColor: tokens.surfaceCard,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.explore_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              'Catalog Discovery & Deep Filter',
              style: TextStyle(
                color: tokens.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        leading: TvFocusable(
          scaleFactor: 1.1,
          shape: tokens.shapeSm,
          onTap: () => Navigator.of(context).pop(),
          child: Icon(Icons.arrow_back_rounded, color: tokens.textPrimary),
        ),
        actions: [
          if (_selectedGenreIds.isNotEmpty ||
              _yearStart != null ||
              _minRating != null ||
              _mediaType != 'all')
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Center(
                child: TvFocusable(
                  scaleFactor: 1.05,
                  shape: tokens.shapeSm,
                  onTap: () {
                    setState(() {
                      _selectedGenreIds.clear();
                      _yearStart = null;
                      _yearEnd = null;
                      _minRating = null;
                      _mediaType = 'all';
                      _sortBy = 'popularity.desc';
                    });
                    _loadItems(reset: true);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.surfaceElevated,
                      borderRadius: tokens.borderRadiusSm,
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          size: 16,
                          color: tokens.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Reset Filters',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Controls Section
          Container(
            color: tokens.surfaceCard.withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Media type & Sort Options
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Media Type chips
                      _buildChip(
                        label: 'All Media',
                        selected: _mediaType == 'all',
                        onTap: () {
                          setState(() => _mediaType = 'all');
                          _triggerFilterUpdate();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildChip(
                        label: 'Movies',
                        selected: _mediaType == 'movie',
                        onTap: () {
                          setState(() => _mediaType = 'movie');
                          _triggerFilterUpdate();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildChip(
                        label: 'TV Shows',
                        selected: _mediaType == 'tv',
                        onTap: () {
                          setState(() => _mediaType = 'tv');
                          _triggerFilterUpdate();
                        },
                      ),
                      const SizedBox(width: 16),
                      Container(
                        height: 20,
                        width: 1,
                        color: tokens.borderSubtle,
                      ),
                      const SizedBox(width: 16),
                      // Sort Options
                      ..._sortOptions.map((opt) {
                        final isSel = _sortBy == opt['val'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _buildChip(
                            label: opt['label']!,
                            selected: isSel,
                            onTap: () {
                              setState(() => _sortBy = opt['val']!);
                              _triggerFilterUpdate();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Second row: Decades & Ratings
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ..._eras.map((era) {
                        final isSel =
                            _yearStart == era['start'] &&
                            _yearEnd == era['end'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _buildChip(
                            label: era['label'] as String,
                            selected: isSel,
                            onTap: () {
                              setState(() {
                                _yearStart = era['start'] as int?;
                                _yearEnd = era['end'] as int?;
                              });
                              _triggerFilterUpdate();
                            },
                          ),
                        );
                      }),
                      const SizedBox(width: 8),
                      Container(
                        height: 20,
                        width: 1,
                        color: tokens.borderSubtle,
                      ),
                      const SizedBox(width: 12),
                      ..._ratingPresets.map((r) {
                        final isSel = _minRating == r['rating'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _buildChip(
                            label: r['label'] as String,
                            selected: isSel,
                            onTap: () {
                              setState(
                                () => _minRating = r['rating'] as double?,
                              );
                              _triggerFilterUpdate();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Third row: Genre chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _quickGenres.map((g) {
                      final id = g['id'] as int;
                      final isSel = _selectedGenreIds.contains(id);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: _buildChip(
                          label: g['name'] as String,
                          selected: isSel,
                          onTap: () {
                            setState(() {
                              if (isSel) {
                                _selectedGenreIds.remove(id);
                              } else {
                                _selectedGenreIds.add(id);
                              }
                            });
                            _triggerFilterUpdate();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Main Results Grid
          Expanded(
            child: _items.isEmpty && !_isLoading
                ? _buildEmptyState()
                : _buildGrid(isTv),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return TvFocusable(
      scaleFactor: 1.08,
      shape: tokens.shapeSm,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.22)
              : tokens.surfaceElevated,
          borderRadius: tokens.borderRadiusSm,
          border: Border.all(
            color: selected ? theme.colorScheme.primary : tokens.borderSubtle,
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? theme.colorScheme.primary : tokens.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(bool isTv) {
    final tokens = context.tokens;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = isTv
        ? (screenWidth > 1200 ? 6 : 5)
        : (screenWidth > 1100 ? 5 : (screenWidth > 700 ? 4 : 3));

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.65,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: _items.length + (_hasMore ? crossAxisCount : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return Container(
            decoration: BoxDecoration(
              color: tokens.surfaceCard.withValues(alpha: 0.5),
              borderRadius: tokens.borderRadiusMd,
            ),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }

        final item = _items[index];
        return _buildMediaCard(item);
      },
    );
  }

  Widget _buildMediaCard(MediaItem item) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return TvFocusable(
      scaleFactor: 1.08,
      shape: tokens.shapeMd,
      onTap: () => _openDetails(item),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surfaceCard,
          borderRadius: tokens.borderRadiusMd,
          border: Border.all(color: tokens.borderSubtle, width: 1),
          boxShadow: [
            BoxShadow(
              color: tokens.shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Poster
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.posterUrl != null && item.posterUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: item.posterUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: tokens.surfaceElevated,
                        child: const Icon(Icons.movie_outlined, size: 28),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: tokens.surfaceElevated,
                        child: const Icon(Icons.broken_image_rounded, size: 28),
                      ),
                    )
                  else
                    Container(
                      color: tokens.surfaceElevated,
                      child: const Icon(Icons.movie_outlined, size: 28),
                    ),
                  // Rating Badge
                  if (item.rating != null && item.rating! > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.canvasBackground.withValues(
                            alpha: 0.85,
                          ),
                          borderRadius: tokens.borderRadiusSm,
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              item.rating!.toStringAsFixed(1),
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Title & Year info
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        item.year ?? '',
                        style: TextStyle(color: tokens.textMuted, fontSize: 11),
                      ),
                      const Spacer(),
                      Text(
                        item.isSeries ? 'TV Series' : 'Movie',
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 10.5,
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
    );
  }

  Widget _buildEmptyState() {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.filter_list_off_rounded,
            size: 64,
            color: tokens.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'No matching titles found',
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try loosening your rating, era, or genre filters',
            style: TextStyle(color: tokens.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TvFocusable(
            scaleFactor: 1.08,
            shape: tokens.shapeSm,
            onTap: () {
              setState(() {
                _selectedGenreIds.clear();
                _yearStart = null;
                _yearEnd = null;
                _minRating = null;
                _mediaType = 'all';
                _sortBy = 'popularity.desc';
              });
              _loadItems(reset: true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: tokens.borderRadiusSm,
              ),
              child: Text(
                'Clear All Filters',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
