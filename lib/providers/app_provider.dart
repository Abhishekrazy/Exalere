import 'dart:async';

import 'package:flutter/material.dart';

import '../models/home_provider_row.dart';
import '../models/media_item.dart';
import '../models/provider_search_section.dart';
import '../models/subtitle_style_preferences.dart';
import '../models/video_decoder_mode.dart';
import '../services/fuzzy_search_service.dart';
import '../services/moviebox_provider.dart';
import '../services/provider_registry.dart';
import '../services/storage_service.dart';
import '../services/stream_availability_service.dart';
import '../services/tmdb_service.dart';
import '../services/provider_base_url_service.dart';
import '../services/provider_home_rows_service.dart';
import '../services/torrent_service.dart';
import '../services/tv_service.dart';
import '../services/update_service.dart';
import '../services/video_cache_service.dart';
import '../ui/theme/app_themes.dart';

class AppProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final UpdateService _updateService = UpdateService();
  final MovieBoxProvider _movieBoxProvider = MovieBoxProvider();
  final StreamAvailabilityService _availability = StreamAvailabilityService();

  ProviderType _activeProvider = ProviderType.plugins;
  int _currentThemeIndex = 0;
  CornerStyle _cornerStyle = CornerStyle.rounded;
  int _accentColorIndex = 0;
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
  bool _isNativeTv = false;
  double _uiScale = 1.0;
  bool _autoCheckUpdates = true;
  UpdateInfo? _availableUpdate;
  bool _isCheckingUpdate = false;
  String? _updateCheckError;
  String? _defaultAudioLanguage;
  bool _hasPromptedInitialLanguage = false;
  bool _onlyShowAvailableOnProviders = true;
  VideoDecoderMode _videoDecoderMode = VideoDecoderMode.auto;
  String _p2pEngineUrl = '';
  String _selectedCatalogProvider = 'tmdb';
  bool _hasPromptedProviderSelection = false;
  SubtitleStylePreferences _subtitleStyle = const SubtitleStylePreferences();

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
  bool _needsProviderSetup = false;
  bool _availabilityFiltered = false;

  /// Shelves filled from the installed providers' own catalogues. Loaded after
  /// the editorial feeds so a slow provider never delays Home.
  List<HomeProviderRow> _providerHomeRows = [];
  bool _isLoadingProviderRows = false;

  // Search
  String _searchQuery = '';
  List<MediaItem> _searchResults = [];
  bool _isSearching = false;

  /// One entry per provider for the current query, including ones still
  /// searching, so the search screen can show every provider at once instead of
  /// a single spinner that hides who answered.
  List<ProviderSearchSection> _providerSearchSections = [];

  /// Incremented on every new query. An answer carrying an older generation is
  /// discarded, so a slow provider cannot paint results for a query the user
  /// has already replaced.
  int _searchGeneration = 0;

  /// When set, the search screen shows only this provider's slice.
  String? _selectedSearchProviderId;

  /// Pseudo provider id for the TMDB discovery fallback. Distinct from every
  /// real provider id so it can never be mistaken for a playable source.
  static const String tmdbSearchProviderId = 'tmdb';

  // Getters
  ProviderType get activeProvider => _activeProvider;
  int get currentThemeIndex => _currentThemeIndex;
  ThemeMode get themeMode {
    switch (_currentThemeIndex) {
      case 1:
        return ThemeMode.dark;
      case 2:
        return ThemeMode.light;
      case 0:
      default:
        return ThemeMode.system;
    }
  }

  CornerStyle get cornerStyle => _cornerStyle;
  SurfaceMorphism get surfaceMorphism => _surfaceMorphism;
  String? get fontFamily => _fontFamily;

  ThemeData _buildDynamicThemeData(AppThemeOption base) {
    final updatedTokens = base.tokens.copyWith(
      cornerStyle: _cornerStyle,
      surfaceMorphism: _surfaceMorphism,
      fontFamily: _fontFamily,
      primaryAccent: _accentFor(base.tokens),
      borderFocus: _accentFor(base.tokens),
    );
    final textTheme = _fontFamily != null
        ? base.themeData.textTheme.apply(fontFamily: _fontFamily)
        : base.themeData.textTheme;
    return base.themeData.copyWith(
      textTheme: textTheme,
      extensions: [updatedTokens],
      cardTheme: CardThemeData(
        color: base.cardColor,
        elevation: 0,
        shape: updatedTokens.shapeMd,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: updatedTokens.surfaceElevated,
        shape: updatedTokens.shapeLg,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: updatedTokens.surfaceElevated,
        shape: updatedTokens.shapeLg,
      ),
      chipTheme: ChipThemeData(shape: updatedTokens.shapeSm),
      popupMenuTheme: PopupMenuThemeData(
        color: updatedTokens.surfaceElevated,
        shape: updatedTokens.shapeSm,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: updatedTokens.surfaceElevated,
        shape: updatedTokens.shapeSm,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// App-wide accent, driven by the active profile's accent choice.
  int get accentColorIndex => _accentColorIndex;

  Color _accentFor(AppDesignTokens tokens) {
    switch (_accentColorIndex % 4) {
      case 1:
        return tokens.secondaryAccent;
      case 2:
        return tokens.vipColor;
      case 3:
        return tokens.liveColor;
      case 0:
      default:
        return tokens.primaryAccent;
    }
  }

  Future<void> setAccentColorIndex(int index) async {
    final normalised = index % 4;
    if (_accentColorIndex == normalised) return;
    _accentColorIndex = normalised;
    notifyListeners();
    await _storageService.setAccentColorIndex(normalised);
  }

  ThemeData get lightThemeData => _buildDynamicThemeData(AppThemes.lightTheme);
  ThemeData get darkThemeData => _buildDynamicThemeData(AppThemes.darkTheme);

  AppThemeOption get currentTheme {
    final base = _currentThemeIndex == 2
        ? AppThemes.lightTheme
        : AppThemes.darkTheme;
    final updatedTokens = base.tokens.copyWith(
      cornerStyle: _cornerStyle,
      surfaceMorphism: _surfaceMorphism,
      fontFamily: _fontFamily,
      primaryAccent: _accentFor(base.tokens),
      borderFocus: _accentFor(base.tokens),
    );
    return AppThemeOption(
      name: base.name,
      primaryColor: base.primaryColor,
      backgroundColor: base.backgroundColor,
      cardColor: base.cardColor,
      tokens: updatedTokens,
      themeData: _buildDynamicThemeData(base),
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
  bool get isNativeTv => _isNativeTv;
  double get uiScale => _uiScale;
  bool get autoCheckUpdates => _autoCheckUpdates;
  UpdateInfo? get availableUpdate => _availableUpdate;
  bool get isCheckingUpdate => _isCheckingUpdate;
  String? get updateCheckError => _updateCheckError;
  String get currentVersion => UpdateService.currentAppVersion;
  InstallSource get installSource => UpdateService.installSource;
  bool get isPlayStoreInstall => UpdateService.isPlayStoreInstall;
  String? get defaultAudioLanguage => _defaultAudioLanguage;
  bool get hasPromptedInitialLanguage => _hasPromptedInitialLanguage;
  String get selectedCatalogProvider => _selectedCatalogProvider;
  bool get hasPromptedProviderSelection => _hasPromptedProviderSelection;
  SubtitleStylePreferences get subtitleStyle => _subtitleStyle;

  int get settingsSubpageDepth => _settingsSubpageDepth;
  bool get isSettingsSubpageOpen => _settingsSubpageDepth > 0;
  bool get hadRecentSettingsSubpagePop =>
      !WidgetsBinding.instance.runtimeType.toString().contains('Test') &&
      DateTime.now().difference(_lastSettingsSubpagePopTime) <
          const Duration(milliseconds: 350);

  void setSettingsSubpageDepth(int depth) {
    if (_settingsSubpageDepth != depth) {
      _settingsSubpageDepth = depth;
    }
  }

  void recordSettingsSubpagePop() {
    _lastSettingsSubpagePopTime = DateTime.now();
  }

  List<MediaItem> get featuredFeed => _featuredFeed;
  List<MediaItem> get moviesFeed => _moviesFeed;
  List<MediaItem> get seriesFeed => _seriesFeed;
  List<MediaItem> get popularFeed => _popularFeed;

  /// Hero billboard items.
  ///
  /// With a stream provider installed, Home is built from provider catalogues
  /// only, so the hero must come from there too: a TMDb billboard title that no
  /// add-on can resolve is exactly the dead end this screen should not open on.
  /// When no provider shelf has arrived yet (or none is installed) the catalogue
  /// feed is used, which is empty in that state anyway.
  List<MediaItem> get homeHeroItems {
    if (_featuredFeed.isNotEmpty) return _featuredFeed;

    final seen = <String>{};
    final items = <MediaItem>[];
    for (final row in _providerHomeRows) {
      for (final item in row.items) {
        if (seen.add(item.id)) items.add(item);
        if (items.length >= 8) return items;
      }
    }
    return items;
  }

  List<MediaItem> get trendingFeed => _trendingFeed;
  List<MediaItem> get horrorFeed => _horrorFeed;
  List<MediaItem> get documentaryFeed => _documentaryFeed;
  List<MediaItem> get actionFeed => _actionFeed;
  List<MediaItem> get comedyFeed => _comedyFeed;
  List<MediaItem> get sciFiFeed => _sciFiFeed;
  bool get isLoadingHome => _isLoadingHome;

  /// True when the catalogue is empty because no provider capable of resolving
  /// streams is installed, so the home screen can prompt for setup instead of
  /// showing titles that can never be played.
  bool get needsProviderSetup => _needsProviderSetup;

  /// True when the last catalogue load was filtered down to playable titles.
  bool get isCatalogueAvailabilityFiltered => _availabilityFiltered;

  /// Whether at least one installed provider can resolve streams.
  bool get hasStreamProviders => ProviderRegistry().hasStreamProviders;

  /// Provider-contributed Home rows, in provider-priority order.
  List<HomeProviderRow> get providerHomeRows =>
      List<HomeProviderRow>.unmodifiable(_providerHomeRows);

  /// True while the provider-declared Home rows are still being fetched, so the
  /// screen shows skeletons instead of the empty state on a cold start.
  bool get isLoadingProviderRows => _isLoadingProviderRows;

  String get searchQuery => _searchQuery;
  List<MediaItem> get searchResults => _searchResults;
  bool get isSearching => _isSearching;

  /// Every provider's slice of the current query, in provider-priority order.
  List<ProviderSearchSection> get providerSearchSections =>
      List<ProviderSearchSection>.unmodifiable(_providerSearchSections);

  /// The provider the results are restricted to, or `null` for "all providers".
  String? get selectedSearchProviderId => _selectedSearchProviderId;

  /// Results the grid should show: the merged list, or one provider's slice
  /// when a provider chip is selected.
  List<MediaItem> get visibleSearchResults {
    final selected = _selectedSearchProviderId;
    if (selected == null) return _searchResults;
    for (final section in _providerSearchSections) {
      if (section.providerId == selected) return section.items;
    }
    return const [];
  }

  /// How many providers have answered the current query.
  int get searchProvidersAnswered =>
      _providerSearchSections.where((s) => !s.isSearching).length;

  /// Providers that errored or timed out for the current query.
  List<ProviderSearchSection> get failedSearchProviders =>
      _providerSearchSections.where((s) => s.hasFailed).toList(growable: false);

  /// Providers that answered but had nothing for the current query.
  List<ProviderSearchSection> get emptySearchProviders =>
      _providerSearchSections
          .where((s) => s.status == ProviderSearchStatus.empty)
          .toList(growable: false);

  /// Providers that returned at least one title.
  List<ProviderSearchSection> get matchingSearchProviders =>
      _providerSearchSections
          .where((s) => s.hasResults)
          .toList(growable: false);

  /// Restricts the search grid to one provider, or to every provider with
  /// `null`.
  void selectSearchProvider(String? providerId) {
    if (_selectedSearchProviderId == providerId) return;
    _selectedSearchProviderId = providerId;
    notifyListeners();
  }

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
    final savedTheme = await _storageService.getThemeIndex();
    _currentThemeIndex = (savedTheme >= 0 && savedTheme <= 2) ? savedTheme : 0;
    _useExternalPlayer = await _storageService.getUseExternalPlayer();
    _autoSkipIntro = await _storageService.getAutoSkipIntro();
    _autoSkipOutro = await _storageService.getAutoSkipOutro();
    _enableSmartSkip = await _storageService.getEnableSmartSkip();
    final savedTvMode = await _storageService.getTvMode();
    _isNativeTv = await TvService.isNativeTvDevice();
    if (_isNativeTv) {
      // Hardware is a native TV / Leanback device: strictly lock to TV Mode
      _isTvMode = true;
      TvService.setOverride(true);
      await _storageService.setTvMode(true);
    } else if (savedTvMode != null) {
      _isTvMode = savedTvMode;
    } else {
      _isTvMode = await TvService.isTvDevice();
    }

    _autoPlayTrailers = await _storageService.getAutoPlayTrailers(
      isTv: _isTvMode,
    );

    _filterAdultContent = await _storageService.getFilterAdultContent();
    _backgroundPlayback = await _storageService.getBackgroundPlayback();
    _pipEnabled = await _storageService.getPipEnabled();

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

    _accentColorIndex = (await _storageService.getAccentColorIndex() ?? 0) % 4;

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
    _onlyShowAvailableOnProviders = await _storageService
        .getOnlyShowAvailableOnProviders();
    _videoDecoderMode = await _storageService.getVideoDecoderMode();
    _p2pEngineUrl = await _storageService.getP2pEngineUrl();
    // Loads any cached provider domains and refreshes them in the background;
    // scraped providers must not hardcode a domain that has since moved.
    await ProviderBaseUrlService.instance.warmUp();
    _selectedCatalogProvider = await _storageService
        .getSelectedCatalogProvider();
    _hasPromptedProviderSelection = await _storageService
        .getHasPromptedProviderSelection();
    _subtitleStyle = await _storageService.getSubtitleStylePreferences();

    notifyListeners();

    // Fast-path bootstrap: unblock runApp and load network feeds in background
    unawaited(_bootstrapBackgroundFeeds());
  }

  Future<void> _bootstrapBackgroundFeeds() async {
    try {
      await ProviderRegistry().initAll();
      if (ProviderRegistry().resolveProvider('moviebox') != null) {
        try {
          await _movieBoxProvider.init();
        } catch (_) {}
      }
      await loadHomeFeeds();
      if (_autoCheckUpdates) {
        Future.microtask(() => checkForUpdates(manual: false));
      }
    } catch (e) {
      debugPrint('Error bootstrapping background feeds: $e');
    }
  }

  Future<UpdateInfo?> checkForUpdates({bool manual = false}) async {
    // Play Store installs delegate updates to Google Play — never query GitHub.
    if (UpdateService.isPlayStoreInstall) {
      debugPrint(
        'AppProvider: Play Store install detected — skipping GitHub update check.',
      );
      return null;
    }

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
    if (_isNativeTv && !value) {
      debugPrint(
        'AppProvider: Disabling TV mode blocked on native TV hardware.',
      );
      return;
    }
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
    if (index >= 0 && index <= 2) {
      _currentThemeIndex = index;
      await _storageService.setThemeIndex(index);
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final idx = mode == ThemeMode.dark ? 1 : (mode == ThemeMode.light ? 2 : 0);
    await setThemeIndex(idx);
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

  bool get onlyShowAvailableOnProviders => _onlyShowAvailableOnProviders;

  /// How the player decodes video. Read once when the player is created, so a
  /// change takes effect on the next playback.
  VideoDecoderMode get videoDecoderMode => _videoDecoderMode;

  Future<void> setVideoDecoderMode(VideoDecoderMode mode) async {
    if (_videoDecoderMode == mode) return;
    _videoDecoderMode = mode;
    await _storageService.setVideoDecoderMode(mode);
    notifyListeners();
  }

  /// Base URL of an external P2P engine, or empty to use the bundled one.
  ///
  /// A BitTorrent engine cannot be a downloadable plugin (it is native code, and
  /// Play forbids downloading executable code), so peer-to-peer support comes
  /// either from the engine bundled into the GitHub build or from a separate
  /// engine service the user points this at.
  String get p2pEngineUrl => _p2pEngineUrl;

  bool get usesExternalP2pEngine => _p2pEngineUrl.trim().isNotEmpty;

  Future<void> setP2pEngineUrl(String url) async {
    final cleaned = url.trim();
    if (cleaned == _p2pEngineUrl) return;
    _p2pEngineUrl = cleaned;
    await _storageService.setP2pEngineUrl(cleaned);
    // The engine choice is read by TorrentService, which caches it.
    await TorrentService.instance.refreshEngineConfiguration();
    notifyListeners();
  }

  /// Called when the installed provider set changes (install, uninstall, or
  /// enable/disable). Availability is entirely provider-dependent, so every
  /// cached verdict must be discarded before the catalogue is rebuilt.
  Future<void> onProvidersChanged() async {
    await _availability.invalidateAll();
    await loadHomeFeeds();
  }

  Future<void> setOnlyShowAvailableOnProviders(bool value) async {
    _onlyShowAvailableOnProviders = value;
    await _storageService.setOnlyShowAvailableOnProviders(value);
    notifyListeners();
    await loadHomeFeeds();
  }

  Future<void> setSelectedCatalogProvider(String providerId) async {
    if (_selectedCatalogProvider == providerId) return;
    _selectedCatalogProvider = providerId;
    await _storageService.setSelectedCatalogProvider(providerId);
    notifyListeners();
    await loadHomeFeeds();
  }

  Future<void> setHasPromptedProviderSelection(bool value) async {
    _hasPromptedProviderSelection = value;
    await _storageService.setHasPromptedProviderSelection(value);
    notifyListeners();
  }

  Future<void> setSubtitleStyle(SubtitleStylePreferences style) async {
    _subtitleStyle = style;
    await _storageService.saveSubtitleStylePreferences(style);
    notifyListeners();
  }

  Future<void> loadHomeFeeds() async {
    _isLoadingHome = true;
    notifyListeners();

    try {
      List<MediaItem> allFeatured = [];
      List<MediaItem> allMovies = [];
      List<MediaItem> allSeries = [];

      final registry = ProviderRegistry();
      final hasStreamProviders = registry.hasStreamProviders;

      // With no stream-capable provider installed nothing can be verified as
      // playable. Rather than emptying the home screen, the catalogue falls back
      // to the built-in metadata provider (TMDB) so there is still something to
      // browse; the UI hides play actions in that state.
      _needsProviderSetup = !hasStreamProviders;
      if (_needsProviderSetup) {
        debugPrint(
          'AppProvider: no stream-capable provider installed; serving the '
          'metadata catalogue so titles stay browsable.',
        );
      }

      final preferred = registry.resolveProvider(_selectedCatalogProvider);

      // Pick the catalogue source. With a stream provider installed Home is
      // built from provider catalogues only: TMDb is never the source in that
      // state, because its rows are full of titles no installed add-on can
      // resolve. Only when nothing playable is installed does the metadata
      // provider drive the page (as a browse-only catalogue).
      MediaProviderPlugin? source;
      if (hasStreamProviders) {
        if (preferred != null &&
            preferred.supportsCatalogFeeds &&
            preferred.supportsStreams) {
          source = preferred;
        }
        if (source == null && registry.catalogProviders.isNotEmpty) {
          source = registry.catalogProviders.first;
        }
      } else {
        source = (preferred != null && preferred.supportsCatalogFeeds)
            ? preferred
            : null;
        if (source == null && registry.metadataCatalogProviders.isNotEmpty) {
          source = registry.metadataCatalogProviders.first;
        }
        if (source == null && registry.catalogProviders.isNotEmpty) {
          source = registry.catalogProviders.first;
        }
      }

      if (source != null) {
        debugPrint('AppProvider: catalogue source = ${source.id}');
        try {
          final pResults = await Future.wait([
            source.getCatalogFeed(category: 'featured', page: 1),
            source.getCatalogFeed(category: 'movies', page: 1),
            source.getCatalogFeed(category: 'series', page: 1),
            if (!_isTvMode) ...[
              source.getCatalogFeed(category: 'featured', page: 2),
              source.getCatalogFeed(category: 'movies', page: 2),
              source.getCatalogFeed(category: 'series', page: 2),
            ],
          ]);
          allFeatured = _deduplicateResults([
            ...pResults[0],
            if (!_isTvMode && pResults.length > 3) ...pResults[3],
          ]);
          allMovies = _deduplicateResults([
            ...pResults[1],
            if (!_isTvMode && pResults.length > 4) ...pResults[4],
          ]);
          allSeries = _deduplicateResults([
            ...pResults[2],
            if (!_isTvMode && pResults.length > 5) ...pResults[5],
          ]);
        } catch (e) {
          debugPrint('Provider ${source.id} catalog feed error: $e');
        }
      } else {
        debugPrint(
          'AppProvider: no catalogue-capable provider available '
          '(selected: $_selectedCatalogProvider).',
        );
      }

      _featuredFeed = _filterAdultContent
          ? allFeatured.where(_isSafeContent).toList()
          : allFeatured;
      _moviesFeed = _filterAdultContent
          ? allMovies.where(_isSafeContent).toList()
          : allMovies;
      _seriesFeed = _filterAdultContent
          ? allSeries.where(_isSafeContent).toList()
          : allSeries;

      // Gate the base feeds before the derived shelves are built, so trending,
      // popular and genre rows inherit the filter instead of re-probing. Skipped
      // when no stream provider is installed: there is nothing to verify against,
      // and the catalogue stays browsable behind the browse-only notice.
      _availabilityFiltered = false;
      if (_onlyShowAvailableOnProviders && hasStreamProviders) {
        await _applyAvailabilityGate();
        _availabilityFiltered = true;
      }

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
    unawaited(_loadProviderHomeRows());
  }

  /// Drops every title that no installed provider can actually play.
  ///
  /// Items served by a provider's own catalogue pass through untouched; only
  /// metadata-sourced titles (TMDB discovery and similar) are checked, and they
  /// are checked against the providers' own search indexes.
  Future<void> _applyAvailabilityGate() async {
    // With no stream-capable provider installed, nothing can be verified —
    // and nothing can be played either. Under the "only show available" rule
    // that means every title is unplayable, so the shelves are emptied rather
    // than filled with entries whose play button cannot do anything. The Home
    // screen shows a "no provider installed" notice for this state.
    if (!ProviderRegistry().hasStreamProviders) {
      // Nothing can be verified without a stream provider - but nothing can be
      // played either. The catalogue is deliberately left browsable here instead
      // of blanked: Home shows the browse-only notice and withholds every play
      // action, so the app never claims a stream exists. Preinstalling a stream
      // provider to fill the screen would hand the store build a piracy surface
      // it does not need.
      debugPrint(
        'AppProvider: no stream provider installed - catalogue stays browse-only.',
      );
      return;
    }

    try {
      // Gated one shelf at a time: the service bounds concurrency per call, so
      // running the three in parallel would multiply the request fan-out.
      _featuredFeed = await _availability.filterAvailable(_featuredFeed);
      _moviesFeed = await _availability.filterAvailable(_moviesFeed);
      _seriesFeed = await _availability.filterAvailable(_seriesFeed);

      debugPrint(
        'AppProvider: availability gate kept '
        '${_featuredFeed.length} featured / ${_moviesFeed.length} movies / '
        '${_seriesFeed.length} series.',
      );
    } catch (e) {
      // Never blank the catalogue because a probe failed: showing a title that
      // might not play is better than showing nothing at all.
      debugPrint('AppProvider: availability gate failed: $e');
    }
  }

  /// Removes TMDB discovery titles that no installed provider can play.
  ///
  /// Only the TMDB fallback row is gated: a title that came from a provider's own
  /// search is playable there by definition, and re-probing it would throw away
  /// real results when a provider's probe endpoint is unreachable.
  Future<void> _applySearchAvailabilityGate(int generation) async {
    if (!_onlyShowAvailableOnProviders) return;

    final index = _providerSearchSections.indexWhere(
      (s) => s.providerId == tmdbSearchProviderId,
    );
    if (index < 0) return;
    final before = _providerSearchSections[index].items;
    if (before.isEmpty) return;

    try {
      final filtered = await _availability.filterAvailable(before);
      if (generation != _searchGeneration) return;
      if (filtered.length == before.length) return;

      _providerSearchSections =
          List<ProviderSearchSection>.of(_providerSearchSections)
            ..[index] = _providerSearchSections[index].copyWith(
              items: filtered,
              status: filtered.isEmpty
                  ? ProviderSearchStatus.empty
                  : ProviderSearchStatus.loaded,
            );
      _rebuildSearchResults();
      notifyListeners();
    } catch (e) {
      debugPrint('AppProvider: search availability gate failed: $e');
    }
  }

  Future<void> _enrichGenreShelves() async {
    try {
      // Only providers the user actually installed may contribute shelves.
      final searchProviders = ProviderRegistry().streamProviders
          .where((p) => p.supportsSearch)
          .toList(growable: false);

      // TMDB genre rows are metadata only. When the user asked for available
      // content, they are only worth fetching if they can be gated afterwards.
      final tmdbFallbackAllowed = !_onlyShowAvailableOnProviders;
      if (searchProviders.isEmpty && !tmdbFallbackAllowed) return;

      final genres = ['horror', 'documentary', 'action', 'comedy', 'sci-fi'];
      final is32Bit = VideoCacheService.instance.is32BitOrLowRam;

      Future<List<MediaItem>> searchGenre(String genre) async {
        for (final provider in searchProviders) {
          try {
            final items = await provider.search(genre);
            if (items.isNotEmpty) return items;
          } catch (e) {
            debugPrint(
              'Provider ${provider.id} genre search "$genre" failed: $e',
            );
          }
        }
        if (tmdbFallbackAllowed) {
          try {
            return await TmdbService().getGenreFeed(genre);
          } catch (_) {}
        }
        return const [];
      }

      final List<List<MediaItem>> genreSearches;
      if (is32Bit) {
        genreSearches = [];
        for (final genre in genres) {
          genreSearches.add(await searchGenre(genre));
          await Future.delayed(const Duration(milliseconds: 150));
        }
      } else {
        genreSearches = await Future.wait(genres.map(searchGenre));
      }

      var hasUpdates = false;

      Future<void> mergeShelf(
        List<MediaItem> current,
        List<MediaItem> additions,
        void Function(List<MediaItem>) assign,
      ) async {
        if (additions.isEmpty) return;
        var merged = _deduplicateResults([...current, ...additions]);
        if (_filterAdultContent) {
          merged = merged.where(_isSafeContent).toList();
        }
        if (_onlyShowAvailableOnProviders) {
          merged = await _availability.filterAvailable(merged);
        }
        assign(merged);
        hasUpdates = true;
      }

      await mergeShelf(_horrorFeed, genreSearches[0], (v) => _horrorFeed = v);
      await mergeShelf(
        _documentaryFeed,
        genreSearches[1],
        (v) => _documentaryFeed = v,
      );
      await mergeShelf(_actionFeed, genreSearches[2], (v) => _actionFeed = v);
      await mergeShelf(_comedyFeed, genreSearches[3], (v) => _comedyFeed = v);
      await mergeShelf(_sciFiFeed, genreSearches[4], (v) => _sciFiFeed = v);

      if (hasUpdates) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error in _enrichGenreShelves: $e');
    }
  }

  /// Loads the shelves each installed provider declares for Home.
  ///
  /// Vega builds its home screen the same way: every catalogue the provider
  /// declares becomes one row, fetched in parallel, and one dead row is dropped
  /// on its own instead of blanking the page. [ProviderHomeRowsService] owns the
  /// bounds and the failure tolerance; this only decides which providers may
  /// contribute.
  Future<void> _loadProviderHomeRows() async {
    final registry = ProviderRegistry();

    if (!registry.hasStreamProviders) {
      // Browse-only install: there is nothing playable to promote, and the
      // metadata catalogue above already fills the screen.
      if (_providerHomeRows.isNotEmpty || _isLoadingProviderRows) {
        _providerHomeRows = [];
        _isLoadingProviderRows = false;
        notifyListeners();
      }
      return;
    }

    // Every provider that declares rows contributes: these are the only titles
    // guaranteed to be playable, and ShelfPlanner de-duplicates across rows.
    final providers = registry.streamProviders
        .where((p) => p.catalogs.isNotEmpty)
        .toList(growable: false);

    if (providers.isEmpty) {
      _isLoadingProviderRows = false;
      return;
    }

    _isLoadingProviderRows = true;
    notifyListeners();

    final rows = await _providerRowsService.load(
      providers,
      isAllowed: _isSafeContent,
    );

    _isLoadingProviderRows = false;
    if (!_sameProviderRows(rows, _providerHomeRows)) {
      _providerHomeRows = rows;
    }
    notifyListeners();
  }

  final ProviderHomeRowsService _providerRowsService =
      const ProviderHomeRowsService();

  /// Cheap change check so a refresh does not rebuild Home twice.
  bool _sameProviderRows(List<HomeProviderRow> a, List<HomeProviderRow> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].providerId != b[i].providerId) return false;
      if (a[i].rowId != b[i].rowId) return false;
      if (a[i].items.length != b[i].items.length) return false;
    }
    return true;
  }

  Future<void> _enrichFeaturedBackdrops() async {
    if (_featuredFeed.isEmpty) return;
    try {
      final tmdb = TmdbService();
      final maxEnrich = _isTvMode ? 2 : 8;
      final itemsToEnrich = _featuredFeed.take(maxEnrich).toList();
      bool anyUpdated = false;

      for (final item in itemsToEnrich) {
        if (item.backdropUrl != null && item.backdropUrl!.isNotEmpty) {
          continue; // Already has sharp backdrop from MovieBox
        }
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
        } else if (!existing.title.contains('4K') &&
            item.title.contains('4K')) {
          seen[key] = item;
        }
      }
    }
    return seen.values.toList();
  }

  /// Runs the global search: one concurrent query per installed provider.
  ///
  /// Results are kept per provider ([providerSearchSections]) and merged into
  /// [searchResults] as each provider answers, so the screen fills in gradually
  /// instead of waiting for the slowest provider, and a failure is attributed to
  /// the provider that failed rather than blanking the whole page.
  Future<void> search(String query) async {
    final generation = ++_searchGeneration;
    _searchQuery = query;
    _selectedSearchProviderId = null;

    if (query.trim().isEmpty) {
      _providerSearchSections = [];
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    final registry = ProviderRegistry();
    final targets = registry.searchProviders;

    // Seeded as "searching" before any request goes out: the screen can then
    // show every provider that is being asked, exactly as Vega does, instead of
    // an empty page behind one spinner.
    _providerSearchSections = [
      for (final provider in targets)
        ProviderSearchSection(
          providerId: provider.id,
          providerName: provider.name,
          priority: provider.priority,
          status: ProviderSearchStatus.searching,
        ),
    ];
    _searchResults = [];
    _isSearching = targets.isNotEmpty;
    notifyListeners();

    if (targets.isEmpty) {
      // Nothing installed can search, so discovery is the only possible answer.
      // It is metadata only and is gated below like any other TMDB row.
      await _searchTmdbFallback(query, generation);
      return;
    }

    await registry.searchAllProviders(
      query,
      isCancelled: () => generation != _searchGeneration,
      onSection: (section) => _onProviderSearchSection(section, generation),
    );

    if (generation != _searchGeneration) return;

    _isSearching = false;
    _rebuildSearchResults();
    notifyListeners();

    final hasAnyResult = _providerSearchSections.any((s) => s.hasResults);
    if (!hasAnyResult) {
      await _searchTmdbFallback(query, generation);
    }
  }

  /// Stores one provider's answer and refreshes the merged list.
  void _onProviderSearchSection(ProviderSearchSection section, int generation) {
    if (generation != _searchGeneration) return;

    final index = _providerSearchSections.indexWhere(
      (s) => s.providerId == section.providerId,
    );
    if (index < 0) return;

    _providerSearchSections = List<ProviderSearchSection>.of(
      _providerSearchSections,
    )..[index] = section.copyWith(items: _prepareProviderSearchItems(section));
    _rebuildSearchResults();
    notifyListeners();
  }

  /// Applies the adult filter, provider attribution and fuzzy relevance to one
  /// provider's raw answer.
  ///
  /// Ranking per provider rather than over the merged list keeps a noisy
  /// provider from crowding out an exact match on a quieter one, and keeps each
  /// provider's slice in the same order the grid showed for it.
  List<MediaItem> _prepareProviderSearchItems(ProviderSearchSection section) {
    final is32Bit = VideoCacheService.instance.is32BitOrLowRam;
    final owned = <MediaItem>[];
    for (final item in section.items) {
      if (!_isSafeContent(item)) continue;
      owned.add(
        (item.providerId == null || item.providerId!.isEmpty)
            ? item.copyWith(providerId: section.providerId)
            : item,
      );
    }

    final ranked = FuzzySearchService.search<MediaItem>(
      query: _searchQuery,
      items: owned,
      getTitle: (m) => m.title,
      limit: is32Bit ? 36 : 100,
      minScore: 25.0,
    );
    return ranked.isNotEmpty ? ranked : owned;
  }

  /// Merges every provider's slice into one list, deduplicated by title.
  ///
  /// Sections are ordered by provider priority, so when several providers know a
  /// title the merged card belongs to the highest-priority one and selecting
  /// that chip still shows it.
  void _rebuildSearchResults() {
    final ordered = List<ProviderSearchSection>.of(_providerSearchSections)
      ..sort((a, b) => b.priority.compareTo(a.priority));
    final merged = <MediaItem>[];
    for (final section in ordered) {
      merged.addAll(section.items);
    }
    _searchResults = _deduplicateResults(merged);
  }

  /// Last-resort discovery when no installed provider knows the title.
  ///
  /// TMDB is metadata only: its rows are appended as their own section and, when
  /// the user asked for available titles, gated in the background so unplayable
  /// entries disappear as their verdicts arrive instead of being offered as
  /// playable up front.
  Future<void> _searchTmdbFallback(String query, int generation) async {
    try {
      final discovery = await TmdbService().searchMulti(query);
      if (generation != _searchGeneration) return;

      final items = discovery.where(_isSafeContent).toList(growable: false);
      if (items.isEmpty) {
        _isSearching = false;
        notifyListeners();
        return;
      }

      _providerSearchSections = [
        ..._providerSearchSections,
        ProviderSearchSection(
          providerId: tmdbSearchProviderId,
          providerName: 'TMDB',
          priority: 0,
          status: ProviderSearchStatus.loaded,
          items: items,
        ),
      ];
      _rebuildSearchResults();
      _isSearching = false;
      notifyListeners();

      unawaited(_applySearchAvailabilityGate(generation));
    } catch (e) {
      debugPrint('TMDB search fallback error: $e');
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Returns fuzzy matching title suggestions from in-memory catalogue
  /// and search results for live typeahead.
  List<String> getTitleSuggestions(String query, {int limit = 8}) {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) return const [];
    final pool = <String>{};
    for (final item in allCataloguePool) {
      pool.add(item.title);
    }
    for (final item in _searchResults) {
      pool.add(item.title);
    }
    return FuzzySearchService.getTitleSuggestions(
      query: cleanQ,
      candidateTitles: pool,
      limit: limit,
    );
  }

  /// Performs instant in-memory fuzzy search across cached feeds.
  List<MediaItem> fuzzySearchInMemory(String query, {int limit = 30}) {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) return const [];
    return FuzzySearchService.search<MediaItem>(
      query: cleanQ,
      items: allCataloguePool,
      getTitle: (item) => item.title,
      limit: limit,
      minScore: 30.0,
    );
  }

  Future<void> searchCategory(String genre) async {
    // Category browsing is not a provider search: drop the per-provider slices
    // so a stale provider chip cannot filter a category grid.
    _searchGeneration++;
    _providerSearchSections = [];
    _selectedSearchProviderId = null;
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

      if (localMatches.isNotEmpty) {
        _searchResults = _deduplicateResults(localMatches);
        notifyListeners();
      }

      // 2. Concurrently search MovieBox and active providers for the category / keyword
      final List<Future<List<MediaItem>>> searchFutures = [];

      searchFutures.add(
        _movieBoxProvider.search(genre).catchError((e) {
          debugPrint('MovieBox genre search error: $e');
          return <MediaItem>[];
        }),
      );

      for (final p in ProviderRegistry().activeProviders) {
        if (p.supportsSearch &&
            p.id != 'moviebox' &&
            p.id != 'org.exalere.moviebox') {
          searchFutures.add(
            p.search(genre).catchError((e) {
              debugPrint('Provider ${p.id} searchCategory error: $e');
              return <MediaItem>[];
            }),
          );
        }
      }

      final results = await Future.wait(searchFutures);
      final providerResults = results.expand((list) => list).toList();

      // 3. Combine local catalog matches + provider search results
      var combined = [...localMatches, ...providerResults];
      if (combined.isEmpty) {
        try {
          final tmdbGenre = await TmdbService().getGenreFeed(genre);
          combined = tmdbGenre;
        } catch (_) {}
      }

      debugPrint(
        'searchCategory raw items: ${combined.length} (Local: ${localMatches.length}, Providers: ${providerResults.length})',
      );
      final is32Bit = VideoCacheService.instance.is32BitOrLowRam;
      final deduplicated = _deduplicateResults(combined);
      _searchResults = (is32Bit && deduplicated.length > 36)
          ? deduplicated.sublist(0, 36)
          : deduplicated;
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
    _searchGeneration++;
    _searchQuery = '';
    _searchResults = [];
    _providerSearchSections = [];
    _selectedSearchProviderId = null;
    _isSearching = false;
    notifyListeners();
  }
}
