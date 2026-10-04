import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/models/app_feature.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/movie_collection.dart';
import 'package:exalere/models/person_details.dart';
import 'package:exalere/models/user_playlist.dart';
import 'package:exalere/providers/library_provider.dart';
import 'package:exalere/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserPlaylist Model & JSON Tests', () {
    test('UserPlaylist serialization and deserialization', () {
      final sampleItem = MediaItem(
        id: 'movie_1',
        title: 'Inception',
        year: '2010',
        posterUrl: 'https://image.tmdb.org/t/p/w500/inception.jpg',
        provider: ProviderType.plugins,
        mediaType: MediaType.movie,
      );

      final playlist = UserPlaylist(
        id: 'pl_100',
        name: 'Mind Benders',
        profileId: 'profile_a',
        createdAt: 1600000000,
        updatedAt: 1600005000,
        items: [sampleItem],
      );

      expect(playlist.itemCount, equals(1));
      expect(
        playlist.coverPosterUrl,
        equals('https://image.tmdb.org/t/p/w500/inception.jpg'),
      );

      final json = playlist.toJson();
      final restored = UserPlaylist.fromJson(json);

      expect(restored.id, equals('pl_100'));
      expect(restored.name, equals('Mind Benders'));
      expect(restored.profileId, equals('profile_a'));
      expect(restored.createdAt, equals(1600000000));
      expect(restored.items.length, equals(1));
      expect(restored.items.first.title, equals('Inception'));
    });

    test('UserPlaylist copyWith updates specified fields', () {
      final playlist = UserPlaylist(
        id: 'pl_1',
        name: 'Original',
        profileId: 'default',
        createdAt: 100,
        updatedAt: 200,
      );

      final updated = playlist.copyWith(name: 'Renamed', updatedAt: 300);
      expect(updated.id, equals('pl_1'));
      expect(updated.name, equals('Renamed'));
      expect(updated.updatedAt, equals(300));
    });
  });

  group('StorageService Custom Playlists Tests', () {
    test(
      'Create, retrieve, and delete user playlists with profile scoping',
      () async {
        final storage = StorageService();

        // Initially empty
        final initial = await storage.getUserPlaylists(profileId: 'user_1');
        expect(initial, isEmpty);

        // Create playlist on user_1
        final created = await storage.createUserPlaylist(
          'Sci-Fi Vault',
          profileId: 'user_1',
        );
        expect(created.name, equals('Sci-Fi Vault'));
        expect(created.profileId, equals('user_1'));

        final listUser1 = await storage.getUserPlaylists(profileId: 'user_1');
        expect(listUser1.length, equals(1));
        expect(listUser1.first.id, equals(created.id));

        // User 2 should have empty playlists (isolated scoping)
        final listUser2 = await storage.getUserPlaylists(profileId: 'user_2');
        expect(listUser2, isEmpty);

        // Add item to user_1 playlist
        final item = MediaItem(
          id: 'matrix_1',
          title: 'The Matrix',
          year: '1999',
          provider: ProviderType.plugins,
          mediaType: MediaType.movie,
        );
        await storage.addToUserPlaylist(created.id, item, profileId: 'user_1');

        final withItem = await storage.getUserPlaylists(profileId: 'user_1');
        expect(withItem.first.items.length, equals(1));
        expect(withItem.first.items.first.id, equals('matrix_1'));

        // Rename playlist
        await storage.renameUserPlaylist(
          created.id,
          'Ultimate Sci-Fi',
          profileId: 'user_1',
        );
        final renamed = await storage.getUserPlaylists(profileId: 'user_1');
        expect(renamed.first.name, equals('Ultimate Sci-Fi'));

        // Remove item
        await storage.removeFromUserPlaylist(
          created.id,
          'matrix_1',
          profileId: 'user_1',
        );
        final removed = await storage.getUserPlaylists(profileId: 'user_1');
        expect(removed.first.items, isEmpty);

        // Delete playlist
        await storage.deleteUserPlaylist(created.id, profileId: 'user_1');
        final emptyAgain = await storage.getUserPlaylists(profileId: 'user_1');
        expect(emptyAgain, isEmpty);
      },
    );
  });

  group('LibraryProvider Playlist Integration Tests', () {
    test(
      'LibraryProvider playlist operations update state and notify listeners',
      () async {
        final library = LibraryProvider();
        await library.init(profileId: 'test_prof');

        expect(library.playlists, isEmpty);

        // Create playlist
        final pl = await library.createPlaylist('Action Classics');
        expect(library.playlists.length, equals(1));
        expect(library.playlists.first.name, equals('Action Classics'));

        final movie = MediaItem(
          id: 'die_hard',
          title: 'Die Hard',
          year: '1988',
          provider: ProviderType.plugins,
          mediaType: MediaType.movie,
        );

        // Add to playlist
        await library.addToPlaylist(pl.id, movie);
        expect(library.isItemInPlaylist(pl.id, 'die_hard'), isTrue);
        expect(library.getPlaylistsContaining('die_hard').length, equals(1));

        // Rename
        await library.renamePlaylist(pl.id, '80s Action');
        expect(library.playlists.first.name, equals('80s Action'));

        // Remove from playlist
        await library.removeFromPlaylist(pl.id, 'die_hard');
        expect(library.isItemInPlaylist(pl.id, 'die_hard'), isFalse);

        // Delete playlist
        await library.deletePlaylist(pl.id);
        expect(library.playlists, isEmpty);
      },
    );
  });

  group('MovieCollection & PersonDetails Models Tests', () {
    test('MovieCollection parses and orders parts chronologically', () {
      final rawJson = {
        'id': 86311,
        'name': 'The Avengers Collection',
        'overview': 'Earth\'s mightiest heroes assembly.',
        'poster_path': '/avengers_poster.jpg',
        'backdrop_path': '/avengers_backdrop.jpg',
        'parts': [
          {
            'id': 299534,
            'title': 'Avengers: Endgame',
            'release_date': '2019-04-24',
            'poster_path': '/endgame.jpg',
            'vote_average': 8.3,
          },
          {
            'id': 24428,
            'title': 'The Avengers',
            'release_date': '2012-04-25',
            'poster_path': '/avengers1.jpg',
            'vote_average': 7.7,
          },
          {
            'id': 299536,
            'title': 'Avengers: Infinity War',
            'release_date': '2018-04-25',
            'poster_path': '/infinity_war.jpg',
            'vote_average': 8.2,
          },
        ],
      };

      final collection = MovieCollection.fromJson(rawJson);
      expect(collection.id, equals(86311));
      expect(collection.name, equals('The Avengers Collection'));
      expect(collection.parts.length, equals(3));

      // Parts should be sorted chronologically by release date
      expect(collection.parts[0].title, equals('The Avengers'));
      expect(collection.parts[0].year, equals('2012'));
      expect(collection.parts[1].title, equals('Avengers: Infinity War'));
      expect(collection.parts[1].year, equals('2018'));
      expect(collection.parts[2].title, equals('Avengers: Endgame'));
      expect(collection.parts[2].year, equals('2019'));
    });

    test('PersonDetails parses bio and filmography correctly', () {
      final rawPersonJson = {
        'id': 3223,
        'name': 'Robert Downey Jr.',
        'biography': 'Robert John Downey Jr. is an American actor.',
        'birthday': '1965-04-04',
        'place_of_birth': 'Manhattan, New York, USA',
        'profile_path': '/rdj.jpg',
        'known_for_department': 'Acting',
        'combined_credits': {
          'cast': [
            {
              'id': 1726,
              'media_type': 'movie',
              'title': 'Iron Man',
              'character': 'Tony Stark / Iron Man',
              'release_date': '2008-04-30',
              'poster_path': '/ironman.jpg',
              'vote_average': 7.6,
              'vote_count': 24000,
            },
            {
              'id': 70785,
              'media_type': 'tv',
              'name': 'The Sympathizer',
              'character': 'Claude / Professor Hammer',
              'first_air_date': '2024-04-14',
              'poster_path': '/sympathizer.jpg',
              'vote_average': 7.3,
            },
          ],
        },
      };

      final person = PersonDetails.fromJson(rawPersonJson);
      expect(person.id, equals(3223));
      expect(person.name, equals('Robert Downey Jr.'));
      expect(person.birthday, equals('1965-04-04'));
      expect(person.movieCredits.length, equals(1));
      expect(person.movieCredits.first.title, equals('Iron Man'));
      expect(person.tvCredits.length, equals(1));
      expect(person.tvCredits.first.title, equals('The Sympathizer'));
    });
  });

  group('Catalog of 6 New Features in AppFeaturesCatalog', () {
    test('All 6 new features are registered and queryable', () {
      final audioDelay = AppFeaturesCatalog.allFeatures.firstWhere(
        (f) => f.id == 'audio_delay_sync',
      );
      expect(audioDelay.title, contains('Audio & Subtitle Sync Delay'));
      expect(audioDelay.category, equals(FeatureCategory.audioSubtitles));

      final aspect = AppFeaturesCatalog.allFeatures.firstWhere(
        (f) => f.id == 'aspect_ratio_zoom_fit',
      );
      expect(aspect.title, contains('Aspect Ratio'));
      expect(aspect.category, equals(FeatureCategory.playback));

      final franchise = AppFeaturesCatalog.allFeatures.firstWhere(
        (f) => f.id == 'movie_franchises_hub',
      );
      expect(franchise.title, contains('Franchise Universes'));
      expect(franchise.category, equals(FeatureCategory.discovery));

      final person = AppFeaturesCatalog.allFeatures.firstWhere(
        (f) => f.id == 'cast_filmography_deep_dive',
      );
      expect(person.title, contains('Cast & Crew Filmography'));
      expect(person.category, equals(FeatureCategory.discovery));

      final playlists = AppFeaturesCatalog.allFeatures.firstWhere(
        (f) => f.id == 'custom_user_playlists',
      );
      expect(playlists.title, contains('Custom User Playlists'));
      expect(playlists.category, equals(FeatureCategory.profilesSync));

      final voice = AppFeaturesCatalog.allFeatures.firstWhere(
        (f) => f.id == 'voice_search_dpad',
      );
      expect(voice.title, contains('Voice Search'));
      expect(voice.category, equals(FeatureCategory.tvNavigation));

      // Query verification
      expect(
        AppFeaturesCatalog.search('Franchise').length,
        greaterThanOrEqualTo(1),
      );
      expect(
        AppFeaturesCatalog.search('Playlists').length,
        greaterThanOrEqualTo(1),
      );
      expect(
        AppFeaturesCatalog.search('Voice Search').length,
        greaterThanOrEqualTo(1),
      );
    });
  });
}
