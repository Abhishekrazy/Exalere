import 'dart:async';

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

  /// Normalizes a provider identifier so legacy engine tags and fully-qualified
  /// plugin ids resolve to the same key.
  ///
  /// Engine scrapers tag their catalog items with short ids (`moviebox`,
  /// `fourkhdhub`) while the installed plugin is registered under its manifest
  /// id (`org.exalere.moviebox`, `org.exalere.fourkhd`). Without this bridge,
  /// preferred-provider hints and availability checks silently miss.
  static String providerMatchKey(String raw) {
    var value = raw.toLowerCase().trim();
    if (value.startsWith('org.exalere.')) {
      value = value.substring('org.exalere.'.length);
    }
    value = value.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (value.contains('fourkhd') || value.contains('4khd')) return 'fourkhd';
    if (value.contains('moviebox')) return 'moviebox';
    if (value.contains('dramachi')) return 'dramachi';
    if (value.contains('vidsrc')) return 'vidsrc';
    if (value.contains('circleftp')) return 'circleftp';
    return value;
  }

  /// Resolves a provider by any known alias of its id, or `null` when no
  /// registered provider matches.
  MediaProviderPlugin? resolveProvider(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    final direct = _providers[id];
    if (direct != null) return direct;

    final target = providerMatchKey(id);
    if (target.isEmpty) return null;
    for (final provider in _providers.values) {
      if (providerMatchKey(provider.id) == target) return provider;
    }
    return null;
  }

  /// Active providers that can actually resolve playable video streams.
  ///
  /// Metadata-only addons (Cinemeta and similar) are excluded so they can never
  /// masquerade as playback sources.
  List<MediaProviderPlugin> get streamProviders =>
      activeProviders.where((p) => p.supportsStreams).toList(growable: false);

  /// Active providers that can serve a browsable discovery catalog.
  List<MediaProviderPlugin> get catalogProviders => activeProviders
      .where((p) => p.supportsStreams && p.supportsCatalogFeeds)
      .toList(growable: false);

  /// Active providers that can serve a browsable catalog even though they cannot
  /// resolve streams — metadata-only catalogs such as the built-in TMDB
  /// provider. These are what keep a fresh install from being an empty screen.
  List<MediaProviderPlugin> get metadataCatalogProviders => activeProviders
      .where((p) => !p.supportsStreams && p.supportsCatalogFeeds)
      .toList(growable: false);

  /// Whether at least one installed provider can resolve streams.
  bool get hasStreamProviders => streamProviders.isNotEmpty;

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
  /// Providers are queried concurrently to gather streams. Streams from the
  /// preferred provider (or [defaultProviderId]) are prioritized at the top of
  /// the list for initial playback, while streams from every other enabled
  /// provider remain available in the player's server selection dialog.
  ///
  /// Resolution returns as soon as the first provider succeeds and a short
  /// grace window elapses, so one slow or hanging provider can no longer delay
  /// playback until the per-provider timeout expires.
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
    final preferredKey = effectivePreferred == null
        ? null
        : providerMatchKey(effectivePreferred);

    final effectiveIsSeries = isSeries ?? (season != null && season > 0);

    // Metadata-only addons can never return a stream, so they are excluded up
    // front instead of burning a full timeout on every playback attempt.
    final eligible = streamProviders
        .where(
          (provider) => effectiveIsSeries
              ? provider.supportsSeries
              : provider.supportsMovies,
        )
        .toList(growable: false);

    if (eligible.isEmpty) {
      debugPrint(
        '[ProviderRegistry] No installed provider can resolve streams.',
      );
      return const [];
    }

    final allStreams = <StreamSource>[];
    final seenUrls = <String>{};

    final completer = Completer<void>();
    var pending = eligible.length;
    var completed = false;
    Timer? graceTimer;

    void finish() {
      if (completed) return;
      completed = true;
      graceTimer?.cancel();
      if (!completer.isCompleted) completer.complete();
    }

    void collect(Iterable<StreamSource> streams, MediaProviderPlugin provider) {
      if (completed) return;
      for (final s in streams) {
        if (s.url.isEmpty || !seenUrls.add(s.url)) continue;
        allStreams.add(
          (s.server == null || s.server!.isEmpty)
              ? s.copyWith(
                  server: provider.name,
                  providerId: provider.id,
                  providerName: provider.name,
                )
              : s,
        );
      }
    }

    // Hard ceiling: never block playback longer than this, even if a provider
    // never settles.
    final hardCap = Timer(_resolutionHardCap, () {
      debugPrint('[ProviderRegistry] Stream resolution hard cap reached.');
      finish();
    });

    // Providers that have not yet answered, keyed for the preferred check below.
    final outstanding = eligible.map((p) => providerMatchKey(p.id)).toSet();

    for (final provider in eligible) {
      unawaited(
        provider
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
            .timeout(_perProviderTimeout)
            .then((streams) => collect(streams, provider))
            .catchError((Object e) {
              debugPrint(
                '[ProviderRegistry] Provider ${provider.name} failed: $e',
              );
            })
            .whenComplete(() {
              pending--;
              outstanding.remove(providerMatchKey(provider.id));
              if (pending <= 0) {
                finish();
              } else if (allStreams.isNotEmpty && graceTimer == null) {
                // First success: give the remaining providers a brief window to
                // contribute alternates, then let playback start. The window is
                // longer while the user's preferred provider is still working,
                // so its streams are never cut off.
                final waitingOnPreferred =
                    preferredKey != null && outstanding.contains(preferredKey);
                graceTimer = Timer(
                  waitingOnPreferred ? _preferredGraceWindow : _graceWindow,
                  finish,
                );
              }
            }),
      );
    }

    await completer.future;
    hardCap.cancel();

    // Sort streams:
    // 1. Direct playable media streams (MP4/HLS) strictly ahead of raw P2P torrent magnets
    // 2. Preferred / default provider streams prioritized
    // 3. Direct streams before embeds
    // 4. Direct progressive MP4 / HLS before chunked DASH
    allStreams.sort((a, b) {
      // 1. Prioritize direct playable streams over raw P2P torrent magnets
      final aIsMagnet = a.url.toLowerCase().startsWith('magnet:');
      final bIsMagnet = b.url.toLowerCase().startsWith('magnet:');
      if (!aIsMagnet && bIsMagnet) return -1;
      if (aIsMagnet && !bIsMagnet) return 1;

      // 2. Preferred / default provider prioritized
      if (preferredKey != null) {
        final aIsPref = providerMatchKey(a.effectiveProviderId) == preferredKey;
        final bIsPref = providerMatchKey(b.effectiveProviderId) == preferredKey;
        if (aIsPref && !bIsPref) return -1;
        if (!aIsPref && bIsPref) return 1;
      }

      // 3. Direct streams before embeds
      final aIsEmbed =
          a.format.toLowerCase().contains('embed') || a.url.contains('/embed/');
      final bIsEmbed =
          b.format.toLowerCase().contains('embed') || b.url.contains('/embed/');
      if (aIsEmbed && !bIsEmbed) return 1;
      if (!aIsEmbed && bIsEmbed) return -1;

      // 4. Prioritize direct progressive MP4 / HLS ahead of chunked DASH for smooth playback
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
    } else {
      debugPrint(
        '[ProviderRegistry] All providers exhausted. No active streams found.',
      );
    }

    return List<StreamSource>.of(allStreams);
  }

  /// Maximum time to wait for a single provider to answer.
  static const Duration _perProviderTimeout = Duration(seconds: 20);

  /// After the first provider succeeds, how long to keep collecting alternates.
  static const Duration _graceWindow = Duration(milliseconds: 3000);

  /// Longer grace window used while the user's preferred provider is still
  /// resolving, so its streams are never dropped from the server list.
  static const Duration _preferredGraceWindow = Duration(seconds: 9);

  /// Absolute ceiling on a single stream resolution attempt.
  static const Duration _resolutionHardCap = Duration(seconds: 22);

  /// Retrieve media details from the appropriate provider.
  Future<MediaDetails?> getDetails(
    String id, {
    String? providerId,
    String? title,
    String? year,
    bool? isSeries,
  }) async {
    // Resolve through the alias bridge so short engine tags ('moviebox') and
    // manifest ids ('org.exalere.moviebox') both reach the installed plugin.
    final requested = resolveProvider(providerId);
    if (requested != null) {
      try {
        final details = await requested.getDetails(id);
        if (details != null) return details;
      } catch (e) {
        debugPrint(
          '[ProviderRegistry] Provider ${requested.id} getDetails error: $e',
        );
      }
    }

    for (final provider in activeProviders) {
      if (provider.id == requested?.id) continue;
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
            final matched = MediaItem.findBestMatch(
              candidates: matches,
              title: title.trim(),
              year: year,
              isSeries: isSeries,
            );
            if (matched != null) {
              final details = await provider.getDetails(matched.id);
              if (details != null) return details;
            }
          }
        } catch (_) {}
      }
    }

    return null;
  }

  /// Search across all active stream providers, or a single provider.
  ///
  /// Metadata-only addons are skipped: their results could never be played, so
  /// surfacing them here would only create dead ends.
  Future<List<MediaItem>> search(String query, {String? providerId}) async {
    final requested = resolveProvider(providerId);
    if (requested != null) {
      try {
        return await requested.search(query);
      } catch (e) {
        debugPrint(
          '[ProviderRegistry] Provider ${requested.id} search error: $e',
        );
        return [];
      }
    }

    final allItems = <MediaItem>[];
    final seenIds = <String>{};

    for (final provider in streamProviders) {
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

  /// Get catalog discovery feed from the first catalog-capable stream provider.
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
    String? providerId,
  }) async {
    final requested = resolveProvider(providerId);
    if (requested != null) {
      try {
        return await requested.getCatalogFeed(category: category, page: page);
      } catch (e) {
        debugPrint(
          '[ProviderRegistry] Provider ${requested.id} getCatalogFeed error: $e',
        );
        return [];
      }
    }

    for (final provider in catalogProviders) {
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

  /// Clear all user-installed providers, then restore the always-present
  /// built-ins. Called by [PluginService.loadInstalledPlugins] so the registry
  /// reflects exactly the user's installed plugin list plus the defaults.
  void clearAll() {
    _providers.clear();
    _registerDefaultProviders();
    debugPrint('[ProviderRegistry] User providers cleared.');
  }

  /// Registers providers that ship with the app and are always available.
  ///
  /// The TMDB catalog is metadata only ([MediaProviderPlugin.supportsStreams] is
  /// `false`), so it gives a fresh install something to browse without ever
  /// pretending a stream exists.
  void _registerDefaultProviders() {
    final tmdb = TmdbPlugin();
    _providers[tmdb.id] = tmdb;

    // HDHub4u is deliberately NOT registered here. A fresh install must not
    // claim it can play anything: that is what keeps the browse-only notice and
    // the library/favourite buttons in place until the user installs a provider
    // that can actually resolve streams. It ships as an installable built-in
    // add-on instead (see PluginService.builtInEngineManifests).
  }
}
