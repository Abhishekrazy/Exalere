import 'package:flutter/foundation.dart';

import '../models/media_item.dart';
import '../models/media_details.dart';
import '../models/stream_source.dart';
import 'media_provider_plugin.dart';
import 'moviebox_provider.dart';
import 'fourkhdhub_provider.dart';

import 'vidsrc_provider.dart';

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

    for (final provider in candidates) {
      if (season != null && !provider.supportsSeries) continue;
      if (season == null && !provider.supportsMovies) continue;

      try {
        final streams = await provider.getStreams(
          subjectId: subjectId,
          season: season,
          episode: episode,
        );

        if (streams.isNotEmpty) {
          debugPrint(
            '[ProviderRegistry] Successfully resolved ${streams.length} stream(s) using ${provider.name}',
          );
          return streams;
        }
      } catch (e) {
        debugPrint(
          '[ProviderRegistry] Provider ${provider.name} failed with: $e. Falling back to next vendor...',
        );
      }
    }

    debugPrint(
      '[ProviderRegistry] All providers exhausted. No active streams found.',
    );
    return [];
  }

  void _registerDefaultProviders() {
    registerProvider(_MovieBoxAdapter());
    registerProvider(_FourKHdHubAdapter());
    registerProvider(VidSrcProvider());
  }
}

/// Adapter wrapping [MovieBoxProvider] as a plug-and-play [MediaProviderPlugin]
class _MovieBoxAdapter extends MediaProviderPlugin {
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
class _FourKHdHubAdapter extends MediaProviderPlugin {
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
    int? season,
    int? episode,
  }) {
    return _hub.getStreams(subjectId);
  }
}
