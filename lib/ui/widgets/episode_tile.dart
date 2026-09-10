import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/media_details.dart';
import '../theme/app_tokens.dart';

/// 16:9 Grid Card for Desktop & Tablet Episode Browser (Netflix Web Style)
class EpisodeGridCard extends StatefulWidget {
  final Episode episode;
  final bool isSelected;
  final VoidCallback onTap;
  final double? progress;
  final bool isWatched;
  final VoidCallback? onToggleWatched;

  const EpisodeGridCard({
    super.key,
    required this.episode,
    required this.isSelected,
    required this.onTap,
    this.progress,
    this.isWatched = false,
    this.onToggleWatched,
  });

  @override
  State<EpisodeGridCard> createState() => _EpisodeGridCardState();
}

class _EpisodeGridCardState extends State<EpisodeGridCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final ep = widget.episode;
    final isActive = _isHovered || _isFocused;
    final cardRadius = tokens.borderRadiusSm.topLeft.x;
    final shapeBorder = tokens.getShapeBorder(
      radius: cardRadius,
      side: BorderSide(
        color: widget.isSelected || isActive
            ? theme.colorScheme.primary
            : tokens.borderSubtle,
        width: widget.isSelected || isActive ? 2.0 : 1.0,
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: isActive ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          borderRadius: tokens.borderRadiusSm,
          child: Container(
            decoration: tokens.getShapeDecoration(
              color: widget.isSelected || isActive
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : theme.colorScheme.surface,
              radius: cardRadius,
              side: BorderSide(
                color: widget.isSelected || isActive
                    ? theme.colorScheme.primary
                    : tokens.borderSubtle,
                width: widget.isSelected || isActive ? 2.0 : 1.0,
              ),
              shadows: widget.isSelected || isActive
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(
                          alpha: isActive ? 0.45 : 0.25,
                        ),
                        blurRadius: isActive ? 14 : 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : tokens.getCardShadows(),
            ),
            child: ClipPath(
              clipper: ShapeBorderClipper(shape: shapeBorder),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 16:9 Thumbnail
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (ep.thumbnail != null && ep.thumbnail!.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: ep.thumbnail!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                Container(color: tokens.surfaceCard),
                            errorWidget: (_, _, _) => Container(
                              color: tokens.surfaceCard,
                              child: Center(
                                child: Text(
                                  'EP ${ep.episode}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            color: tokens.surfaceCard,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.play_circle_outline_rounded,
                                    size: 32,
                                    color: tokens.textMuted,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'EPISODE ${ep.episode}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: tokens.textSecondary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Dark Gradient Overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                tokens.canvasBackground.withValues(alpha: 0.0),
                                tokens.canvasBackground.withValues(alpha: 0.65),
                              ],
                            ),
                          ),
                        ),

                        // Center Play Button on Hover or Selected
                        Center(
                          child: AnimatedOpacity(
                            opacity: (_isHovered || widget.isSelected)
                                ? 1.0
                                : 0.0,
                            duration: const Duration(milliseconds: 150),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.isSelected
                                    ? theme.colorScheme.primary
                                    : tokens.canvasBackground.withValues(
                                        alpha: 0.7,
                                      ),
                                border: Border.all(
                                  color: tokens.textPrimary.withValues(
                                    alpha: 0.8,
                                  ),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: widget.isSelected
                                    ? theme.colorScheme.onPrimary
                                    : tokens.textPrimary,
                                size: 28,
                              ),
                            ),
                          ),
                        ),

                        // Episode Number Badge (Top-Left)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: ShapeDecoration(
                              color: tokens.surfaceElevated.withValues(
                                alpha: 0.85,
                              ),
                              shape: tokens.getShapeBorder(
                                radius: 4,
                                side: BorderSide(
                                  color: tokens.borderSubtle,
                                  width: 0.6,
                                ),
                              ),
                            ),
                            child: Text(
                              'EP ${ep.episode}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: tokens.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        if (widget.progress != null && widget.progress! > 0.0)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(
                              value: widget.progress!.clamp(0.0, 1.0),
                              minHeight: 3,
                              backgroundColor: tokens.borderSubtle,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary,
                              ),
                            ),
                          ),

                        // Watched checkmark badge / button
                        if (widget.onToggleWatched != null || widget.isWatched)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Tooltip(
                              message: widget.isWatched
                                  ? 'Marked as Watched (tap to unmark)'
                                  : 'Mark as Watched',
                              child: InkWell(
                                onTap: widget.onToggleWatched,
                                borderRadius: tokens.borderRadiusPill,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: tokens.canvasBackground.withValues(
                                      alpha: 0.75,
                                    ),
                                    border: Border.all(
                                      color: widget.isWatched
                                          ? theme.colorScheme.primary
                                          : tokens.textPrimary.withValues(
                                              alpha: 0.25,
                                            ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    widget.isWatched
                                        ? Icons.check_circle_rounded
                                        : Icons.check_circle_outline_rounded,
                                    size: 14,
                                    color: widget.isWatched
                                        ? theme.colorScheme.primary
                                        : tokens.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Title and Overview inside Expanded to guarantee zero layout overflows
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${ep.episode}. ${ep.title}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: widget.isSelected
                                        ? theme.colorScheme.primary
                                        : tokens.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                widget.isSelected
                                    ? Icons.play_circle_fill_rounded
                                    : Icons.play_circle_outline_rounded,
                                size: 18,
                                color: widget.isSelected
                                    ? theme.colorScheme.primary
                                    : tokens.textMuted,
                              ),
                            ],
                          ),
                          if (ep.overview != null && ep.overview!.isNotEmpty)
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  ep.overview!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: tokens.textSecondary,
                                    height: 1.2,
                                  ),
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
          ),
        ),
      ),
    );
  }
}

/// Horizontal List Tile for Mobile / Compact Views
class EpisodeTile extends StatefulWidget {
  final Episode episode;
  final bool isSelected;
  final VoidCallback onTap;
  final double? progress;
  final bool isWatched;
  final VoidCallback? onToggleWatched;

  const EpisodeTile({
    super.key,
    required this.episode,
    required this.isSelected,
    required this.onTap,
    this.progress,
    this.isWatched = false,
    this.onToggleWatched,
  });

  @override
  State<EpisodeTile> createState() => _EpisodeTileState();
}

class _EpisodeTileState extends State<EpisodeTile> {
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final isActive = _isHovered || _isFocused;

    final cardRadius = tokens.borderRadiusSm.topLeft.x;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        borderRadius: tokens.borderRadiusSm,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          padding: const EdgeInsets.all(10),
          decoration: tokens.getShapeDecoration(
            color: widget.isSelected || isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : theme.colorScheme.surface,
            radius: cardRadius,
            side: BorderSide(
              color: widget.isSelected || isActive
                  ? theme.colorScheme.primary
                  : tokens.borderSubtle,
              width: widget.isSelected || isActive ? 1.8 : 1.0,
            ),
            shadows: isActive
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : tokens.getCardShadows(),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 16:9 Landscape Thumbnail / Episode Number Box
              ClipPath(
                clipper: ShapeBorderClipper(
                  shape: tokens.getShapeBorder(radius: cardRadius * 0.7),
                ),
                child: SizedBox(
                  width: 90,
                  height: 56,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.episode.thumbnail != null &&
                          widget.episode.thumbnail!.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: widget.episode.thumbnail!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            color: tokens.surfaceCard,
                            child: Center(
                              child: Text(
                                '${widget.episode.episode}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          color: tokens.surfaceCard,
                          child: Center(
                            child: Text(
                              'EP ${widget.episode.episode}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ),
                        ),

                      // Center Play Overlay
                      Container(
                        color: tokens.canvasBackground.withValues(
                          alpha: widget.isSelected ? 0.3 : 0.45,
                        ),
                        child: Center(
                          child: Icon(
                            widget.isSelected
                                ? Icons.play_arrow_rounded
                                : Icons.play_arrow_outlined,
                            color: widget.isSelected
                                ? theme.colorScheme.primary
                                : tokens.textPrimary,
                            size: 22,
                          ),
                        ),
                      ),
                      if (widget.progress != null && widget.progress! > 0.0)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(
                            value: widget.progress!.clamp(0.0, 1.0),
                            minHeight: 2.5,
                            backgroundColor: tokens.borderSubtle,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Episode Title & Synopsis
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${widget.episode.episode}. ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: widget.isSelected
                                ? theme.colorScheme.primary
                                : tokens.textPrimary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.episode.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: widget.isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: widget.isSelected
                                  ? theme.colorScheme.primary
                                  : tokens.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.episode.overview != null &&
                        widget.episode.overview!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          widget.episode.overview!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Right watched toggle button & play icon
              if (widget.onToggleWatched != null || widget.isWatched)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Tooltip(
                    message: widget.isWatched
                        ? 'Marked as Watched (tap to unmark)'
                        : 'Mark as Watched',
                    child: InkWell(
                      onTap: widget.onToggleWatched,
                      borderRadius: tokens.borderRadiusPill,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          widget.isWatched
                              ? Icons.check_circle_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 22,
                          color: widget.isWatched
                              ? theme.colorScheme.primary
                              : tokens.textMuted.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  widget.isSelected
                      ? Icons.play_circle_fill_rounded
                      : Icons.play_circle_outline_rounded,
                  size: 24,
                  color: widget.isSelected
                      ? theme.colorScheme.primary
                      : tokens.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
