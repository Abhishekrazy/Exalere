import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exalere/services/tmdb_service.dart';
import 'package:exalere/models/media_details.dart';

class RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = RealHttpOverrides();

  group('TmdbService', () {
    final service = TmdbService();

    test('cleanTitle strips resolution and tags correctly', () {
      expect(
        service.cleanTitle('[Hindi] Inception (2010) [1080p] [BluRay]'),
        equals('Inception'),
      );
      expect(
        service.cleanTitle('Stranger Things 4K UHD HDR'),
        equals('Stranger Things'),
      );
      expect(
        service.cleanTitle('Interstellar (4K HEVC Dual Audio)'),
        equals('Interstellar'),
      );
    });

    test('getSearchCandidates produces smart candidate variations', () {
      final gdnCandidates = service.getSearchCandidates('G.D.N.');
      expect(gdnCandidates.contains('G.D.N.'), isTrue);
      expect(gdnCandidates.contains('G.D.N'), isTrue);
      expect(gdnCandidates.contains('GDN'), isTrue);

      final rrrCandidates = service.getSearchCandidates('R.R.R.');
      expect(rrrCandidates.contains('RRR'), isTrue);

      final punctuationCandidates = service.getSearchCandidates(
        'Movie Title: The Sequel -',
      );
      expect(punctuationCandidates.any((c) => !c.endsWith('-')), isTrue);
    });

    test('TmdbCastMember parses role correctly', () {
      final json = {
        'id': 12345,
        'name': 'Leonardo DiCaprio',
        'character': 'Dom Cobb',
        'profile_path': '/wo2SYRgizvMyAJvdvs5bSwALOmm.jpg',
      };
      final cast = TmdbCastMember.fromJson(json);
      expect(cast.name, equals('Leonardo DiCaprio'));
      expect(cast.character, equals('Dom Cobb'));
      expect(cast.profileUrl, contains('image.tmdb.org'));
    });

    test('TmdbCrewMember parses and serializes correctly', () {
      const crew = TmdbCrewMember(
        name: 'Destin Daniel Cretton',
        role: 'Director',
        profilePath: '/director_profile.jpg',
      );
      expect(crew.name, equals('Destin Daniel Cretton'));
      expect(crew.role, equals('Director'));
      expect(
        crew.profileUrl,
        equals('https://image.tmdb.org/t/p/w185/director_profile.jpg'),
      );

      final json = crew.toJson();
      final fromJson = TmdbCrewMember.fromJson(json);
      expect(fromJson.name, equals('Destin Daniel Cretton'));
      expect(fromJson.role, equals('Director'));
      expect(fromJson.profilePath, equals('/director_profile.jpg'));
    });

    test('TmdbEnrichedDetails model properties and JSON roundtrip for persistent caching', () {
      const details = TmdbEnrichedDetails(
        id: 27205,
        title: 'Spider-Man: Brand New Day',
        overview: 'Peter Parker begins a brand new chapter in his life.',
        tagline: 'A brand new day starts now.',
        rating: 7.9,
        voteCount: 1420,
        userScore: 79,
        runtimeMinutes: 145,
        formattedRuntime: '2h 25m',
        releaseDateWithCountry: '07/30/2026 (IN)',
        certification: 'U/A 13+',
        director: 'Destin Daniel Cretton',
        trailerYoutubeKey: 'YoHD9XEInc0',
        posterPath: '/spiderman_poster.jpg',
        backdropPath: '/spiderman_backdrop.jpg',
        genres: ['Action', 'Adventure', 'Science Fiction'],
        releaseDate: '2026-07-30',
        crew: [
          TmdbCrewMember(name: 'Destin Daniel Cretton', role: 'Director'),
          TmdbCrewMember(name: 'Stan Lee', role: 'Characters'),
          TmdbCrewMember(name: 'Steve Ditko', role: 'Characters'),
          TmdbCrewMember(name: 'Chris McKenna', role: 'Writer'),
          TmdbCrewMember(name: 'Erik Sommers', role: 'Writer'),
        ],
        cast: [
          TmdbCastMember(
            id: 1136406,
            name: 'Tom Holland',
            character: 'Peter Parker / Spider-Man',
          ),
          TmdbCastMember(
            id: 505710,
            name: 'Zendaya',
            character: 'Michelle "MJ" Jones',
          ),
        ],
      );

      // Verify property accessors
      expect(
        details.trailerUrl,
        equals('https://www.youtube.com/watch?v=YoHD9XEInc0'),
      );
      expect(
        details.posterUrl,
        contains('image.tmdb.org/t/p/w500/spiderman_poster.jpg'),
      );
      expect(
        details.backdropUrl,
        contains('image.tmdb.org/t/p/w1280/spiderman_backdrop.jpg'),
      );
      expect(details.userScore, equals(79));
      expect(details.formattedRuntime, equals('2h 25m'));
      expect(details.releaseDateWithCountry, equals('07/30/2026 (IN)'));
      expect(details.certification, equals('U/A 13+'));
      expect(details.tagline, equals('A brand new day starts now.'));
      expect(details.crew.length, equals(5));
      expect(details.crew.first.name, equals('Destin Daniel Cretton'));
      expect(details.crew.first.role, equals('Director'));

      // Test JSON roundtrip (the format cached in SharedPreferences disk storage)
      final jsonMap = details.toJson();
      final jsonString = jsonEncode(jsonMap);

      // Verify that NO image binary is in the JSON, only links and text
      expect(jsonString.contains('image.tmdb.org'), isFalse);
      expect(jsonString.contains('A brand new day starts now.'), isTrue);
      expect(jsonString.contains('07/30/2026 (IN)'), isTrue);
      expect(jsonString.contains('2h 25m'), isTrue);

      final restored = TmdbEnrichedDetails.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );
      expect(restored.id, equals(27205));
      expect(restored.title, equals('Spider-Man: Brand New Day'));
      expect(
        restored.overview,
        equals('Peter Parker begins a brand new chapter in his life.'),
      );
      expect(restored.tagline, equals('A brand new day starts now.'));
      expect(restored.userScore, equals(79));
      expect(restored.formattedRuntime, equals('2h 25m'));
      expect(restored.releaseDateWithCountry, equals('07/30/2026 (IN)'));
      expect(restored.certification, equals('U/A 13+'));
      expect(restored.crew.length, equals(5));
      expect(restored.crew[1].name, equals('Stan Lee'));
      expect(restored.crew[1].role, equals('Characters'));
      expect(restored.cast.length, equals(2));
      expect(restored.cast[0].name, equals('Tom Holland'));
    });

    test(
      'Persistent disk cache retrieves stored JSON without network hit',
      () async {
        SharedPreferences.setMockInitialValues({
          'tmdb_meta_the matrix-1999-false': jsonEncode(
            const TmdbEnrichedDetails(
              id: 603,
              title: 'The Matrix',
              userScore: 82,
              formattedRuntime: '2h 16m',
              releaseDateWithCountry: '03/30/1999 (US)',
              tagline: 'Welcome to the Real World.',
              certification: 'R',
            ).toJson(),
          ),
        });

        final cached = await service.getEnrichedDetails(
          title: 'The Matrix',
          year: '1999',
          isSeries: false,
        );

        expect(cached, isNotNull);
        expect(cached!.id, equals(603));
        expect(cached.title, equals('The Matrix'));
        expect(cached.userScore, equals(82));
        expect(cached.formattedRuntime, equals('2h 16m'));
        expect(cached.releaseDateWithCountry, equals('03/30/1999 (US)'));
        expect(cached.tagline, equals('Welcome to the Real World.'));
        expect(cached.certification, equals('R'));
      },
    );

    test('TmdbEpisodeInfo parses and constructs 16:9 thumbnail still URL', () {
      const ep = TmdbEpisodeInfo(
        episodeNumber: 1,
        name: 'Chapter One: The Vanishing of Will Byers',
        overview: 'On his way home from a friend house, Will sees something terrifying.',
        stillPath: '/6jSA6JpxNDV63aDXpmsUFCjCINb.jpg',
      );

      expect(ep.episodeNumber, equals(1));
      expect(ep.name, equals('Chapter One: The Vanishing of Will Byers'));
      expect(
        ep.stillUrl,
        equals(
          'https://image.tmdb.org/t/p/w500/6jSA6JpxNDV63aDXpmsUFCjCINb.jpg',
        ),
      );

      final json = ep.toJson();
      final fromJson = TmdbEpisodeInfo.fromJson(json);
      expect(fromJson.episodeNumber, equals(1));
      expect(fromJson.name, equals('Chapter One: The Vanishing of Will Byers'));
      expect(
        fromJson.stillUrl,
        equals(
          'https://image.tmdb.org/t/p/w500/6jSA6JpxNDV63aDXpmsUFCjCINb.jpg',
        ),
      );
    });

    test('getSeasonEpisodes retrieves cached episode stills from persistent disk storage', () async {
      final mockSeason = [
        const TmdbEpisodeInfo(
          episodeNumber: 1,
          name: 'Winter Is Coming',
          overview: 'Ned Stark is torn between his family and an old friend.',
          stillPath: '/wrGWeW4WKxnaeA8sxJb2T9Ofl2R.jpg',
        ).toJson(),
        const TmdbEpisodeInfo(
          episodeNumber: 2,
          name: 'The Kingsroad',
          overview: 'Bran survival remains in doubt.',
          stillPath: '/9GvhICFhYST6GUMcW3eq2e6a3vL.jpg',
        ).toJson(),
      ];

      SharedPreferences.setMockInitialValues({
        'tmdb_season_episodes_1399_1': jsonEncode(mockSeason),
      });

      final episodes = await service.getSeasonEpisodes(
        tvId: 1399,
        seasonNumber: 1,
      );
      expect(episodes.length, equals(2));
      expect(episodes[1]?.name, equals('Winter Is Coming'));
      expect(
        episodes[1]?.stillUrl,
        equals(
          'https://image.tmdb.org/t/p/w500/wrGWeW4WKxnaeA8sxJb2T9Ofl2R.jpg',
        ),
      );
      expect(episodes[2]?.name, equals('The Kingsroad'));
      expect(
        episodes[2]?.stillUrl,
        equals(
          'https://image.tmdb.org/t/p/w500/9GvhICFhYST6GUMcW3eq2e6a3vL.jpg',
        ),
      );
    });

    test('TmdbEnrichedDetails correctly persists and restores imdbId', () {
      const details = TmdbEnrichedDetails(
        id: 66732,
        title: 'Stranger Things',
        imdbId: 'tt4574334',
      );

      final json = details.toJson();
      expect(json['imdbId'], equals('tt4574334'));

      final restored = TmdbEnrichedDetails.fromJson(json);
      expect(restored.imdbId, equals('tt4574334'));
    });

    test(
      'getEpisodeIntroSkip reads verified interval from disk cache',
      () async {
        const verifiedSkip = SkipInterval(
          type: SkipType.intro,
          startSeconds: 505,
          endSeconds: 555,
          label: 'Skip Intro',
        );

        SharedPreferences.setMockInitialValues({
          'intro_skip_stranger things_s1_e1': jsonEncode(verifiedSkip.toJson()),
        });

        final result = await service.getEpisodeIntroSkip(
          title: 'Stranger Things',
          season: 1,
          episode: 1,
          imdbId: 'tt4574334',
        );

        expect(result, isNotNull);
        expect(result!.startSeconds, equals(505));
        expect(result.endSeconds, equals(555));
        expect(result.type, equals(SkipType.intro));
      },
    );

    test('getEpisodeIntroSkip handles null cache gracefully returning no skip interval', () async {
      SharedPreferences.setMockInitialValues({
        'intro_skip_nonexistent show_s1_e1': 'null',
      });

      final result = await service.getEpisodeIntroSkip(
        title: 'Nonexistent Show',
        season: 1,
        episode: 1,
        imdbId: 'tt0000000',
      );

      expect(result, isNull);
    });

    test('getEnrichedDetails fetches G.D.N. (2026) with automatic fallback and candidate search', () async {
      if (TmdbService.apiKey.isEmpty) {
        // Live network test requires TMDB API key supplied via dart-define
        return;
      }
      final details = await service.getEnrichedDetails(
        title: 'G.D.N.',
        year: '2026',
      );

      expect(details, isNotNull);
      expect(details!.id, equals(1489543));
      expect(details.title, equals('G.D.N'));
      expect(details.tagline, equals('Edison Of India'));
      expect(details.director, equals('Krishnakumar Ramakumar'));
      expect(details.trailerYoutubeKey, isNotEmpty);
      expect(details.cast.any((c) => c.name.contains('Madhavan')), isTrue);
      expect(details.formattedRuntime, equals('2h 26m'));
    });
  });
}
