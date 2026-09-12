import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/live_channel.dart';
import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../../services/external_player_service.dart';
import '../../services/iptv_provider.dart';
import '../../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/tv_focusable.dart';
import 'live_tv/live_channel_card.dart';
import 'live_tv/live_tv_category_dialog.dart';
import 'live_tv/live_tv_country_dialog.dart';
import 'live_tv/live_tv_filter_bar.dart';
import 'live_tv/live_tv_language_dialog.dart';
import 'player_screen.dart';

export 'live_tv/live_channel_card.dart';

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
      builder: (ctx) => LiveTvCountryDialog(
        selectedCountry: _selectedCountry,
        iptvProvider: _iptvProvider,
        onCountrySelected: _selectCountry,
      ),
    );
  }

  void _showLanguageSelectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => LiveTvLanguageDialog(
        selectedLanguages: _selectedLanguages,
        onLanguagesSelected: _selectLanguages,
      ),
    );
  }

  void _showCategorySelectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => LiveTvCategoryDialog(
        categories: _iptvProvider.categories,
        selectedCategory: _selectedCategory,
        onCategorySelected: (cat) {
          if (_selectedCategory != cat) {
            setState(() => _selectedCategory = cat);
          }
        },
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isPortrait = screenHeight > screenWidth;

    bool isTv = false;
    try {
      isTv = context.watch<AppProvider>().isTvMode;
    } catch (_) {}

    // TV interface: compact cards, more per row (4 to 6 per line)
    // Mobile / Tablet:
    // - Portrait mode: 2 columns so cards fit comfortably without overflowing
    // - Landscape / Tablet / Desktop: 3 to 5 columns depending on width
    final crossAxisCount = isTv
        ? (screenWidth >= 1200 ? 6 : (screenWidth >= 760 ? 5 : 4))
        : (isPortrait
              ? (screenWidth >= 600 ? 3 : 2)
              : (screenWidth >= 1250 ? 5 : (screenWidth >= 850 ? 4 : 3)));

    final childAspectRatio = isTv ? 1.30 : (isPortrait ? 1.15 : 1.32);

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

            // Filter Icon Buttons Row (Country, Language, Category, Search)
            LiveTvFilterBar(
              selectedCountry: _selectedCountry,
              countryDisplayName: _getCountryDisplayName(_selectedCountry),
              selectedLanguages: _selectedLanguages,
              languageDisplayName: _getLanguageDisplayName(_selectedLanguages),
              selectedCategory: _selectedCategory,
              isSearchVisible: _isSearchVisible,
              hasSearchQuery: _searchQuery.isNotEmpty,
              onCountryTap: _showCountrySelectionDialog,
              onLanguageTap: _showLanguageSelectionDialog,
              onCategoryTap: _showCategorySelectionDialog,
              onSearchToggle: () {
                setState(() => _isSearchVisible = !_isSearchVisible);
                if (!_isSearchVisible) {
                  _searchController.clear();
                  _searchFocusNode.unfocus();
                  setState(() => _searchQuery = '');
                }
              },
            ),

            // Channels Counter Bar & D-Pad focusable Refresh
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_selectedCategory Channels • ${_getCountryDisplayName(_selectedCountry)} (${filtered.length})',
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
