import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/services/provider_registry.dart';
import 'package:exalere/services/stream_availability_service.dart';

/// A stream provider whose search index is a fixed list of titles.
class _FakeProvider extends MediaProviderPlugin {
  _FakeProvider({
    required this.id,
    required this.titles,
    this.years = const {},
    this.searchable = true,
    this.streamable = true,
  });

  @override
  final String id;
  final List<String> titles;

  /// Release year per title; a title with no entry has an unknown year.
  final Map<String, String> years;
  final bool searchable;
  final bool streamable;

  int searchCalls = 0;
  int streamCalls = 0;

  @override
  String get name => 'Fake $id';

  @override
  bool get supportsSearch => searchable;

  @override
  bool get supportsCatalogFeeds => true;

  @override
  bool get supportsStreams => streamable;

  @override
  Future<List<MediaItem>> search(String query) async {
    searchCalls++;
    final needle = MediaItem.normalizeTitleForMatching(query);
    return titles
        .where((t) => MediaItem.normalizeTitleForMatching(t).contains(needle))
        .map(
          (t) => MediaItem(
            id: '${id}_${MediaItem.normalizeTitleForMatching(t)}',
            title: t,
            mediaType: MediaType.movie,
            year: years[t],
            providerId: id,
          ),
        )
        .toList();
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
    streamCalls++;
    final wanted = MediaItem.normalizeTitleForMatching(title ?? '');
    final known =
        wanted.isNotEmpty &&
        titles.any((t) => MediaItem.normalizeTitleForMatching(t) == wanted);
    if (!known) return const [];
    return [
      StreamSource(
        quality: '1080p',
        resolution: '1920x1080',
        format: 'MP4',
        url: 'https://cdn.example/$id.mp4',
      ),
    ];
  }
}

/// A metadata-sourced item, exactly how TMDB discovery produces them.
MediaItem _metadataItem(String title, {String year = '2024'}) => MediaItem(
  id: '12345',
  title: title,
  mediaType: MediaType.movie,
  year: year,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ProviderRegistry().clearAll();
    await StreamAvailabilityService().reset();
  });

  tearDown(() {
    ProviderRegistry().clearAll();
  });

  group('ProviderRegistry.providerMatchKey', () {
    test('bridges legacy engine tags and manifest ids', () {
      expect(ProviderRegistry.providerMatchKey('moviebox'), 'moviebox');
      expect(
        ProviderRegistry.providerMatchKey('org.exalere.moviebox'),
        'moviebox',
      );
      expect(ProviderRegistry.providerMatchKey('fourkhdhub'), 'fourkhd');
      expect(
        ProviderRegistry.providerMatchKey('org.exalere.fourkhd'),
        'fourkhd',
      );
      expect(ProviderRegistry.providerMatchKey('4khd'), 'fourkhd');
      expect(ProviderRegistry.providerMatchKey('dramachi'), 'dramachi');
      expect(ProviderRegistry.providerMatchKey('vidsrc'), 'vidsrc');
      expect(ProviderRegistry.providerMatchKey('circleftp'), 'circleftp');
    });

    test('keeps unrelated addon ids distinct', () {
      expect(
        ProviderRegistry.providerMatchKey('com.stremio.torrentio.addon'),
        isNot(ProviderRegistry.providerMatchKey('org.stremio.watchhub')),
      );
      expect(ProviderRegistry.providerMatchKey('tmdb'), 'tmdb');
    });
  });

  group('ProviderRegistry.resolveProvider', () {
    test('resolves an item tag to the installed plugin id', () {
      final provider = _FakeProvider(
        id: 'org.exalere.moviebox',
        titles: const ['Dune'],
      );
      ProviderRegistry().registerProvider(provider);

      // Catalog items from the MovieBox engine are tagged with the short id.
      expect(ProviderRegistry().resolveProvider('moviebox'), same(provider));
      expect(
        ProviderRegistry().resolveProvider('org.exalere.moviebox'),
        same(provider),
      );
      expect(ProviderRegistry().resolveProvider('nope'), isNull);
      expect(ProviderRegistry().resolveProvider(null), isNull);
    });
  });

  group('ProviderRegistry.streamProviders', () {
    test('excludes metadata-only addons', () {
      ProviderRegistry().registerProvider(
        _FakeProvider(
          id: 'com.linvo.cinemeta',
          titles: const [],
          streamable: false,
        ),
      );
      ProviderRegistry().registerProvider(
        _FakeProvider(id: 'com.stremio.torrentio.addon', titles: const []),
      );

      final ids = ProviderRegistry().streamProviders.map((p) => p.id).toList();
      expect(ids, contains('com.stremio.torrentio.addon'));
      expect(ids, isNot(contains('com.linvo.cinemeta')));
      expect(ProviderRegistry().hasStreamProviders, isTrue);
    });

    test('is false when only metadata-only addons are installed', () {
      ProviderRegistry().registerProvider(
        _FakeProvider(
          id: 'com.linvo.cinemeta',
          titles: const [],
          streamable: false,
        ),
      );
      expect(ProviderRegistry().hasStreamProviders, isFalse);
      expect(ProviderRegistry().catalogProviders, isEmpty);
    });
  });

  group('StreamAvailabilityService', () {
    test('trusts titles that came from an installed provider index', () async {
      ProviderRegistry().registerProvider(
        _FakeProvider(id: 'org.exalere.moviebox', titles: const ['Dune']),
      );

      final fromProvider = MediaItem(
        id: '9988776655',
        title: 'Dune',
        mediaType: MediaType.movie,
        year: '2021',
        providerId: 'moviebox', // short engine tag
      );

      expect(StreamAvailabilityService.isProviderSourced(fromProvider), isTrue);
      expect(
        await StreamAvailabilityService().isAvailable(fromProvider),
        isTrue,
      );
    });

    test('does not trust metadata-only items', () async {
      ProviderRegistry().registerProvider(
        _FakeProvider(id: 'org.exalere.moviebox', titles: const ['Dune']),
      );

      final tmdbItem = _metadataItem('Some Obscure Film');
      expect(StreamAvailabilityService.isProviderSourced(tmdbItem), isFalse);
      expect(await StreamAvailabilityService().isAvailable(tmdbItem), isFalse);
    });

    test('keeps playable metadata items and drops dead ends', () async {
      final provider = _FakeProvider(
        id: 'org.exalere.moviebox',
        titles: const ['Dune', 'Arrival'],
        years: const {'Dune': '2021', 'Arrival': '2016'},
      );
      ProviderRegistry().registerProvider(provider);

      final items = [
        _metadataItem('Dune', year: '2021'),
        _metadataItem('Nonexistent Movie'),
        _metadataItem('Arrival', year: '2016'),
      ];

      final kept = await StreamAvailabilityService().filterAvailable(items);

      expect(kept.map((i) => i.title), ['Dune', 'Arrival']);
      // One search per distinct title, never one per shelf occurrence.
      expect(provider.searchCalls, lessThanOrEqualTo(3));
    });

    test('treats a year mismatch as a different, unavailable title', () async {
      ProviderRegistry().registerProvider(
        _FakeProvider(
          id: 'org.exalere.moviebox',
          titles: const ['Dune'],
          years: const {'Dune': '2021'},
        ),
      );

      // The 1984 film is a different title from the 2021 one, so a provider
      // holding only the 2021 release must not mark it available.
      expect(
        await StreamAvailabilityService().isAvailable(
          _metadataItem('Dune', year: '1984'),
        ),
        isFalse,
      );
      expect(
        await StreamAvailabilityService().isAvailable(
          _metadataItem('Dune', year: '2021'),
        ),
        isTrue,
      );
    });

    test('caches verdicts across calls', () async {
      final provider = _FakeProvider(
        id: 'org.exalere.moviebox',
        titles: const ['Dune'],
        years: const {'Dune': '2021'},
      );
      ProviderRegistry().registerProvider(provider);

      final item = _metadataItem('Dune', year: '2021');
      expect(await StreamAvailabilityService().isAvailable(item), isTrue);
      final callsAfterFirst = provider.searchCalls;

      expect(await StreamAvailabilityService().isAvailable(item), isTrue);
      expect(provider.searchCalls, callsAfterFirst);
    });

    test('reports everything as unavailable when nothing can play', () async {
      final kept = await StreamAvailabilityService().filterAvailable([
        _metadataItem('Dune'),
        _metadataItem('Arrival'),
      ]);
      expect(kept, isEmpty);
    });

    test(
      'verifies via a real resolve when the provider cannot search',
      () async {
        // Addons such as Torrentio expose no search index; the only honest check
        // is asking them for streams.
        final provider = _FakeProvider(
          id: 'com.stremio.torrentio.addon',
          titles: const ['Dune'],
          searchable: false,
        );
        ProviderRegistry().registerProvider(provider);

        expect(
          await StreamAvailabilityService().isAvailable(
            _metadataItem('Dune', year: '2021'),
          ),
          isTrue,
        );
        expect(provider.streamCalls, greaterThan(0));
        expect(provider.searchCalls, 0);
      },
    );

    test('a non-searchable provider still rejects titles it lacks', () async {
      final provider = _FakeProvider(
        id: 'com.stremio.torrentio.addon',
        titles: const ['Dune'],
        searchable: false,
      );
      ProviderRegistry().registerProvider(provider);

      expect(
        await StreamAvailabilityService().isAvailable(
          _metadataItem('Something Else'),
        ),
        isFalse,
      );
      expect(provider.streamCalls, greaterThan(0));
    });

    test('isProviderSourced ignores providers that cannot stream', () {
      ProviderRegistry().registerProvider(
        _FakeProvider(
          id: 'community.anime.kitsu',
          titles: const ['Naruto'],
          streamable: false,
        ),
      );
      final item = MediaItem(
        id: 'kitsu:1',
        title: 'Naruto',
        mediaType: MediaType.series,
        providerId: 'community.anime.kitsu',
      );
      expect(StreamAvailabilityService.isProviderSourced(item), isFalse);
    });

    test('cache keys are provider independent and type aware', () {
      final movie = _metadataItem('Dune', year: '2021');
      final asSeries = MediaItem(
        id: '999',
        title: 'Dune',
        mediaType: MediaType.series,
        year: '2021',
      );
      final tagged = MediaItem(
        id: 'moviebox_1',
        title: 'Dune',
        mediaType: MediaType.movie,
        year: '2021',
        providerId: 'moviebox',
      );

      expect(
        StreamAvailabilityService.cacheKeyFor(movie),
        StreamAvailabilityService.cacheKeyFor(tagged),
      );
      expect(
        StreamAvailabilityService.cacheKeyFor(movie),
        isNot(StreamAvailabilityService.cacheKeyFor(asSeries)),
      );
    });

    test('invalidateAll clears cached verdicts', () async {
      final provider = _FakeProvider(
        id: 'org.exalere.moviebox',
        titles: const ['Dune'],
        years: const {'Dune': '2021'},
      );
      ProviderRegistry().registerProvider(provider);

      final item = _metadataItem('Dune', year: '2021');
      await StreamAvailabilityService().isAvailable(item);
      final before = provider.searchCalls;

      await StreamAvailabilityService().invalidateAll();
      await StreamAvailabilityService().isAvailable(item);

      expect(provider.searchCalls, greaterThan(before));
    });
  });
}
