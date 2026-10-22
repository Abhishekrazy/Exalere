import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/media_item.dart';
import 'package:exalere/plugins/tmdb/tmdb_plugin.dart';
import 'package:exalere/services/provider_registry.dart';

void main() {
  tearDown(() {
    // Leave the registry in its default state for other tests.
    ProviderRegistry().clearAll();
  });

  group('TmdbPlugin capability contract', () {
    final plugin = TmdbPlugin();

    test('is a catalog provider that never resolves streams', () {
      expect(plugin.id, 'tmdb');
      expect(plugin.supportsCatalogFeeds, isTrue);
      expect(plugin.supportsSearch, isTrue);
      expect(plugin.supportsMovies, isTrue);
      expect(plugin.supportsSeries, isTrue);

      // The whole point: metadata only.
      expect(plugin.supportsStreams, isFalse);
    });

    test('refuses to invent a stream', () async {
      expect(await plugin.getStreams(subjectId: '603'), isEmpty);
      expect(
        await plugin.getStreams(
          subjectId: '1399',
          title: 'Game of Thrones',
          season: 1,
          episode: 1,
          isSeries: true,
        ),
        isEmpty,
      );
    });

    test('returns no results for an empty query', () async {
      expect(await plugin.search('   '), isEmpty);
    });

    test(
      'defers details to the TMDB enrichment on the details screens',
      () async {
        expect(await plugin.getDetails('603'), isNull);
      },
    );
  });

  group('ProviderRegistry built-in defaults', () {
    test('always exposes the TMDB catalog, even after clearing', () {
      ProviderRegistry().clearAll();

      final tmdb = ProviderRegistry().resolveProvider('tmdb');
      expect(tmdb, isNotNull);
      expect(tmdb!.id, 'tmdb');
      expect(tmdb.supportsStreams, isFalse);
    });

    test('TMDB is a metadata catalog, not a playback source', () {
      ProviderRegistry().clearAll();

      expect(
        ProviderRegistry().metadataCatalogProviders.map((p) => p.id),
        contains('tmdb'),
      );
      expect(
        ProviderRegistry().streamProviders.map((p) => p.id),
        isNot(contains('tmdb')),
      );
      // Playable catalogs require a stream capability, so TMDB is excluded.
      expect(
        ProviderRegistry().catalogProviders.map((p) => p.id),
        isNot(contains('tmdb')),
      );
    });

    test('a fresh registry has no playable provider', () {
      ProviderRegistry().clearAll();
      expect(ProviderRegistry().hasStreamProviders, isFalse);
    });

    test('an installed stream provider makes playback possible', () {
      ProviderRegistry().clearAll();
      ProviderRegistry().registerProvider(_StreamCapableProvider());

      expect(ProviderRegistry().hasStreamProviders, isTrue);
      expect(
        ProviderRegistry().streamProviders.map((p) => p.id),
        contains('moviebox'),
      );
    });
  });

  group('MediaItem safety for metadata rows', () {
    test('a TMDB-shaped item is not provider sourced', () {
      final item = MediaItem(
        id: '603',
        title: 'The Matrix',
        mediaType: MediaType.movie,
        year: '1999',
      );
      expect(item.effectiveProviderId, 'plugins');
      expect(
        ProviderRegistry().resolveProvider(item.effectiveProviderId),
        isNull,
      );
    });
  });
}

/// Minimal stand-in for an installed engine such as MovieBox.
class _StreamCapableProvider extends TmdbPlugin {
  @override
  String get id => 'moviebox';

  @override
  String get name => 'Fake MovieBox';

  @override
  bool get supportsStreams => true;
}
