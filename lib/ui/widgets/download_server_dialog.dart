import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_details.dart';
import '../../models/media_item.dart';
import '../../models/stream_source.dart';
import '../../providers/library_provider.dart';
import '../../services/direct_stream_service.dart';
import '../../services/provider_registry.dart';
import '../theme/app_tokens.dart';
import 'tv/tv_popup_scope.dart';
import 'tv_focusable.dart';

/// Helper to check if a stream source is direct-downloadable offline
/// (supports progressive MP4/MKV, MPEG-DASH manifests, and HLS playlists;
/// excludes web embeds, HTML iframes, and torrent magnets).
bool isStreamDownloadable(StreamSource source) {
  final url = source.url.trim().toLowerCase();
  final fmt = source.format.trim().toUpperCase();

  if (url.isEmpty) return false;
  if (url.startsWith('magnet:')) return false;

  // Filter out web embed URLs (e.g., VidSrc embed iframes)
  if (url.contains('/embed/') ||
      url.contains('vidsrc.sh') ||
      url.contains('vidsrc.me') ||
      url.contains('vidsrc.cc') ||
      url.contains('vidsrc.to') ||
      fmt == 'WEB EMBED' ||
      fmt == 'EMBED') {
    return false;
  }

  // Progressive MP4/MKV, MPEG-DASH manifests (.mpd), and HLS playlists (.m3u8) can all be saved offline
  return true;
}

/// Dialog allowing user to pick an available download server / quality.
/// Enforces duplicate prevention, TV D-Pad focusability, and design token styling.
class DownloadServerDialog extends StatefulWidget {
  final MediaItem mediaItem;
  final Episode? episode;
  final int? seasonNumber;
  final List<Episode>? seasonEpisodes;
  final bool isSeasonDownload;
  final String? imdbId;
  final int? year;
  final List<StreamSource>? preloadedStreams;
  final void Function(String message)? onShowToast;

  const DownloadServerDialog({
    super.key,
    required this.mediaItem,
    this.episode,
    this.seasonNumber,
    this.seasonEpisodes,
    this.isSeasonDownload = false,
    this.imdbId,
    this.year,
    this.preloadedStreams,
    this.onShowToast,
  });

  /// Entry point for downloading a movie, single episode, or entire season.
  /// Handles duplicate detection, pause/resume prompts, and server selection.
  static Future<void> show({
    required BuildContext context,
    required MediaItem mediaItem,
    Episode? episode,
    int? seasonNumber,
    List<Episode>? seasonEpisodes,
    bool isSeasonDownload = false,
    String? imdbId,
    int? year,
    List<StreamSource>? preloadedStreams,
    void Function(String message)? onShowToast,
  }) async {
    final directStreamService = DirectStreamService.instance;

    // 1. Single Item Duplicate Check (Movie or Episode)
    if (!isSeasonDownload) {
      final epNum = episode?.episode;
      final sNum = seasonNumber ?? episode?.season;
      final displayTitle = epNum != null
          ? '${mediaItem.title} - S${sNum}E$epNum'
          : mediaItem.title;

      final check = directStreamService.checkExistingDownload(
        mediaId: mediaItem.id,
        season: sNum,
        episode: epNum,
        title: mediaItem.title,
      );

      if (check.status == DownloadCheckStatus.alreadyDownloaded) {
        final redownload = await showDialog<bool>(
          context: context,
          builder: (ctx) => _DownloadInfoDialog(
            title: 'Already Downloaded',
            message:
                '"$displayTitle" is already downloaded and saved on your device.',
            primaryActionLabel: 'OK',
            secondaryActionLabel: 'Download Again',
            onSecondaryAction: () => Navigator.of(ctx).pop(true),
          ),
        );
        if (redownload != true) return;
      } else if (check.status == DownloadCheckStatus.alreadyDownloading) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => _DownloadInfoDialog(
            title: 'Currently Downloading',
            message: '"$displayTitle" is currently downloading in your queue.',
            primaryActionLabel: 'OK',
          ),
        );
        return;
      } else if (check.status == DownloadCheckStatus.alreadyQueued) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => _DownloadInfoDialog(
            title: 'Already Queued',
            message:
                '"$displayTitle" is already waiting in your download queue.',
            primaryActionLabel: 'OK',
          ),
        );
        return;
      } else if (check.status == DownloadCheckStatus.paused &&
          check.existingTask != null) {
        final resume = await showDialog<bool>(
          context: context,
          builder: (ctx) => _DownloadInfoDialog(
            title: 'Download Paused',
            message:
                '"$displayTitle" is currently paused. Would you like to resume downloading from where it left off?',
            primaryActionLabel: 'Resume',
            secondaryActionLabel: 'Cancel',
            onPrimaryAction: () => Navigator.of(ctx).pop(true),
            onSecondaryAction: () => Navigator.of(ctx).pop(false),
          ),
        );
        if (resume == true) {
          directStreamService.resumeDownload(check.existingTask!.id);
          onShowToast?.call('Resumed download for "$displayTitle"');
        }
        return;
      }
    } else if (seasonEpisodes != null && seasonEpisodes.isNotEmpty) {
      // 2. Season Duplicate Check
      int downloadedCount = 0;
      int activeCount = 0;
      for (final ep in seasonEpisodes) {
        final check = directStreamService.checkExistingDownload(
          mediaId: mediaItem.id,
          season: seasonNumber,
          episode: ep.episode,
        );
        if (check.status == DownloadCheckStatus.alreadyDownloaded) {
          downloadedCount++;
        } else if (check.status == DownloadCheckStatus.alreadyDownloading ||
            check.status == DownloadCheckStatus.alreadyQueued) {
          activeCount++;
        }
      }

      if (downloadedCount == seasonEpisodes.length) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => _DownloadInfoDialog(
            title: 'Season Already Downloaded',
            message:
                'All ${seasonEpisodes.length} episodes of Season $seasonNumber are already downloaded on your device.',
            primaryActionLabel: 'OK',
          ),
        );
        return;
      } else if (activeCount == seasonEpisodes.length) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => _DownloadInfoDialog(
            title: 'Season in Queue',
            message:
                'All episodes of Season $seasonNumber are already downloading or in your queue.',
            primaryActionLabel: 'OK',
          ),
        );
        return;
      }
    }

    // 3. Show Server Picker Dialog
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => DownloadServerDialog(
        mediaItem: mediaItem,
        episode: episode,
        seasonNumber: seasonNumber,
        seasonEpisodes: seasonEpisodes,
        isSeasonDownload: isSeasonDownload,
        imdbId: imdbId,
        year: year,
        preloadedStreams: preloadedStreams,
        onShowToast: onShowToast,
      ),
    );
  }

  @override
  State<DownloadServerDialog> createState() => _DownloadServerDialogState();
}

class _DownloadServerDialogState extends State<DownloadServerDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  List<StreamSource> _downloadableStreams = [];

  @override
  void initState() {
    super.initState();
    if (widget.preloadedStreams != null &&
        widget.preloadedStreams!.isNotEmpty) {
      final filtered = widget.preloadedStreams!
          .where(isStreamDownloadable)
          .toList();
      if (filtered.isNotEmpty) {
        _downloadableStreams = filtered;
        _isLoading = false;
        return;
      }
    }
    _resolveStreams();
  }

  Future<void> _resolveStreams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final library = context.read<LibraryProvider?>();
      final lastStream = library?.getLastUsedStream(widget.mediaItem.id);
      final preferred =
          lastStream?.effectiveProviderId ??
          ProviderRegistry().defaultProviderId ??
          widget.mediaItem.providerId ??
          (widget.mediaItem.provider != ProviderType.plugins
              ? widget.mediaItem.provider.shortId
              : null);

      final isSeries =
          widget.isSeasonDownload ||
          widget.episode != null ||
          widget.mediaItem.isSeries;

      final epNum =
          widget.episode?.episode ?? (widget.isSeasonDownload ? 1 : null);
      final sNum =
          widget.seasonNumber ??
          widget.episode?.season ??
          (widget.isSeasonDownload ? 1 : null);

      final resolvedImdbId =
          widget.imdbId ??
          (widget.mediaItem.id.startsWith('tt') ? widget.mediaItem.id : null);

      final streams = await ProviderRegistry().resolveStreams(
        subjectId: widget.mediaItem.id,
        title: widget.mediaItem.title,
        year: widget.year?.toString() ?? widget.mediaItem.year,
        imdbId: resolvedImdbId,
        season: sNum,
        episode: epNum,
        preferredProviderId: preferred,
        originProviderId: widget.mediaItem.effectiveProviderId,
        isSeries: isSeries,
      );

      final filtered = streams.where(isStreamDownloadable).toList();

      if (mounted) {
        setState(() {
          _downloadableStreams = filtered;
          _isLoading = false;
          if (filtered.isEmpty) {
            _errorMessage = streams.isEmpty
                ? 'No streams found for this title.'
                : 'No downloadable video servers available (web embeds and torrents cannot be saved offline).';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to resolve servers: $e';
        });
      }
    }
  }

  Future<void> _onSelectStream(StreamSource stream) async {
    Navigator.of(context).pop();

    final directStreamService = DirectStreamService.instance;

    if (widget.isSeasonDownload && widget.seasonEpisodes != null) {
      final seasonNum = widget.seasonNumber ?? 1;
      final added = await directStreamService.enqueueSeason(
        mediaItem: widget.mediaItem,
        seasonNumber: seasonNum,
        episodes: widget.seasonEpisodes!,
        preferredProviderId: stream.effectiveProviderId,
        preferredQuality: stream.quality,
        serverName: stream.server ?? stream.quality,
      );

      final total = widget.seasonEpisodes!.length;
      final skipped = total - added.length;

      if (added.isNotEmpty) {
        if (skipped > 0) {
          widget.onShowToast?.call(
            'Queued ${added.length} episodes for Season $seasonNum ($skipped skipped - already downloaded)',
          );
        } else {
          widget.onShowToast?.call(
            'Queued Season $seasonNum (${added.length} episodes) for download',
          );
        }
      } else {
        widget.onShowToast?.call(
          'All episodes for Season $seasonNum are already downloaded or in queue',
        );
      }
    } else {
      final ep = widget.episode;
      final title = ep != null
          ? '${widget.mediaItem.title} - S${ep.season}E${ep.episode}: ${ep.title}'
          : widget.mediaItem.title;

      await directStreamService.enqueueDownload(
        url: stream.url,
        title: title,
        headers: stream.headers,
        mediaId: widget.mediaItem.id,
        mediaTitle: widget.mediaItem.title,
        season: ep?.season ?? widget.seasonNumber,
        episode: ep?.episode,
        thumbnailUrl: ep?.thumbnail ?? widget.mediaItem.posterUrl,
        quality: stream.quality,
        serverName: stream.server ?? stream.quality,
        preferredProviderId: stream.effectiveProviderId,
      );

      widget.onShowToast?.call('Added "$title" to download queue');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final isCompact = screenHeight < 550 || screenWidth < 500;
    final dialogWidth = (screenWidth * 0.90).clamp(320.0, 520.0);
    final dialogMaxHeight = (screenHeight * 0.85).clamp(240.0, 540.0);

    final String subtitle;
    if (widget.isSeasonDownload) {
      final epCount = widget.seasonEpisodes?.length ?? 0;
      subtitle = 'Season ${widget.seasonNumber ?? 1} • $epCount episodes';
    } else if (widget.episode != null) {
      subtitle =
          'S${widget.episode!.season}E${widget.episode!.episode} • ${widget.episode!.title}';
    } else {
      subtitle = widget.mediaItem.title;
    }

    return PopScope(
      canPop: true,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(maxHeight: dialogMaxHeight),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceElevated,
              radius: tokens.cardRadius + 8,
              side: BorderSide(color: tokens.borderSubtle, width: 1),
            ),
            child: TvPopupScope(
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 14 : 20,
                    vertical: isCompact ? 12 : 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(isCompact ? 6 : 8),
                                  decoration: BoxDecoration(
                                    color: tokens.primaryAccent.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: tokens.borderRadiusSm,
                                  ),
                                  child: Icon(
                                    Icons.download_rounded,
                                    color: tokens.primaryAccent,
                                    size: isCompact ? 18 : 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.isSeasonDownload
                                            ? 'Download Season'
                                            : 'Select Download Server',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: isCompact ? 15 : 18,
                                          fontWeight: FontWeight.bold,
                                          color: tokens.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: isCompact ? 11 : 12,
                                          color: tokens.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TvFocusable(
                            borderRadius: tokens.borderRadiusPill,
                            onTap: () {
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: Padding(
                              padding: EdgeInsets.all(isCompact ? 4 : 6),
                              child: Icon(
                                Icons.close_rounded,
                                color: tokens.textSecondary,
                                size: isCompact ? 20 : 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(
                        color: tokens.borderSubtle.withValues(alpha: 0.4),
                        height: 1,
                      ),
                      const SizedBox(height: 8),

                      // Content Body
                      Expanded(
                        child: _isLoading
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation(
                                        tokens.primaryAccent,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Searching for available download servers...',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _errorMessage != null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.cloud_off_rounded,
                                        size: 40,
                                        color: tokens.textMuted,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        _errorMessage!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: tokens.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      TvFocusable(
                                        autofocus: true,
                                        borderRadius: tokens.borderRadiusPill,
                                        onTap: () =>
                                            Navigator.of(context).pop(),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tokens.surfaceCard,
                                            borderRadius:
                                                tokens.borderRadiusPill,
                                            border: Border.all(
                                              color: tokens.borderSubtle,
                                            ),
                                          ),
                                          child: Text(
                                            'Close',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: tokens.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                clipBehavior: Clip.none,
                                cacheExtent: 350.0,
                                itemCount: _downloadableStreams.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (ctx, index) {
                                  final stream = _downloadableStreams[index];
                                  return _StreamDownloadOptionCard(
                                    stream: stream,
                                    autofocus: index == 0,
                                    onTap: () => _onSelectStream(stream),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card representing a downloadable server / quality choice.
class _StreamDownloadOptionCard extends StatelessWidget {
  final StreamSource stream;
  final bool autofocus;
  final VoidCallback onTap;

  const _StreamDownloadOptionCard({
    required this.stream,
    required this.autofocus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final pName = stream.effectiveProviderName;
    final quality = stream.quality.isNotEmpty ? stream.quality : 'Standard';
    final format = stream.format.isNotEmpty ? stream.format : 'MP4';
    final size = stream.formattedSize;

    return TvFocusable(
      autofocus: autofocus,
      borderRadius: tokens.borderRadiusSm,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: tokens.surfaceCard,
          borderRadius: tokens.borderRadiusSm,
          border: Border.all(
            color: tokens.borderSubtle.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: tokens.primaryAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.dns_rounded,
                size: 16,
                color: tokens.primaryAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          pName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                      if (stream.server != null &&
                          stream.server != pName &&
                          stream.server!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.surfaceElevated,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: tokens.borderSubtle,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            stream.server!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: tokens.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.primaryAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          quality,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: tokens.primaryAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surfaceElevated,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: tokens.borderSubtle,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          format,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                      if (size.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          size,
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.file_download_outlined,
              size: 20,
              color: tokens.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Alert dialog for duplicate downloads, active queue items, and paused downloads.
/// Complies strictly with TV D-Pad navigation (Rule 5: exactly one autofocus: true action).
class _DownloadInfoDialog extends StatelessWidget {
  final String title;
  final String message;
  final String primaryActionLabel;
  final String? secondaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSecondaryAction;

  const _DownloadInfoDialog({
    required this.title,
    required this.message,
    required this.primaryActionLabel,
    this.secondaryActionLabel,
    this.onPrimaryAction,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width * 0.85).clamp(280.0, 440.0);

    return PopScope(
      canPop: true,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: dialogWidth,
            padding: const EdgeInsets.all(20),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceElevated,
              radius: tokens.cardRadius + 8,
              side: BorderSide(color: tokens.borderSubtle, width: 1),
            ),
            child: TvPopupScope(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tokens.primaryAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          color: tokens.primaryAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (secondaryActionLabel != null) ...[
                        TvFocusable(
                          autofocus: false,
                          borderRadius: tokens.borderRadiusPill,
                          onTap:
                              onSecondaryAction ??
                              () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: tokens.borderRadiusPill,
                              border: Border.all(color: tokens.borderSubtle),
                            ),
                            child: Text(
                              secondaryActionLabel!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      TvFocusable(
                        autofocus: true,
                        borderRadius: tokens.borderRadiusPill,
                        onTap:
                            onPrimaryAction ??
                            () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.primaryAccent,
                            borderRadius: tokens.borderRadiusPill,
                          ),
                          child: Text(
                            primaryActionLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
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
