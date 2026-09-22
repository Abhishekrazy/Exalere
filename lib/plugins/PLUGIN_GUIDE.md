# Exalere Media Provider Plugin Guide

## 1. Overview & Architecture

Exalere is designed with **Inversion of Control (IoC)**:
- **The Core App & Video Player NEVER depend on specific plugins or streaming scrapers.**
- **All plugins depend on the Exalere Generic Provider Specification (`MediaProviderPlugin`).**
- **TMDB is the universal high-definition discovery catalog** across the entire app. It guarantees store-compliant metadata, crisp 1080p/4K backdrops and posters, and consistent ratings.
- Plugins are decoupled modular units responsible for resolving **playable streams**, **external subtitles**, and **vendor-specific search**.

```
+-------------------------------------------------------------------------------+
|                                  EXALERE APP                                  |
|   PlayerScreen  *  TvSeriesSheet  *  DetailsScreen  *  AppProvider  *  Search |
+-------------------------------------------------------------------------------+
                                        |
                                        v
+-------------------------------------------------------------------------------+
|                       TMDB Discovery Catalog (Universal)                      |
|           Home Feeds  *  Trending  *  Top Rated  *  Genres  *  Details        |
+-------------------------------------------------------------------------------+
                                        | (On play or details request)
                                        v
+-------------------------------------------------------------------------------+
|                              ProviderRegistry                                 |
|      resolveStreams(...)  *  getSubtitles(...)  *  getDetails(...)            |
+-------------------------------------------------------------------------------+
                                        | (Polymorphic Delegation)
                                        v
+-------------------------------------------------------------------------------+
|                           <<MediaProviderPlugin>>                             |
|                           (The Standard Contract)                             |
|   + id: String                                                                |
|   + name: String                                                              |
|   + priority: int                                                             |
|   + supportsMovies: bool          + supportsSeries: bool                      |
|   + supportsSearch: bool          + supportsSubtitles: bool                   |
|   + getStreams(...)               + getSubtitles(...)                         |
|   + getDetails(...)               + search(...)                               |
+-------------------------------------------------------------------------------+
       ^                   ^                     ^                   ^
       |                   |                     |                   |
+--------------+   +---------------+   +-------------------+   +---------------+
|   MovieBox   |   |   4K HD Hub   |   | Exalere / Stremio |   | Custom Plugin |
|    Plugin    |   |    Plugin     |   |   Remote Addons   |   |  (Community)  |
+--------------+   +---------------+   +-------------------+   +---------------+
```

---

## 2. The `MediaProviderPlugin` Specification

Every plugin implements the abstract class `MediaProviderPlugin`:

```dart
abstract class MediaProviderPlugin {
  /// Unique machine-readable identifier (e.g. 'moviebox', 'fourkhdhub', 'vidsrc')
  String get id;

  /// User-friendly display name (e.g. '4K HD Hub', 'MovieBox Engine')
  String get name;

  /// Priority of this provider for resolving streams (higher numbers attempted first)
  int get priority => 10;

  /// Whether this provider is enabled and active
  bool get isEnabled => true;

  /// Capabilities
  bool get supportsMovies => true;
  bool get supportsSeries => false;
  bool get supportsSearch => false;
  bool get supportsSubtitles => false;
  bool get supportsCatalogFeeds => false;

  /// Lifecycle: Initialize tokens, crypto keys, or remote configurations
  Future<void> init() async {}

  /// Search for items matching [query]
  Future<List<MediaItem>> search(String query) async => [];

  /// Get detailed information, synopsis, and season/episode lists
  Future<MediaDetails?> getDetails(String id) async => null;

  /// Resolve playable video streams for a movie or TV episode
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
    String? originProviderId,
    bool? isSeries,
  });

  /// Resolve external subtitles / closed captions for a movie or TV episode
  Future<List<SubtitleOption>> getSubtitles({
    required String subjectId,
    String? resourceId,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
  }) async => [];
}
```

---

## 3. Implementing a New Plugin

### Step 1: Create Your Plugin Directory
Place all provider-specific code, scraping logic, and vendor parsers in a dedicated folder:
`lib/plugins/<your_plugin_id>/`

```
lib/plugins/myprovider/
|-- myprovider_api.dart      # HTTP client & scraping logic
|-- myprovider_parser.dart   # Vendor-specific JSON/HTML parser
`-- myprovider_plugin.dart   # Implements MediaProviderPlugin
```

### Step 2: Implement the Interface
```dart
import '../../models/media_details.dart';
import '../../models/media_item.dart';
import '../../models/stream_source.dart';
import '../../services/media_provider_plugin.dart';
import 'myprovider_api.dart';
import 'myprovider_parser.dart';

class MyProviderPlugin extends MediaProviderPlugin {
  final MyProviderApi _api = MyProviderApi();

  @override
  String get id => 'myprovider';

  @override
  String get name => 'My Provider CDN';

  @override
  int get priority => 80;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  @override
  bool get supportsSubtitles => true;

  @override
  Future<void> init() async {
    await _api.init();
  }

  @override
  Future<List<MediaItem>> search(String query) async {
    final rawResults = await _api.search(query);
    return MyProviderParser.parseSearchItems(rawResults);
  }

  @override
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
    String? originProviderId,
    bool? isSeries,
  }) async {
    // 1. If subjectId belongs to this provider, resolve directly
    if (originProviderId == id) {
      return _api.resolveDirect(subjectId, season: season, episode: episode);
    }

    // 2. Otherwise match by Title + Release Year
    if (title != null && title.isNotEmpty) {
      final matches = await search(title);
      final bestMatch = MediaItem.findBestMatch(
        candidates: matches,
        targetTitle: title,
        targetYear: year,
        targetIsSeries: isSeries ?? (season != null && season > 0),
      );
      if (bestMatch != null) {
        return _api.resolveDirect(bestMatch.id, season: season, episode: episode);
      }
    }

    return [];
  }

  @override
  Future<List<SubtitleOption>> getSubtitles({
    required String subjectId,
    String? resourceId,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
  }) async {
    return _api.fetchSubtitles(subjectId, season: season, episode: episode);
  }
}
```

### Step 3: Publish to Community Catalog or Install via URL
Exalere uses a 100% dynamic remote-plugin architecture to comply with Google Play guidelines and keep the core app lightweight:
1. Host your plugin as a standard Stremio/Exalere v3 endpoint (`/manifest.json`, `/stream/...`, `/subtitles/...`).
2. Add your plugin's HTTP manifest URL to `docs/plugins.json` in the Exalere repository.
3. Users can install your plugin with 1 click from the in-app Add-on Store or by pasting the URL directly into Exalere!

---

## 4. Best Practices for Plugins

1. **Title & Year Cross-Resolution**:
   Always handle queries from other providers by matching against `title` and `year` using `MediaItem.findBestMatch(...)`. Never assume `subjectId` is always your proprietary database ID.
2. **Resilience & Fast Timeouts**:
   Network requests inside `getStreams()` should have bounded timeouts (typically 2 to 5 seconds per mirror). The `ProviderRegistry` enforces an outer 25-second timeout across all providers.
3. **Encapsulation**:
   Never expose vendor-specific types (e.g. proprietary JSON structures) outside your plugin folder. Always map them to Exalere standard models (`StreamSource`, `MediaItem`, `SubtitleOption`, `MediaDetails`).
4. **No UI or Player Imports**:
   A plugin must **never** import UI widgets, mixins, or player files. Plugins are purely data and stream resolution providers.
5. **Zero Hardcoded Colors**:
   Plugins do not render UI directly. Any metadata or UI badges are rendered using the app's theme tokens (`context.tokens`).
