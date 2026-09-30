import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/services/fuzzy_search_service.dart';

void main() {
  group('FuzzySearchService - Normalization & Levenshtein', () {
    test('normalize strips accents, punctuation and collapses spaces', () {
      expect(
        FuzzySearchService.normalize('Amélie: Season 1!'),
        'amelie season 1',
      );
      expect(
        FuzzySearchService.normalize('  Spider-Man:   Across  '),
        'spider man across',
      );
      expect(FuzzySearchService.normalize('Pokémon'), 'pokemon');
    });

    test('levenshtein computes edit distances accurately', () {
      expect(FuzzySearchService.levenshtein('avengers', 'avengers'), 0);
      expect(FuzzySearchService.levenshtein('avengrs', 'avengers'), 1);
      expect(FuzzySearchService.levenshtein('oppenhimr', 'oppenheimer'), 2);
    });
  });

  group('FuzzySearchService - Scoring & Matching', () {
    test('Exact matches score highest', () {
      final sExact = FuzzySearchService.score('Avengers', 'Avengers');
      final sPrefix = FuzzySearchService.score('Aven', 'Avengers');
      expect(sExact, equals(1000.0));
      expect(sExact, greaterThan(sPrefix));
    });

    test('Prefix matches rank higher than deep substrings', () {
      final sPrefix = FuzzySearchService.score('Dark', 'Dark Knight');
      final sSubstring = FuzzySearchService.score(
        'Dark',
        'The Secret of the Dark',
      );
      expect(sPrefix, greaterThan(sSubstring));
    });

    test('Acronym matching succeeds for popular abbreviations', () {
      final sGot = FuzzySearchService.score('got', 'Game of Thrones');
      expect(sGot, greaterThan(500.0));

      final sLotr = FuzzySearchService.score('lotr', 'The Lord of the Rings');
      expect(sLotr, greaterThan(500.0));
    });

    test('Typo tolerance matches misspelled queries', () {
      // 1-letter omission
      final sTypo1 = FuzzySearchService.score('avengrs', 'The Avengers');
      expect(sTypo1, greaterThan(400.0));

      // 1-letter typo in word
      final sTypo2 = FuzzySearchService.score('braking', 'Breaking Bad');
      expect(sTypo2, greaterThan(400.0));
    });

    test('Token matching handles out-of-order words', () {
      final sTokens = FuzzySearchService.score('bad breaking', 'Breaking Bad');
      expect(sTokens, greaterThan(500.0));
    });

    test('Fuzzy search sorts results by relevance', () {
      final titles = [
        'Spider-Man: No Way Home',
        'The Amazing Spider-Man',
        'Spider-Man',
        'Superman',
        'Batman Begins',
      ];

      final results = FuzzySearchService.search<String>(
        query: 'spider',
        items: titles,
        getTitle: (t) => t,
      );

      expect(results.first, equals('Spider-Man'));
      expect(results.contains('Batman Begins'), isFalse);
    });

    test('getTitleSuggestions returns top matches as you type', () {
      final titles = [
        'Breaking Bad',
        'Better Call Saul',
        'Stranger Things',
        'The Boys',
        'Braveheart',
      ];

      final suggestions = FuzzySearchService.getTitleSuggestions(
        query: 'br',
        candidateTitles: titles,
        limit: 3,
      );

      expect(suggestions.contains('Breaking Bad'), isTrue);
      expect(suggestions.contains('Braveheart'), isTrue);
      expect(suggestions.contains('Stranger Things'), isFalse);
    });
  });
}
