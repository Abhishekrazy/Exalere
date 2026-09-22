import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/services/provider_registry.dart';

/// Test mock plugin implementing the generic MediaProviderPlugin contract
class MockCommunityPlugin extends MediaProviderPlugin {
  @override
  String get id => 'mock_community';

  @override
  String get name => 'Community Mock Provider';

  @override
  int get priority => 95;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  @override
  bool get supportsSubtitles => true;

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
    return [
      const StreamSource(
        quality: '1080p',
        resolution: '1920x1080',
        format: 'MP4',
        url: 'https://cdn.mockcommunity.org/stream/1080p.mp4',
        server: 'Mock CDN Europe',
        providerId: 'mock_community',
        providerName: 'Community Mock Provider',
      ),
    ];
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
    return [
      const SubtitleOption(
        language: 'en',
        name: 'English',
        url: 'https://cdn.mockcommunity.org/subs/en.vtt',
      ),
      const SubtitleOption(
        language: 'es',
        name: 'Spanish',
        url: 'https://cdn.mockcommunity.org/subs/es.vtt',
      ),
    ];
  }

  @override
  Future<List<MediaItem>> search(String query) async {
    return [
      MediaItem(
        id: 'mock_101',
        title: 'Mock Movie 2026',
        mediaType: MediaType.movie,
        year: '2026',
        provider: ProviderType.plugins,
        providerId: id,
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Generic MediaProviderPlugin Contract & Registry Tests', () {
    late ProviderRegistry registry;
    late MockCommunityPlugin mockPlugin;

    setUp(() {
      registry = ProviderRegistry();
      registry.clearAll();
      mockPlugin = MockCommunityPlugin();
      registry.registerProvider(mockPlugin);
    });

    tearDown(() {
      registry.clearAll();
    });

    test('Plugin registers and conforms to generic contract', () {
      final provider = registry.getProvider('mock_community');
      expect(provider, isNotNull);
      expect(provider!.name, equals('Community Mock Provider'));
      expect(provider.supportsSubtitles, isTrue);
      expect(provider.supportsSearch, isTrue);
      expect(provider.supportsMovies, isTrue);
      expect(provider.supportsSeries, isTrue);
    });

    test(
      'ProviderRegistry resolves streams generically across plugins',
      () async {
        final streams = await registry.resolveStreams(
          subjectId: 'tt9999999',
          title: 'Mock Movie',
          year: '2026',
        );

        expect(streams.isNotEmpty, isTrue);
        expect(streams.first.providerId, equals('mock_community'));
        expect(streams.first.quality, equals('1080p'));
        expect(streams.first.url, contains('mockcommunity.org'));
      },
    );

    test('ProviderRegistry fetches subtitles generically without knowing plugin type', () async {
      final subtitles = await registry.getSubtitles(
        subjectId: 'tt9999999',
        title: 'Mock Movie',
        year: '2026',
      );

      expect(subtitles.length, equals(2));
      expect(subtitles[0].name, equals('English'));
      expect(subtitles[0].url, contains('subs/en.vtt'));
      expect(subtitles[1].name, equals('Spanish'));
    });
  });
}
