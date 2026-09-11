import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_details.dart';
import '../../models/media_item.dart';
import '../../providers/library_provider.dart';
import '../../services/moviebox_provider.dart';
import '../../services/provider_registry.dart';
import '../screens/player_screen.dart';
import '../theme/app_tokens.dart';
import 'tv_focusable.dart';

/// Clean, high-contrast 10-foot TV Episode Browser for TV Series.
/// Direct D-Pad navigation for selecting Seasons and Episodes with instant playback.
class TvSeriesSheet extends StatefulWidget {
  final MediaItem mediaItem;

  const TvSeriesSheet({super.key, required this.mediaItem});

  static Future<void> show(BuildContext context, MediaItem item) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TvSeriesSheet(mediaItem: item),
    );
  }

  @override
  State<TvSeriesSheet> createState() => _TvSeriesSheetState();
}

class _TvSeriesSheetState extends State<TvSeriesSheet> {
  final MovieBoxProvider _provider = MovieBoxProvider();
  MediaDetails? _details;
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedSeasonIdx = 0;
  bool _isLaunchingEpisode = false;

  @override
  void initState() {
    super.initState();
    _loadSeriesDetails();
  }

  Future<void> _loadSeriesDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final details = await _provider.getDetails(widget.mediaItem.id);
      if (!mounted) return;

      int initialSeasonIdx = 0;
      final history = context.read<LibraryProvider>().getHistoryItem(
        widget.mediaItem.id,
      );
      if (history != null &&
          history.season != null &&
          details != null &&
          details.seasons.isNotEmpty) {
        final found = details.seasons.indexWhere(
          (s) => s.seasonNumber == history.season,
        );
        if (found >= 0) initialSeasonIdx = found;
      }

      setState(() {
        _details = details;
        _selectedSeasonIdx = initialSeasonIdx;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load series episodes: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _playEpisode(Episode episode, int seasonNumber) async {
    if (_isLaunchingEpisode) return;
    setState(() => _isLaunchingEpisode = true);

    try {
      final streams = await ProviderRegistry().resolveStreams(
        subjectId: widget.mediaItem.id,
        season: seasonNumber,
        episode: episode.episode,
        preferredProviderId: 'moviebox',
      );

      if (!mounted) return;

      if (streams.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No active streams found for this episode.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isLaunchingEpisode = false);
        return;
      }

      final library = context.read<LibraryProvider>();
      final resumePos = library.getResumePosition(
        widget.mediaItem.id,
        season: seasonNumber,
        episode: episode.episode,
      );

      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              mediaItem: widget.mediaItem,
              streamSource: streams.first,
              availableSources: streams,
              season: seasonNumber,
              episode: episode.episode,
              startPositionSeconds: resumePos > 0 ? resumePos : null,
              mediaDetails: _details,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing episode: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isLaunchingEpisode = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.88,
      decoration: context.tokens.getShapeDecoration(
        color: context.tokens.surfaceCard,
        radius: context.tokens.cardRadius + 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar with Title & Close
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 24, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.mediaItem.cleanTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: context.tokens.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (widget.mediaItem.effectiveLanguageTag != null &&
                              widget
                                  .mediaItem
                                  .effectiveLanguageTag!
                                  .isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: context.tokens.getShapeDecoration(
                                color: context.tokens.borderSubtle,
                                radius: context.tokens.cardRadius * 0.3,
                              ),
                              child: Text(
                                widget.mediaItem.effectiveLanguageTag!
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: context.tokens.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (widget.mediaItem.year != null) ...[
                            Text(
                              '${widget.mediaItem.year}',
                              style: TextStyle(
                                color: context.tokens.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (widget.mediaItem.genre != null &&
                              widget.mediaItem.genre!.isNotEmpty) ...[
                            Text(
                              widget.mediaItem.genre!,
                              style: TextStyle(
                                color: context.tokens.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                TvFocusable(
                  onTap: () => Navigator.of(context).pop(),
                  shape: context.tokens.shapePill,
                  borderRadius: context.tokens.borderRadiusPill,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: context.tokens.getShapeDecoration(
                      color: context.tokens.surfaceElevated.withValues(
                        alpha: 0.6,
                      ),
                      radius: context.tokens.cardRadius * 2,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: context.tokens.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(color: context.tokens.borderSubtle, height: 1),

          // Body Content
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading episodes...',
                          style: TextStyle(
                            color: context.tokens.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                ? Center(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 14,
                      ),
                    ),
                  )
                : _buildEpisodesContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesContent(ThemeData theme) {
    if (_details == null || _details!.seasons.isEmpty) {
      return Center(
        child: Text(
          'No episodes available for this title.',
          style: TextStyle(color: context.tokens.textMuted),
        ),
      );
    }

    final seasons = _details!.seasons;
    final activeSeason =
        (_selectedSeasonIdx >= 0 && _selectedSeasonIdx < seasons.length)
        ? seasons[_selectedSeasonIdx]
        : seasons.first;
    final episodes = activeSeason.episodes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Seasons Row (Horizontally navigable via D-Pad)
        if (seasons.length > 1) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: seasons.length,
                separatorBuilder: (context, _) => const SizedBox(width: 10),
                itemBuilder: (context, idx) {
                  final s = seasons[idx];
                  final isSelected = idx == _selectedSeasonIdx;
                  return TvFocusable(
                    onTap: () => setState(() => _selectedSeasonIdx = idx),
                    scaleFactor: 1.08,
                    shape: context.tokens.shapeSm,
                    borderRadius: context.tokens.borderRadiusSm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: context.tokens.getShapeDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : context.tokens.surfaceElevated.withValues(
                                alpha: 0.6,
                              ),
                        radius: context.tokens.cardRadius * 0.7,
                        side: BorderSide(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : context.tokens.borderSubtle,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Season ${s.seasonNumber}',
                          style: TextStyle(
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : context.tokens.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Divider(color: context.tokens.borderSubtle, height: 1),
        ],

        // Scrollable Episode Grid / List
        Expanded(
          child: _isLaunchingEpisode
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Connecting to stream...',
                        style: TextStyle(
                          color: context.tokens.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : episodes.isEmpty
              ? Center(
                  child: Text(
                    'No episodes found for this season.',
                    style: TextStyle(color: context.tokens.textMuted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  itemCount: episodes.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 10),
                  itemBuilder: (context, epIdx) {
                    final ep = episodes[epIdx];
                    return TvFocusable(
                      autofocus: epIdx == 0,
                      scaleFactor: 1.03,
                      shape: context.tokens.shapeSm,
                      borderRadius: context.tokens.borderRadiusSm,
                      onTap: () => _playEpisode(ep, activeSeason.seasonNumber),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: context.tokens.getShapeDecoration(
                          color: context.tokens.surfaceElevated,
                          radius: context.tokens.cardRadius * 0.7,
                          side: BorderSide(color: context.tokens.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: context.tokens.getShapeDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.15,
                                ),
                                radius: context.tokens.cardRadius * 0.4,
                              ),
                              child: Center(
                                child: Text(
                                  '${ep.episode}',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ep.title.isNotEmpty
                                        ? ep.title
                                        : 'Episode ${ep.episode}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: context.tokens.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (ep.overview != null &&
                                      ep.overview!.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      ep.overview!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: context.tokens.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: context.tokens.getShapeDecoration(
                                color: theme.colorScheme.primary,
                                radius: context.tokens.cardRadius * 2,
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: theme.colorScheme.onPrimary,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
