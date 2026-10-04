import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../models/person_details.dart';
import '../../providers/app_provider.dart';
import '../../services/image_cache_manager.dart';
import '../../services/tmdb_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/tv_focusable.dart';
import 'details_screen.dart';
import 'tv_details_screen.dart';

/// Screen presenting biographical info, profile imagery, and categorized filmography
/// for an actor, creator, or director.
class PersonDetailsScreen extends StatefulWidget {
  final int personId;
  final String personName;
  final String? profileUrl;

  const PersonDetailsScreen({
    super.key,
    required this.personId,
    required this.personName,
    this.profileUrl,
  });

  @override
  State<PersonDetailsScreen> createState() => _PersonDetailsScreenState();
}

class _PersonDetailsScreenState extends State<PersonDetailsScreen> {
  PersonDetails? _details;
  bool _isLoading = true;
  bool _isBioExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadPersonDetails();
  }

  Future<void> _loadPersonDetails() async {
    final details = await TmdbService.instance.getPersonDetails(
      widget.personId,
    );
    if (mounted) {
      setState(() {
        _details = details;
        _isLoading = false;
      });
    }
  }

  void _navigateToMedia(MediaItem item) {
    final isTv = context.read<AppProvider>().isTvMode;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => isTv
            ? TvDetailsScreen(mediaItem: item)
            : DetailsScreen(mediaItem: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final isTv = context.read<AppProvider>().isTvMode;

    return Scaffold(
      backgroundColor: tokens.canvasBackground,
      appBar: AppBar(
        backgroundColor: tokens.surfaceCard.withValues(alpha: 0.8),
        elevation: 0,
        leading: TvFocusable(
          autofocus: isTv,
          borderRadius: tokens.borderRadiusPill,
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tokens.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back_rounded, color: tokens.textPrimary),
          ),
        ),
        title: Text(
          widget.personName,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Hero Bio & Profile Card
                  _buildHeaderProfileCard(context),

                  const SizedBox(height: 28),

                  // 2. Movies Filmography
                  if (_details != null &&
                      _details!.movieCredits.isNotEmpty) ...[
                    _buildSectionHeader(
                      context,
                      title: 'MOVIES',
                      count: _details!.movieCredits.length,
                      icon: Icons.movie_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildMediaShelf(context, _details!.movieCredits),
                    const SizedBox(height: 28),
                  ],

                  // 3. TV Series Filmography
                  if (_details != null && _details!.tvCredits.isNotEmpty) ...[
                    _buildSectionHeader(
                      context,
                      title: 'TV & SERIES',
                      count: _details!.tvCredits.length,
                      icon: Icons.tv_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildMediaShelf(context, _details!.tvCredits),
                    const SizedBox(height: 28),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderProfileCard(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final photoUrl = _details?.profileUrl ?? widget.profileUrl;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: tokens.getShapeDecoration(
        color: tokens.surfaceCard,
        radius: tokens.cardRadius * 1.2,
        side: BorderSide(color: tokens.borderSubtle, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actor Headshot
          ClipRRect(
            borderRadius: tokens.borderRadiusMd,
            child: SizedBox(
              width: 110,
              height: 150,
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      cacheManager: ExalereImageCacheManager.instance,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: tokens.surfaceElevated),
                      errorWidget: (_, _, _) => Container(
                        color: tokens.surfaceElevated,
                        child: Icon(
                          Icons.person_rounded,
                          size: 54,
                          color: tokens.textMuted,
                        ),
                      ),
                    )
                  : Container(
                      color: tokens.surfaceElevated,
                      child: Icon(
                        Icons.person_rounded,
                        size: 54,
                        color: tokens.textMuted,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 20),

          // Metadata & Biography
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _details?.name ?? widget.personName,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),

                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (_details?.knownForDepartment != null)
                      _buildChip(
                        context,
                        label: _details!.knownForDepartment!,
                        isPrimary: true,
                      ),
                    if (_details?.birthday != null)
                      _buildChip(
                        context,
                        label: 'Born: ${_details!.birthday}',
                        isPrimary: false,
                      ),
                    if (_details?.placeOfBirth != null)
                      _buildChip(
                        context,
                        label: _details!.placeOfBirth!,
                        isPrimary: false,
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_details?.biography != null &&
                    _details!.biography!.isNotEmpty) ...[
                  Text(
                    _details!.biography!,
                    maxLines: _isBioExpanded ? 100 : 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  if (_details!.biography!.length > 250) ...[
                    const SizedBox(height: 6),
                    TvFocusable(
                      borderRadius: tokens.borderRadiusSm,
                      onTap: () {
                        setState(() {
                          _isBioExpanded = !_isBioExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          _isBioExpanded ? 'Show Less' : 'Read Full Biography',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required bool isPrimary,
  }) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary
            ? theme.colorScheme.primary.withValues(alpha: 0.18)
            : tokens.surfaceElevated,
        borderRadius: tokens.borderRadiusXs,
        border: Border.all(
          color: isPrimary
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : tokens.borderSubtle,
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isPrimary ? theme.colorScheme.primary : tokens.textSecondary,
          fontSize: 11,
          fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
    required IconData icon,
  }) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.18),
            borderRadius: tokens.borderRadiusXs,
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaShelf(BuildContext context, List<MediaItem> items) {
    final tokens = context.tokens;

    return SizedBox(
      height: 220,
      child: ListView.separated(
        clipBehavior: Clip.none,
        cacheExtent: 350.0,
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (ctx, index) {
          final item = items[index];
          return TvFocusable(
            scaleFactor: 1.05,
            borderRadius: tokens.borderRadiusSm,
            onTap: () => _navigateToMedia(item),
            child: SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: tokens.borderRadiusSm,
                      child: Container(
                        decoration: BoxDecoration(
                          color: tokens.surfaceCard,
                          border: Border.all(
                            color: tokens.borderSubtle,
                            width: 0.8,
                          ),
                        ),
                        child:
                            item.posterUrl != null && item.posterUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: item.posterUrl!,
                                cacheManager: ExalereImageCacheManager.instance,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : Center(
                                child: Icon(
                                  Icons.movie_rounded,
                                  color: tokens.textMuted,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.year != null)
                    Text(
                      item.year!,
                      style: TextStyle(color: tokens.textMuted, fontSize: 11),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
