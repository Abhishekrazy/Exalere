import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../models/user_playlist.dart';
import '../../providers/app_provider.dart';
import '../../providers/library_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/media_card.dart';
import '../widgets/tv_focusable.dart';
import 'details_screen.dart';
import 'tv_details_screen.dart';

/// Screen displaying all media items inside a custom user playlist.
/// Provides editing (rename, delete playlist, remove items) and direct playback navigation.
class PlaylistDetailsScreen extends StatefulWidget {
  final String playlistId;

  const PlaylistDetailsScreen({super.key, required this.playlistId});

  @override
  State<PlaylistDetailsScreen> createState() => _PlaylistDetailsScreenState();
}

class _PlaylistDetailsScreenState extends State<PlaylistDetailsScreen> {
  final FocusNode _firstCardFocusNode = FocusNode(
    debugLabel: 'PlaylistFirstCard',
  );

  @override
  void dispose() {
    _firstCardFocusNode.dispose();
    super.dispose();
  }

  void _openDetails(BuildContext context, MediaItem item) {
    final isTv = context.read<AppProvider>().isTvMode;
    if (isTv) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TvDetailsScreen(mediaItem: item)),
      );
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => DetailsScreen(mediaItem: item)));
    }
  }

  void _showRenameDialog(BuildContext context, UserPlaylist playlist) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final controller = TextEditingController(text: playlist.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surfaceElevated,
        shape: tokens.getShapeBorder(
          radius: tokens.cardRadius,
          side: BorderSide(color: tokens.borderSubtle),
        ),
        title: Text(
          'Rename Playlist',
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: tokens.textPrimary),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: tokens.textMuted),
            filled: true,
            fillColor: tokens.surfaceCard,
            border: OutlineInputBorder(
              borderRadius: tokens.borderRadiusXs,
              borderSide: BorderSide(color: tokens.borderSubtle),
            ),
          ),
        ),
        actions: [
          TvFocusable(
            borderRadius: tokens.borderRadiusSm,
            onTap: () => Navigator.of(ctx).pop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text('Cancel', style: TextStyle(color: tokens.textMuted)),
            ),
          ),
          TvFocusable(
            borderRadius: tokens.borderRadiusSm,
            onTap: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                context.read<LibraryProvider>().renamePlaylist(
                  playlist.id,
                  newName,
                );
              }
              Navigator.of(ctx).pop();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                'Save',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, UserPlaylist playlist) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surfaceElevated,
        shape: tokens.getShapeBorder(
          radius: tokens.cardRadius,
          side: BorderSide(color: tokens.borderSubtle),
        ),
        title: Text(
          'Delete Playlist?',
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${playlist.name}"? This action cannot be undone.',
          style: TextStyle(color: tokens.textSecondary),
        ),
        actions: [
          TvFocusable(
            borderRadius: tokens.borderRadiusSm,
            onTap: () => Navigator.of(ctx).pop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text('Cancel', style: TextStyle(color: tokens.textMuted)),
            ),
          ),
          TvFocusable(
            borderRadius: tokens.borderRadiusSm,
            onTap: () {
              context.read<LibraryProvider>().deletePlaylist(playlist.id);
              Navigator.of(ctx).pop(); // dismiss dialog
              Navigator.of(context).pop(); // exit playlist screen
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                'Delete',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final library = context.watch<LibraryProvider>();
    final playlist = library.playlists
        .where((p) => p.id == widget.playlistId)
        .firstOrNull;

    if (playlist == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          leading: const BackButton(),
        ),
        body: Center(
          child: Text(
            'Playlist not found',
            style: TextStyle(color: tokens.textSecondary),
          ),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = (width / 160).floor().clamp(2, 8);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: TvFocusable(
          borderRadius: tokens.borderRadiusPill,
          onTap: () => Navigator.of(context).pop(),
          child: const BackButton(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
              ),
            ),
            Text(
              '${playlist.itemCount} ${playlist.itemCount == 1 ? "title" : "titles"}',
              style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
            ),
          ],
        ),
        actions: [
          TvFocusable(
            borderRadius: tokens.borderRadiusPill,
            onTap: () => _showRenameDialog(context, playlist),
            child: Tooltip(
              message: 'Rename Playlist',
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.edit_rounded,
                  color: tokens.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ),
          TvFocusable(
            borderRadius: tokens.borderRadiusPill,
            onTap: () => _showDeleteDialog(context, playlist),
            child: Tooltip(
              message: 'Delete Playlist',
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: playlist.items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.movie_creation_outlined,
                      size: 64,
                      color: tokens.textMuted.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'This Playlist is Empty',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Browse titles and choose "Add to Playlist" to populate this collection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.58,
                crossAxisSpacing: 10,
                mainAxisSpacing: 14,
              ),
              itemCount: playlist.items.length,
              itemBuilder: (context, index) {
                final item = playlist.items[index];
                return Stack(
                  children: [
                    MediaCard(
                      item: item,
                      focusNode: index == 0 ? _firstCardFocusNode : null,
                      onTap: () => _openDetails(context, item),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: TvFocusable(
                        borderRadius: tokens.borderRadiusPill,
                        onTap: () =>
                            library.removeFromPlaylist(playlist.id, item.id),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: tokens.surfaceCard.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            border: Border.all(color: tokens.borderSubtle),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
