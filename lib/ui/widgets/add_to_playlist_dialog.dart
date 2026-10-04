import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/library_provider.dart';
import '../../services/image_cache_manager.dart';
import '../theme/app_tokens.dart';
import 'tv_focusable.dart';

/// Modal dialog allowing users to add or remove a title from custom playlists.
/// Supports TV D-Pad spatial navigation and mobile touch interactions.
class AddToPlaylistDialog extends StatefulWidget {
  final MediaItem mediaItem;

  const AddToPlaylistDialog({super.key, required this.mediaItem});

  static Future<void> show(BuildContext context, MediaItem item) {
    return showDialog(
      context: context,
      builder: (ctx) => AddToPlaylistDialog(mediaItem: item),
    );
  }

  @override
  State<AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends State<AddToPlaylistDialog> {
  final TextEditingController _newPlaylistController = TextEditingController();
  bool _isCreatingNew = false;
  String? _createError;

  @override
  void dispose() {
    _newPlaylistController.dispose();
    super.dispose();
  }

  Future<void> _handleCreatePlaylist(LibraryProvider library) async {
    final name = _newPlaylistController.text.trim();
    if (name.isEmpty) {
      setState(() => _createError = 'Please enter a name');
      return;
    }
    setState(() => _createError = null);
    final pl = await library.createPlaylist(name);
    await library.addToPlaylist(pl.id, widget.mediaItem);
    _newPlaylistController.clear();
    if (mounted) {
      setState(() {
        _isCreatingNew = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final library = context.watch<LibraryProvider>();
    final playlists = library.playlists;

    return Dialog(
      backgroundColor: tokens.surfaceElevated,
      shape: tokens.getShapeBorder(
        radius: tokens.cardRadius,
        side: BorderSide(color: tokens.borderSubtle),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Title & Media Preview
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: tokens.borderRadiusXs,
                    child: SizedBox(
                      width: 44,
                      height: 64,
                      child: widget.mediaItem.posterUrl != null
                          ? CachedNetworkImage(
                              imageUrl: widget.mediaItem.posterUrl!,
                              cacheManager: ExalereImageCacheManager.instance,
                              fit: BoxFit.cover,
                              errorWidget: (context, error, stackTrace) =>
                                  Container(
                                    color: tokens.surfaceCard,
                                    child: Icon(
                                      Icons.movie_rounded,
                                      color: tokens.textMuted,
                                    ),
                                  ),
                            )
                          : Container(
                              color: tokens.surfaceCard,
                              child: Icon(
                                Icons.movie_rounded,
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
                        Text(
                          'Add to Playlist',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.mediaItem.cleanTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: tokens.textSecondary,
                          ),
                        ),
                        if (widget.mediaItem.year != null &&
                            widget.mediaItem.year!.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            widget.mediaItem.year!,
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  TvFocusable(
                    borderRadius: tokens.borderRadiusPill,
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.close_rounded,
                        color: tokens.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: tokens.borderSubtle, height: 1),
              const SizedBox(height: 12),

              // Playlist List or Create New Form
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Create New Playlist Trigger / Inline Form
                      if (_isCreatingNew)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: tokens.surfaceCard,
                            borderRadius: tokens.borderRadiusSm,
                            border: Border.all(
                              color: tokens.primaryAccent.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'New Playlist Name',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _newPlaylistController,
                                autofocus: true,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'e.g., Weekend Marathons, Sci-Fi Gems',
                                  hintStyle: TextStyle(
                                    color: tokens.textMuted,
                                    fontSize: 13,
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  filled: true,
                                  fillColor: tokens.surfaceElevated,
                                  border: OutlineInputBorder(
                                    borderRadius: tokens.borderRadiusXs,
                                    borderSide: BorderSide(
                                      color: tokens.borderSubtle,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: tokens.borderRadiusXs,
                                    borderSide: BorderSide(
                                      color: tokens.primaryAccent,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) =>
                                    _handleCreatePlaylist(library),
                              ),
                              if (_createError != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _createError!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TvFocusable(
                                    borderRadius: tokens.borderRadiusXs,
                                    onTap: () {
                                      setState(() {
                                        _isCreatingNew = false;
                                        _createError = null;
                                        _newPlaylistController.clear();
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                          color: tokens.textMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TvFocusable(
                                    borderRadius: tokens.borderRadiusXs,
                                    onTap: () => _handleCreatePlaylist(library),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tokens.primaryAccent,
                                        borderRadius: tokens.borderRadiusXs,
                                      ),
                                      child: Text(
                                        'Create & Add',
                                        style: TextStyle(
                                          color: theme.colorScheme.onPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TvFocusable(
                            borderRadius: tokens.borderRadiusSm,
                            onTap: () => setState(() => _isCreatingNew = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.surfaceCard,
                                borderRadius: tokens.borderRadiusSm,
                                border: Border.all(color: tokens.borderSubtle),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: tokens.primaryAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Create New Playlist',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.primaryAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      if (playlists.isEmpty && !_isCreatingNew)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.playlist_add_rounded,
                                  size: 40,
                                  color: tokens.textMuted.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No custom playlists created yet.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Existing Playlists List
                      ...playlists.map((pl) {
                        final inThisPl = pl.items.any(
                          (i) => i.id == widget.mediaItem.id,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: TvFocusable(
                            borderRadius: tokens.borderRadiusSm,
                            onTap: () async {
                              if (inThisPl) {
                                await library.removeFromPlaylist(
                                  pl.id,
                                  widget.mediaItem.id,
                                );
                              } else {
                                await library.addToPlaylist(
                                  pl.id,
                                  widget.mediaItem,
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: inThisPl
                                    ? tokens.primaryAccent.withValues(
                                        alpha: 0.12,
                                      )
                                    : tokens.surfaceCard,
                                borderRadius: tokens.borderRadiusSm,
                                border: Border.all(
                                  color: inThisPl
                                      ? tokens.primaryAccent.withValues(
                                          alpha: 0.6,
                                        )
                                      : tokens.borderSubtle,
                                  width: inThisPl ? 1.2 : 0.8,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    inThisPl
                                        ? Icons.check_box_rounded
                                        : Icons.check_box_outline_blank_rounded,
                                    color: inThisPl
                                        ? tokens.primaryAccent
                                        : tokens.textMuted,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pl.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: inThisPl
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: tokens.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          '${pl.itemCount} ${pl.itemCount == 1 ? "item" : "items"}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: tokens.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),
              // Done Button
              Align(
                alignment: Alignment.centerRight,
                child: TvFocusable(
                  borderRadius: tokens.borderRadiusSm,
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.surfaceCard,
                      borderRadius: tokens.borderRadiusSm,
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
