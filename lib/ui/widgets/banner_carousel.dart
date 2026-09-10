import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../../providers/library_provider.dart';
import 'tv_focusable.dart';

class BannerCarousel extends StatefulWidget {
  final List<MediaItem> items;
  final Function(MediaItem) onSelect;
  final Function(MediaItem)? onPlayDirect;

  const BannerCarousel({
    super.key,
    required this.items,
    required this.onSelect,
    this.onPlayDirect,
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  static const int _kLoopMultiplier = 10000;

  late PageController _pageController;
  late int _currentVirtualPage;
  Timer? _timer;
  bool _hasButtonFocus = false;

  @override
  void initState() {
    super.initState();
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
          : ((_currentVirtualPage % oldWidget.items.length) + oldWidget.items.length) % oldWidget.items.length;
      _currentVirtualPage = count > 1 ? (count * _kLoopMultiplier) + (oldRealIndex % count) : 0;
      _timer?.cancel();
      _pageController.dispose();
      _pageController = PageController(initialPage: _currentVirtualPage);
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _timer?.cancel();
    if (widget.items.length <= 1) return;
    // Android TV: keep carousel stable on current title so remote navigation is rock-solid
    if (!kIsWeb && Platform.isAndroid) return;

    _timer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (!mounted || widget.items.length <= 1 || !_pageController.hasClients || _hasButtonFocus) return;
      _currentVirtualPage++;
      _pageController.animateToPage(
        _currentVirtualPage,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _goToPrevious() {
    if (widget.items.length <= 1 || !_pageController.hasClients) return;
    setState(() {
      _currentVirtualPage--;
    });
    _pageController.animateToPage(
      _currentVirtualPage,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
    _startAutoScroll();
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
    final currentReal = ((_currentVirtualPage % widget.items.length) + widget.items.length) % widget.items.length;
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

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final library = context.watch<LibraryProvider>();
    bool isTv = false;
    try {
      isTv = context.watch<AppProvider>().isTvMode;
    } catch (_) {
      isTv = false;
    }
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width > 768;
    final bannerHeight = isTv
        ? 250.0
        : (isDesktop
            ? (screenSize.height * 0.58).clamp(480.0, 580.0)
            : 340.0);
    final count = widget.items.length;

    final activeRealIndex = count == 0
        ? 0
        : ((_currentVirtualPage % count) + count) % count;
    final currentItem = widget.items[activeRealIndex];
    final isFav = library.isFavorite(currentItem.id);

    return SizedBox(
      height: bannerHeight,
      child: Stack(
        children: [
          PageView.builder(
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
                onTap: () => widget.onSelect(item),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // High-Res Backdrop Image
                    if (imgUrl != null && imgUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: imgUrl,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.15),
                        placeholder: (_, _) => Container(color: theme.colorScheme.surface),
                        errorWidget: (_, _, _) => Container(color: theme.colorScheme.surface),
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
                            Colors.black.withValues(alpha: 0.35),
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
                            theme.scaffoldBackgroundColor.withValues(alpha: 0.4),
                            theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
                            theme.scaffoldBackgroundColor,
                          ],
                          stops: const [0.0, 0.50, 0.75, 0.90, 1.0],
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
                            theme.scaffoldBackgroundColor.withValues(alpha: 0.92),
                            theme.scaffoldBackgroundColor.withValues(alpha: 0.55),
                            theme.scaffoldBackgroundColor.withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.22, 0.40, 0.56],
                        ),
                      ),
                    ),

                    // Banner Content Overlay (Constrained to left side, sits above fixed buttons)
                    Positioned(
                      left: isTv ? 28 : (isDesktop ? 48 : 18),
                      bottom: isTv ? 56 : (isDesktop ? 96 : 76),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isTv
                              ? (screenSize.width * 0.52).clamp(320.0, 520.0)
                              : (isDesktop
                                  ? (screenSize.width * 0.46).clamp(380.0, 640.0)
                                  : (screenSize.width - 36)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Netflix/Hotstar Pill Badge
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: isTv ? 6 : 8, vertical: isTv ? 2 : 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE50914), // Netflix Red
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.isSeries ? 'SERIES SPOTLIGHT' : 'TOP FEATURED',
                                    style: TextStyle(
                                      fontSize: isTv ? 8.5 : 10,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: isTv ? 5 : 6, vertical: isTv ? 1.5 : 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: Colors.white24, width: 0.6),
                                  ),
                                  child: Text(
                                    '4K ULTRA HD',
                                    style: TextStyle(
                                      fontSize: isTv ? 8 : 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white70,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isTv ? 4 : 8),

                            // Giant Stylized Title
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isTv ? 21 : (isDesktop ? 32 : 24),
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    blurRadius: 16,
                                    color: Colors.black.withValues(alpha: 0.9),
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isTv ? 3 : 6),

                            // Metadata Badges (IMDb, Year, Genre)
                            Row(
                              children: [
                                if (item.rating != null && item.rating! > 0) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.amber.withValues(alpha: 0.7)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                        const SizedBox(width: 3),
                                        Text(
                                          item.rating!.toStringAsFixed(1),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                if (item.year != null && item.year!.isNotEmpty) ...[
                                  Text(
                                    item.year!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('•', style: TextStyle(color: Colors.white38)),
                                  const SizedBox(width: 8),
                                ],
                                if (item.genre != null && item.genre!.isNotEmpty)
                                  Flexible(
                                    child: Text(
                                      item.genre!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
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

          // Fixed Action Buttons Overlay (stays stationary when sliding between movies)
          Positioned(
            left: isTv ? 28 : (isDesktop ? 48 : 18),
            bottom: isTv ? 14 : (isDesktop ? 36 : 22),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTv
                    ? (screenSize.width * 0.52).clamp(320.0, 520.0)
                    : (isDesktop
                        ? (screenSize.width * 0.46).clamp(380.0, 640.0)
                        : (screenSize.width - 36)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // TV Mode: D-Pad Prev Slide Button
                    if (isTv && count > 1) ...[
                      TvFocusable(
                        scaleFactor: 1.1,
                        borderRadius: BorderRadius.circular(8),
                        onFocusChange: (f) => setState(() => _hasButtonFocus = f),
                        onTap: _goToPrevious,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chevron_left_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 2),
                              Text(
                                'Prev',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Primary Solid Play Button (Netflix signature)
                    TvFocusable(
                      autofocus: isTv,
                      scaleFactor: 1.08,
                      borderRadius: BorderRadius.circular(8),
                      onFocusChange: (f) => setState(() => _hasButtonFocus = f),
                      onTap: () => widget.onPlayDirect != null
                          ? widget.onPlayDirect!(currentItem)
                          : widget.onSelect(currentItem),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: isTv ? 14 : 18, vertical: isTv ? 7 : 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded, color: Colors.black, size: isTv ? 18 : 22),
                            const SizedBox(width: 4),
                            Text(
                              isTv ? 'Watch' : 'Play',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: isTv ? 12 : 14,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Frosted Glass "My List" Button
                    TvFocusable(
                      scaleFactor: 1.08,
                      borderRadius: BorderRadius.circular(8),
                      onFocusChange: (f) => setState(() => _hasButtonFocus = f),
                      onTap: () => library.toggleFavorite(currentItem),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: isTv ? 11 : 14, vertical: isTv ? 7 : 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isFav
                                ? theme.colorScheme.primary.withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFav ? Icons.check_rounded : Icons.add_rounded,
                              color: isFav ? theme.colorScheme.primary : Colors.white,
                              size: isTv ? 16 : 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isFav ? 'In List' : 'My List',
                              style: TextStyle(
                                color: isFav ? theme.colorScheme.primary : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: isTv ? 12 : 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // TV Mode: D-Pad Next Slide Button & Indicator
                    if (isTv && count > 1) ...[
                      const SizedBox(width: 8),
                      TvFocusable(
                        scaleFactor: 1.1,
                        borderRadius: BorderRadius.circular(8),
                        onFocusChange: (f) => setState(() => _hasButtonFocus = f),
                        onTap: _goToNext,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Next',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          '${activeRealIndex + 1} of $count',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],

                    // Non-TV: Info Button
                    if (!isTv) ...[
                      const SizedBox(width: 12),
                      TvFocusable(
                        scaleFactor: 1.15,
                        borderRadius: BorderRadius.circular(20),
                        onFocusChange: (f) => setState(() => _hasButtonFocus = f),
                        onTap: () => widget.onSelect(currentItem),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Desktop / Non-TV: Floating Previous Title Button
          if (!isTv)
            Positioned(
              left: isDesktop ? 24 : 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _goToPrevious,
                    mouseCursor: SystemMouseCursors.click,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Desktop / Non-TV: Floating Next Title Button
          if (!isTv)
            Positioned(
              right: isDesktop ? 24 : 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _goToNext,
                    mouseCursor: SystemMouseCursors.click,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
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
                right: isDesktop ? 50 : 18,
                bottom: isDesktop ? 28 : 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            width: activeRealIndex == i ? 18 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: activeRealIndex == i
                                  ? const Color(0xFFE50914) // Netflix Red
                                  : Colors.white38,
                              borderRadius: BorderRadius.circular(3),
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
