import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../models/live_channel.dart';
import '../../models/media_item.dart';
import '../../models/stream_source.dart';
import '../../providers/app_provider.dart';
import '../../services/iptv_provider.dart';
import '../../services/storage_service.dart';
import '../../services/external_player_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/tv_focusable.dart';
import 'player_screen.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  final IptvProvider _iptvProvider = IptvProvider();
  final StorageService _storageService = StorageService();
  final FocusNode _searchFocusNode = FocusNode();

  List<LiveChannel> _channels = [];
  bool _isLoading = true;
  bool _isSearchFocused = false;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
      }
    });
    _loadChannels();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    setState(() => _isLoading = true);
    final customUrl = await _storageService.getCustomIptvUrl();
    final channels = await _iptvProvider.fetchChannels(customUrl: customUrl);
    if (mounted) {
      setState(() {
        _channels = channels;
        _isLoading = false;
      });
    }
  }

  void _playChannel(LiveChannel channel) {
    if (context.read<AppProvider>().useExternalPlayer) {
      _openExternalPlayer(channel);
      return;
    }

    final mediaItem = MediaItem(
      id: channel.id,
      title: channel.name,
      mediaType: MediaType.movie,
      posterUrl: channel.logoUrl,
      genre: channel.category,
      provider: ProviderType.liveTv,
    );

    final streamSource = StreamSource(
      quality: channel.resolution ?? 'Live HD',
      resolution: channel.resolution ?? '1080p',
      format: 'HLS Live',
      url: channel.streamUrl,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PlayerScreen(mediaItem: mediaItem, streamSource: streamSource),
      ),
    );
  }

  Future<void> _openExternalPlayer(LiveChannel channel) async {
    final launched = await ExternalPlayerService().launch(
      url: channel.streamUrl,
      title: channel.name,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open external player for ${channel.name}. Ensure MPV or VLC is installed.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final categories = _iptvProvider.categories;
    final screenWidth = MediaQuery.of(context).size.width;

    bool isTv = false;
    try {
      isTv = context.watch<AppProvider>().isTvMode;
    } catch (_) {}

    // TV interface: compact cards, more per row (5 or 6 per line)
    // Non-TV: standard responsive grid (1 to 4)
    final crossAxisCount = isTv
        ? (screenWidth >= 1200 ? 6 : (screenWidth >= 760 ? 5 : 4))
        : (screenWidth >= 1250
              ? 4
              : (screenWidth >= 900 ? 3 : (screenWidth >= 600 ? 2 : 1)));

    final childAspectRatio = isTv ? 1.30 : 1.34;

    final filtered = _channels.where((c) {
      final matchesCat =
          _selectedCategory == 'All' || c.category == _selectedCategory;
      final matchesSearch =
          _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Bar with TV Focus Highlighting
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: tokens.surfaceCard,
                  borderRadius: tokens.borderRadiusMd,
                  border: Border.all(
                    color: _isSearchFocused
                        ? theme.colorScheme.primary
                        : tokens.borderSubtle,
                    width: _isSearchFocused ? 2.0 : 1.0,
                  ),
                  boxShadow: _isSearchFocused
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: TextField(
                  focusNode: _searchFocusNode,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: TextStyle(color: tokens.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search 100+ live TV channels & sports...',
                    hintStyle: TextStyle(color: tokens.textMuted),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: _isSearchFocused
                          ? theme.colorScheme.primary
                          : tokens.textSecondary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: tokens.textSecondary,
                            ),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),

            // Category Filter Pills with D-Pad TV Focusable glow
            if (categories.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: Row(
                  children: categories.map((cat) {
                    final isSel = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: TvFocusable(
                        scaleFactor: 1.08,
                        borderRadius: tokens.borderRadiusPill,
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSel
                                ? theme.colorScheme.primary
                                : tokens.surfaceElevated.withValues(alpha: 0.5),
                            borderRadius: tokens.borderRadiusPill,
                            border: Border.all(
                              color: isSel
                                  ? theme.colorScheme.primary
                                  : tokens.borderSubtle,
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSel) ...[
                                Icon(
                                  Icons.check_rounded,
                                  size: 13,
                                  color: theme.colorScheme.onPrimary,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSel
                                      ? FontWeight.w900
                                      : FontWeight.w600,
                                  color: isSel
                                      ? theme.colorScheme.onPrimary
                                      : tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Channels Counter Bar & D-Pad focusable Refresh
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_selectedCategory Channels (${filtered.length})',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TvFocusable(
                    scaleFactor: 1.08,
                    borderRadius: tokens.borderRadiusXs,
                    onTap: _loadChannels,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Refresh',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Channels Grid with TV Spatial Navigation & Highlighting
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Connecting to Live TV broadcast feeds...',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No live TV channels found in this category.',
                        style: TextStyle(color: tokens.textSecondary),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: childAspectRatio,
                        crossAxisSpacing: isTv ? 10 : 12,
                        mainAxisSpacing: isTv ? 10 : 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final c = filtered[index];
                        return LiveChannelCard(
                          channel: c,
                          isTv: isTv,
                          onTap: () => _playChannel(c),
                          onOpenVlc: () => _openExternalPlayer(c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class LiveChannelCard extends StatefulWidget {
  final LiveChannel channel;
  final bool isTv;
  final VoidCallback onTap;
  final VoidCallback onOpenVlc;

  const LiveChannelCard({
    super.key,
    required this.channel,
    this.isTv = false,
    required this.onTap,
    required this.onOpenVlc,
  });

  @override
  State<LiveChannelCard> createState() => _LiveChannelCardState();
}

class _LiveChannelCardState extends State<LiveChannelCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  Color _getCategoryColor(String category, AppTokens tokens) {
    final cat = category.toLowerCase();
    if (cat.contains('sport')) return tokens.liveColor;
    if (cat.contains('news')) return tokens.errorColor;
    if (cat.contains('movie') || cat.contains('cinema')) {
      return tokens.primaryAccent;
    }
    if (cat.contains('music')) return tokens.secondaryAccent;
    if (cat.contains('kid') || cat.contains('anim')) {
      return tokens.vipColor;
    }
    if (cat.contains('doc')) return tokens.secondaryAccent;
    return tokens.primaryAccent;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final c = widget.channel;
    final catColor = _getCategoryColor(c.category, tokens);
    final isActive = _isHovered || _isFocused;
    final isTv = widget.isTv;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: TvFocusable(
        scaleFactor: isTv ? 1.06 : 1.03,
        borderRadius: tokens.borderRadiusMd,
        onTap: widget.onTap,
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            borderRadius: tokens.borderRadiusMd,
            border: Border.all(
              color: isActive ? theme.colorScheme.primary : tokens.borderSubtle,
              width: isActive ? 2.0 : 1.0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : tokens.getCardShadows(),
          ),
          child: ClipRRect(
            borderRadius: tokens.borderRadiusSm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 16:9 Visual Thumbnail / Logo Canvas
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              tokens.surfaceElevated,
                              tokens.surfaceCard,
                              catColor.withValues(alpha: 0.08),
                            ],
                          ),
                        ),
                      ),

                      // Channel Logo or Stylized Emblem
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTv ? 14 : 24,
                            vertical: isTv ? 8 : 14,
                          ),
                          child: c.logoUrl != null && c.logoUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: c.logoUrl!,
                                  fit: BoxFit.contain,
                                  placeholder: (_, _) => SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  errorWidget: (_, _, _) =>
                                      _buildEmblem(c, catColor, isTv, tokens),
                                )
                              : _buildEmblem(c, catColor, isTv, tokens),
                        ),
                      ),

                      // Top Badges Overlay
                      Positioned(
                        top: isTv ? 5 : 8,
                        left: isTv ? 5 : 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTv ? 5 : 7,
                            vertical: isTv ? 2 : 3,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.canvasBackground.withValues(
                              alpha: 0.75,
                            ),
                            borderRadius: tokens.borderRadiusXs,
                            border: Border.all(
                              color: catColor.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            c.category.toUpperCase(),
                            style: TextStyle(
                              fontSize: isTv ? 7.5 : 9,
                              fontWeight: FontWeight.bold,
                              color: catColor,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),

                      // Live Badge (Top Right)
                      Positioned(
                        top: isTv ? 5 : 8,
                        right: isTv ? 5 : 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTv ? 4 : 6,
                            vertical: isTv ? 2 : 3,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.primaryAccent,
                            borderRadius: tokens.borderRadiusXs,
                            boxShadow: [
                              BoxShadow(
                                color: tokens.primaryAccent.withValues(
                                  alpha: 0.6,
                                ),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                color: theme.colorScheme.onPrimary,
                                size: isTv ? 5 : 7,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: isTv ? 7.5 : 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Focus / Hover Play Icon Overlay
                      AnimatedOpacity(
                        opacity: isActive ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          color: tokens.canvasBackground.withValues(
                            alpha: 0.35,
                          ),
                          child: Center(
                            child: Container(
                              width: isTv ? 34 : 44,
                              height: isTv ? 34 : 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primary,
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: theme.colorScheme.onPrimary,
                                size: isTv ? 22 : 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Metadata Bar
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isTv ? 8 : 12,
                    isTv ? 5 : 8,
                    isTv ? 6 : 8,
                    isTv ? 5 : 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: isTv ? 11 : 13,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  c.category,
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: isTv ? 9.5 : 11,
                                  ),
                                ),
                                if (c.resolution != null) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tokens.surfaceElevated.withValues(
                                        alpha: 0.8,
                                      ),
                                      borderRadius:
                                          context.tokens.borderRadiusXs,
                                      border: Border.all(
                                        color: tokens.borderSubtle,
                                        width: 0.6,
                                      ),
                                    ),
                                    child: Text(
                                      c.resolution!,
                                      style: TextStyle(
                                        color: tokens.textSecondary,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isTv)
                        IconButton(
                          icon: Icon(
                            Icons.open_in_new_rounded,
                            size: 18,
                            color: tokens.textMuted,
                          ),
                          tooltip: 'Open in VLC / External Player',
                          onPressed: widget.onOpenVlc,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmblem(
    LiveChannel c,
    Color catColor,
    bool isTv,
    AppTokens tokens,
  ) {
    final initials = c.name.trim().isNotEmpty
        ? c.name
              .trim()
              .split(' ')
              .take(2)
              .map((w) => w.isNotEmpty ? w[0] : '')
              .join('')
              .toUpperCase()
        : 'TV';

    final size = isTv ? 38.0 : 52.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tokens.canvasBackground.withValues(alpha: 0.45),
        border: Border.all(color: catColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: catColor,
            fontWeight: FontWeight.bold,
            fontSize: isTv ? 12 : 16,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
