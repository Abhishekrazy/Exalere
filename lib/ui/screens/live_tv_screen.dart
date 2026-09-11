import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../models/live_channel.dart';
import '../../models/media_item.dart';
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
  final TextEditingController _searchController = TextEditingController();

  List<LiveChannel> _channels = [];
  bool _isLoading = true;
  bool _isSearchVisible = false;
  bool _isSearchFocused = false;
  String _selectedCategory = 'All';
  String _selectedCountry = 'IN';
  Set<String> _selectedLanguages = {'ALL'};
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    setState(() => _isLoading = true);
    final customUrl = await _storageService.getCustomIptvUrl();
    _selectedCountry = await _storageService.getLiveTvCountry();
    _selectedLanguages = await _storageService.getLiveTvLanguages();
    // Fetch by country; language filtering done client-side for multi-select
    final channels = await _iptvProvider.fetchChannels(
      customUrl: customUrl,
      countryCode: _selectedCountry,
    );
    if (mounted) {
      setState(() {
        _channels = _applyLanguageFilter(channels);
        _isLoading = false;
      });
    }
  }

  Future<void> _selectCountry(String code) async {
    if (_selectedCountry == code) return;
    setState(() {
      _selectedCountry = code;
      _selectedCategory = 'All';
      _isLoading = true;
    });
    await _storageService.setLiveTvCountry(code);
    final customUrl = await _storageService.getCustomIptvUrl();
    final channels = await _iptvProvider.fetchChannels(
      customUrl: customUrl,
      countryCode: code,
    );
    if (mounted) {
      setState(() {
        _channels = _applyLanguageFilter(channels);
        _isLoading = false;
      });
    }
  }

  /// Filters [channels] by the current [_selectedLanguages] set.
  /// If the set is empty or contains 'ALL', all channels are returned.
  List<LiveChannel> _applyLanguageFilter(List<LiveChannel> channels) {
    final langs = _selectedLanguages;
    if (langs.isEmpty || langs.contains('ALL')) return channels;
    return channels.where((ch) {
      final lang = (ch.language ?? '').toUpperCase();
      return langs.any((code) {
        if (lang.contains(code)) return true;
        // Fuzzy name-based fallback for common codes
        final n = ch.name.toLowerCase();
        if (code == 'HIN' &&
            (n.contains('hindi') ||
                n.contains('hindustan') ||
                n.contains('aaj tak') ||
                n.contains('abp') ||
                n.contains('zee') ||
                n.contains('ndtv') ||
                n.contains('india today') ||
                n.contains('republic bharat') ||
                n.contains('dd news') ||
                n.contains('9xm') ||
                n.contains('mastiii'))) {
          return true;
        }
        if (code == 'ENG' &&
            (n.contains('english') ||
                n.contains('bloomberg') ||
                n.contains('cnn') ||
                n.contains('bbc') ||
                n.contains('sky') ||
                n.contains('cnbc'))) {
          return true;
        }
        return false;
      });
    }).toList();
  }

  Future<void> _selectLanguages(Set<String> codes) async {
    final normalized = codes.isEmpty
        ? <String>{'ALL'}
        : codes.map((c) => c.toUpperCase()).toSet();
    if (normalized == _selectedLanguages) return;
    setState(() {
      _selectedLanguages = normalized;
      _selectedCategory = 'All';
      _isLoading = true;
    });
    await _storageService.setLiveTvLanguages(normalized);
    final customUrl = await _storageService.getCustomIptvUrl();
    final channels = await _iptvProvider.fetchChannels(
      customUrl: customUrl,
      countryCode: _selectedCountry,
    );
    if (mounted) {
      setState(() {
        _channels = _applyLanguageFilter(channels);
        _isLoading = false;
      });
    }
  }

  void _showCountrySelectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _LiveTvCountryDialog(
        selectedCountry: _selectedCountry,
        iptvProvider: _iptvProvider,
        onCountrySelected: _selectCountry,
      ),
    );
  }

  void _showLanguageSelectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _LiveTvLanguageDialog(
        selectedLanguages: _selectedLanguages,
        onLanguagesSelected: _selectLanguages,
      ),
    );
  }

  String _getCountryDisplayName(String code) {
    if (code.toUpperCase() == 'ALL') return 'Worldwide';
    final match = IptvProvider.popularCountries.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
      orElse: () => IptvCountry(code: code, name: code, flag: code),
    );
    return match.name;
  }

  String _getLanguageDisplayName(Set<String> codes) {
    if (codes.isEmpty || codes.contains('ALL')) return 'All Languages';
    if (codes.length == 1) {
      final code = codes.first;
      final match = IptvProvider.popularLanguages.firstWhere(
        (l) => l.code.toUpperCase() == code.toUpperCase(),
        orElse: () => IptvLanguage(code: code, name: code, nativeName: code),
      );
      return match.name;
    }
    return '${codes.length} Languages';
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

    final sources = channel.effectiveSources;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          mediaItem: mediaItem,
          streamSource: sources.first,
          availableSources: sources,
        ),
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
      final matchesCountry =
          _selectedCountry == 'ALL' ||
          c.country == null ||
          c.country!.toUpperCase() == _selectedCountry.toUpperCase();
      final matchesCat =
          _selectedCategory == 'All' || c.category == _selectedCategory;
      final matchesSearch =
          _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCountry && matchesCat && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Animated Search Bar (visible only when _isSearchVisible)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              firstCurve: Curves.easeOut,
              secondCurve: Curves.easeIn,
              crossFadeState: _isSearchVisible
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
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
                                alpha: 0.28,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: TextField(
                    focusNode: _searchFocusNode,
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: tokens.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search channels…',
                      hintStyle: TextStyle(color: tokens.textMuted),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: _isSearchFocused
                            ? theme.colorScheme.primary
                            : tokens.textSecondary,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchQuery.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: tokens.textSecondary,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: tokens.textSecondary,
                              size: 18,
                            ),
                            tooltip: 'Close search',
                            onPressed: () {
                              _searchController.clear();
                              _searchFocusNode.unfocus();
                              setState(() {
                                _searchQuery = '';
                                _isSearchVisible = false;
                              });
                            },
                          ),
                        ],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),

            // Category Filter Pills with Country Selector to the Left of ALL
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  // Country Selector Pill (Left of ALL)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TvFocusable(
                      scaleFactor: 1.08,
                      borderRadius: tokens.borderRadiusPill,
                      onTap: _showCountrySelectionDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surfaceElevated,
                          borderRadius: tokens.borderRadiusPill,
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.6,
                            ),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.public_rounded,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _getCountryDisplayName(_selectedCountry),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: tokens.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Language Selector Pill (Between Country and Categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TvFocusable(
                      scaleFactor: 1.08,
                      borderRadius: tokens.borderRadiusPill,
                      onTap: _showLanguageSelectionDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surfaceElevated,
                          borderRadius: tokens.borderRadiusPill,
                          border: Border.all(
                            color: theme.colorScheme.secondary.withValues(
                              alpha: 0.6,
                            ),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.translate_rounded,
                              size: 14,
                              color:
                                  (!_selectedLanguages.contains('ALL') &&
                                      _selectedLanguages.isNotEmpty)
                                  ? theme.colorScheme.secondary
                                  : tokens.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _getLanguageDisplayName(_selectedLanguages),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color:
                                    (!_selectedLanguages.contains('ALL') &&
                                        _selectedLanguages.isNotEmpty)
                                    ? theme.colorScheme.secondary
                                    : tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: tokens.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (categories.isNotEmpty)
                    ...categories.map((cat) {
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
                                  : tokens.surfaceElevated.withValues(
                                      alpha: 0.5,
                                    ),
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
                    }),
                  // Search toggle pill at the end of the filter row
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: TvFocusable(
                      scaleFactor: 1.08,
                      borderRadius: tokens.borderRadiusPill,
                      onTap: () {
                        setState(() => _isSearchVisible = !_isSearchVisible);
                        if (!_isSearchVisible) {
                          _searchController.clear();
                          _searchFocusNode.unfocus();
                          setState(() => _searchQuery = '');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _isSearchVisible || _searchQuery.isNotEmpty
                              ? theme.colorScheme.primary
                              : tokens.surfaceElevated.withValues(alpha: 0.5),
                          borderRadius: tokens.borderRadiusPill,
                          border: Border.all(
                            color: _isSearchVisible || _searchQuery.isNotEmpty
                                ? theme.colorScheme.primary
                                : tokens.borderSubtle,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 14,
                              color: _isSearchVisible || _searchQuery.isNotEmpty
                                  ? theme.colorScheme.onPrimary
                                  : tokens.textSecondary,
                            ),
                            if (_searchQuery.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                _searchQuery,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Channels Counter Bar & D-Pad focusable Refresh
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_selectedCategory Channels Â· ${_getCountryDisplayName(_selectedCountry)} (${filtered.length})',
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

    final cardRadius = tokens.cardRadius;
    final shapeBorder = tokens.getShapeBorder(
      radius: cardRadius,
      side: BorderSide(
        color: isActive ? theme.colorScheme.primary : tokens.borderSubtle,
        width: isActive ? 2.0 : 1.0,
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: TvFocusable(
        scaleFactor: isTv ? 1.06 : 1.03,
        shape: shapeBorder,
        borderRadius: tokens.borderRadiusMd,
        onTap: widget.onTap,
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: tokens.getShapeDecoration(
            color: tokens.surfaceCard,
            radius: cardRadius,
            side: BorderSide(
              color: isActive ? theme.colorScheme.primary : tokens.borderSubtle,
              width: isActive ? 2.0 : 1.0,
            ),
            shadows: isActive
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
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: shapeBorder),
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
                          decoration: tokens.getShapeDecoration(
                            color: tokens.canvasBackground.withValues(
                              alpha: 0.75,
                            ),
                            radius: (tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                            side: BorderSide(
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
                          decoration: tokens.getShapeDecoration(
                            color: tokens.primaryAccent,
                            radius: (tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                            shadows: [
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
                                    decoration: tokens.getShapeDecoration(
                                      color: tokens.surfaceElevated.withValues(
                                        alpha: 0.8,
                                      ),
                                      radius: (tokens.cardRadius * 0.35).clamp(
                                        2.0,
                                        6.0,
                                      ),
                                      side: BorderSide(
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
                                if (c.sources.length > 1) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: tokens.getShapeDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.15),
                                      radius: (tokens.cardRadius * 0.35).clamp(
                                        2.0,
                                        6.0,
                                      ),
                                      side: BorderSide(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.5),
                                        width: 0.6,
                                      ),
                                    ),
                                    child: Text(
                                      '${c.sources.length} SERVERS',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
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

class _LiveTvCountryDialog extends StatefulWidget {
  final String selectedCountry;
  final IptvProvider iptvProvider;
  final ValueChanged<String> onCountrySelected;

  const _LiveTvCountryDialog({
    required this.selectedCountry,
    required this.iptvProvider,
    required this.onCountrySelected,
  });

  @override
  State<_LiveTvCountryDialog> createState() => _LiveTvCountryDialogState();
}

class _LiveTvCountryDialogState extends State<_LiveTvCountryDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<IptvCountry> _allCountries = IptvProvider.popularCountries;
  List<IptvCountry> _filtered = IptvProvider.popularCountries;
  bool _loading = true;
  bool _isSearchOpen = false;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    final list = await widget.iptvProvider.fetchCountries();
    if (mounted) {
      setState(() {
        _allCountries = list;
        _filtered = list;
        _loading = false;
      });
    }
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _allCountries;
      } else {
        _filtered = _allCountries
            .where(
              (c) =>
                  c.name.toLowerCase().contains(q) ||
                  c.code.toLowerCase().contains(q),
            )
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 600;

    return Dialog(
      backgroundColor: tokens.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: tokens.borderRadiusLg,
        side: BorderSide(color: tokens.borderSubtle),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 48,
        vertical: isCompact ? 24 : 36,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: size.height * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.public_rounded,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Select Live TV Country',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Search toggle button in header
                      TvFocusable(
                        scaleFactor: 1.1,
                        borderRadius: tokens.borderRadiusPill,
                        onTap: () {
                          setState(() => _isSearchOpen = !_isSearchOpen);
                          if (!_isSearchOpen) {
                            _searchCtrl.clear();
                            _onSearch('');
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            _isSearchOpen
                                ? Icons.search_off_rounded
                                : Icons.search_rounded,
                            color: _isSearchOpen
                                ? theme.colorScheme.primary
                                : tokens.textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TvFocusable(
                        scaleFactor: 1.1,
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
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Filter channels and search results by broadcast country.',
                style: TextStyle(fontSize: 12, color: tokens.textMuted),
              ),
              // Animated search field
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _isSearchOpen
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: tokens.surfaceCard,
                      borderRadius: tokens.borderRadiusMd,
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      onChanged: _onSearch,
                      style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search countries…',
                        hintStyle: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: tokens.textSecondary,
                          size: 20,
                        ),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear_rounded,
                                  color: tokens.textSecondary,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _onSearch('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                secondChild: const SizedBox(height: 10),
              ),
              // Countries list

              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No matching countries found.',
                          style: TextStyle(color: tokens.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: tokens.borderSubtle.withValues(alpha: 0.5),
                        ),
                        itemBuilder: (context, index) {
                          final c = _filtered[index];
                          final isSelected =
                              c.code.toUpperCase() ==
                              widget.selectedCountry.toUpperCase();
                          return TvFocusable(
                            autofocus: isSelected && index == 0,
                            scaleFactor: 1.03,
                            borderRadius: tokens.borderRadiusSm,
                            onTap: () {
                              widget.onCountrySelected(c.code);
                              Navigator.of(context).pop();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.12,
                                      )
                                    : null,
                                borderRadius: tokens.borderRadiusSm,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    c.code == 'ALL'
                                        ? Icons.public_rounded
                                        : Icons.flag_rounded,
                                    size: 18,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : tokens.textSecondary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      c.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : tokens.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tokens.surfaceCard,
                                      borderRadius: tokens.borderRadiusXs,
                                      border: Border.all(
                                        color: tokens.borderSubtle,
                                      ),
                                    ),
                                    child: Text(
                                      c.code,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: tokens.textMuted,
                                      ),
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 10),
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: theme.colorScheme.primary,
                                      size: 18,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveTvLanguageDialog extends StatefulWidget {
  final Set<String> selectedLanguages;
  final ValueChanged<Set<String>> onLanguagesSelected;

  const _LiveTvLanguageDialog({
    required this.selectedLanguages,
    required this.onLanguagesSelected,
  });

  @override
  State<_LiveTvLanguageDialog> createState() => _LiveTvLanguageDialogState();
}

class _LiveTvLanguageDialogState extends State<_LiveTvLanguageDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<IptvLanguage> _filtered = [];
  late Set<String> _pending;
  bool _isSearchOpen = false;

  @override
  void initState() {
    super.initState();
    _filtered = IptvProvider.popularLanguages;
    _pending = Set<String>.from(widget.selectedLanguages);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = IptvProvider.popularLanguages;
      } else {
        _filtered = IptvProvider.popularLanguages.where((l) {
          return l.name.toLowerCase().contains(q) ||
              l.nativeName.toLowerCase().contains(q) ||
              l.code.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  void _toggle(String code) {
    setState(() {
      if (code == 'ALL') {
        _pending = {'ALL'};
      } else {
        _pending.remove('ALL');
        if (_pending.contains(code)) {
          _pending.remove(code);
          if (_pending.isEmpty) _pending = {'ALL'};
        } else {
          _pending.add(code);
        }
      }
    });
  }

  void _apply() {
    widget.onLanguagesSelected(Set<String>.from(_pending));
    Navigator.of(context).pop();
  }

  void _clear() {
    setState(() => _pending = {'ALL'});
  }

  bool get _isFiltered => !_pending.contains('ALL') && _pending.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final isAllSelected = _pending.contains('ALL') || _pending.isEmpty;

    return Center(
      child: Material(
        color: tokens.canvasBackground.withValues(alpha: 0),
        child: Container(
          width: 500,
          height: 600,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          decoration: tokens.getShapeDecoration(
            color: tokens.surfaceElevated,
            radius: tokens.cardRadius * 1.2,
            side: BorderSide(
              color: theme.colorScheme.secondary.withValues(alpha: 0.5),
              width: 1.5,
            ),
            shadows: tokens.getCardShadows(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(
                        alpha: 0.15,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.translate_rounded,
                      color: theme.colorScheme.secondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Languages',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          'Pick one or more broadcast languages.',
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TvFocusable(
                    borderRadius: tokens.borderRadiusPill,
                    onTap: () {
                      setState(() => _isSearchOpen = !_isSearchOpen);
                      if (!_isSearchOpen) {
                        _searchCtrl.clear();
                        _onSearch('');
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        _isSearchOpen
                            ? Icons.search_off_rounded
                            : Icons.search_rounded,
                        color: _isSearchOpen
                            ? theme.colorScheme.secondary
                            : tokens.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
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
              // ── Animated search field ─────────────────────────────────
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _isSearchOpen
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: tokens.surfaceCard,
                      borderRadius: tokens.borderRadiusMd,
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      onChanged: _onSearch,
                      style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search languages…',
                        hintStyle: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: tokens.textSecondary,
                          size: 20,
                        ),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear_rounded,
                                  color: tokens.textSecondary,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _onSearch('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                secondChild: const SizedBox(height: 8),
              ),
              // ── "All Languages" row ───────────────────────────────────
              TvFocusable(
                autofocus: isAllSelected,
                scaleFactor: 1.03,
                borderRadius: tokens.borderRadiusSm,
                onTap: () => _toggle('ALL'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isAllSelected
                        ? theme.colorScheme.secondary.withValues(alpha: 0.12)
                        : null,
                    borderRadius: tokens.borderRadiusSm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.language_rounded,
                        size: 20,
                        color: isAllSelected
                            ? theme.colorScheme.secondary
                            : tokens.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'All Languages',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isAllSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isAllSelected
                                ? theme.colorScheme.secondary
                                : tokens.textPrimary,
                          ),
                        ),
                      ),
                      _CheckBox(
                        checked: isAllSelected,
                        color: theme.colorScheme.secondary,
                      ),
                    ],
                  ),
                ),
              ),
              Divider(
                height: 8,
                color: tokens.borderSubtle.withValues(alpha: 0.5),
              ),
              // â”€â”€ Language list â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No matching languages found.',
                          style: TextStyle(color: tokens.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: tokens.borderSubtle.withValues(alpha: 0.4),
                        ),
                        itemBuilder: (context, index) {
                          final l = _filtered[index];
                          final isChecked = _pending.contains(
                            l.code.toUpperCase(),
                          );
                          return TvFocusable(
                            scaleFactor: 1.03,
                            borderRadius: tokens.borderRadiusSm,
                            onTap: () => _toggle(l.code),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isChecked
                                    ? theme.colorScheme.secondary.withValues(
                                        alpha: 0.1,
                                      )
                                    : null,
                                borderRadius: tokens.borderRadiusSm,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.translate_rounded,
                                    size: 18,
                                    color: isChecked
                                        ? theme.colorScheme.secondary
                                        : tokens.textSecondary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isChecked
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: isChecked
                                                ? theme.colorScheme.secondary
                                                : tokens.textPrimary,
                                          ),
                                        ),
                                        if (l.nativeName != l.name) ...[
                                          Text(
                                            l.nativeName,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: tokens.textMuted,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tokens.surfaceCard,
                                      borderRadius: tokens.borderRadiusXs,
                                      border: Border.all(
                                        color: tokens.borderSubtle,
                                      ),
                                    ),
                                    child: Text(
                                      l.code,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: tokens.textMuted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _CheckBox(
                                    checked: isChecked,
                                    color: theme.colorScheme.secondary,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              // â”€â”€ Footer: Clear + Apply â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              const SizedBox(height: 10),
              Row(
                children: [
                  if (_isFiltered) ...[
                    TvFocusable(
                      borderRadius: tokens.borderRadiusPill,
                      onTap: _clear,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surfaceCard,
                          borderRadius: tokens.borderRadiusPill,
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.clear_all_rounded,
                              size: 16,
                              color: tokens.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 13,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: TvFocusable(
                      autofocus: !isAllSelected,
                      borderRadius: tokens.borderRadiusPill,
                      onTap: _apply,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary,
                          borderRadius: tokens.borderRadiusPill,
                        ),
                        child: Center(
                          child: Text(
                            _isFiltered
                                ? 'Apply (${_pending.length} selected)'
                                : 'Apply',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSecondary,
                            ),
                          ),
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
    );
  }
}

/// Lightweight checkbox indicator for multi-select language rows.
class _CheckBox extends StatelessWidget {
  final bool checked;
  final Color color;

  const _CheckBox({required this.checked, required this.color});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: checked ? color : tokens.surfaceCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: checked ? color : tokens.borderSubtle,
          width: 1.5,
        ),
      ),
      child: checked
          ? Icon(
              Icons.check_rounded,
              size: 13,
              color: Theme.of(context).colorScheme.onSecondary,
            )
          : null,
    );
  }
}
