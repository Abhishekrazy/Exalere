import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/live_channel.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tv_focusable.dart';

class LiveChannelCard extends StatefulWidget {
  final LiveChannel channel;
  final bool isTv;
  final VoidCallback onTap;
  final VoidCallback onOpenVlc;

  const LiveChannelCard({
    super.key,
    required this.channel,
    this.isTv = false,
    required this.onTap,
    required this.onOpenVlc,
  });

  @override
  State<LiveChannelCard> createState() => _LiveChannelCardState();
}

class _LiveChannelCardState extends State<LiveChannelCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  Color _getCategoryColor(String category, AppTokens tokens) {
    final cat = category.toLowerCase();
    if (cat.contains('sport')) return tokens.liveColor;
    if (cat.contains('news')) return tokens.errorColor;
    if (cat.contains('movie') || cat.contains('cinema')) {
      return tokens.primaryAccent;
    }
    if (cat.contains('music')) return tokens.secondaryAccent;
    if (cat.contains('kid') || cat.contains('anim')) {
      return tokens.vipColor;
    }
    if (cat.contains('doc')) return tokens.secondaryAccent;
    return tokens.primaryAccent;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final c = widget.channel;
    final catColor = _getCategoryColor(c.category, tokens);
    final isActive = _isHovered || _isFocused;
    final isTv = widget.isTv;

    final cardRadius = tokens.cardRadius;
    final shapeBorder = tokens.getShapeBorder(
      radius: cardRadius,
      side: BorderSide(
        color: isActive ? theme.colorScheme.primary : tokens.borderSubtle,
        width: isActive ? 2.0 : 1.0,
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: TvFocusable(
        scaleFactor: isTv ? 1.06 : 1.03,
        shape: shapeBorder,
        borderRadius: tokens.borderRadiusMd,
        onTap: widget.onTap,
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: tokens.getShapeDecoration(
            color: tokens.surfaceCard,
            radius: cardRadius,
            side: BorderSide(
              color: isActive ? theme.colorScheme.primary : tokens.borderSubtle,
              width: isActive ? 2.0 : 1.0,
            ),
            shadows: isActive
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : tokens.getCardShadows(),
          ),
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: shapeBorder),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 16:9 Visual Thumbnail / Logo Canvas
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              tokens.surfaceElevated,
                              tokens.surfaceCard,
                              catColor.withValues(alpha: 0.08),
                            ],
                          ),
                        ),
                      ),

                      // Channel Logo or Stylized Emblem
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTv ? 14 : 24,
                            vertical: isTv ? 8 : 14,
                          ),
                          child: c.logoUrl != null && c.logoUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: c.logoUrl!,
                                  fit: BoxFit.contain,
                                  placeholder: (_, _) => SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  errorWidget: (_, _, _) =>
                                      _buildEmblem(c, catColor, isTv, tokens),
                                )
                              : _buildEmblem(c, catColor, isTv, tokens),
                        ),
                      ),

                      // Top Badges Overlay
                      Positioned(
                        top: isTv ? 5 : 8,
                        left: isTv ? 5 : 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTv ? 5 : 7,
                            vertical: isTv ? 2 : 3,
                          ),
                          decoration: tokens.getShapeDecoration(
                            color: tokens.canvasBackground.withValues(
                              alpha: 0.75,
                            ),
                            radius: (tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                            side: BorderSide(
                              color: catColor.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            c.category.toUpperCase(),
                            style: TextStyle(
                              fontSize: isTv ? 7.5 : 9,
                              fontWeight: FontWeight.bold,
                              color: catColor,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),

                      // Live Badge (Top Right)
                      Positioned(
                        top: isTv ? 5 : 8,
                        right: isTv ? 5 : 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTv ? 4 : 6,
                            vertical: isTv ? 2 : 3,
                          ),
                          decoration: tokens.getShapeDecoration(
                            color: tokens.primaryAccent,
                            radius: (tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                            shadows: [
                              BoxShadow(
                                color: tokens.primaryAccent.withValues(
                                  alpha: 0.6,
                                ),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                color: theme.colorScheme.onPrimary,
                                size: isTv ? 5 : 7,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: isTv ? 7.5 : 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Focus / Hover Play Icon Overlay
                      AnimatedOpacity(
                        opacity: isActive ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          color: tokens.canvasBackground.withValues(
                            alpha: 0.35,
                          ),
                          child: Center(
                            child: Container(
                              width: isTv ? 34 : 44,
                              height: isTv ? 34 : 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primary,
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: theme.colorScheme.onPrimary,
                                size: isTv ? 22 : 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Metadata Bar
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isTv ? 8 : 12,
                    isTv ? 5 : 8,
                    isTv ? 6 : 8,
                    isTv ? 5 : 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: isTv ? 11 : 13,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    c.category,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: tokens.textSecondary,
                                      fontSize: isTv ? 9.5 : 11,
                                    ),
                                  ),
                                ),
                                if (c.resolution != null) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: tokens.getShapeDecoration(
                                      color: tokens.surfaceElevated.withValues(
                                        alpha: 0.8,
                                      ),
                                      radius: (tokens.cardRadius * 0.35).clamp(
                                        2.0,
                                        6.0,
                                      ),
                                      side: BorderSide(
                                        color: tokens.borderSubtle,
                                        width: 0.6,
                                      ),
                                    ),
                                    child: Text(
                                      c.resolution!,
                                      style: TextStyle(
                                        color: tokens.textSecondary,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                if (c.sources.length > 1) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: tokens.getShapeDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.15),
                                      radius: (tokens.cardRadius * 0.35).clamp(
                                        2.0,
                                        6.0,
                                      ),
                                      side: BorderSide(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.5),
                                        width: 0.6,
                                      ),
                                    ),
                                    child: Text(
                                      '${c.sources.length} SVR',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isTv)
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: IconButton(
                            icon: Icon(
                              Icons.open_in_new_rounded,
                              size: 15,
                              color: tokens.textMuted,
                            ),
                            tooltip: 'Open in VLC / External Player',
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                              minWidth: 22,
                              minHeight: 22,
                            ),
                            onPressed: widget.onOpenVlc,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmblem(
    LiveChannel c,
    Color catColor,
    bool isTv,
    AppTokens tokens,
  ) {
    final initials = c.name.trim().isNotEmpty
        ? c.name
              .trim()
              .split(' ')
              .take(2)
              .map((w) => w.isNotEmpty ? w[0] : '')
              .join('')
              .toUpperCase()
        : 'TV';

    final size = isTv ? 38.0 : 52.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tokens.canvasBackground.withValues(alpha: 0.45),
        border: Border.all(color: catColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: catColor,
            fontWeight: FontWeight.bold,
            fontSize: isTv ? 12 : 16,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
