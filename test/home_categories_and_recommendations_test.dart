import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/providers/library_provider.dart';

void main() {
  group('Home Categories & Smart Recommendation Engine Tests', () {
    test('MediaItem matchesCategory detects horror, documentary, action, comedy, sci-fi', () {
      const horrorItem = MediaItem(
        id: 'h1',
        title: 'The Conjuring: Last Rites',
        mediaType: MediaType.movie,
        genre: 'Supernatural, Mystery',
      );
      expect(horrorItem.matchesCategory('horror'), isTrue);
      expect(horrorItem.matchesCategory('documentary'), isFalse);

      const docItem = MediaItem(
        id: 'd1',
        title: 'Planet Earth III',
        mediaType: MediaType.series,
        genre: 'Nature, Wildlife, Docuseries',
      );
      expect(docItem.matchesCategory('documentary'), isTrue);
      expect(docItem.matchesCategory('horror'), isFalse);

      const comedyItem = MediaItem(
        id: 'c1',
        title: 'Brooklyn Nine-Nine',
        mediaType: MediaType.series,
        genre: 'Sitcom, Humor',
      );
      expect(comedyItem.matchesCategory('comedy'), isTrue);

      const sciFiItem = MediaItem(
        id: 'sf1',
        title: 'Dune: Part Two',
        mediaType: MediaType.movie,
        genre: 'Science Fiction, Space',
      );
      expect(sciFiItem.matchesCategory('sci-fi'), isTrue);
      expect(sciFiItem.matchesCategory('fantasy'), isTrue);
    });

    test('LibraryProvider generates personalized recommendations from local watch history', () async {
      SharedPreferences.setMockInitialValues({});
      final library = LibraryProvider();
      await library.init();

      final catalog = [
        const MediaItem(
          id: 'h1',
          title: 'A Quiet Place',
          mediaType: MediaType.movie,
          genre: 'Horror, Thriller',
          rating: 7.5,
        ),
        const MediaItem(
          id: 'h2',
          title: 'Hereditary',
          mediaType: MediaType.movie,
          genre: 'Horror, Supernatural',
          rating: 7.3,
        ),
        const MediaItem(
          id: 'h3',
          title: 'The Nun II',
          mediaType: MediaType.movie,
          genre: 'Horror, Occult',
          rating: 6.9,
        ),
        const MediaItem(
          id: 'c1',
          title: 'Superbad',
          mediaType: MediaType.movie,
          genre: 'Comedy',
          rating: 7.6,
        ),
      ];

      // 1. Initially when history is empty, falls back to What to Watch / Top Picks
      final initialRec = library.getPersonalizedRecommendations(catalog);
      expect(initialRec.title, contains('What to Watch'));
      expect(initialRec.items.isNotEmpty, isTrue);

      // 2. Simulate playing a horror movie
      await library.recordProgress(
        item: const MediaItem(
          id: 'played_horror',
          title: 'Insidious',
          mediaType: MediaType.movie,
          genre: 'Horror, Supernatural',
        ),
        positionSeconds: 120,
        totalSeconds: 6000,
      );

      // 3. Recommendation engine should now recommend "Because You Watched Insidious" with horror titles
      final personalizedRec = library.getPersonalizedRecommendations(catalog);
      expect(personalizedRec.title, contains('Because You Watched Insidious'));
      expect(personalizedRec.items.any((i) => i.id == 'h1'), isTrue);
      expect(personalizedRec.items.any((i) => i.id == 'h2'), isTrue);
      expect(personalizedRec.items.any((i) => i.id == 'h3'), isTrue);
    });
  });
}
