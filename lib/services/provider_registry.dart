import 'package:flutter/foundation.dart';

import '../models/media_item.dart';
import '../models/media_details.dart';
import '../models/stream_source.dart';
import 'media_provider_plugin.dart';
import 'moviebox_provider.dart';
import 'fourkhdhub_provider.dart';

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

  /// Automatically attempt stream resolution across all active providers in priority order.
  /// If one vendor is down or rate-limited, it silently fails over to the next provider.
  Future<List<StreamSource>> resolveStreams({
    required String subjectId,
    String? imdbId,
    int? season,
    int? episode,
    String? preferredProviderId,
  }) async {
    final candidates = List<MediaProviderPlugin>.from(activeProviders);

    // If a preferred provider is specified, place it first
    if (preferredProviderId != null &&
        _providers.containsKey(preferredProviderId)) {
      candidates.removeWhere((p) => p.id == preferredProviderId);
      candidates.insert(0, _providers[preferredProviderId]!);
    }

    final eligible = candidates.where((provider) {
      if (season != null && !provider.supportsSeries) return false;
      if (season == null && !provider.supportsMovies) return false;
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
                imdbId: imdbId,
                season: season,
                episode: episode,
              )
              .timeout(const Duration(seconds: 7));

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

    // Sort direct playable media streams (DASH, HLS, MP4) first before embed links
    allStreams.sort((a, b) {
      final aIsEmbed =
          a.format.toLowerCase().contains('embed') || a.url.contains('/embed/');
      final bIsEmbed =
          b.format.toLowerCase().contains('embed') || b.url.contains('/embed/');
      if (aIsEmbed && !bIsEmbed) return 1;
      if (!aIsEmbed && bIsEmbed) return -1;
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

  void _registerDefaultProviders() {
    // Zero built-in streaming providers.
    // Exalere starts strictly as a movie/media manager until user installs plugins.
  }
}

/// Adapter wrapping [MovieBoxProvider] as a plug-and-play [MediaProviderPlugin].
/// Can be registered/unregistered dynamically when user installs or enables the plugin.
class MovieBoxAdapter extends MediaProviderPlugin {
  final MovieBoxProvider _mb = MovieBoxProvider();

  @override
  String get id => 'moviebox';

  @override
  String get name => 'MovieBox Engine';

  @override
  int get priority => 100; // Primary provider

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  @override
  Future<void> init() async {
    await _mb.init();
  }

  @override
  Future<List<MediaItem>> search(String query) => _mb.search(query);

  @override
  Future<MediaDetails?> getDetails(String id) => _mb.getDetails(id);

  @override
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? imdbId,
    int? season,
    int? episode,
  }) {
    return _mb.getStreams(
      subjectId: subjectId,
      season: season ?? 0,
      episode: episode ?? 0,
    );
  }
}

/// Adapter wrapping [FourKHdHubProvider] as a plug-and-play [MediaProviderPlugin]
class FourKHdHubAdapter extends MediaProviderPlugin {
  final FourKHdHubProvider _hub = FourKHdHubProvider();

  @override
  String get id => 'fourkhdhub';

  @override
  String get name => '4K HD Hub';

  @override
  int get priority => 50; // Fallback provider

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => false;

  @override
  bool get supportsSearch => true;

  @override
  Future<List<MediaItem>> search(String query) => _hub.search(query);

  @override
  Future<MediaDetails?> getDetails(String id) => _hub.getDetails(id);

  @override
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? imdbId,
    int? season,
    int? episode,
  }) {
    return _hub.getStreams(subjectId);
  }
}
