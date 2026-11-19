import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/media_item.dart';
import '../../../services/tmdb_service.dart';
import '../../theme/app_tokens.dart';
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
  final List<TmdbCrewMember> crew;

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
    this.crew = const [],
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
    List<TmdbCrewMember> crew = const [],
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
        crew: crew,
      ),
    );
  }

  @override
  State<TvDescriptionDialog> createState() => _TvDescriptionDialogState();
}

class _TvDescriptionDialogState extends State<TvDescriptionDialog> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, List<String>> _crewGroups() {
    final groups = <String, List<String>>{};
    for (final member in widget.crew) {
      final role = member.role.toLowerCase();
      String? label;
      if (role.contains('director')) {
        label = 'Director';
      } else if (role.contains('screenplay') ||
          role.contains('writer') ||
          role.contains('story')) {
        label = 'Writer';
      } else if (role.contains('producer')) {
        label = 'Producer';
      } else if (role.contains('music') ||
          role.contains('composer') ||
          role.contains('song')) {
        label = 'Music';
      } else if (role.contains('cinematograph') ||
          role.contains('photography') ||
          role.contains('camera')) {
        label = 'Cinematography';
      } else if (role.contains('editor')) {
        label = 'Editor';
      }
      if (label == null) continue;
      final names = groups.putIfAbsent(label, () => <String>[]);
      if (!names.contains(member.name)) names.add(member.name);
    }
    return groups;
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
              side: BorderSide(
                color: tokens.borderSubtle,
                width: AppStroke.border,
              ),
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
                            width: AppStroke.border,
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
                            width: AppStroke.border,
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
                  child: Focus(
                    autofocus: true,
                    // No button to close or focus: the panel itself owns focus
                    // so Up/Down scroll the synopsis and cast list.
                    onKeyEvent: (node, event) {
                      if (event is! KeyDownEvent) return KeyEventResult.ignored;
                      final key = event.logicalKey;
                      if (key != LogicalKeyboardKey.arrowDown &&
                          key != LogicalKeyboardKey.arrowUp) {
                        return KeyEventResult.ignored;
                      }
                      if (!_scrollController.hasClients) {
                        return KeyEventResult.handled;
                      }
                      final delta = key == LogicalKeyboardKey.arrowDown
                          ? 140.0
                          : -140.0;
                      final position = _scrollController.position;
                      _scrollController.animateTo(
                        (position.pixels + delta).clamp(
                          0.0,
                          position.maxScrollExtent,
                        ),
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                      );
                      return KeyEventResult.handled;
                    },
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

                          // Full crew, grouped by department: directors,
                          // writers, producers, music and photography.
                          if (widget.crew.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'CREW',
                              style: TextStyle(
                                color: tokens.primaryAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._crewGroups().entries.map(
                              (group) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${group.key}: ',
                                        style: TextStyle(
                                          color: tokens.textSecondary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      TextSpan(
                                        text: group.value.join(', '),
                                        style: TextStyle(
                                          color: tokens.textPrimary,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
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
                                        width: AppStroke.border,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
