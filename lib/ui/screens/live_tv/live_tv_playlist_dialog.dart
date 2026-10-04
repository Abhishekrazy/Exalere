import 'package:flutter/material.dart';

import '../../../services/storage_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tv/tv_popup_scope.dart';
import '../../widgets/tv_focusable.dart';

/// Interactive modal allowing viewers to manage and switch between multiple M3U playlists.
class LiveTvPlaylistDialog extends StatefulWidget {
  final String? activePlaylistUrl;
  final ValueChanged<String?> onPlaylistSelected;

  const LiveTvPlaylistDialog({
    super.key,
    required this.activePlaylistUrl,
    required this.onPlaylistSelected,
  });

  @override
  State<LiveTvPlaylistDialog> createState() => _LiveTvPlaylistDialogState();
}

class _LiveTvPlaylistDialogState extends State<LiveTvPlaylistDialog> {
  final StorageService _storageService = StorageService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  List<Map<String, String>> _playlists = [];
  bool _isLoading = true;
  bool _isAdding = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaylists() async {
    final list = await _storageService.getIptvPlaylists();
    if (mounted) {
      setState(() {
        _playlists = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _addPlaylist() async {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();

    if (name.isEmpty || url.isEmpty) {
      setState(() {
        _errorMessage = 'Please provide both a name and a valid M3U URL.';
      });
      return;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() {
        _errorMessage = 'URL must start with http:// or https://';
      });
      return;
    }

    final updated = List<Map<String, String>>.from(_playlists);
    updated.add({'name': name, 'url': url});
    await _storageService.saveIptvPlaylists(updated);

    if (mounted) {
      _nameController.clear();
      _urlController.clear();
      setState(() {
        _playlists = updated;
        _isAdding = false;
        _errorMessage = null;
      });
    }
  }

  Future<void> _deletePlaylist(int index) async {
    final updated = List<Map<String, String>>.from(_playlists);
    final removed = updated.removeAt(index);
    await _storageService.saveIptvPlaylists(updated);

    // If active was deleted, reset to default
    if (widget.activePlaylistUrl == removed['url']) {
      widget.onPlaylistSelected(null);
    }

    if (mounted) {
      setState(() {
        _playlists = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 540 || size.height < 600;

    final isDefaultActive =
        widget.activePlaylistUrl == null || widget.activePlaylistUrl!.isEmpty;

    return TvPopupScope(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: (size.width * 0.9).clamp(340.0, 560.0),
              maxHeight: (size.height * 0.85).clamp(380.0, 640.0),
            ),
            margin: const EdgeInsets.all(20),
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 18 : 24,
              vertical: isCompact ? 18 : 22,
            ),
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
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: tokens.getShapeDecoration(
                        color: tokens.primaryAccent.withValues(alpha: 0.15),
                        radius: 999.0,
                      ),
                      child: Icon(
                        Icons.playlist_play_rounded,
                        color: tokens.primaryAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'M3U Playlists',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: isCompact ? 17 : 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Switch between custom streams or community feeds.',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TvFocusable(
                      borderRadius: tokens.borderRadiusPill,
                      onTap: () => Navigator.of(context).pop(),
                      child: IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: tokens.textMuted,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Content
                Flexible(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Default Playlist Card
                              _buildPlaylistItem(
                                title: 'Default iptv-org Feeds',
                                subtitle:
                                    'Free legal community global broadcast streams',
                                isSelected: isDefaultActive,
                                isDefault: true,
                                onSelect: () {
                                  widget.onPlaylistSelected(null);
                                  Navigator.of(context).pop();
                                },
                              ),
                              const SizedBox(height: 8),

                              // Custom Playlists
                              ..._playlists.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final item = entry.value;
                                final isSelected =
                                    widget.activePlaylistUrl == item['url'];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _buildPlaylistItem(
                                    title: item['name'] ?? 'Custom Playlist',
                                    subtitle: item['url'] ?? '',
                                    isSelected: isSelected,
                                    onSelect: () {
                                      widget.onPlaylistSelected(item['url']);
                                      Navigator.of(context).pop();
                                    },
                                    onDelete: () => _deletePlaylist(idx),
                                  ),
                                );
                              }),

                              // Add New Playlist Form / Button
                              const SizedBox(height: 8),
                              if (!_isAdding)
                                TvFocusable(
                                  borderRadius: BorderRadius.circular(
                                    tokens.cardRadius * 0.7,
                                  ),
                                  onTap: () => setState(() => _isAdding = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: tokens.getShapeDecoration(
                                      color: tokens.surfaceCard,
                                      radius: tokens.cardRadius * 0.7,
                                      side: BorderSide(
                                        color: tokens.borderSubtle,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_rounded,
                                          color: tokens.primaryAccent,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Add M3U Playlist',
                                          style: TextStyle(
                                            color: tokens.primaryAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else ...[
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: tokens.getShapeDecoration(
                                    color: tokens.surfaceCard,
                                    radius: tokens.cardRadius * 0.7,
                                    side: BorderSide(color: tokens.borderFocus),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Add Custom M3U / M3U8 Playlist',
                                        style: TextStyle(
                                          color: tokens.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextField(
                                        controller: _nameController,
                                        style: TextStyle(
                                          color: tokens.textPrimary,
                                          fontSize: 13,
                                        ),
                                        decoration: InputDecoration(
                                          hintText:
                                              'Playlist Name (e.g. Sports Hub)',
                                          hintStyle: TextStyle(
                                            color: tokens.textMuted,
                                          ),
                                          filled: true,
                                          fillColor: tokens.canvasBackground,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              tokens.cardRadius * 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _urlController,
                                        style: TextStyle(
                                          color: tokens.textPrimary,
                                          fontSize: 13,
                                        ),
                                        decoration: InputDecoration(
                                          hintText:
                                              'https://example.com/playlist.m3u',
                                          hintStyle: TextStyle(
                                            color: tokens.textMuted,
                                          ),
                                          filled: true,
                                          fillColor: tokens.canvasBackground,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              tokens.cardRadius * 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_errorMessage != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          _errorMessage!,
                                          style: TextStyle(
                                            color: theme.colorScheme.error,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TvFocusable(
                                            borderRadius: BorderRadius.circular(
                                              tokens.cardRadius * 0.5,
                                            ),
                                            onTap: () {
                                              setState(() {
                                                _isAdding = false;
                                                _errorMessage = null;
                                              });
                                            },
                                            child: TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  _isAdding = false;
                                                  _errorMessage = null;
                                                });
                                              },
                                              child: Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  color: tokens.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          TvFocusable(
                                            borderRadius: BorderRadius.circular(
                                              tokens.cardRadius * 0.5,
                                            ),
                                            onTap: _addPlaylist,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    tokens.primaryAccent,
                                                foregroundColor:
                                                    tokens.canvasBackground,
                                              ),
                                              onPressed: _addPlaylist,
                                              child: const Text('Save'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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

  Widget _buildPlaylistItem({
    required String title,
    required String subtitle,
    required bool isSelected,
    bool isDefault = false,
    required VoidCallback onSelect,
    VoidCallback? onDelete,
  }) {
    final tokens = context.tokens;

    return TvFocusable(
      borderRadius: BorderRadius.circular(tokens.cardRadius * 0.7),
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: tokens.getShapeDecoration(
          color: isSelected
              ? tokens.primaryAccent.withValues(alpha: 0.12)
              : tokens.surfaceCard,
          radius: tokens.cardRadius * 0.7,
          side: BorderSide(
            color: isSelected ? tokens.primaryAccent : tokens.borderSubtle,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? tokens.primaryAccent : tokens.textMuted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      fontSize: 13.5,
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
            ),
            if (!isDefault && onDelete != null)
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: tokens.errorColor,
                  size: 18,
                ),
                tooltip: 'Delete Playlist',
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
