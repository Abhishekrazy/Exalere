import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/services/provider_registry.dart';

class _FakeMovieBoxPlugin extends MediaProviderPlugin {
  @override
  String get id => 'moviebox';

  @override
  String get name => 'MovieBox Engine';

  @override
  int get priority => 100;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  final Map<String, List<StreamSource>> subjectStreams = {};
  final List<MediaItem> searchCatalog = [];

  @override
  Future<List<MediaItem>> search(String query) async {
    return searchCatalog
        .where(
          (item) =>
              item.title.toLowerCase().contains(query.toLowerCase()) ||
              query.toLowerCase().contains(item.title.toLowerCase()),
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
    // If native moviebox ID, lookup directly
    if (originProviderId == 'moviebox' &&
        subjectStreams.containsKey(subjectId)) {
      return subjectStreams[subjectId]!;
    }

    // Otherwise cross-provider title + year resolution
    if (title != null && title.isNotEmpty) {
      final matches = await search(title);
      final best = MediaItem.findBestMatch(
        candidates: matches,
        title: title,
        year: year,
        isSeries: isSeries,
      );
      if (best != null && subjectStreams.containsKey(best.id)) {
        return subjectStreams[best.id]!;
      }
    }

    return [];
  }
}

class _FakeFourKHdHubPlugin extends MediaProviderPlugin {
  @override
  String get id => 'fourkhdhub';

  @override
  String get name => '4K HD Hub';

  @override
  int get priority => 50;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  final Map<String, List<StreamSource>> pathStreams = {};
  final List<MediaItem> searchCatalog = [];

  @override
  Future<List<MediaItem>> search(String query) async {
    return searchCatalog
        .where(
          (item) =>
              item.title.toLowerCase().contains(query.toLowerCase()) ||
              query.toLowerCase().contains(item.title.toLowerCase()),
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
    // If native 4khdhub path, lookup directly
    if ((originProviderId == 'fourkhdhub' || subjectId.startsWith('/')) &&
        pathStreams.containsKey(subjectId)) {
      return pathStreams[subjectId]!;
    }

    // Otherwise cross-provider title + year resolution
    if (title != null && title.isNotEmpty) {
      final matches = await search(title);
      final best = MediaItem.findBestMatch(
        candidates: matches,
        title: title,
        year: year,
        isSeries: isSeries,
      );
      if (best != null && pathStreams.containsKey(best.id)) {
        return pathStreams[best.id]!;
      }
    }

    return [];
  }
}

void main() {
  group('Multi-Provider Concurrent Resolution Tests', () {
    late ProviderRegistry registry;
    late _FakeMovieBoxPlugin movieBox;
    late _FakeFourKHdHubPlugin fourKHdHub;

    setUp(() {
      registry = ProviderRegistry();
      registry.clearAll();

      movieBox = _FakeMovieBoxPlugin();
      fourKHdHub = _FakeFourKHdHubPlugin();

      // MovieBox catalog & streams
      movieBox.searchCatalog.addAll([
        MediaItem(
          id: 'mb_avatar_1',
          title: 'Avatar',
          year: '2009',
          mediaType: MediaType.movie,
          providerId: 'moviebox',
        ),
        MediaItem(
          id: 'mb_avatar_2',
          title: 'Avatar: The Way of Water',
          year: '2022',
          mediaType: MediaType.movie,
          providerId: 'moviebox',
        ),
      ]);
      movieBox.subjectStreams['mb_avatar_2'] = [
        StreamSource(
          quality: '1080p',
          resolution: '1920x1080',
          format: 'MP4',
          url: 'https://moviebox.cdn/avatar2_1080p.mp4',
          server: 'MovieBox Engine',
          providerId: 'moviebox',
          providerName: 'MovieBox Engine',
        ),
      ];

      // 4KHDHub catalog & streams
      fourKHdHub.searchCatalog.addAll([
        MediaItem(
          id: '/avatar-2009/',
          title: 'Avatar',
          year: '2009',
          mediaType: MediaType.movie,
          providerId: 'fourkhdhub',
        ),
        MediaItem(
          id: '/avatar-the-way-of-water-2022/',
          title: 'Avatar: The Way of Water',
          year: '2022',
          mediaType: MediaType.movie,
          providerId: 'fourkhdhub',
        ),
      ]);
      fourKHdHub.pathStreams['/avatar-the-way-of-water-2022/'] = [
        StreamSource(
          quality: '4K (2160p)',
          resolution: '3840x2160',
          format: 'MKV',
          url: 'https://hubcloud.stream/avatar2_4k.mkv',
          server: '4K HD Hub (4K • HubCloud)',
          providerId: 'fourkhdhub',
          providerName: '4K HD Hub',
        ),
      ];

      registry.registerProvider(movieBox);
      registry.registerProvider(fourKHdHub);
    });

    tearDown(() {
      registry.clearAll();
      registry.defaultProviderId = null;
    });

    test('resolves streams from BOTH MovieBox and 4KHDHub when item originates from MovieBox', () async {
      // User clicked item on MovieBox home feed
      final streams = await registry.resolveStreams(
        subjectId: 'mb_avatar_2',
        title: 'Avatar: The Way of Water',
        year: '2022',
        originProviderId: 'moviebox',
        isSeries: false,
      );

      // Must return streams from both providers simultaneously
      expect(streams.length, equals(2));

      final providerIds = streams.map((s) => s.effectiveProviderId).toSet();
      expect(providerIds, contains('moviebox'));
      expect(providerIds, contains('fourkhdhub'));

      final serverNames = streams.map((s) => s.effectiveProviderName).toSet();
      expect(serverNames, contains('MovieBox Engine'));
      expect(serverNames, contains('4K HD Hub'));
    });

    test('resolves streams from BOTH MovieBox and 4KHDHub when item originates from 4KHDHub', () async {
      // User clicked item on 4KHDHub search
      final streams = await registry.resolveStreams(
        subjectId: '/avatar-the-way-of-water-2022/',
        title: 'Avatar: The Way of Water',
        year: '2022',
        originProviderId: 'fourkhdhub',
        isSeries: false,
      );

      expect(streams.length, equals(2));

      final providerIds = streams.map((s) => s.effectiveProviderId).toSet();
      expect(providerIds, contains('moviebox'));
      expect(providerIds, contains('fourkhdhub'));
    });

    test('resolves streams from BOTH providers when item originates from TMDB catalog', () async {
      // User clicked item on default TMDB trending catalog
      final streams = await registry.resolveStreams(
        subjectId: '76600', // TMDB ID for Avatar: The Way of Water
        title: 'Avatar: The Way of Water',
        year: '2022',
        originProviderId: 'tmdb',
        isSeries: false,
      );

      expect(streams.length, equals(2));

      final providerIds = streams.map((s) => s.effectiveProviderId).toSet();
      expect(providerIds, contains('moviebox'));
      expect(providerIds, contains('fourkhdhub'));
    });
  });
}
