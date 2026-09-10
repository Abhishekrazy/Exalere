import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/models/media_item.dart';

void main() {
  group('Adult Content Detection & MediaItem Parsing', () {
    test('Correctly identifies adult titles via restrictKid == 1', () {
      final json = {
        'id': 'mb_101',
        'title': 'SWAMP STAMP Anime Edition',
        'restrictKid': 1,
        'genre': 'Anime',
      };
      final item = MediaItem.fromMovieBoxJson(json);
      expect(item.isAdult, isTrue);
    });

    test(
      'Correctly identifies adult titles via genre containing ecchi or hentai',
      () {
        final json = {
          'id': 'mb_102',
          'title': 'School Days Special',
          'restrictKid': 0,
          'genre': ['Animation', 'Ecchi'],
        };
        final item = MediaItem.fromMovieBoxJson(json);
        expect(item.isAdult, isTrue);
      },
    );

    test('Correctly identifies adult titles via MovieBox Anime Edition title convention', () {
      final json = {
        'id': 'mb_103',
        'title': 'Momoiro Bouenkyou Anime Edition',
        'restrictKid': 1,
        'genre': 'Anime',
      };
      final item = MediaItem.fromMovieBoxJson(json);
      expect(item.isAdult, isTrue);
    });

    test('Correctly identifies adult titles via uncensored resourceLink', () {
      final json = {
        'id': 'mb_104',
        'title': '3 Seconds Later, He Turned into a Beast',
        'restrictKid': 0,
        'genre': 'Animation',
        'resourceLink':
            'https://watchhentai.net/stream/3-seconds-uncensored.mp4',
      };
      final item = MediaItem.fromMovieBoxJson(json);
      expect(item.isAdult, isTrue);
    });

    test('Leaves general audience anime as non-adult', () {
      final json = {
        'id': 'mb_201',
        'title': 'Demon Slayer: Kimetsu no Yaiba',
        'restrictKid': 0,
        'genre': ['Animation', 'Action', 'Fantasy'],
      };
      final item = MediaItem.fromMovieBoxJson(json);
      expect(item.isAdult, isFalse);
    });

    test('Leaves family animated films as non-adult', () {
      final json = {
        'id': 'mb_202',
        'title': 'Spirited Away',
        'restrictKid': 0,
        'genre': 'Animation',
      };
      final item = MediaItem.fromMovieBoxJson(json);
      expect(item.isAdult, isFalse);
    });

    test('MediaItem JSON serialization preserves isAdult attribute', () {
      const original = MediaItem(
        id: 'test_adult_1',
        title: 'Adult Test Show',
        mediaType: MediaType.series,
        isAdult: true,
      );
      final json = original.toJson();
      expect(json['isAdult'], isTrue);

      final restored = MediaItem.fromJson(json);
      expect(restored.isAdult, isTrue);
      expect(restored.id, equals(original.id));
    });

    test('copyWith properly updates isAdult attribute', () {
      const item = MediaItem(
        id: 'test_1',
        title: 'Regular Title',
        mediaType: MediaType.movie,
        isAdult: false,
      );
      final updated = item.copyWith(isAdult: true);
      expect(updated.isAdult, isTrue);
      expect(updated.title, equals('Regular Title'));
    });
  });
}
