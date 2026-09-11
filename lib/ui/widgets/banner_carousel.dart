import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../../providers/library_provider.dart';
import '../theme/app_tokens.dart';
import 'tv_focusable.dart';

class BannerCarousel extends StatefulWidget {
  final List<MediaItem> items;
  final Function(MediaItem) onSelect;
  final Function(MediaItem)? onPlayDirect;
  final Function(MediaItem)? onInfo;

  const BannerCarousel({
    super.key,
    required this.items,
    required this.onSelect,
    this.onPlayDirect,
    this.onInfo,
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  static const int _kLoopMultiplier = 10000;

  late PageController _pageController;
  late int _currentVirtualPage;
  late FocusNode _watchFocusNode;
  late FocusNode _myListFocusNode;
  Timer? _timer;
  bool _hasButtonFocus = false;

  @override
  void initState() {
    super.initState();
    _watchFocusNode = FocusNode(debugLabel: 'BannerWatch');
    _myListFocusNode = FocusNode(debugLabel: 'BannerMyList');
    final count = widget.items.length;
    _currentVirtualPage = count > 1 ? count * _kLoopMultiplier : 0;
    _pageController = PageController(initialPage: _currentVirtualPage);
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(covariant BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      final count = widget.items.length;
      final oldRealIndex = oldWidget.items.isEmpty
          ? 0
          : ((_currentVirtualPage % oldWidget.items.length) +
                    oldWidget.items.length) %
                oldWidget.items.length;
      _currentVirtualPage = count > 1
          ? (count * _kLoopMultiplier) + (oldRealIndex % count)
          : 0;
      _timer?.cancel();
      _pageController.dispose();
      _pageController = PageController(initialPage: _currentVirtualPage);
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _timer?.cancel();
    if (widget.items.length <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (!mounted ||
          widget.items.length <= 1 ||
          !_pageController.hasClients ||
          _hasButtonFocus) {
        return;
      }
      try {
        if (_pageController.position.isScrollingNotifier.value) {
          return;
        }
      } catch (_) {}

      _currentVirtualPage++;
      _pageController.animateToPage(
        _currentVirtualPage,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _goToNext() {
    if (widget.items.length <= 1 || !_pageController.hasClients) return;
    setState(() {
      _currentVirtualPage++;
    });
    _pageController.animateToPage(
      _currentVirtualPage,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
    _startAutoScroll();
  }

  void _goToItemIndex(int targetRealIndex) {
    if (widget.items.length <= 1 || !_pageController.hasClients) return;
    final currentReal =
        ((_currentVirtualPage % widget.items.length) + widget.items.length) %
        widget.items.length;
    final diff = targetRealIndex - currentReal;
    setState(() {
      _currentVirtualPage += diff;
    });
    _pageController.animateToPage(
      _currentVirtualPage,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
    _startAutoScroll();
  }

  void _scrollToTop() {
    void doScroll() {
      if (!mounted) return;
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable != null &&
          scrollable.position.hasPixels &&
          scrollable.position.pixels > 0) {
        scrollable.position.animateTo(
          0.0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    }

    try {
      doScroll();
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => doScroll());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _watchFocusNode.dispose();
    _myListFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final tokens = context.tokens;
    final library = context.watch<LibraryProvider>();
    bool isTv = false;
    try {
      final app = context.watch<AppProvider>();
      isTv = app.isTvMode;
    } catch (_) {
      isTv = false;
    }
    final screenSize = MediaQuery.of(context).size;
    final isCompactLandscape =
        screenSize.width > screenSize.height && screenSize.height < 550;
    final isDesktop = screenSize.width >= 900 && screenSize.height >= 550;

    final double bannerHeight;
    if (isTv) {
      bannerHeight = (screenSize.height * 0.65).clamp(340.0, 480.0);
    } else if (isCompactLandscape) {
      bannerHeight = (screenSize.height * 0.84).clamp(300.0, 350.0);
    } else if (isDesktop) {
      bannerHeight = (screenSize.height * 0.52).clamp(380.0, 500.0);
    } else {
      bannerHeight = 330.0;
    }

    final count = widget.items.length;
    final activeRealIndex = count == 0
        ? 0
        : ((_currentVirtualPage % count) + count) % count;
    final currentItem = widget.items[activeRealIndex];
    final isFav = library.isFavorite(currentItem.id);

    final double horizontalOffset = isTv
        ? 28
        : (isDesktop ? 48 : (isCompactLandscape ? 20 : 18));
    final double contentBottomOffset = isTv
        ? 66
        : (isCompactLandscape ? 56 : (isDesktop ? 80 : 70));
    final double buttonsBottomOffset = isTv
        ? 18
        : (isCompactLandscape ? 14 : (isDesktop ? 26 : 18));
    final double titleFontSize = isTv
        ? 21
        : (isCompactLandscape ? 21 : (isDesktop ? 30 : 24));
    final double badgeFontSize = (isTv || isCompactLandscape) ? 8.5 : 10.0;
    final double metadataFontSize = (isTv || isCompactLandscape) ? 12.0 : 13.0;

    return SizedBox(
      height: bannerHeight,
      child: Stack(
        children: [
          NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction != ScrollDirection.idle) {
                _timer?.cancel();
              } else {
                _startAutoScroll();
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: count <= 1 ? count : null,
              onPageChanged: (virtualIndex) {
                if (_currentVirtualPage != virtualIndex) {
                  setState(() => _currentVirtualPage = virtualIndex);
                }
              },
              itemBuilder: (context, index) {
                final realIndex = ((index % count) + count) % count;
                final item = widget.items[realIndex];
                final imgUrl = item.backdropUrl ?? item.posterUrl;

                return GestureDetector(
                  onTap: () => widget.onPlayDirect != null
                      ? widget.onPlayDirect!(item)
                      : widget.onSelect(item),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // High-Res Backdrop Image
                      if (imgUrl != null && imgUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: imgUrl,
                          fit: BoxFit.cover,
                          alignment: isTv
                              ? Alignment.topCenter
                              : const Alignment(0, -0.15),
                          memCacheWidth: isTv ? 960 : 1920,
                          maxWidthDiskCache: isTv ? 960 : 1920,
                          placeholder: (_, _) =>
                              Container(color: theme.colorScheme.surface),
                          errorWidget: (_, _, _) =>
                              Container(color: theme.colorScheme.surface),
                        )
                      else
                        Container(color: theme.colorScheme.surface),

                      // Multi-stop Vignette Gradients (Netflix Dark Fade)
                      // 1. Subtle top vignette for window and navbar contrast
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              tokens.shadowColor.withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.18],
                          ),
                        ),
                      ),
                      // 2. Bottom-to-Top Fade to blend into scaffold background seamlessly
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              theme.scaffoldBackgroundColor.withValues(
                                alpha: 0.2,
                              ),
                              theme.scaffoldBackgroundColor.withValues(
                                alpha: 0.75,
                              ),
                              theme.scaffoldBackgroundColor,
                            ],
                            stops: const [0.0, 0.52, 0.74, 0.90, 1.0],
                          ),
                        ),
                      ),
                      // 3. Left-to-Right Fade for high contrast text readability (leaves center & right artwork crisp)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              theme.scaffoldBackgroundColor.withValues(
                                alpha: isTv ? 0.85 : 0.92,
                              ),
                              theme.scaffoldBackgroundColor.withValues(
                                alpha: 0.5,
                              ),
                              theme.scaffoldBackgroundColor.withValues(
                                alpha: 0.1,
                              ),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.22, 0.40, 0.56],
                          ),
                        ),
                      ),

                      // Banner Content Overlay (Constrained to left side, sits above fixed buttons)
                      Positioned(
                        left: horizontalOffset,
                        bottom: contentBottomOffset,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isTv
                                ? (screenSize.width * 0.52).clamp(320.0, 520.0)
                                : (isCompactLandscape
                                      ? (screenSize.width * 0.58).clamp(
                                          300.0,
                                          520.0,
                                        )
                                      : (isDesktop
                                            ? (screenSize.width * 0.46).clamp(
                                                380.0,
                                                640.0,
                                              )
                                            : (screenSize.width - 36))),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Category / Quality / Language Pill Badges
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: (isTv || isCompactLandscape)
                                          ? 6
                                          : 8,
                                      vertical: (isTv || isCompactLandscape)
                                          ? 2
                                          : 3,
                                    ),
                                    decoration: tokens.getShapeDecoration(
                                      color: tokens.primaryAccent,
                                      radius: (tokens.cardRadius * 0.35).clamp(
                                        2.0,
                                        6.0,
                                      ),
                                    ),
                                    child: Text(
                                      item.isSeries
                                          ? 'SERIES SPOTLIGHT'
                                          : 'TOP FEATURED',
                                      style: TextStyle(
                                        fontSize: badgeFontSize,
                                        fontWeight: FontWeight.w900,
                                        color: theme.colorScheme.onPrimary,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  if (item.isCam) ...[
                                    SizedBox(
                                      width: (isTv || isCompactLandscape)
                                          ? 4
                                          : 6,
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: (isTv || isCompactLandscape)
                                            ? 5
                                            : 6,
                                        vertical: (isTv || isCompactLandscape)
                                            ? 1.5
                                            : 2,
                                      ),
                                      decoration: tokens.getShapeDecoration(
                                        color: tokens.vipColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        radius: (tokens.cardRadius * 0.35)
                                            .clamp(2.0, 6.0),
                                        side: BorderSide(
                                          color: tokens.vipColor.withValues(
                                            alpha: 0.8,
                                          ),
                                          width: 0.6,
                                        ),
                                      ),
                                      child: Text(
                                        item.qualityTag ?? 'CAM',
                                        style: TextStyle(
                                          fontSize: (isTv || isCompactLandscape)
                                              ? 8
                                              : 9,
                                          fontWeight: FontWeight.bold,
                                          color: tokens.vipColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (item.effectiveLanguageTag != null &&
                                      item
                                          .effectiveLanguageTag!
                                          .isNotEmpty) ...[
                                    SizedBox(
                                      width: (isTv || isCompactLandscape)
                                          ? 4
                                          : 6,
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: (isTv || isCompactLandscape)
                                            ? 5
                                            : 6,
                                        vertical: (isTv || isCompactLandscape)
                                            ? 1.5
                                            : 2,
                                      ),
                                      decoration: tokens.getShapeDecoration(
                                        color: tokens.surfaceElevated
                                            .withValues(alpha: 0.8),
                                        radius: (tokens.cardRadius * 0.35)
                                            .clamp(2.0, 6.0),
                                        side: BorderSide(
                                          color: tokens.primaryAccent
                                              .withValues(alpha: 0.6),
                                          width: 0.6,
                                        ),
                                      ),
                                      child: Text(
                                        item.effectiveLanguageTag!
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontSize: (isTv || isCompactLandscape)
                                              ? 8
                                              : 9,
                                          fontWeight: FontWeight.w800,
                                          color: tokens.primaryAccent,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              SizedBox(
                                height: (isTv || isCompactLandscape) ? 4 : 8,
                              ),

                              // Stylized Title
                              Text(
                                item.cleanTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: tokens.textPrimary,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 16,
                                      color: tokens.shadowColor.withValues(
                                        alpha: 0.9,
                                      ),
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: (isTv || isCompactLandscape) ? 3 : 6,
                              ),

                              // Metadata Badges (IMDb, Year, Genre)
                              Row(
                                children: [
                                  if (item.rating != null &&
                                      item.rating! > 0) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tokens.vipColor.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: tokens.borderRadiusXs,
                                        border: Border.all(
                                          color: tokens.vipColor.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.star_rounded,
                                            size: 14,
                                            color: tokens.vipColor,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            item.rating!.toStringAsFixed(1),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: tokens.vipColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  if (item.year != null &&
                                      item.year!.isNotEmpty) ...[
                                    Text(
                                      item.year!,
                                      style: TextStyle(
                                        fontSize: metadataFontSize,
                                        fontWeight: FontWeight.w500,
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '•',
                                      style: TextStyle(color: tokens.textMuted),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (item.genre != null &&
                                      item.genre!.isNotEmpty)
                                    Flexible(
                                      child: Text(
                                        item.genre!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: metadataFontSize,
                                          fontWeight: FontWeight.w500,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Fixed Action Buttons Overlay (stays stationary when sliding between movies)
          Positioned(
            left: horizontalOffset,
            bottom: buttonsBottomOffset,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTv
                    ? (screenSize.width * 0.55).clamp(320.0, 560.0)
                    : (isCompactLandscape
                          ? (screenSize.width * 0.58).clamp(300.0, 520.0)
                          : (isDesktop
                                ? (screenSize.width * 0.46).clamp(380.0, 640.0)
                                : (screenSize.width - 36))),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Primary Solid Play / Watch Button
                  TvFocusable(
                    focusNode: _watchFocusNode,
                    autofocus: isTv,
                    scaleFactor: 1.08,
                    shape: tokens.shapeSm,
                    borderRadius: tokens.borderRadiusSm,
                    onDirection: (direction) {
                      if (direction == TraversalDirection.right) {
                        if (isTv) {
                          _goToNext();
                          return true;
                        } else {
                          _myListFocusNode.requestFocus();
                          return true;
                        }
                      } else if (direction == TraversalDirection.up) {
                        _scrollToTop();
                        return true;
                      }
                      return false;
                    },
                    onFocusChange: (f) {
                      setState(() => _hasButtonFocus = f);
                      if (f) _scrollToTop();
                    },
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                          if (isTv) {
                            _goToNext();
                          } else {
                            _myListFocusNode.requestFocus();
                          }
                          return KeyEventResult.handled;
                        } else if (event.logicalKey ==
                            LogicalKeyboardKey.arrowUp) {
                          // Scroll to top so banner is fully visible
                          _scrollToTop();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    onTap: () => widget.onPlayDirect != null
                        ? widget.onPlayDirect!(currentItem)
                        : widget.onSelect(currentItem),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: (isTv || isCompactLandscape) ? 14 : 18,
                        vertical: (isTv || isCompactLandscape) ? 7 : 10,
                      ),
                      decoration: tokens.getShapeDecoration(
                        color: tokens.textPrimary,
                        radius: (tokens.cardRadius * 0.65).clamp(4.0, 10.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: theme.scaffoldBackgroundColor,
                            size: (isTv || isCompactLandscape) ? 18 : 22,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isTv ? 'Watch' : 'Play',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: (isTv || isCompactLandscape) ? 12 : 14,
                              color: theme.scaffoldBackgroundColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Frosted Glass "My List" Button (hidden in TV interface)
                  if (!isTv) ...[
                    const SizedBox(width: 8),
                    TvFocusable(
                      focusNode: _myListFocusNode,
                      scaleFactor: 1.08,
                      shape: tokens.shapeSm,
                      borderRadius: tokens.borderRadiusSm,
                      onDirection: (direction) {
                        if (direction == TraversalDirection.right) {
                          _goToNext();
                          return true;
                        } else if (direction == TraversalDirection.left) {
                          _watchFocusNode.requestFocus();
                          return true;
                        } else if (direction == TraversalDirection.up) {
                          _scrollToTop();
                          return true;
                        }
                        return false;
                      },
                      onFocusChange: (f) {
                        setState(() => _hasButtonFocus = f);
                        if (f) _scrollToTop();
                      },
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent) {
                          if (event.logicalKey ==
                              LogicalKeyboardKey.arrowRight) {
                            _goToNext();
                            return KeyEventResult.handled;
                          } else if (event.logicalKey ==
                              LogicalKeyboardKey.arrowLeft) {
                            _watchFocusNode.requestFocus();
                            return KeyEventResult.handled;
                          } else if (event.logicalKey ==
                              LogicalKeyboardKey.arrowUp) {
                            _scrollToTop();
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      onTap: () => library.toggleFavorite(currentItem),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: (isTv || isCompactLandscape) ? 11 : 14,
                          vertical: (isTv || isCompactLandscape) ? 7 : 10,
                        ),
                        decoration: tokens.getShapeDecoration(
                          color: tokens.surfaceElevated.withValues(alpha: 0.8),
                          radius: (tokens.cardRadius * 0.65).clamp(4.0, 10.0),
                          side: BorderSide(
                            color: isFav
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.8,
                                  )
                                : tokens.borderSubtle,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFav ? Icons.check_rounded : Icons.add_rounded,
                              color: isFav
                                  ? theme.colorScheme.primary
                                  : tokens.textPrimary,
                              size: (isTv || isCompactLandscape) ? 16 : 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isFav ? 'In List' : 'My List',
                              style: TextStyle(
                                color: isFav
                                    ? theme.colorScheme.primary
                                    : tokens.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: (isTv || isCompactLandscape)
                                    ? 12
                                    : 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // TV Mode: Sleek Slide Counter Badge (Non-focusable, purely informative)
                  if (isTv && count > 1) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: tokens.getShapeDecoration(
                        color: tokens.surfaceCard.withValues(alpha: 0.8),
                        radius: (tokens.cardRadius * 0.65).clamp(4.0, 10.0),
                        side: BorderSide(color: tokens.borderSubtle),
                      ),
                      child: Text(
                        '${activeRealIndex + 1} of $count',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],

                  // Non-TV: Info Button
                  if (!isTv) ...[
                    SizedBox(width: (isTv || isCompactLandscape) ? 8 : 12),
                    TvFocusable(
                      scaleFactor: 1.15,
                      shape: tokens.shapePill,
                      borderRadius: tokens.borderRadiusPill,
                      onFocusChange: (f) {
                        setState(() => _hasButtonFocus = f);
                        if (f) _scrollToTop();
                      },
                      onTap: () => widget.onInfo != null
                          ? widget.onInfo!(currentItem)
                          : widget.onSelect(currentItem),
                      child: Container(
                        padding: EdgeInsets.all(
                          (isTv || isCompactLandscape) ? 8 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surfaceElevated.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          color: tokens.textPrimary,
                          size: (isTv || isCompactLandscape) ? 16 : 18,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Translucent Indicator Pill Dots (Bottom Center/Right)
          if (!isTv)
            Builder(
              builder: (context) {
                final activeRealIndex = count == 0
                    ? 0
                    : ((_currentVirtualPage % count) + count) % count;
                return Positioned(
                  right: isDesktop ? 48 : (isCompactLandscape ? 20 : 18),
                  bottom: buttonsBottomOffset + 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.surfaceCard.withValues(alpha: 0.7),
                      borderRadius: tokens.borderRadiusMd,
                      border: Border.all(
                        color: tokens.borderSubtle.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        widget.items.length.clamp(0, 8),
                        (i) => MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => _goToItemIndex(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 2.5,
                              ),
                              width: activeRealIndex == i ? 18 : 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: activeRealIndex == i
                                    ? tokens.primaryAccent
                                    : tokens.textMuted,
                                borderRadius: tokens.borderRadiusXs,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
