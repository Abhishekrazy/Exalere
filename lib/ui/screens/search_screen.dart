import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../theme/app_themes.dart';
import '../widgets/search_media_card.dart';
import '../widgets/tv_focusable.dart';
import 'active_search_screen.dart';
import 'details_screen.dart';
import 'tv_details_screen.dart';

/// Default Discover & Category screen.
///
/// Provides a keyboard-free, TV D-Pad optimized experience where users can
/// seamlessly browse categories and trending titles without virtual keyboard
/// interference or focus trapping. Active text and voice searches are initiated
/// via the top action buttons which navigate to [ActiveSearchScreen].
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final FocusNode _searchButtonFocusNode = FocusNode(
    debugLabel: 'DiscoverSearchButton',
  );
  final FocusNode _voiceButtonFocusNode = FocusNode(
    debugLabel: 'DiscoverVoiceButton',
  );
  final FocusNode _firstCategoryFocusNode = FocusNode(
    debugLabel: 'DiscoverFirstCategoryChip',
  );
  final FocusNode _firstGridCardFocusNode = FocusNode(
    debugLabel: 'DiscoverFirstGridCard',
  );

  final ScrollController _categoryScrollController = ScrollController();
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
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
    'Animation',
    'Drama',
  ];

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    if (_categories.contains(app.searchQuery)) {
      _selectedCategory = app.searchQuery;
    } else {
      _selectedCategory = 'All';
    }

    if (app.trendingTitles.isEmpty && !app.isLoadingHome) {
      Future.microtask(() => app.loadHomeFeeds());
    }
  }

  @override
  void dispose() {
    _searchButtonFocusNode.dispose();
    _voiceButtonFocusNode.dispose();
    _firstCategoryFocusNode.dispose();
    _firstGridCardFocusNode.dispose();
    _categoryScrollController.dispose();
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

  void _onCategorySelected(String cat) {
    setState(() => _selectedCategory = cat);
    final app = context.read<AppProvider>();
    if (cat == 'All') {
      app.clearSearch();
    } else {
      app.searchCategory(cat);
    }
  }

  void _openActiveSearch({required bool autoStartVoice}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveSearchScreen(autoStartVoice: autoStartVoice),
      ),
    );
  }

  void _handleItemSelect(MediaItem item, [String? heroTag]) {
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

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'all':
        return Icons.auto_awesome_rounded;
      case 'action':
        return Icons.flash_on_rounded;
      case 'sci-fi':
        return Icons.rocket_launch_rounded;
      case 'anime':
        return Icons.animation_rounded;
      case 'marvel':
        return Icons.shield_rounded;
      case 'bollywood':
        return Icons.movie_filter_rounded;
      case 'thriller':
        return Icons.psychology_rounded;
      case 'comedy':
        return Icons.mood_rounded;
      case 'horror':
        return Icons.dark_mode_rounded;
      case 'romance':
        return Icons.favorite_rounded;
      case 'documentary':
        return Icons.menu_book_rounded;
      case 'animation':
        return Icons.toys_rounded;
      case 'drama':
        return Icons.theater_comedy_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final width = MediaQuery.of(context).size.width;
    final isTv = app.isTvMode;
    final uiScale = app.uiScale;

    // Responsive grid columns: smoothly scales for mobile, tablet, desktop, and TV
    int crossAxisCount;
    if (isTv) {
      if (width < 900) {
        crossAxisCount = 5;
      } else if (width < 1200) {
        crossAxisCount = 6;
      } else if (width < 1600) {
        crossAxisCount = 7;
      } else {
        crossAxisCount = 8;
      }
    } else {
      if (width < 450) {
        crossAxisCount = 2;
      } else if (width < 700) {
        crossAxisCount = 3;
      } else if (width < 950) {
        crossAxisCount = 4;
      } else if (width < 1250) {
        crossAxisCount = 5;
      } else if (width < 1600) {
        crossAxisCount = 6;
      } else {
        crossAxisCount = 7;
      }
    }

    if (uiScale < 0.92) {
      crossAxisCount = (crossAxisCount + 1).clamp(2, 9);
    }

    final isCategoryFiltered = _selectedCategory != 'All';
    final List<MediaItem> displayedItems = isCategoryFiltered
        ? app.searchResults
        : app.trendingTitles;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Action Row: Prominent Search Button & Voice Search Button
            Padding(
              padding: EdgeInsets.fromLTRB(
                isTv ? 24 : 16,
                isTv ? 12 : 12,
                isTv ? 24 : 16,
                8,
              ),
              child: Row(
                children: [
                  // Prominent Search Bar Button (Navigates to ActiveSearchScreen)
                  Expanded(
                    child: TvFocusable(
                      focusNode: _searchButtonFocusNode,
                      scaleFactor: 1.02,
                      borderRadius: tokens.borderRadiusMd,
                      onTap: () => _openActiveSearch(autoStartVoice: false),
                      onDirection: (direction) {
                        if (direction == TraversalDirection.down) {
                          _safeFocus(_firstCategoryFocusNode);
                          return true;
                        }
                        if (direction == TraversalDirection.right) {
                          _safeFocus(_voiceButtonFocusNode);
                          return true;
                        }
                        return false;
                      },
                      child: Container(
                        height: isTv ? 44 : 50,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: tokens.surfaceElevated,
                          borderRadius: tokens.borderRadiusMd,
                          border: Border.all(
                            color: tokens.borderSubtle,
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: tokens.shadowColor.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: tokens.textSecondary,
                              size: isTv ? 18 : 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Search movies, TV shows, anime across all providers...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: isTv ? 13 : 14,
                                ),
                              ),
                            ),
                            if (isTv) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.surfaceCard,
                                  borderRadius: tokens.borderRadiusSm,
                                  border: Border.all(
                                    color: tokens.borderSubtle,
                                  ),
                                ),
                                child: Text(
                                  'PRESS OK',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.textSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Voice Search Trigger Button
                  TvFocusable(
                    focusNode: _voiceButtonFocusNode,
                    scaleFactor: 1.06,
                    borderRadius: tokens.borderRadiusMd,
                    onTap: () => _openActiveSearch(autoStartVoice: true),
                    onDirection: (direction) {
                      if (direction == TraversalDirection.left) {
                        _safeFocus(_searchButtonFocusNode);
                        return true;
                      }
                      if (direction == TraversalDirection.down) {
                        _safeFocus(_firstCategoryFocusNode);
                        return true;
                      }
                      return false;
                    },
                    child: Container(
                      height: isTv ? 44 : 50,
                      padding: EdgeInsets.symmetric(horizontal: isTv ? 16 : 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            tokens.secondaryAccent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: tokens.borderRadiusMd,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.mic_rounded,
                            color: theme.colorScheme.onPrimary,
                            size: isTv ? 18 : 20,
                          ),
                          if (width >= 620) ...[
                            const SizedBox(width: 8),
                            Text(
                              'Voice',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: isTv ? 13 : 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Horizontal Category Shelf (TV D-Pad optimized, no text trap)
            Padding(
              padding: EdgeInsets.only(
                left: isTv ? 24 : 16,
                right: isTv ? 24 : 16,
                top: 4,
                bottom: 8,
              ),
              child: SizedBox(
                height: isTv ? 48 : 52,
                child: ListView.builder(
                  controller: _categoryScrollController,
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  cacheExtent: 350.0,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = cat == _selectedCategory;
                    final icon = _getCategoryIcon(cat);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TvFocusable(
                        focusNode: index == 0 ? _firstCategoryFocusNode : null,
                        scaleFactor: 1.08,
                        borderRadius: tokens.borderRadiusPill,
                        onTap: () => _onCategorySelected(cat),
                        onDirection: (direction) {
                          if (direction == TraversalDirection.up) {
                            _safeFocus(_searchButtonFocusNode);
                            return true;
                          }
                          if (direction == TraversalDirection.down) {
                            _safeFocus(_firstGridCardFocusNode);
                            return true;
                          }
                          return false;
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTv ? 14 : 16,
                            vertical: isTv ? 8 : 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : tokens.surfaceElevated,
                            borderRadius: tokens.borderRadiusPill,
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : tokens.borderSubtle,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                )
                              else
                                BoxShadow(
                                  color: tokens.shadowColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: isTv ? 15 : 17,
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                    : tokens.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                cat,
                                style: TextStyle(
                                  fontSize: isTv ? 12 : 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary
                                      : tokens.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 3. Content Area: Category Header + Responsive Grid
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Category / Trending Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isTv ? 24 : 16,
                        8,
                        isTv ? 24 : 16,
                        8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCategoryFiltered
                                ? _getCategoryIcon(_selectedCategory)
                                : Icons.local_fire_department_rounded,
                            color: isCategoryFiltered
                                ? theme.colorScheme.primary
                                : tokens.primaryAccent,
                            size: isTv ? 18 : 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isCategoryFiltered
                                ? '$_selectedCategory Titles'
                                : 'Trending & Popular Now',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: isTv ? 14 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (displayedItems.isNotEmpty)
                            Text(
                              '${displayedItems.length} titles',
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Results / Loading / Empty State
                  if (app.isSearching)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
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
                            Text(
                              'Loading $_selectedCategory titles across providers...',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (displayedItems.isNotEmpty)
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTv ? 24 : 16,
                        vertical: 8,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: isTv ? 12 : 16,
                          mainAxisSpacing: isTv ? 14 : 18,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = displayedItems[index];
                          final heroTag =
                              'cat_${_selectedCategory}_${item.id}_$index';
                          final total = displayedItems.length;
                          final isTopRow = index < crossAxisCount;
                          final isFirstCol = index % crossAxisCount == 0;
                          final isLastCol =
                              (index + 1) % crossAxisCount == 0 ||
                              index == total - 1;
                          return SearchMediaCard(
                            item: item,
                            heroTag: heroTag,
                            focusNode: index == 0
                                ? _firstGridCardFocusNode
                                : null,
                            isTopRow: isTopRow,
                            isFirstCol: isFirstCol,
                            isLastCol: isLastCol,
                            onUp: isTopRow
                                ? () {
                                    _safeFocus(_firstCategoryFocusNode);
                                    return true;
                                  }
                                : null,
                            onTap: () => _handleItemSelect(item, heroTag),
                          );
                        }, childCount: displayedItems.length),
                      ),
                    )
                  else if (app.isLoadingHome)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Loading catalog...',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.movie_filter_rounded,
                              size: 64,
                              color: tokens.borderSubtle,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No titles found in $_selectedCategory',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Select another category above or tap Search to find specific titles',
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
          ],
        ),
      ),
    );
  }
}
