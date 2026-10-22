import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';
import 'provider_registry.dart';

/// Persisted record of one availability verdict.
class _AvailabilityEntry {
  final bool available;
  final DateTime checkedAt;

  const _AvailabilityEntry({required this.available, required this.checkedAt});
}

/// Decides whether a catalog item can actually be played with the providers the
/// user has installed right now.
///
/// The rule the app follows is that **metadata is never proof of playability**:
///
///  * An item produced by an installed stream provider's own catalog or search
///    index is trusted — the provider that listed it can serve it.
///  * Any other item (TMDB discovery, related titles, a stale cached feed) must
///    be corroborated by a provider search before it is shown as watchable.
///
/// Verdicts are cached in memory and on disk so repeated titles across home
/// shelves cost at most one lookup.
class StreamAvailabilityService {
  StreamAvailabilityService._internal();

  static final StreamAvailabilityService _instance =
      StreamAvailabilityService._internal();

  factory StreamAvailabilityService() => _instance;

  static const String _prefsKey = 'exalere_stream_availability_v2';

  /// Upper bound on persisted verdicts; oldest entries are trimmed first.
  static const int maxEntries = 3000;

  /// How many catalog items are probed in parallel.
  static const int maxConcurrentItems = 6;

  /// A positive verdict stays valid for this long.
  static const Duration positiveTtl = Duration(hours: 12);

  /// A negative verdict is re-checked sooner, because providers add titles.
  static const Duration negativeTtl = Duration(hours: 3);

  /// Per-provider timeout while probing a single title.
  static const Duration probeTimeout = Duration(seconds: 8);

  final Map<String, _AvailabilityEntry> _entries =
      <String, _AvailabilityEntry>{};

  /// Short-lived per-provider probe memo, so the same title appearing in
  /// several shelves does not trigger repeated network searches.
  final Map<String, _AvailabilityEntry> _probeMemo =
      <String, _AvailabilityEntry>{};

  /// De-duplicates concurrent probes for the same item key.
  final Map<String, Future<bool>> _inFlight = <String, Future<bool>>{};

  bool _loaded = false;
  Future<void>? _loadingFuture;
  Timer? _persistTimer;
  bool _persistScheduled = false;

  /// Number of cached verdicts; exposed for tests and diagnostics.
  @visibleForTesting
  int get cachedEntryCount => _entries.length;

  /// Drops all in-memory and persisted state. Used by tests.
  @visibleForTesting
  Future<void> reset() async {
    _entries.clear();
    _probeMemo.clear();
    _inFlight.clear();
    _loaded = false;
    _loadingFuture = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// Invalidates every verdict. Call this whenever the installed provider list
  /// changes, because availability is entirely provider-dependent.
  Future<void> invalidateAll() async {
    _entries.clear();
    _probeMemo.clear();
    _inFlight.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// Stable cache key for an item, independent of which provider produced it.
  static String cacheKeyFor(MediaItem item) {
    final title = item.cleanTitle.isNotEmpty ? item.cleanTitle : item.title;
    final normalized = MediaItem.normalizeTitleForMatching(title);
    final year = item.year?.trim() ?? '';
    return '$normalized|$year|${item.isSeries ? 's' : 'm'}';
  }

  /// A provider-sourced item came from an installed provider's own index, so it
  /// is playable by construction and needs no probing.
  static bool isProviderSourced(MediaItem item) {
    final provider = ProviderRegistry().resolveProvider(
      item.effectiveProviderId,
    );
    if (provider == null || !provider.isEnabled || !provider.supportsStreams) {
      return false;
    }
    return provider.supportsCatalogFeeds || provider.supportsSearch;
  }

  /// Whether [item] is currently known to be playable.
  Future<bool> isAvailable(MediaItem item) async {
    if (isProviderSourced(item)) return true;

    final key = cacheKeyFor(item);
    if (key.startsWith('|')) return false; // Untitled item: nothing to look up.

    await _ensureLoaded();

    final cached = _entries[key];
    if (cached != null && !_isExpired(cached)) return cached.available;

    final existing = _inFlight[key];
    if (existing != null) return existing;

    final probe = _probe(item)
        .then((available) {
          _entries[key] = _AvailabilityEntry(
            available: available,
            checkedAt: DateTime.now(),
          );
          _schedulePersist();
          return available;
        })
        // Must not return the removed future: whenComplete awaits a returned
        // future, and the removed value is this very future, which deadlocks.
        .whenComplete(() {
          _inFlight.remove(key);
        });

    _inFlight[key] = probe;
    return probe;
  }

  /// Filters [items] down to the ones that are actually playable, preserving
  /// the original order.
  ///
  /// Items that are already provider-sourced are passed through untouched and
  /// cost nothing; only metadata-sourced items are probed, with bounded
  /// concurrency so a large feed cannot stampede the network.
  Future<List<MediaItem>> filterAvailable(
    Iterable<MediaItem> items, {
    void Function(MediaItem item, bool available)? onVerdict,
  }) async {
    final source = items.toList(growable: false);
    if (source.isEmpty) return const [];

    final results = List<bool>.filled(source.length, false);

    // Trusted items short-circuit without any I/O.
    final pending = <int>[];
    for (var i = 0; i < source.length; i++) {
      if (isProviderSourced(source[i])) {
        results[i] = true;
        onVerdict?.call(source[i], true);
      } else {
        pending.add(i);
      }
    }

    if (pending.isNotEmpty) {
      var cursor = 0;
      final workers = List<Future<void>>.generate(
        maxConcurrentItems < pending.length
            ? maxConcurrentItems
            : pending.length,
        (_) async {
          while (true) {
            final index = cursor < pending.length ? pending[cursor++] : -1;
            if (index < 0) return;
            final item = source[index];
            var available = false;
            try {
              available = await isAvailable(item);
            } catch (e) {
              debugPrint(
                '[StreamAvailability] Probe failed for ${item.title}: $e',
              );
            }
            results[index] = available;
            onVerdict?.call(item, available);
          }
        },
      );
      await Future.wait(workers);
    }

    final filtered = <MediaItem>[];
    for (var i = 0; i < source.length; i++) {
      if (results[i]) filtered.add(source[i]);
    }
    return filtered;
  }

  /// Probes every installed provider that can search, in priority order, and
  /// stops at the first provider that recognises the title.
  ///
  /// When no installed provider exposes a searchable index (for example the
  /// user only added Stremio/Torrentio-style addons, which resolve streams from
  /// an id), the title is verified by asking those providers for streams
  /// directly. That is the accurate check, so it is used only as a fallback
  /// because it costs a real resolve.
  Future<bool> _probe(MediaItem item) async {
    final registry = ProviderRegistry();
    final applicable = registry.streamProviders
        .where((p) => item.isSeries ? p.supportsSeries : p.supportsMovies)
        .toList(growable: false);

    if (applicable.isEmpty) {
      // Nothing installed can play anything, so playability is unknown and
      // unknown is not "available".
      return false;
    }

    final title = item.cleanTitle.isNotEmpty ? item.cleanTitle : item.title;
    if (title.trim().isEmpty) return false;

    final searchable = applicable
        .where((p) => p.supportsSearch)
        .toList(growable: false);

    if (searchable.isNotEmpty &&
        await _probeViaSearch(item, title, searchable)) {
      return true;
    }

    final resolvers = applicable
        .where((p) => !p.supportsSearch)
        .toList(growable: false);
    if (resolvers.isEmpty) return false;

    return _probeViaResolution(item, title, resolvers);
  }

  /// Cheap check: does any provider's own index know this title?
  Future<bool> _probeViaSearch(
    MediaItem item,
    String title,
    List<MediaProviderPlugin> providers,
  ) async {
    for (final provider in providers) {
      final memoKey =
          '${ProviderRegistry.providerMatchKey(provider.id)}|'
          '${MediaItem.normalizeTitleForMatching(title)}|'
          '${item.year?.trim() ?? ''}|${item.isSeries ? 's' : 'm'}';

      final memo = _probeMemo[memoKey];
      if (memo != null && !_isExpired(memo)) {
        if (memo.available) return true;
        continue;
      }

      var matched = false;
      try {
        final matches = await provider.search(title).timeout(probeTimeout);
        if (matches.isNotEmpty) {
          matched =
              MediaItem.findBestMatch(
                candidates: matches,
                title: title,
                year: item.year,
                isSeries: item.isSeries,
              ) !=
              null;
        }
      } catch (e) {
        debugPrint(
          '[StreamAvailability] ${provider.name} search failed for "$title": $e',
        );
      }

      _probeMemo[memoKey] = _AvailabilityEntry(
        available: matched,
        checkedAt: DateTime.now(),
      );
      if (matched) return true;
    }
    return false;
  }

  /// Accurate check: can any provider actually hand back a stream?
  Future<bool> _probeViaResolution(
    MediaItem item,
    String title,
    List<MediaProviderPlugin> providers,
  ) async {
    final attempts = providers.map((provider) async {
      try {
        final streams = await provider
            .getStreams(
              subjectId: item.id,
              title: title,
              year: item.year,
              imdbId: item.isTmdb ? null : item.id,
              isSeries: item.isSeries,
            )
            .timeout(probeTimeout);
        return streams.any((s) => s.url.isNotEmpty);
      } catch (e) {
        debugPrint(
          '[StreamAvailability] ${provider.name} resolve failed for "$title": $e',
        );
        return false;
      }
    });

    final verdicts = await Future.wait(attempts);
    return verdicts.any((v) => v);
  }

  static bool _isExpired(_AvailabilityEntry entry) {
    final ttl = entry.available ? positiveTtl : negativeTtl;
    return DateTime.now().difference(entry.checkedAt) > ttl;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final pending = _loadingFuture;
    if (pending != null) return pending;

    final future = _load();
    _loadingFuture = future;
    return future;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        final now = DateTime.now();
        decoded.forEach((key, value) {
          if (value is! Map) return;
          final entry = _AvailabilityEntry(
            available: value['a'] == true,
            checkedAt: DateTime.tryParse(value['t']?.toString() ?? '') ?? now,
          );
          if (!_isExpired(entry)) _entries[key] = entry;
        });
      }
    } catch (e) {
      debugPrint('[StreamAvailability] Failed to load cached verdicts: $e');
    } finally {
      _loaded = true;
      _loadingFuture = null;
    }
  }

  /// Coalesces bursts of verdicts into a single disk write.
  void _schedulePersist() {
    if (_persistScheduled) return;
    _persistScheduled = true;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 800), () {
      _persistScheduled = false;
      unawaited(_persist());
    });
  }

  Future<void> _persist() async {
    try {
      if (_entries.length > maxEntries) {
        final sorted = _entries.entries.toList()
          ..sort((a, b) => a.value.checkedAt.compareTo(b.value.checkedAt));
        for (final stale in sorted.take(_entries.length - maxEntries)) {
          _entries.remove(stale.key);
        }
      }

      final payload = <String, dynamic>{
        for (final entry in _entries.entries)
          entry.key: {
            'a': entry.value.available,
            't': entry.value.checkedAt.toIso8601String(),
          },
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, json.encode(payload));
    } catch (e) {
      debugPrint('[StreamAvailability] Failed to persist verdicts: $e');
    }
  }
}
