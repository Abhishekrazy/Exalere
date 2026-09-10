import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/media_details.dart';

/// 16:9 Grid Card for Desktop & Tablet Episode Browser (Netflix Web Style)
class EpisodeGridCard extends StatefulWidget {
  final Episode episode;
  final bool isSelected;
  final VoidCallback onTap;
  final double? progress;

  const EpisodeGridCard({
    super.key,
    required this.episode,
    required this.isSelected,
    required this.onTap,
    this.progress,
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
    final ep = widget.episode;
    final isActive = _isHovered || _isFocused;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: isActive ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: widget.isSelected || isActive
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isSelected || isActive
                    ? theme.colorScheme.primary
                    : Colors.white.withValues(alpha: 0.08),
                width: widget.isSelected || isActive ? 2.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isSelected || isActive
                      ? theme.colorScheme.primary.withValues(alpha: isActive ? 0.45 : 0.25)
                      : Colors.black.withValues(alpha: 0.3),
                  blurRadius: isActive ? 14 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
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
                            placeholder: (_, _) => Container(color: Colors.white10),
                            errorWidget: (_, _, _) => Container(
                              color: Colors.white10,
                              child: Center(
                                child: Text(
                                  'EP ${ep.episode}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white60,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            color: Colors.white.withValues(alpha: 0.06),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.play_circle_outline_rounded,
                                    size: 32,
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'EPISODE ${ep.episode}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white60,
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
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                        ),

                        // Center Play Button on Hover or Selected
                        Center(
                          child: AnimatedOpacity(
                            opacity: (_isHovered || widget.isSelected) ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 150),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.isSelected
                                    ? theme.colorScheme.primary
                                    : Colors.black.withValues(alpha: 0.7),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: widget.isSelected ? Colors.black : Colors.white,
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white24, width: 0.6),
                            ),
                            child: Text(
                              'EP ${ep.episode}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Title and Overview inside Expanded to guarantee zero layout overflows
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                        : Colors.white,
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
                                    : Colors.white38,
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
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white60,
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

  const EpisodeTile({
    super.key,
    required this.episode,
    required this.isSelected,
    required this.onTap,
    this.progress,
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
    final isActive = _isHovered || _isFocused;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.isSelected || isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected || isActive
                  ? theme.colorScheme.primary
                  : Colors.white.withValues(alpha: 0.06),
              width: widget.isSelected || isActive ? 1.8 : 1.0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 16:9 Landscape Thumbnail / Episode Number Box
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 90,
                  height: 56,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.episode.thumbnail != null && widget.episode.thumbnail!.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: widget.episode.thumbnail!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            color: Colors.white10,
                            child: Center(
                              child: Text(
                                '${widget.episode.episode}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white60,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          color: Colors.white10,
                          child: Center(
                            child: Text(
                              'EP ${widget.episode.episode}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),

                      // Center Play Overlay
                      Container(
                        color: Colors.black.withValues(alpha: widget.isSelected ? 0.3 : 0.45),
                        child: Center(
                          child: Icon(
                            widget.isSelected ? Icons.play_arrow_rounded : Icons.play_arrow_outlined,
                            color: widget.isSelected ? theme.colorScheme.primary : Colors.white,
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
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
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
                            color: widget.isSelected ? theme.colorScheme.primary : Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.episode.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w600,
                              color: widget.isSelected ? theme.colorScheme.primary : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.episode.overview != null && widget.episode.overview!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          widget.episode.overview!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white60,
                            height: 1.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Right play / check icon
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  widget.isSelected ? Icons.play_circle_fill_rounded : Icons.play_circle_outline_rounded,
                  size: 24,
                  color: widget.isSelected ? theme.colorScheme.primary : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
