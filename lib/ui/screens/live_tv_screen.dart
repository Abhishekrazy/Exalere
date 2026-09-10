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
import 'player_screen.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  final IptvProvider _iptvProvider = IptvProvider();
  final StorageService _storageService = StorageService();

  List<LiveChannel> _channels = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadChannels();
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
    final categories = _iptvProvider.categories;
    final screenWidth = MediaQuery.of(context).size.width;

    final crossAxisCount = screenWidth >= 1250
        ? 4
        : screenWidth >= 900
        ? 3
        : screenWidth >= 600
        ? 2
        : 1;

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
            // Search Input Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: context.tokens.surfaceCard,
                  borderRadius: context.tokens.borderRadiusMd,
                  border: Border.all(
                    color: context.tokens.borderSubtle,
                  ),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search 100+ live TV channels & sports...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white54,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: Colors.white54,
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

            // Category Filter Pills (JioHotstar Broadcast Style)
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
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSel,
                        onSelected: (sel) {
                          if (sel) setState(() => _selectedCategory = cat);
                        },
                        selectedColor: theme.colorScheme.primary,
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        side: BorderSide(
                          color: isSel
                              ? theme.colorScheme.primary
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSel ? Colors.black : Colors.white70,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Channels Counter Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_selectedCategory Channels (${filtered.length})',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  InkWell(
                    onTap: _loadChannels,
                    borderRadius: context.tokens.borderRadiusXs,
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

            // Channels List or Grid
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
                          const Text(
                            'Connecting to Live TV broadcast feeds...',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No live TV channels found in this category.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 1.34,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final c = filtered[index];
                        return LiveChannelCard(
                          channel: c,
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
  final VoidCallback onTap;
  final VoidCallback onOpenVlc;

  const LiveChannelCard({
    super.key,
    required this.channel,
    required this.onTap,
    required this.onOpenVlc,
  });

  @override
  State<LiveChannelCard> createState() => _LiveChannelCardState();
}

class _LiveChannelCardState extends State<LiveChannelCard> {
  bool _isHovered = false;

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

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _isHovered ? 1.025 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: context.tokens.surfaceCard,
            borderRadius: context.tokens.borderRadiusMd,
            border: Border.all(
              color: _isHovered
                  ? context.tokens.borderFocus
                  : context.tokens.borderSubtle,
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? context.tokens.primaryAccent.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.35),
                blurRadius: _isHovered ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: context.tokens.borderRadiusSm,
            child: InkWell(
              onTap: widget.onTap,
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
                                context.tokens.surfaceElevated,
                                context.tokens.surfaceCard,
                                catColor.withValues(alpha: 0.08),
                              ],
                            ),
                          ),
                        ),

                        // Channel Logo or Stylized Emblem
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            child: c.logoUrl != null && c.logoUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: c.logoUrl!,
                                    fit: BoxFit.contain,
                                    placeholder: (_, _) => SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    errorWidget: (_, _, _) =>
                                        _buildEmblem(c, catColor),
                                  )
                                : _buildEmblem(c, catColor),
                          ),
                        ),

                        // Top Badges Overlay
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: context.tokens.borderRadiusXs,
                              border: Border.all(
                                color: catColor.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              c.category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: catColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),

                        // Live Badge (Top Right)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.tokens.primaryAccent,
                              borderRadius: context.tokens.borderRadiusXs,
                              boxShadow: [
                                BoxShadow(
                                  color: context.tokens.primaryAccent
                                      .withValues(alpha: 0.6),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Colors.white,
                                  size: 7,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Hover Play Icon Overlay
                        AnimatedOpacity(
                          opacity: _isHovered ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 150),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.35),
                            child: Center(
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.colorScheme.primary,
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.5),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 28,
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
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    c.category,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (c.resolution != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: context.tokens.borderRadiusXs,
                                        border: Border.all(
                                          color: Colors.white24,
                                          width: 0.6,
                                        ),
                                      ),
                                      child: Text(
                                        c.resolution!,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 9,
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
                        IconButton(
                          icon: const Icon(
                            Icons.open_in_new_rounded,
                            size: 18,
                            color: Colors.white38,
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
      ),
    );
  }

  Widget _buildEmblem(LiveChannel c, Color catColor) {
    final initials = c.name.trim().isNotEmpty
        ? c.name
              .trim()
              .split(' ')
              .take(2)
              .map((w) => w.isNotEmpty ? w[0] : '')
              .join('')
              .toUpperCase()
        : 'TV';

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.45),
        border: Border.all(color: catColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: catColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
