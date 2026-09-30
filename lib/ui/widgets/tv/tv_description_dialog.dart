import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/media_item.dart';
import '../../../services/tmdb_service.dart';
import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';
import 'tv_popup_scope.dart';

/// 10-foot UI Dialog displaying the full un-truncated show description,
/// synopsis, genres, director/creator, and full cast details for Android TV.
class TvDescriptionDialog extends StatefulWidget {
  final MediaItem mediaItem;
  final String title;
  final String? year;
  final String? ageCert;
  final String? rating;
  final String? runtime;
  final String? tagline;
  final String overview;
  final List<String> genres;
  final String? director;
  final List<TmdbCastMember> cast;

  const TvDescriptionDialog({
    super.key,
    required this.mediaItem,
    required this.title,
    this.year,
    this.ageCert,
    this.rating,
    this.runtime,
    this.tagline,
    required this.overview,
    this.genres = const [],
    this.director,
    this.cast = const [],
  });

  static Future<void> show(
    BuildContext context, {
    required MediaItem mediaItem,
    required String title,
    String? year,
    String? ageCert,
    String? rating,
    String? runtime,
    String? tagline,
    required String overview,
    List<String> genres = const [],
    String? director,
    List<TmdbCastMember> cast = const [],
  }) {
    return showDialog(
      context: context,
      barrierColor: context.tokens.shadowColor.withValues(alpha: 0.75),
      builder: (_) => TvDescriptionDialog(
        mediaItem: mediaItem,
        title: title,
        year: year,
        ageCert: ageCert,
        rating: rating,
        runtime: runtime,
        tagline: tagline,
        overview: overview,
        genres: genres,
        director: director,
        cast: cast,
      ),
    );
  }

  @override
  State<TvDescriptionDialog> createState() => _TvDescriptionDialogState();
}

class _TvDescriptionDialogState extends State<TvDescriptionDialog> {
  final FocusNode _closeButtonFocusNode = FocusNode(
    debugLabel: 'TvDescCloseBtn',
  );
  final ScrollController _scrollController = ScrollController();

  late final DateTime _openedAt;
  bool _keyReleased = false;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
  }

  @override
  void dispose() {
    _closeButtonFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.of(context).size;

    return TvPopupScope(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: (size.width * 0.75).clamp(540.0, 920.0),
              maxHeight: size.height * 0.82,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 26),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceElevated,
              radius: tokens.cardRadius,
              side: BorderSide(color: tokens.borderSubtle, width: 1.5),
              shadows: tokens.getCardShadows(),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row: Title & Close Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (widget.tagline != null &&
                              widget.tagline!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '“${widget.tagline!}”',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    TvFocusable(
                      focusNode: _closeButtonFocusNode,
                      autofocus: true,
                      scaleFactor: 1.1,
                      shape: tokens.shapeSm,
                      borderRadius: tokens.borderRadiusPill,
                      onKeyEvent: (node, event) {
                        final isSelectKey =
                            event.logicalKey == LogicalKeyboardKey.select ||
                            event.logicalKey == LogicalKeyboardKey.enter ||
                            event.logicalKey == LogicalKeyboardKey.space ||
                            event.logicalKey == LogicalKeyboardKey.numpadEnter;

                        if (isSelectKey) {
                          final elapsed = DateTime.now().difference(_openedAt);
                          if (!_keyReleased) {
                            if (event is KeyUpEvent ||
                                elapsed > const Duration(milliseconds: 400)) {
                              _keyReleased = true;
                            }
                            return KeyEventResult.handled;
                          }
                          if (elapsed < const Duration(milliseconds: 300)) {
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: tokens.getShapeDecoration(
                          color: tokens.surfaceCard,
                          radius: tokens.cardRadius,
                          side: BorderSide(
                            color: tokens.borderSubtle,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: tokens.textPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Close',
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Metadata Badges Row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (widget.year != null && widget.year!.isNotEmpty)
                      Text(
                        widget.year!,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (widget.ageCert != null && widget.ageCert!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: tokens.getShapeDecoration(
                          color: tokens.surfaceCard,
                          radius: (tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                          side: BorderSide(
                            color: tokens.borderSubtle,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          widget.ageCert!,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (widget.rating != null && widget.rating!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: tokens.vipColor,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            widget.rating!,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    if (widget.runtime != null && widget.runtime!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: tokens.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            widget.runtime!,
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    for (final genre in widget.genres)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: tokens.getShapeDecoration(
                          color: tokens.surfaceCard,
                          radius: (tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                          side: BorderSide(
                            color: tokens.borderSubtle,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          genre,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // Divider
                Container(
                  height: 1,
                  color: tokens.borderSubtle,
                  margin: const EdgeInsets.only(bottom: 14),
                ),

                // Scrollable Content: Full Description & Cast Info
                Flexible(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Overview Text
                        Text(
                          'SYNOPSIS',
                          style: TextStyle(
                            color: tokens.primaryAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.overview.isNotEmpty
                              ? widget.overview
                              : 'No synopsis available.',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 14,
                            height: 1.45,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Director / Creator
                        if (widget.director != null &&
                            widget.director!.isNotEmpty) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.mediaItem.isSeries
                                    ? 'Creator / Director: '
                                    : 'Director: ',
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  widget.director!,
                                  style: TextStyle(
                                    color: tokens.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Full Cast
                        if (widget.cast.isNotEmpty) ...[
                          Text(
                            'CAST & CHARACTERS',
                            style: TextStyle(
                              color: tokens.primaryAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              for (final actor in widget.cast)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: tokens.getShapeDecoration(
                                    color: tokens.surfaceCard,
                                    radius: (tokens.cardRadius * 0.4).clamp(
                                      4.0,
                                      8.0,
                                    ),
                                    side: BorderSide(
                                      color: tokens.borderSubtle,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: actor.name,
                                          style: TextStyle(
                                            color: tokens.textPrimary,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (actor.character != null &&
                                            actor.character!.isNotEmpty)
                                          TextSpan(
                                            text: ' as ${actor.character}',
                                            style: TextStyle(
                                              color: tokens.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
