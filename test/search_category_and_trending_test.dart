import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/models/media_item.dart';

void main() {
  group('MediaItem category matching and genre parsing tests', () {
    test('MediaItem.fromMovieBoxJson extracts multiple genres and tags', () {
      final json = {
        'id': '101',
        'title': 'Avengers: Endgame',
        'genre': ['Action', 'Sci-Fi', 'Adventure'],
        'tags': ['Marvel', 'Superhero'],
      };

      final item = MediaItem.fromMovieBoxJson(json);
      expect(item.genre, isNotNull);
      expect(item.genre, contains('Action'));
      expect(item.genre, contains('Sci-Fi'));
      expect(item.genre, contains('Marvel'));
    });

    test('matchesCategory correctly identifies curated and standard categories', () {
      const marvelMovie = MediaItem(
        id: '1',
        title: 'Spider-Man: No Way Home',
        mediaType: MediaType.movie,
        genre: 'Action, Sci-Fi',
      );

      const bollywoodMovie = MediaItem(
        id: '2',
        title: 'Jawan',
        mediaType: MediaType.movie,
        genre: 'Action, Thriller',
        languageTag: 'Hindi',
      );

      const animeShow = MediaItem(
        id: '3',
        title: 'Attack on Titan',
        mediaType: MediaType.series,
        genre: 'Animation, Action',
      );

      const sciFiMovie = MediaItem(
        id: '4',
        title: 'Interstellar',
        mediaType: MediaType.movie,
        genre: 'Science Fiction, Drama',
      );

      // Marvel
      expect(marvelMovie.matchesCategory('Marvel'), isTrue);
      expect(bollywoodMovie.matchesCategory('Marvel'), isFalse);

      // Bollywood
      expect(bollywoodMovie.matchesCategory('Bollywood'), isTrue);
      expect(animeShow.matchesCategory('Bollywood'), isFalse);

      // Anime
      expect(animeShow.matchesCategory('Anime'), isTrue);
      expect(sciFiMovie.matchesCategory('Anime'), isFalse);

      // Sci-Fi
      expect(sciFiMovie.matchesCategory('Sci-Fi'), isTrue);
      expect(marvelMovie.matchesCategory('Sci-Fi'), isTrue);

      // Action
      expect(marvelMovie.matchesCategory('Action'), isTrue);
      expect(bollywoodMovie.matchesCategory('Action'), isTrue);
      expect(animeShow.matchesCategory('Action'), isTrue);
      expect(sciFiMovie.matchesCategory('Action'), isFalse);
    });
  });
}
