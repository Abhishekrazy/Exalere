import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/moviebox_provider.dart';
import '../services/fourkhdhub_provider.dart';
import '../services/storage_service.dart';
import '../services/tmdb_service.dart';
import '../services/tv_service.dart';
import '../ui/theme/app_themes.dart';

class AppProvider extends ChangeNotifier {
  final MovieBoxProvider _movieBoxProvider = MovieBoxProvider();
  final FourKHdHubProvider _fourKHdHubProvider = FourKHdHubProvider();
  final StorageService _storageService = StorageService();

  ProviderType _activeProvider = ProviderType.movieBox;
  int _currentThemeIndex = 0;
  bool _useExternalPlayer = false;
  bool _autoSkipIntro = false;
  bool _autoSkipOutro = false;
  bool _enableSmartSkip = true;
  bool _autoPlayTrailers = true;
  bool _isTvMode = false;

  // Feeds
  List<MediaItem> _featuredFeed = [];
  List<MediaItem> _moviesFeed = [];
  List<MediaItem> _seriesFeed = [];
  bool _isLoadingHome = false;

  // Search
  String _searchQuery = '';
  List<MediaItem> _searchResults = [];
  bool _isSearching = false;

  // Getters
  ProviderType get activeProvider => _activeProvider;
  int get currentThemeIndex => _currentThemeIndex;
  AppThemeOption get currentTheme => AppThemes.allThemes[_currentThemeIndex];
  bool get useExternalPlayer => _useExternalPlayer;
  bool get autoSkipIntro => _autoSkipIntro;
  bool get autoSkipOutro => _autoSkipOutro;
  bool get enableSmartSkip => _enableSmartSkip;
  bool get autoPlayTrailers => _autoPlayTrailers;
  bool get isTvMode => _isTvMode;

  List<MediaItem> get featuredFeed => _featuredFeed;
  List<MediaItem> get moviesFeed => _moviesFeed;
  List<MediaItem> get seriesFeed => _seriesFeed;
  bool get isLoadingHome => _isLoadingHome;

  String get searchQuery => _searchQuery;
  List<MediaItem> get searchResults => _searchResults;
  bool get isSearching => _isSearching;

  Future<void> init() async {
    _currentThemeIndex = await _storageService.getThemeIndex();
    _useExternalPlayer = await _storageService.getUseExternalPlayer();
    _autoSkipIntro = await _storageService.getAutoSkipIntro();
    _autoSkipOutro = await _storageService.getAutoSkipOutro();
    _enableSmartSkip = await _storageService.getEnableSmartSkip();
    _autoPlayTrailers = await _storageService.getAutoPlayTrailers();

    final savedTvMode = await _storageService.getTvMode();
    if (savedTvMode != null) {
      _isTvMode = savedTvMode;
    } else {
      _isTvMode = await TvService.isTvDevice();
    }

    notifyListeners();

    await _movieBoxProvider.init();
    await loadHomeFeeds();
  }

  Future<void> setTvMode(bool value) async {
    _isTvMode = value;
    TvService.setOverride(value);
    await _storageService.setTvMode(value);
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

  Future<void> loadHomeFeeds() async {
    _isLoadingHome = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _movieBoxProvider.getHomepageFeed(tabId: '0'), // Featured
        _movieBoxProvider.getHomepageFeed(tabId: '1'), // Movies
        _movieBoxProvider.getHomepageFeed(tabId: '2'), // Series
      ]);

      _featuredFeed = results[0];
      _moviesFeed = results[1];
      _seriesFeed = results[2];
    } catch (e) {
      debugPrint('Error in loadHomeFeeds: $e');
    } finally {
      _isLoadingHome = false;
      notifyListeners();
    }

    // Asynchronously enrich hero billboard backdrops with TMDB high-res images
    _enrichFeaturedBackdrops();
  }

  Future<void> _enrichFeaturedBackdrops() async {
    if (_featuredFeed.isEmpty) return;
    try {
      final tmdb = TmdbService();
      final itemsToEnrich = _featuredFeed.take(8).toList();
      bool anyUpdated = false;

      for (final item in itemsToEnrich) {
        try {
          final enriched = await tmdb.getEnrichedDetails(
            title: item.title,
            year: item.year,
            isSeries: item.isSeries,
          );

          if (enriched?.backdropUrl != null && enriched!.backdropUrl!.isNotEmpty) {
            final idx = _featuredFeed.indexWhere((e) => e.id == item.id);
            if (idx != -1 && _featuredFeed[idx].backdropUrl != enriched.backdropUrl) {
              _featuredFeed[idx] = _featuredFeed[idx].copyWith(backdropUrl: enriched.backdropUrl);
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
    r'\b(xxx|porn|erotic|sex|nsfw|nude|18\+|hentai|sensual|erotica|adult|camrip)\b',
    caseSensitive: false,
  );

  String _normalizeTitle(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'\[.*?\]|\(.*?\)|4k|uhd|hdr|1080p|720p|dual audio|bluray|webrip|hevc|x264|x265', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }

  bool _isSafeContent(MediaItem item) {
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
            (existing.provider != ProviderType.fourKHdHub && item.title.contains('4K'))) {
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

      final combined = [...results[0], ...results[1]];
      debugPrint('searchCategory raw items: ${combined.length} (MB: ${results[0].length}, 4K: ${results[1].length})');
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
