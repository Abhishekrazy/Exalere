import 'package:flutter/material.dart';

import '../../../services/tmdb_service.dart';
import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';

/// Reviews and multi-source ratings breakdown section for Movie & TV Details screens.
class DetailsReviewsSection extends StatefulWidget {
  final String mediaType;
  final String tmdbId;
  final double? rating;
  final int? voteCount;
  final String? certification;

  const DetailsReviewsSection({
    super.key,
    required this.mediaType,
    required this.tmdbId,
    this.rating,
    this.voteCount,
    this.certification,
  });

  @override
  State<DetailsReviewsSection> createState() => _DetailsReviewsSectionState();
}

class _DetailsReviewsSectionState extends State<DetailsReviewsSection> {
  final TmdbService _tmdb = TmdbService();
  List<TmdbReview> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  @override
  void didUpdateWidget(covariant DetailsReviewsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tmdbId != widget.tmdbId ||
        oldWidget.mediaType != widget.mediaType) {
      _fetchReviews();
    }
  }

  Future<void> _fetchReviews() async {
    if (widget.tmdbId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await _tmdb.getMediaReviews(widget.mediaType, widget.tmdbId);
      if (mounted) {
        setState(() {
          _reviews = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showFullReview(BuildContext context, TmdbReview review) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: tokens.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.cardRadius * 1.5),
          side: BorderSide(color: tokens.borderSubtle),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.2,
                      ),
                      backgroundImage: review.avatarUrl != null
                          ? NetworkImage(review.avatarUrl!)
                          : null,
                      child: review.avatarUrl == null
                          ? Text(
                              review.author.isNotEmpty
                                  ? review.author[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review.author,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (review.rating != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${review.rating!.toStringAsFixed(1)} / 10',
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    TvFocusable(
                      autofocus: true,
                      scaleFactor: 1.1,
                      shape: tokens.shapeSm,
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Icon(
                        Icons.close_rounded,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      review.content,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TvFocusable(
                    scaleFactor: 1.05,
                    shape: tokens.shapeSm,
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: tokens.borderRadiusSm,
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final rating = widget.rating ?? 0.0;

    // Derived estimate scores
    final rtScore = rating > 0 ? (rating * 10).clamp(0, 100).toInt() : null;
    final metaScore = rating > 0
        ? ((rating - 0.5) * 10).clamp(0, 100).toInt()
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Icon(
                Icons.rate_review_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Ratings & Critical Reception',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Multi-Source Score Cards Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // TMDB Score
              _buildScoreCard(
                context,
                title: 'TMDB Community',
                score: rating > 0 ? rating.toStringAsFixed(1) : 'N/A',
                subtitle: widget.voteCount != null
                    ? '${widget.voteCount} votes'
                    : 'Community',
                icon: Icons.star_rounded,
                accentColor: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),

              // Rotten Tomatoes Estimate
              if (rtScore != null)
                _buildScoreCard(
                  context,
                  title: 'Tomatometer Est.',
                  score: '$rtScore%',
                  subtitle: rtScore >= 60
                      ? 'Fresh Consensus'
                      : 'Rotten Consensus',
                  icon: rtScore >= 60
                      ? Icons.thumb_up_rounded
                      : Icons.thumb_down_rounded,
                  accentColor: rtScore >= 60
                      ? theme.colorScheme.secondary
                      : tokens.textMuted,
                ),
              if (rtScore != null) const SizedBox(width: 12),

              // Metacritic Estimate
              if (metaScore != null)
                _buildScoreCard(
                  context,
                  title: 'Metascore Est.',
                  score: '$metaScore',
                  subtitle: metaScore >= 61
                      ? 'Generally Favorable'
                      : (metaScore >= 40 ? 'Mixed Reviews' : 'Unfavorable'),
                  icon: Icons.analytics_rounded,
                  accentColor: metaScore >= 61
                      ? theme.colorScheme.primary
                      : tokens.textSecondary,
                ),
              if (metaScore != null) const SizedBox(width: 12),

              // Content Certification Advisory
              if (widget.certification != null &&
                  widget.certification!.isNotEmpty)
                _buildScoreCard(
                  context,
                  title: 'Advisory Rating',
                  score: widget.certification!,
                  subtitle: 'Age Certification',
                  icon: Icons.verified_user_rounded,
                  accentColor: theme.colorScheme.primary,
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Community Reviews List / Carousel
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
          )
        else if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.surfaceCard.withValues(alpha: 0.5),
                borderRadius: tokens.borderRadiusMd,
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: tokens.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'No community reviews submitted yet for this title',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              cacheExtent: 350.0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _reviews.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final review = _reviews[index];
                return _buildReviewCard(context, review);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildScoreCard(
    BuildContext context, {
    required String title,
    required String score,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    final tokens = context.tokens;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: tokens.borderRadiusMd,
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            score,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context, TmdbReview review) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return TvFocusable(
      scaleFactor: 1.05,
      shape: tokens.shapeMd,
      onTap: () => _showFullReview(context, review),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.surfaceCard,
          borderRadius: tokens.borderRadiusMd,
          border: Border.all(color: tokens.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: tokens.shadowColor,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author row
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.2,
                  ),
                  backgroundImage: review.avatarUrl != null
                      ? NetworkImage(review.avatarUrl!)
                      : null,
                  child: review.avatarUrl == null
                      ? Text(
                          review.author.isNotEmpty
                              ? review.author[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    review.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (review.rating != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: tokens.borderRadiusSm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          review.rating!.toStringAsFixed(0),
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Review content excerpt
            Expanded(
              child: Text(
                review.content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Read more →',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
