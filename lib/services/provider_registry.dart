import 'package:flutter/foundation.dart';

import '../models/media_item.dart';
import '../models/media_details.dart';
import '../models/stream_source.dart';
import '../plugins/plugins.dart';

export 'media_provider_plugin.dart';

/// Central Plug-and-Play Media Provider Registry & Failover Manager.
///
/// When a streaming vendor or scraping endpoint goes down, new providers can
/// simply be registered here. Calls to [resolveStreams] will automatically fall back
/// across all registered providers in priority order.
class ProviderRegistry {
  static final ProviderRegistry _instance = ProviderRegistry._internal();
  factory ProviderRegistry() => _instance;
  ProviderRegistry._internal() {
    _registerDefaultProviders();
  }

  final Map<String, MediaProviderPlugin> _providers = {};

  /// The user-designated default provider ID.
  /// When set, [resolveStreams] prioritizes this provider's streams first.
  String? defaultProviderId;

  /// All currently registered provider plugins sorted by priority (highest first)
  List<MediaProviderPlugin> get activeProviders {
    final list = _providers.values.where((p) => p.isEnabled).toList();
    list.sort((a, b) => b.priority.compareTo(a.priority));
    return list;
  }

  /// Register a new media provider plugin
  void registerProvider(MediaProviderPlugin plugin) {
    _providers[plugin.id] = plugin;
    debugPrint(
      '[ProviderRegistry] Registered provider plugin: ${plugin.name} (${plugin.id})',
    );
  }

  /// Unregister or disable a failing provider
  void unregisterProvider(String id) {
    _providers.remove(id);
    debugPrint('[ProviderRegistry] Unregistered provider: $id');
  }

  /// Lookup a provider by its unique ID
  MediaProviderPlugin? getProvider(String id) => _providers[id];

  /// Initialize all registered providers
  Future<void> initAll() async {
    for (final p in activeProviders) {
      try {
        await p.init();
      } catch (e) {
        debugPrint(
          '[ProviderRegistry] Failed to initialize provider ${p.id}: $e',
        );
      }
    }
  }

  /// Automatically attempt stream resolution across all active providers.
  ///
  /// Providers are queried concurrently to gather available streams.
  /// Streams from the preferred provider (or [defaultProviderId]) are prioritized
  /// at the top of the list for initial playback, while ensuring all streams
  /// across all installed & enabled providers remain available in the player's
  /// server selection dialog.
  Future<List<StreamSource>> resolveStreams({
    required String subjectId,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
    String? preferredProviderId,
    String? originProviderId,
    bool? isSeries,
  }) async {
    final effectivePreferred = preferredProviderId ?? defaultProviderId;

    final candidates = List<MediaProviderPlugin>.from(activeProviders);

    final effectiveIsSeries = isSeries ?? (season != null && season > 0);

    final eligible = candidates.where((provider) {
      if (effectiveIsSeries && !provider.supportsSeries) return false;
      if (!effectiveIsSeries && !provider.supportsMovies) return false;
      return true;
    }).toList();

    final allStreams = <StreamSource>[];
    final seenUrls = <String>{};

    final results = await Future.wait(
      eligible.map((provider) async {
        try {
          final streams = await provider
              .getStreams(
                subjectId: subjectId,
                title: title,
                year: year,
                imdbId: imdbId,
                season: season,
                episode: episode,
                originProviderId: originProviderId,
                isSeries: effectiveIsSeries,
              )
              .timeout(const Duration(seconds: 25));

          return streams.map((s) {
            if (s.server == null || s.server!.isEmpty) {
              return StreamSource(
                quality: s.quality,
                resolution: s.resolution,
                format: s.format,
                url: s.url,
                headers: s.headers,
                codec: s.codec,
                sizeBytes: s.sizeBytes,
                subtitles: s.subtitles,
                resourceId: s.resourceId,
                server: provider.name,
                providerId: provider.id,
                providerName: provider.name,
              );
            }
            return s;
          }).toList();
        } catch (e) {
          debugPrint('[ProviderRegistry] Provider ${provider.name} failed: $e');
          return <StreamSource>[];
        }
      }),
    );

    for (final list in results) {
      for (final s in list) {
        if (s.url.isNotEmpty && !seenUrls.contains(s.url)) {
          seenUrls.add(s.url);
          allStreams.add(s);
        }
      }
    }

    // Sort streams:
    // 1. Preferred / default provider streams first
    // 2. Direct playable media streams (MP4/HLS) before embed links
    // 3. Direct progressive MP4 / HLS before chunked DASH
    allStreams.sort((a, b) {
      // 1. Preferred / default provider prioritized first
      if (effectivePreferred != null) {
        final aIsPref = a.effectiveProviderId == effectivePreferred;
        final bIsPref = b.effectiveProviderId == effectivePreferred;
        if (aIsPref && !bIsPref) return -1;
        if (!aIsPref && bIsPref) return 1;
      }

      // 2. Direct streams before embeds
      final aIsEmbed =
          a.format.toLowerCase().contains('embed') || a.url.contains('/embed/');
      final bIsEmbed =
          b.format.toLowerCase().contains('embed') || b.url.contains('/embed/');
      if (aIsEmbed && !bIsEmbed) return 1;
      if (!aIsEmbed && bIsEmbed) return -1;

      // 3. Prioritize direct progressive MP4 / HLS ahead of chunked DASH for smooth playback
      final aIsDash =
          a.format.toUpperCase() == 'DASH' || a.url.contains('.mpd');
      final bIsDash =
          b.format.toUpperCase() == 'DASH' || b.url.contains('.mpd');
      if (aIsDash && !bIsDash) return 1;
      if (!aIsDash && bIsDash) return -1;

      return 0;
    });

    if (allStreams.isNotEmpty) {
      debugPrint(
        '[ProviderRegistry] Successfully resolved ${allStreams.length} stream(s) across providers.',
      );
      return allStreams;
    }

    debugPrint(
      '[ProviderRegistry] All providers exhausted. No active streams found.',
    );
    return [];
  }

  /// Retrieve media details from the appropriate provider.
  Future<MediaDetails?> getDetails(
    String id, {
    String? providerId,
    String? title,
  }) async {
    if (providerId != null && _providers.containsKey(providerId)) {
      try {
        final details = await _providers[providerId]!.getDetails(id);
        if (details != null) return details;
      } catch (e) {
        debugPrint(
          '[ProviderRegistry] Provider $providerId getDetails error: $e',
        );
      }
    }

    for (final provider in activeProviders) {
      if (provider.id == providerId) continue;
      try {
        final details = await provider.getDetails(id);
        if (details != null) return details;
      } catch (_) {}
    }

    if (title != null && title.trim().isNotEmpty) {
      for (final provider in activeProviders) {
        if (!provider.supportsSearch) continue;
        try {
          final matches = await provider.search(title.trim());
          if (matches.isNotEmpty) {
            final details = await provider.getDetails(matches.first.id);
            if (details != null) return details;
          }
        } catch (_) {}
      }
    }

    return null;
  }

  /// Search across all active providers or a specific provider.
  Future<List<MediaItem>> search(String query, {String? providerId}) async {
    if (providerId != null && _providers.containsKey(providerId)) {
      try {
        return await _providers[providerId]!.search(query);
      } catch (e) {
        debugPrint('[ProviderRegistry] Provider $providerId search error: $e');
        return [];
      }
    }

    final allItems = <MediaItem>[];
    final seenIds = <String>{};

    for (final provider in activeProviders) {
      if (!provider.supportsSearch) continue;
      try {
        final items = await provider.search(query);
        for (final item in items) {
          if (seenIds.add(item.id)) {
            allItems.add(item);
          }
        }
      } catch (e) {
        debugPrint(
          '[ProviderRegistry] Provider ${provider.name} search error: $e',
        );
      }
    }
    return allItems;
  }

  /// Retrieve external subtitles across all active providers that support them.
  Future<List<SubtitleOption>> getSubtitles({
    required String subjectId,
    String? resourceId,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
  }) async {
    final eligible = activeProviders.where((p) => p.supportsSubtitles).toList();
    if (eligible.isEmpty) return [];

    final results = await Future.wait(
      eligible.map((provider) async {
        try {
          return await provider
              .getSubtitles(
                subjectId: subjectId,
                resourceId: resourceId,
                title: title,
                year: year,
                imdbId: imdbId,
                season: season,
                episode: episode,
              )
              .timeout(const Duration(seconds: 10));
        } catch (e) {
          debugPrint(
            '[ProviderRegistry] Provider ${provider.name} getSubtitles error: $e',
          );
          return <SubtitleOption>[];
        }
      }),
    );

    final collected = <SubtitleOption>[];
    final seen = <String>{};
    for (final list in results) {
      for (final sub in list) {
        if (sub.url.isNotEmpty && seen.add(sub.url)) {
          collected.add(sub);
        }
      }
    }
    return collected;
  }

  /// Get catalog discovery feed from the active provider supporting it.
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
    String? providerId,
  }) async {
    if (providerId != null && _providers.containsKey(providerId)) {
      try {
        return await _providers[providerId]!.getCatalogFeed(
          category: category,
          page: page,
        );
      } catch (e) {
        debugPrint(
          '[ProviderRegistry] Provider $providerId getCatalogFeed error: $e',
        );
        return [];
      }
    }

    final eligible = activeProviders
        .where((p) => p.supportsCatalogFeeds)
        .toList();
    if (eligible.isEmpty) return [];

    for (final provider in eligible) {
      try {
        final items = await provider
            .getCatalogFeed(category: category, page: page)
            .timeout(const Duration(seconds: 15));
        if (items.isNotEmpty) return items;
      } catch (e) {
        debugPrint(
          '[ProviderRegistry] Provider ${provider.name} getCatalogFeed error: $e',
        );
      }
    }
    return [];
  }

  /// Clear all registered providers. Called by [PluginService.loadInstalledPlugins]
  /// so the registry reflects exactly the user's installed plugin list.
  void clearAll() {
    _providers.clear();
    debugPrint('[ProviderRegistry] All providers cleared.');
  }

  void _registerDefaultProviders() {
    // Dynamic plugins are loaded and managed via PluginService
  }
}
