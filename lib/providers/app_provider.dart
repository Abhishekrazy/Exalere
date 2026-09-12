import 'dart:async';

import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../services/moviebox_provider.dart';
import '../services/fourkhdhub_provider.dart';
import '../services/storage_service.dart';
import '../services/tmdb_service.dart';
import '../services/tv_service.dart';
import '../services/update_service.dart';
import '../ui/theme/app_themes.dart';

class AppProvider extends ChangeNotifier {
  final MovieBoxProvider _movieBoxProvider = MovieBoxProvider();
  final FourKHdHubProvider _fourKHdHubProvider = FourKHdHubProvider();
  final StorageService _storageService = StorageService();
  final UpdateService _updateService = UpdateService();

  ProviderType _activeProvider = ProviderType.movieBox;
  int _currentThemeIndex = 0;
  CornerStyle _cornerStyle = CornerStyle.rounded;
  SurfaceMorphism _surfaceMorphism = SurfaceMorphism.standard;
  String? _fontFamily;
  bool _useExternalPlayer = false;
  bool _autoSkipIntro = false;
  bool _autoSkipOutro = false;
  bool _enableSmartSkip = true;
  bool _autoPlayTrailers = true;
  bool _filterAdultContent = true;
  bool _backgroundPlayback = false;
  bool _pipEnabled = true;
  bool _isTvMode = false;
  double _uiScale = 1.0;
  bool _autoCheckUpdates = true;
  UpdateInfo? _availableUpdate;
  bool _isCheckingUpdate = false;
  String? _updateCheckError;
  String? _defaultAudioLanguage;
  bool _hasPromptedInitialLanguage = false;

  // TV Settings Navigation Depth
  int _settingsSubpageDepth = 0;
  DateTime _lastSettingsSubpagePopTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Feeds
  List<MediaItem> _featuredFeed = [];
  List<MediaItem> _moviesFeed = [];
  List<MediaItem> _seriesFeed = [];
  List<MediaItem> _popularFeed = [];
  List<MediaItem> _trendingFeed = [];
  List<MediaItem> _horrorFeed = [];
  List<MediaItem> _documentaryFeed = [];
  List<MediaItem> _actionFeed = [];
  List<MediaItem> _comedyFeed = [];
  List<MediaItem> _sciFiFeed = [];
  bool _isLoadingHome = false;

  // Search
  String _searchQuery = '';
  List<MediaItem> _searchResults = [];
  bool _isSearching = false;

  // Getters
  MovieBoxProvider get movieBoxProvider => _movieBoxProvider;
  ProviderType get activeProvider => _activeProvider;
  int get currentThemeIndex => _currentThemeIndex;
  CornerStyle get cornerStyle => _cornerStyle;
  SurfaceMorphism get surfaceMorphism => _surfaceMorphism;
  String? get fontFamily => _fontFamily;
  AppThemeOption get currentTheme {
    final base = AppThemes.allThemes[_currentThemeIndex];
    final updatedTokens = base.tokens.copyWith(
      cornerStyle: _cornerStyle,
      surfaceMorphism: _surfaceMorphism,
      fontFamily: _fontFamily,
    );
    final updatedTheme = base.themeData.copyWith(extensions: [updatedTokens]);
    return AppThemeOption(
      name: base.name,
      primaryColor: base.primaryColor,
      backgroundColor: base.backgroundColor,
      cardColor: base.cardColor,
      tokens: updatedTokens,
      themeData: updatedTheme,
    );
  }

  bool get useExternalPlayer => _useExternalPlayer;
  bool get autoSkipIntro => _autoSkipIntro;
  bool get autoSkipOutro => _autoSkipOutro;
  bool get enableSmartSkip => _enableSmartSkip;
  bool get autoPlayTrailers => _autoPlayTrailers;
  bool get filterAdultContent => _filterAdultContent;
  bool get backgroundPlayback => _backgroundPlayback;
  bool get pipEnabled => _pipEnabled;
  bool get isTvMode => _isTvMode;
  double get uiScale => _uiScale;
  bool get autoCheckUpdates => _autoCheckUpdates;
  UpdateInfo? get availableUpdate => _availableUpdate;
  bool get isCheckingUpdate => _isCheckingUpdate;
  String? get updateCheckError => _updateCheckError;
  String get currentVersion => UpdateService.currentAppVersion;
  String? get defaultAudioLanguage => _defaultAudioLanguage;
  bool get hasPromptedInitialLanguage => _hasPromptedInitialLanguage;

  int get settingsSubpageDepth => _settingsSubpageDepth;
  bool get isSettingsSubpageOpen => _settingsSubpageDepth > 0;
  bool get hadRecentSettingsSubpagePop =>
      DateTime.now().difference(_lastSettingsSubpagePopTime) <
      const Duration(milliseconds: 350);

  void setSettingsSubpageDepth(int depth) {
    if (_settingsSubpageDepth != depth) {
      _settingsSubpageDepth = depth;
      notifyListeners();
    }
  }

  void recordSettingsSubpagePop() {
    _lastSettingsSubpagePopTime = DateTime.now();
  }

  List<MediaItem> get featuredFeed => _featuredFeed;
  List<MediaItem> get moviesFeed => _moviesFeed;
  List<MediaItem> get seriesFeed => _seriesFeed;
  List<MediaItem> get popularFeed => _popularFeed;
  List<MediaItem> get trendingFeed => _trendingFeed;
  List<MediaItem> get horrorFeed => _horrorFeed;
  List<MediaItem> get documentaryFeed => _documentaryFeed;
  List<MediaItem> get actionFeed => _actionFeed;
  List<MediaItem> get comedyFeed => _comedyFeed;
  List<MediaItem> get sciFiFeed => _sciFiFeed;
  bool get isLoadingHome => _isLoadingHome;

  String get searchQuery => _searchQuery;
  List<MediaItem> get searchResults => _searchResults;
  bool get isSearching => _isSearching;

  List<MediaItem> get allCataloguePool {
    final pool = [
      ..._featuredFeed,
      ..._moviesFeed,
      ..._seriesFeed,
      ..._popularFeed,
      ..._trendingFeed,
      ..._horrorFeed,
      ..._documentaryFeed,
      ..._actionFeed,
      ..._comedyFeed,
      ..._sciFiFeed,
    ];
    return _deduplicateResults(pool);
  }

  List<MediaItem> get trendingTitles {
    if (_trendingFeed.isNotEmpty) {
      return _trendingFeed;
    }
    final combined = [..._featuredFeed, ..._moviesFeed, ..._seriesFeed];
    return _deduplicateResults(combined);
  }

  Future<void> init() async {
    _currentThemeIndex = await _storageService.getThemeIndex();
    _useExternalPlayer = await _storageService.getUseExternalPlayer();
    _autoSkipIntro = await _storageService.getAutoSkipIntro();
    _autoSkipOutro = await _storageService.getAutoSkipOutro();
    _enableSmartSkip = await _storageService.getEnableSmartSkip();
    _autoPlayTrailers = await _storageService.getAutoPlayTrailers();
    _filterAdultContent = await _storageService.getFilterAdultContent();
    _backgroundPlayback = await _storageService.getBackgroundPlayback();
    _pipEnabled = await _storageService.getPipEnabled();

    final savedTvMode = await _storageService.getTvMode();
    if (savedTvMode != null) {
      _isTvMode = savedTvMode;
    } else {
      _isTvMode = await TvService.isTvDevice();
    }

    final savedUiScale = await _storageService.getUiScale();
    if (savedUiScale != null) {
      _uiScale = savedUiScale;
    } else {
      // Default to 0.85 (Compact) for TV so 10-foot Leanback displays are clean and spacious
      _uiScale = _isTvMode ? 0.85 : 1.0;
    }

    _autoCheckUpdates = await _storageService.getAutoCheckUpdates();

    final savedCorner = await _storageService.getCornerStyle();
    if (savedCorner != null) {
      _cornerStyle = CornerStyle.values.firstWhere(
        (e) => e.name == savedCorner,
        orElse: () => CornerStyle.rounded,
      );
    }

    final savedMorphism = await _storageService.getSurfaceMorphism();
    if (savedMorphism != null) {
      _surfaceMorphism = SurfaceMorphism.values.firstWhere(
        (e) => e.name == savedMorphism,
        orElse: () => SurfaceMorphism.standard,
      );
    }

    _fontFamily = await _storageService.getFontFamily();
    _defaultAudioLanguage = await _storageService.getDefaultAudioLanguage();
    _hasPromptedInitialLanguage = await _storageService
        .getHasPromptedInitialLanguage();

    notifyListeners();

    // Fast-path bootstrap: unblock runApp and load network feeds in background
    unawaited(_bootstrapBackgroundFeeds());
  }

  Future<void> _bootstrapBackgroundFeeds() async {
    try {
      await _movieBoxProvider.init();
      await loadHomeFeeds();
      if (_autoCheckUpdates) {
        Future.microtask(() => checkForUpdates(manual: false));
      }
    } catch (e) {
      debugPrint('Error bootstrapping background feeds: $e');
    }
  }

  Future<UpdateInfo?> checkForUpdates({bool manual = false}) async {
    if (_isCheckingUpdate) return _availableUpdate;
    _isCheckingUpdate = true;
    _updateCheckError = null;
    notifyListeners();

    try {
      final info = await _updateService.checkLatestRelease(isTv: _isTvMode);
      if (info != null && info.isUpdateAvailable) {
        _availableUpdate = info;
      } else {
        _availableUpdate = null;
      }
      await _storageService.setLastUpdateCheckTime(DateTime.now());
      _isCheckingUpdate = false;
      notifyListeners();
      return info;
    } catch (e) {
      _updateCheckError = e.toString();
      _isCheckingUpdate = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> setAutoCheckUpdates(bool value) async {
    _autoCheckUpdates = value;
    await _storageService.setAutoCheckUpdates(value);
    notifyListeners();
    if (value) {
      checkForUpdates(manual: true);
    }
  }

  Future<void> setTvMode(bool value) async {
    _isTvMode = value;
    TvService.setOverride(value);
    await _storageService.setTvMode(value);
    // If no custom scale has been set yet, adjust default scale for the mode
    final savedUiScale = await _storageService.getUiScale();
    if (savedUiScale == null) {
      _uiScale = value ? 0.85 : 1.0;
    }
    notifyListeners();
  }

  Future<void> setUiScale(double value) async {
    _uiScale = value;
    await _storageService.setUiScale(value);
    notifyListeners();
  }

  void setActiveProvider(ProviderType provider) {
    if (_activeProvider == provider) return;
    _activeProvider = provider;
    notifyListeners();
    if (_searchQuery.isNotEmpty) {
      search(_searchQuery);
    }
  }

  Future<void> setThemeIndex(int index) async {
    if (index >= 0 && index < AppThemes.allThemes.length) {
      _currentThemeIndex = index;
      await _storageService.setThemeIndex(index);
      notifyListeners();
    }
  }

  Future<void> setCornerStyle(CornerStyle style) async {
    _cornerStyle = style;
    await _storageService.setCornerStyle(style.name);
    notifyListeners();
  }

  Future<void> setSurfaceMorphism(SurfaceMorphism morphism) async {
    _surfaceMorphism = morphism;
    await _storageService.setSurfaceMorphism(morphism.name);
    notifyListeners();
  }

  Future<void> setFontFamily(String? family) async {
    _fontFamily = family;
    await _storageService.setFontFamily(family);
    notifyListeners();
  }

  Future<void> setUseExternalPlayer(bool value) async {
    _useExternalPlayer = value;
    await _storageService.setUseExternalPlayer(value);
    notifyListeners();
  }

  Future<void> setAutoSkipIntro(bool value) async {
    _autoSkipIntro = value;
    await _storageService.setAutoSkipIntro(value);
    notifyListeners();
  }

  Future<void> setAutoSkipOutro(bool value) async {
    _autoSkipOutro = value;
    await _storageService.setAutoSkipOutro(value);
    notifyListeners();
  }

  Future<void> setEnableSmartSkip(bool value) async {
    _enableSmartSkip = value;
    await _storageService.setEnableSmartSkip(value);
    notifyListeners();
  }

  Future<void> setAutoPlayTrailers(bool value) async {
    _autoPlayTrailers = value;
    await _storageService.setAutoPlayTrailers(value);
    notifyListeners();
  }

  Future<void> setFilterAdultContent(bool value) async {
    _filterAdultContent = value;
    await _storageService.setFilterAdultContent(value);
    if (_searchQuery.isNotEmpty) {
      search(_searchQuery);
    } else {
      loadHomeFeeds();
    }
    notifyListeners();
  }

  Future<void> setBackgroundPlayback(bool value) async {
    _backgroundPlayback = value;
    await _storageService.setBackgroundPlayback(value);
    notifyListeners();
  }

  Future<void> setPipEnabled(bool value) async {
    _pipEnabled = value;
    await _storageService.setPipEnabled(value);
    notifyListeners();
  }

  Future<void> setDefaultAudioLanguage(String? language) async {
    _defaultAudioLanguage = language;
    await _storageService.setDefaultAudioLanguage(language);
    notifyListeners();
  }

  Future<void> setHasPromptedInitialLanguage(bool value) async {
    _hasPromptedInitialLanguage = value;
    await _storageService.setHasPromptedInitialLanguage(value);
    notifyListeners();
  }

  Future<void> loadHomeFeeds() async {
    _isLoadingHome = true;
    notifyListeners();

    try {
      // On TV mode, fetch only page 1 for the 3 tabs initially to prevent
      // network socket exhaustion, CPU locks from JSON parsing, and memory heap spikes.
      final results = await Future.wait([
        _movieBoxProvider.getHomepageFeed(tabId: '0', page: 1),
        _movieBoxProvider.getHomepageFeed(tabId: '1', page: 1),
        _movieBoxProvider.getHomepageFeed(tabId: '2', page: 1),
        if (!_isTvMode) ...[
          _movieBoxProvider.getHomepageFeed(tabId: '0', page: 2),
          _movieBoxProvider.getHomepageFeed(tabId: '1', page: 2),
          _movieBoxProvider.getHomepageFeed(tabId: '2', page: 2),
        ],
      ]);

      final allFeatured = _deduplicateResults([
        ...results[0],
        if (!_isTvMode && results.length > 3) ...results[3],
      ]);
      final allMovies = _deduplicateResults([
        ...results[1],
        if (!_isTvMode && results.length > 4) ...results[4],
      ]);
      final allSeries = _deduplicateResults([
        ...results[2],
        if (!_isTvMode && results.length > 5) ...results[5],
      ]);

      _featuredFeed = _filterAdultContent
          ? allFeatured.where(_isSafeContent).toList()
          : allFeatured;
      _moviesFeed = _filterAdultContent
          ? allMovies.where(_isSafeContent).toList()
          : allMovies;
      _seriesFeed = _filterAdultContent
          ? allSeries.where(_isSafeContent).toList()
          : allSeries;

      // 1. Trending: hot featured titles beyond billboard + prominent movies & series
      final trendingCandidates = [
        ..._featuredFeed.skip(8),
        ..._moviesFeed.take(15),
        ..._seriesFeed.take(15),
      ];
      _trendingFeed = _deduplicateResults(trendingCandidates);

      // 2. Popular: High-rated items across catalog sorted by rating descending
      final popularCandidates = [
        ..._moviesFeed,
        ..._seriesFeed,
        ..._featuredFeed,
      ];
      final ratedItems =
          popularCandidates
              .where((i) => i.rating != null && i.rating! >= 6.5)
              .toList()
            ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      _popularFeed = _deduplicateResults(
        ratedItems.isNotEmpty ? ratedItems : popularCandidates,
      );

      // 3. Populate initial genre shelves from loaded catalogue
      final catalogue = allCataloguePool;
      _horrorFeed = _deduplicateResults(
        catalogue.where((i) => i.matchesCategory('horror')).toList(),
      );
      _documentaryFeed = _deduplicateResults(
        catalogue.where((i) => i.matchesCategory('documentary')).toList(),
      );
      _actionFeed = _deduplicateResults(
        catalogue.where((i) => i.matchesCategory('action')).toList(),
      );
      _comedyFeed = _deduplicateResults(
        catalogue.where((i) => i.matchesCategory('comedy')).toList(),
      );
      _sciFiFeed = _deduplicateResults(
        catalogue.where((i) => i.matchesCategory('sci-fi')).toList(),
      );
    } catch (e) {
      debugPrint('Error in loadHomeFeeds: $e');
    } finally {
      _isLoadingHome = false;
      notifyListeners();
    }

    // Asynchronously enrich hero billboard backdrops and genre shelves with targeted discovery
    _enrichFeaturedBackdrops();
    _enrichGenreShelves();
  }

  Future<void> _enrichGenreShelves() async {
    // Skip heavy concurrent network searches on TV to eliminate CPU spikes and memory exhaustion.
    // The genre shelves are already populated instantly from the loaded catalogue pool.
    if (_isTvMode) return;

    try {
      final genreSearches = await Future.wait([
        _movieBoxProvider.search('horror').catchError((_) => <MediaItem>[]),
        _movieBoxProvider
            .search('documentary')
            .catchError((_) => <MediaItem>[]),
        _movieBoxProvider.search('action').catchError((_) => <MediaItem>[]),
        _movieBoxProvider.search('comedy').catchError((_) => <MediaItem>[]),
        _movieBoxProvider.search('sci-fi').catchError((_) => <MediaItem>[]),
      ]);

      bool hasUpdates = false;

      final newHorror = _deduplicateResults([
        ..._horrorFeed,
        ...genreSearches[0],
      ]);
      if (newHorror.length != _horrorFeed.length) {
        _horrorFeed = _filterAdultContent
            ? newHorror.where(_isSafeContent).toList()
            : newHorror;
        hasUpdates = true;
      }

      final newDocu = _deduplicateResults([
        ..._documentaryFeed,
        ...genreSearches[1],
      ]);
      if (newDocu.length != _documentaryFeed.length) {
        _documentaryFeed = _filterAdultContent
            ? newDocu.where(_isSafeContent).toList()
            : newDocu;
        hasUpdates = true;
      }

      final newAction = _deduplicateResults([
        ..._actionFeed,
        ...genreSearches[2],
      ]);
      if (newAction.length != _actionFeed.length) {
        _actionFeed = _filterAdultContent
            ? newAction.where(_isSafeContent).toList()
            : newAction;
        hasUpdates = true;
      }

      final newComedy = _deduplicateResults([
        ..._comedyFeed,
        ...genreSearches[3],
      ]);
      if (newComedy.length != _comedyFeed.length) {
        _comedyFeed = _filterAdultContent
            ? newComedy.where(_isSafeContent).toList()
            : newComedy;
        hasUpdates = true;
      }

      final newSciFi = _deduplicateResults([
        ..._sciFiFeed,
        ...genreSearches[4],
      ]);
      if (newSciFi.length != _sciFiFeed.length) {
        _sciFiFeed = _filterAdultContent
            ? newSciFi.where(_isSafeContent).toList()
            : newSciFi;
        hasUpdates = true;
      }

      if (hasUpdates) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error in _enrichGenreShelves: $e');
    }
  }

  Future<void> _enrichFeaturedBackdrops() async {
    if (_featuredFeed.isEmpty) return;
    try {
      final tmdb = TmdbService();
      final maxEnrich = _isTvMode ? 2 : 8;
      final itemsToEnrich = _featuredFeed.take(maxEnrich).toList();
      bool anyUpdated = false;

      for (final item in itemsToEnrich) {
        if (_isTvMode) {
          await Future.delayed(const Duration(milliseconds: 350));
        }
        try {
          final enriched = await tmdb.getEnrichedDetails(
            title: item.title,
            year: item.year,
            isSeries: item.isSeries,
          );

          if (enriched?.backdropUrl != null &&
              enriched!.backdropUrl!.isNotEmpty) {
            final idx = _featuredFeed.indexWhere((e) => e.id == item.id);
            if (idx != -1 &&
                _featuredFeed[idx].backdropUrl != enriched.backdropUrl) {
              _featuredFeed[idx] = _featuredFeed[idx].copyWith(
                backdropUrl: enriched.backdropUrl,
              );
              anyUpdated = true;
            }
          }
        } catch (e) {
          debugPrint('Failed backdrop enrichment for ${item.title}: $e');
        }
      }

      if (anyUpdated) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error in _enrichFeaturedBackdrops: $e');
    }
  }

  static final RegExp _adultRegex = RegExp(
    r'\b(xxx|porn|erotic|sex|nsfw|nude|18\+|hentai|sensual|erotica|adult|camrip|anime edition|uncensored|smut|r18|r-18)\b',
    caseSensitive: false,
  );

  String _normalizeTitle(String title) {
    return title
        .toLowerCase()
        .replaceAll(
          RegExp(
            r'\[.*?\]|\(.*?\)|4k|uhd|hdr|1080p|720p|dual audio|bluray|webrip|hevc|x264|x265',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }

  bool _isSafeContent(MediaItem item) {
    if (!_filterAdultContent) return true;
    if (item.isAdult) return false;
    if (_adultRegex.hasMatch(item.title)) return false;
    if (item.genre != null && _adultRegex.hasMatch(item.genre!)) return false;
    return true;
  }

  List<MediaItem> _deduplicateResults(List<MediaItem> rawList) {
    final Map<String, MediaItem> seen = {};
    for (final item in rawList) {
      if (!_isSafeContent(item)) continue;
      final key = _normalizeTitle(item.title);
      if (key.isEmpty) continue;

      if (!seen.containsKey(key)) {
        seen[key] = item;
      } else {
        final existing = seen[key]!;
        if ((existing.posterUrl == null || existing.posterUrl!.isEmpty) &&
            (item.posterUrl != null && item.posterUrl!.isNotEmpty)) {
          seen[key] = item;
        } else if (item.provider == ProviderType.fourKHdHub &&
            (existing.provider != ProviderType.fourKHdHub &&
                item.title.contains('4K'))) {
          seen[key] = item;
        }
      }
    }
    return seen.values.toList();
  }

  Future<void> search(String query) async {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      // Scan both MovieBox and 4KHDHub simultaneously
      final results = await Future.wait([
        _movieBoxProvider.search(query).catchError((e) {
          debugPrint('MovieBox search error: $e');
          return <MediaItem>[];
        }),
        _fourKHdHubProvider.search(query).catchError((e) {
          debugPrint('4KHDHub search error: $e');
          return <MediaItem>[];
        }),
      ]);

      final combined = [...results[0], ...results[1]];
      _searchResults = _deduplicateResults(combined);
    } catch (e) {
      debugPrint('Unified search error: $e');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> searchCategory(String genre) async {
    _searchQuery = genre;
    _isSearching = true;
    notifyListeners();

    debugPrint('searchCategory started for: $genre');
    try {
      // 1. Immediately extract matching items from all loaded home feeds
      final allLocal = [..._featuredFeed, ..._moviesFeed, ..._seriesFeed];
      final localMatches = allLocal
          .where((item) => item.matchesCategory(genre))
          .toList();

      // 2. Concurrently search providers for the category / keyword
      final results = await Future.wait([
        _movieBoxProvider.search(genre).catchError((e) {
          debugPrint('MovieBox searchCategory error: $e');
          return <MediaItem>[];
        }),
        _fourKHdHubProvider.search(genre).catchError((e) {
          debugPrint('4KHDHub searchCategory error: $e');
          return <MediaItem>[];
        }),
      ]);

      // 3. Combine local catalog matches + provider search results
      final combined = [...localMatches, ...results[0], ...results[1]];
      debugPrint(
        'searchCategory raw items: ${combined.length} (Local: ${localMatches.length}, MB: ${results[0].length}, 4K: ${results[1].length})',
      );
      _searchResults = _deduplicateResults(combined);
      debugPrint('searchCategory deduplicated items: ${_searchResults.length}');
    } catch (e) {
      debugPrint('searchCategory error: $e');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    _isSearching = false;
    notifyListeners();
  }
}
