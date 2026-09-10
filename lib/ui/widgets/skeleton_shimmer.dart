import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// ============================================================================
/// SHIMMER SKELETON LOADING SYSTEM
/// ============================================================================
/// Provides cinema-grade skeleton placeholders for hero banners, media cards,
/// and category rows while TMDB / MovieBox feeds are loading.
/// Fully respects the active [CornerStyle] (rounded, sharp, cut/bevel).
/// ============================================================================

class SkeletonShimmer extends StatefulWidget {
  final Widget child;

  const SkeletonShimmer({super.key, required this.child});

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final baseColor = tokens.surfaceCard;
    final highlightColor = tokens.surfaceElevated.withValues(alpha: 0.85);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Generic skeleton container that respects active CornerStyle (rounded, sharp, cut)
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double? radius;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final shape = tokens.getShapeBorder(
      radius: radius ?? tokens.borderRadiusSm.topLeft.x,
    );

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: ShapeDecoration(color: tokens.surfaceCard, shape: shape),
    );
  }
}

/// Shimmering media card skeleton placeholder
class SkeletonMediaCard extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonMediaCard({super.key, this.width = 140, this.height = 196});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isTv = tokens.cardRadius >= 14;
    final cWidth = isTv ? 115.0 : width;
    final cHeight = isTv ? 168.0 : height;

    return Container(
      width: cWidth,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster Box
          SkeletonBox(
            width: cWidth,
            height: cHeight,
            radius: tokens.borderRadiusSm.topLeft.x,
          ),
          const SizedBox(height: 8),
          // Title placeholder
          SkeletonBox(
            width: cWidth * 0.85,
            height: 12,
            radius: tokens.borderRadiusXs.topLeft.x,
          ),
          const SizedBox(height: 4),
          // Subtitle placeholder
          SkeletonBox(
            width: cWidth * 0.5,
            height: 10,
            radius: tokens.borderRadiusXs.topLeft.x,
          ),
        ],
      ),
    );
  }
}

/// Shimmering horizontal category row of media cards
class SkeletonMediaRow extends StatelessWidget {
  final String? title;
  final int itemCount;

  const SkeletonMediaRow({super.key, this.title, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading placeholder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SkeletonBox(
                  width: 140,
                  height: 16,
                  radius: tokens.borderRadiusXs.topLeft.x,
                ),
                const Spacer(),
                SkeletonBox(
                  width: 50,
                  height: 12,
                  radius: tokens.borderRadiusXs.topLeft.x,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Horizontal scrolling card skeletons
          SizedBox(
            height: 236,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: itemCount,
              itemBuilder: (_, _) => const SkeletonMediaCard(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmering 16:9 Hero Banner placeholder
class SkeletonHeroBanner extends StatelessWidget {
  const SkeletonHeroBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.of(context).size;
    final bannerHeight = (size.height * 0.42).clamp(260.0, 480.0);

    return Container(
      width: double.infinity,
      height: bannerHeight,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Stack(
        children: [
          // Backdrop surface placeholder
          Positioned.fill(
            child: SkeletonBox(radius: tokens.borderRadiusLg.topLeft.x),
          ),
          // Content placeholders at bottom
          Positioned(
            left: 20,
            bottom: 24,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tag badge
                SkeletonBox(
                  width: 90,
                  height: 20,
                  radius: tokens.borderRadiusPill.topLeft.x,
                ),
                const SizedBox(height: 12),
                // Hero title line 1
                SkeletonBox(
                  width: size.width * 0.6,
                  height: 24,
                  radius: tokens.borderRadiusXs.topLeft.x,
                ),
                const SizedBox(height: 6),
                // Hero title line 2
                SkeletonBox(
                  width: size.width * 0.4,
                  height: 14,
                  radius: tokens.borderRadiusXs.topLeft.x,
                ),
                const SizedBox(height: 16),
                // Action buttons row
                Row(
                  children: [
                    SkeletonBox(
                      width: 110,
                      height: 38,
                      radius: tokens.borderRadiusSm.topLeft.x,
                    ),
                    const SizedBox(width: 10),
                    SkeletonBox(
                      width: 90,
                      height: 38,
                      radius: tokens.borderRadiusSm.topLeft.x,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Complete Shimmering Home Screen Skeleton
class SkeletonHomeScreen extends StatelessWidget {
  const SkeletonHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          SkeletonHeroBanner(),
          SkeletonMediaRow(title: 'Trending Movies'),
          SkeletonMediaRow(title: 'Popular TV Series'),
          SkeletonMediaRow(title: 'Top Rated'),
        ],
      ),
    );
  }
}
