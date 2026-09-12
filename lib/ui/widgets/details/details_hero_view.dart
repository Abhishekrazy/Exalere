import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../../models/media_details.dart';
import '../../../models/media_item.dart';
import '../../../providers/library_provider.dart';
import '../../../services/tmdb_service.dart';
import '../../theme/app_tokens.dart';

/// Circular User Score badge (TMDB style)
class DetailsUserScoreBadge extends StatelessWidget {
  final int score;

  const DetailsUserScoreBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final double progress = (score.clamp(0, 100)) / 100.0;
    final Color ringColor = score >= 70
        ? tokens.liveColor
        : (score >= 40 ? tokens.vipColor : tokens.errorColor);
    final Color trackColor = ringColor.withValues(alpha: 0.25);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: tokens.surfaceElevated,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: tokens.shadowColor.withValues(alpha: 0.6),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3.5,
                  backgroundColor: trackColor,
                  valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: tokens.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      '%',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'User\nScore',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: tokens.textPrimary,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}

/// TMDB-Style Subheader (Certification, Country Release Date, Genres, Runtime, Audio dubs)
class DetailsTmdbSubheader extends StatelessWidget {
  final bool isSeries;
  final String? year;
  final String? rating;
  final TmdbEnrichedDetails? tmdbDetails;
  final MediaDetails? details;

  const DetailsTmdbSubheader({
    super.key,
    required this.isSeries,
    this.year,
    this.rating,
    this.tmdbDetails,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final cert = tmdbDetails?.certification ?? (isSeries ? 'TV-14' : 'U/A 13+');
    final releaseDateStr =
        tmdbDetails?.releaseDateWithCountry ??
        (tmdbDetails?.releaseDate ?? year);
    final genresList = (tmdbDetails != null && tmdbDetails!.genres.isNotEmpty)
        ? tmdbDetails!.genres
        : (details?.genres ?? []);
    final runtimeStr = tmdbDetails?.formattedRuntime ?? details?.duration;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        if (rating != null && rating!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: tokens.vipColor.withValues(alpha: 0.18),
              borderRadius: tokens.borderRadiusXs,
              border: Border.all(color: tokens.vipColor.withValues(alpha: 0.7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, size: 14, color: tokens.vipColor),
                const SizedBox(width: 3),
                Text(
                  rating!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: tokens.vipColor,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Certification Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: tokens.surfaceElevated.withValues(alpha: 0.6),
            borderRadius: tokens.borderRadiusXs,
            border: Border.all(color: tokens.borderSubtle, width: 0.8),
          ),
          child: Text(
            cert,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: tokens.textSecondary,
            ),
          ),
        ),

        // Release Date
        if (releaseDateStr != null && releaseDateStr.isNotEmpty)
          Text(
            releaseDateStr,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

        // Genres
        if (genresList.isNotEmpty) ...[
          Text('•', style: TextStyle(color: tokens.textMuted)),
          Text(
            genresList.join(', '),
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],

        // Duration / Episodes
        if (runtimeStr != null && runtimeStr.isNotEmpty) ...[
          Text('•', style: TextStyle(color: tokens.textMuted)),
          Text(
            runtimeStr,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ] else if (isSeries &&
            details != null &&
            details!.seasons.isNotEmpty) ...[
          Text('•', style: TextStyle(color: tokens.textMuted)),
          Text(
            '${details!.seasons.fold(0, (sum, s) => sum + s.episodes.length)} Episodes',
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],

        // Audio count
        if (details != null && details!.dubs.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tokens.surfaceElevated.withValues(alpha: 0.6),
              borderRadius: tokens.borderRadiusXs,
              border: Border.all(color: tokens.borderSubtle, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.record_voice_over_rounded,
                  size: 12,
                  color: tokens.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${details!.dubs.length} Audios',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Desktop / Tablet 2-column hero view
class DetailsDesktopHero extends StatelessWidget {
  final MediaItem mediaItem;
  final String? heroTag;
  final String title;
  final String? posterUrl;
  final String? year;
  final String? rating;
  final bool isSeries;
  final String desc;
  final bool isFav;
  final String? languageTag;
  final TmdbEnrichedDetails? tmdbDetails;
  final MediaDetails? details;
  final int selectedSeasonIdx;
  final int selectedEpisodeIdx;
  final bool isTrailerPlaying;
  final VoidCallback onPlay;
  final VoidCallback onPlayFromBeginning;
  final VoidCallback onToggleFavorite;
  final VoidCallback onExternalPlayer;
  final VoidCallback onWatchTrailer;
  final Widget? castSection;

  const DetailsDesktopHero({
    super.key,
    required this.mediaItem,
    this.heroTag,
    required this.title,
    this.posterUrl,
    this.year,
    this.rating,
    required this.isSeries,
    required this.desc,
    required this.isFav,
    this.languageTag,
    this.tmdbDetails,
    this.details,
    required this.selectedSeasonIdx,
    required this.selectedEpisodeIdx,
    required this.isTrailerPlaying,
    required this.onPlay,
    required this.onPlayFromBeginning,
    required this.onToggleFavorite,
    required this.onExternalPlayer,
    required this.onWatchTrailer,
    this.castSection,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final library = context.watch<LibraryProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 1000;
    final double posterWidth = isCompact ? 150.0 : 210.0;
    final double posterHeight = isCompact ? 225.0 : 315.0;
    final double columnSpacing = isCompact ? 20.0 : 28.0;
    final double titleFontSize = isCompact ? 24.0 : 32.0;

    final currentSeason = isSeries ? (selectedSeasonIdx + 1) : null;
    final currentEpisode = isSeries ? (selectedEpisodeIdx + 1) : null;
    final resumeSec = library.getResumePosition(
      mediaItem.id,
      season: currentSeason,
      episode: currentEpisode,
    );
    final bool hasResume = resumeSec > 0;
    final userScore =
        tmdbDetails?.userScore ??
        (tmdbDetails?.rating != null
            ? (tmdbDetails!.rating! * 10).round()
            : null);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Poster Card
        Container(
          width: posterWidth,
          height: posterHeight,
          decoration: tokens.getShapeDecoration(
            color: theme.colorScheme.surface,
            radius: tokens.borderRadiusMd.topLeft.x,
            side: BorderSide(color: tokens.borderSubtle),
          ),
          child: ClipPath(
            clipper: ShapeBorderClipper(
              shape: tokens.getShapeBorder(
                radius: tokens.borderRadiusMd.topLeft.x,
                side: BorderSide(color: tokens.borderSubtle),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (posterUrl != null && posterUrl!.isNotEmpty)
                  (heroTag != null
                      ? Hero(
                          tag: heroTag!,
                          child: Material(
                            type: MaterialType.transparency,
                            child: ClipRRect(
                              borderRadius: tokens.borderRadiusMd,
                              child: CachedNetworkImage(
                                imageUrl: posterUrl!,
                                fit: BoxFit.cover,
                                memCacheWidth: 320,
                                memCacheHeight: 460,
                                maxWidthDiskCache: 500,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                placeholder: (_, _) =>
                                    Container(color: theme.colorScheme.surface),
                                errorWidget: (_, _, _) => Container(
                                  color: theme.colorScheme.surface,
                                  child: Icon(
                                    Icons.movie,
                                    size: 48,
                                    color: tokens.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: posterUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 320,
                          memCacheHeight: 460,
                          maxWidthDiskCache: 500,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          placeholder: (_, _) =>
                              Container(color: theme.colorScheme.surface),
                          errorWidget: (_, _, _) => Container(
                            color: theme.colorScheme.surface,
                            child: Icon(
                              Icons.movie,
                              size: 48,
                              color: tokens.textMuted,
                            ),
                          ),
                        ))
                else
                  Container(
                    color: theme.colorScheme.surface,
                    child: Icon(Icons.movie, size: 48, color: tokens.textMuted),
                  ),

                // Quality Badge Pill (Bottom-Left)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.surfaceCard.withValues(alpha: 0.85),
                      borderRadius: tokens.borderRadiusXs,
                      border: Border.all(
                        color: tokens.borderSubtle,
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      '4K ULTRA HD',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: columnSpacing),

        // Right Column: Title, Metadata, Action Buttons, Synopsis
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Format Pill & Language Tag & CAM badge
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isSeries
                          ? tokens.secondaryAccent.withValues(alpha: 0.15)
                          : tokens.primaryAccent.withValues(alpha: 0.15),
                      borderRadius: tokens.borderRadiusXs,
                      border: Border.all(
                        color: isSeries
                            ? tokens.secondaryAccent.withValues(alpha: 0.6)
                            : tokens.primaryAccent.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      isSeries ? 'TV SERIES' : 'FEATURE FILM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: isSeries
                            ? tokens.secondaryAccent
                            : tokens.primaryAccent,
                      ),
                    ),
                  ),
                  if (mediaItem.isCam)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.vipColor.withValues(alpha: 0.15),
                        borderRadius: tokens.borderRadiusXs,
                        border: Border.all(
                          color: tokens.vipColor.withValues(alpha: 0.8),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        mediaItem.qualityTag ?? 'CAM',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: tokens.vipColor,
                        ),
                      ),
                    ),
                  if (languageTag != null && languageTag!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceElevated,
                        borderRadius: tokens.borderRadiusXs,
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.translate_rounded,
                            size: 11,
                            color: tokens.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            languageTag!.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: tokens.textPrimary,
                  shadows: [Shadow(blurRadius: 12, color: tokens.shadowColor)],
                ),
              ),
              const SizedBox(height: 10),

              // TMDB Subheader
              DetailsTmdbSubheader(
                isSeries: isSeries,
                year: year,
                rating: rating,
                tmdbDetails: tmdbDetails,
                details: details,
              ),
              const SizedBox(height: 16),

              // Action Buttons Row
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (userScore != null && userScore > 0)
                    DetailsUserScoreBadge(score: userScore),

                  // Play / Resume Button
                  SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      autofocus: true,
                      onPressed: onPlay,
                      icon: Icon(
                        Icons.play_arrow_rounded,
                        size: 24,
                        color: theme.colorScheme.onPrimary,
                      ),
                      label: Text(
                        hasResume
                            ? (isSeries
                                  ? 'Resume S${selectedSeasonIdx + 1}:E${selectedEpisodeIdx + 1}'
                                  : 'Resume')
                            : (isSeries
                                  ? 'Play S${selectedSeasonIdx + 1}:E${selectedEpisodeIdx + 1}'
                                  : 'Watch Movie'),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.textPrimary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: tokens.borderRadiusSm,
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                  if (hasResume)
                    Tooltip(
                      message: 'Watch from beginning',
                      child: SizedBox(
                        height: 42,
                        width: 42,
                        child: OutlinedButton(
                          onPressed: onPlayFromBeginning,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: tokens.surfaceCard.withValues(
                              alpha: 0.5,
                            ),
                            side: BorderSide(color: tokens.borderSubtle),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: tokens.borderRadiusSm,
                            ),
                          ),
                          child: Icon(
                            Icons.replay_rounded,
                            color: tokens.textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                  // Watchlist Button
                  SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: onToggleFavorite,
                      icon: Icon(
                        isFav ? Icons.check_rounded : Icons.add_rounded,
                        color: isFav
                            ? tokens.primaryAccent
                            : tokens.textPrimary,
                        size: 19,
                      ),
                      label: Text(
                        isFav ? 'In Watchlist' : 'Watchlist',
                        style: TextStyle(
                          color: isFav
                              ? tokens.primaryAccent
                              : tokens.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: tokens.surfaceCard.withValues(
                          alpha: 0.5,
                        ),
                        side: BorderSide(
                          color: isFav
                              ? tokens.primaryAccent.withValues(alpha: 0.8)
                              : tokens.borderSubtle,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: tokens.borderRadiusSm,
                        ),
                      ),
                    ),
                  ),

                  // External Player Button
                  Tooltip(
                    message: 'Open in External Player (VLC / MPV)',
                    child: SizedBox(
                      height: 42,
                      width: 42,
                      child: OutlinedButton(
                        onPressed: onExternalPlayer,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: tokens.surfaceCard.withValues(
                            alpha: 0.5,
                          ),
                          side: BorderSide(color: tokens.borderSubtle),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: tokens.borderRadiusSm,
                          ),
                        ),
                        child: Icon(
                          Icons.open_in_new_rounded,
                          color: tokens.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  // Watch Trailer Button
                  if ((tmdbDetails?.trailerUrl != null ||
                          tmdbDetails?.trailerYoutubeKey != null) &&
                      !isTrailerPlaying)
                    SizedBox(
                      height: 42,
                      child: ElevatedButton.icon(
                        onPressed: onWatchTrailer,
                        icon: Icon(
                          Icons.play_circle_outline_rounded,
                          color: tokens.textPrimary,
                          size: 19,
                        ),
                        label: Text(
                          'Watch Trailer',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.surfaceElevated,
                          foregroundColor: tokens.textPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: tokens.borderRadiusSm,
                          ),
                          elevation: 3,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Overview
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (tmdbDetails?.overview != null &&
                              tmdbDetails!.overview!.isNotEmpty)
                          ? tmdbDetails!.overview!
                          : desc,
                      style: TextStyle(
                        fontSize: 13,
                        color: tokens.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              ?castSection,
            ],
          ),
        ),
      ],
    );
  }
}

/// Mobile stacked hero view
class DetailsMobileHero extends StatelessWidget {
  final MediaItem mediaItem;
  final String? heroTag;
  final String title;
  final String? posterUrl;
  final String? year;
  final String? rating;
  final bool isSeries;
  final String desc;
  final bool isFav;
  final String? languageTag;
  final TmdbEnrichedDetails? tmdbDetails;
  final MediaDetails? details;
  final int selectedSeasonIdx;
  final int selectedEpisodeIdx;
  final bool isTrailerPlaying;
  final VoidCallback onPlay;
  final VoidCallback onPlayFromBeginning;
  final VoidCallback onToggleFavorite;
  final VoidCallback onExternalPlayer;
  final VoidCallback onWatchTrailer;
  final Widget? castSection;

  const DetailsMobileHero({
    super.key,
    required this.mediaItem,
    this.heroTag,
    required this.title,
    this.posterUrl,
    this.year,
    this.rating,
    required this.isSeries,
    required this.desc,
    required this.isFav,
    this.languageTag,
    this.tmdbDetails,
    this.details,
    required this.selectedSeasonIdx,
    required this.selectedEpisodeIdx,
    required this.isTrailerPlaying,
    required this.onPlay,
    required this.onPlayFromBeginning,
    required this.onToggleFavorite,
    required this.onExternalPlayer,
    required this.onWatchTrailer,
    this.castSection,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final library = context.watch<LibraryProvider>();

    final currentSeason = isSeries ? (selectedSeasonIdx + 1) : null;
    final currentEpisode = isSeries ? (selectedEpisodeIdx + 1) : null;
    final resumeSec = library.getResumePosition(
      mediaItem.id,
      season: currentSeason,
      episode: currentEpisode,
    );
    final bool hasResume = resumeSec > 0;
    final userScore =
        tmdbDetails?.userScore ??
        (tmdbDetails?.rating != null
            ? (tmdbDetails!.rating! * 10).round()
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top poster + Title row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 108,
              height: 156,
              decoration: tokens.getShapeDecoration(
                color: theme.colorScheme.surface,
                radius: tokens.borderRadiusSm.topLeft.x,
                side: BorderSide(color: tokens.borderSubtle),
                shadows: tokens.getCardShadows(),
              ),
              child: ClipPath(
                clipper: ShapeBorderClipper(
                  shape: tokens.getShapeBorder(
                    radius: tokens.borderRadiusSm.topLeft.x,
                    side: BorderSide(color: tokens.borderSubtle),
                  ),
                ),
                child: posterUrl != null && posterUrl!.isNotEmpty
                    ? (heroTag != null
                          ? Hero(
                              tag: heroTag!,
                              child: Material(
                                type: MaterialType.transparency,
                                child: ClipRRect(
                                  borderRadius: tokens.borderRadiusSm,
                                  child: CachedNetworkImage(
                                    imageUrl: posterUrl!,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 320,
                                    memCacheHeight: 460,
                                    maxWidthDiskCache: 500,
                                    fadeInDuration: Duration.zero,
                                    fadeOutDuration: Duration.zero,
                                    placeholder: (_, _) => Container(
                                      color: theme.colorScheme.surface,
                                    ),
                                    errorWidget: (_, _, _) => Container(
                                      color: theme.colorScheme.surface,
                                      child: Icon(
                                        Icons.movie_outlined,
                                        size: 32,
                                        color: tokens.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: posterUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 320,
                              memCacheHeight: 460,
                              maxWidthDiskCache: 500,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              placeholder: (_, _) =>
                                  Container(color: theme.colorScheme.surface),
                              errorWidget: (_, _, _) => Container(
                                color: theme.colorScheme.surface,
                                child: Icon(
                                  Icons.movie_outlined,
                                  size: 32,
                                  color: tokens.textMuted,
                                ),
                              ),
                            ))
                    : Container(
                        color: theme.colorScheme.surface,
                        child: Icon(
                          Icons.movie_outlined,
                          size: 32,
                          color: tokens.textMuted,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Format pill, CAM badge, and language
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: isSeries
                              ? tokens.secondaryAccent.withValues(alpha: 0.15)
                              : tokens.primaryAccent.withValues(alpha: 0.15),
                          borderRadius: tokens.borderRadiusXs,
                          border: Border.all(
                            color: isSeries
                                ? tokens.secondaryAccent.withValues(alpha: 0.6)
                                : tokens.primaryAccent.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          isSeries ? 'TV SERIES' : 'FEATURE FILM',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: isSeries
                                ? tokens.secondaryAccent
                                : tokens.primaryAccent,
                          ),
                        ),
                      ),
                      if (mediaItem.isCam)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.vipColor.withValues(alpha: 0.15),
                            borderRadius: tokens.borderRadiusXs,
                            border: Border.all(
                              color: tokens.vipColor.withValues(alpha: 0.8),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            mediaItem.qualityTag ?? 'CAM',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: tokens.vipColor,
                            ),
                          ),
                        ),
                      if (languageTag != null && languageTag!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.surfaceElevated,
                            borderRadius: tokens.borderRadiusXs,
                            border: Border.all(color: tokens.borderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.translate_rounded,
                                size: 10,
                                color: tokens.textSecondary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                languageTag!.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: tokens.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),

                  DetailsTmdbSubheader(
                    isSeries: isSeries,
                    year: year,
                    rating: rating,
                    tmdbDetails: tmdbDetails,
                    details: details,
                  ),
                  if (userScore != null && userScore > 0) ...[
                    const SizedBox(height: 8),
                    DetailsUserScoreBadge(score: userScore),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Action Buttons Row (Play + Watchlist + External + Trailer)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              height: 42,
              child: ElevatedButton.icon(
                autofocus: true,
                onPressed: onPlay,
                icon: Icon(
                  Icons.play_arrow_rounded,
                  size: 22,
                  color: tokens.canvasBackground,
                ),
                label: Text(
                  hasResume
                      ? (isSeries
                            ? 'Resume S${selectedSeasonIdx + 1}:E${selectedEpisodeIdx + 1}'
                            : 'Resume')
                      : (isSeries
                            ? 'Play S${selectedSeasonIdx + 1}:E${selectedEpisodeIdx + 1}'
                            : 'Play'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: tokens.canvasBackground,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.textPrimary,
                  foregroundColor: tokens.canvasBackground,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: tokens.borderRadiusPill,
                  ),
                  elevation: 3,
                ),
              ),
            ),
            if (hasResume)
              InkWell(
                onTap: onPlayFromBeginning,
                borderRadius: tokens.borderRadiusPill,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tokens.surfaceElevated.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Icon(
                    Icons.replay_rounded,
                    color: tokens.textPrimary,
                    size: 20,
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: onToggleFavorite,
              icon: Icon(
                isFav ? Icons.check_rounded : Icons.bookmark_border_rounded,
                size: 18,
                color: isFav ? theme.colorScheme.primary : tokens.textPrimary,
              ),
              label: Text(
                isFav ? 'Watchlist' : 'Add',
                style: TextStyle(
                  color: isFav ? theme.colorScheme.primary : tokens.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: tokens.surfaceElevated.withValues(alpha: 0.6),
                side: BorderSide(
                  color: isFav
                      ? theme.colorScheme.primary.withValues(alpha: 0.8)
                      : tokens.borderSubtle,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: tokens.borderRadiusPill,
                ),
              ),
            ),
            Tooltip(
              message: 'External Player',
              child: InkWell(
                onTap: onExternalPlayer,
                borderRadius: tokens.borderRadiusPill,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tokens.surfaceElevated.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Icon(
                    Icons.open_in_new_rounded,
                    color: tokens.textPrimary,
                    size: 18,
                  ),
                ),
              ),
            ),
            if ((tmdbDetails?.trailerUrl != null ||
                    tmdbDetails?.trailerYoutubeKey != null) &&
                !isTrailerPlaying)
              OutlinedButton.icon(
                onPressed: onWatchTrailer,
                icon: Icon(
                  Icons.play_circle_outline_rounded,
                  size: 18,
                  color: tokens.textPrimary,
                ),
                label: Text(
                  'Trailer',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: tokens.surfaceElevated.withValues(
                    alpha: 0.6,
                  ),
                  side: BorderSide(color: tokens.borderSubtle),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: tokens.borderRadiusPill,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),

        // Overview Synopsis
        Text(
          'Overview',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          (tmdbDetails?.overview != null && tmdbDetails!.overview!.isNotEmpty)
              ? tmdbDetails!.overview!
              : desc,
          style: TextStyle(
            fontSize: 12.5,
            color: tokens.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),

        ?castSection,
      ],
    );
  }
}
