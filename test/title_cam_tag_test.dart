import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/media_details.dart';

void main() {
  group('MediaItem CAM Tag Parsing & Title Cleaning', () {
    test('strips [CAM] from title and sets isCam=true', () {
      final parsed = MediaItem.parseTitleTags('Mirzapur: The Movie [CAM]');
      expect(parsed.cleanTitle, 'Mirzapur: The Movie');
      expect(parsed.isCam, isTrue);
      expect(parsed.qualityTag, 'CAM');
    });

    test('strips [HD-CAM] and [Hindi] correctly', () {
      final parsed = MediaItem.parseTitleTags('Kalki 2898 AD [HD-CAM] [Hindi]');
      expect(parsed.cleanTitle, 'Kalki 2898 AD');
      expect(parsed.languageTag, 'Hindi');
      expect(parsed.isCam, isTrue);
      expect(parsed.qualityTag, 'CAM');
    });

    test('strips (CAM-RIP) parenthesis tag', () {
      final parsed = MediaItem.parseTitleTags('Stree 2 (CAM-RIP)');
      expect(parsed.cleanTitle, 'Stree 2');
      expect(parsed.isCam, isTrue);
      expect(parsed.qualityTag, 'CAM');
    });

    test('detects TELESYNC / TS qualityTag', () {
      final parsed = MediaItem.parseTitleTags('Deadpool 3 [TELESYNC]');
      expect(parsed.cleanTitle, 'Deadpool 3');
      expect(parsed.isCam, isTrue);
      expect(parsed.qualityTag, 'TELESYNC');
    });

    test('keeps normal titles unchanged with isCam=false', () {
      final parsed = MediaItem.parseTitleTags('Reacher');
      expect(parsed.cleanTitle, 'Reacher');
      expect(parsed.isCam, isFalse);
      expect(parsed.qualityTag, isNull);
    });

    test('MediaItem getters reflect parseTitleTags', () {
      const item = MediaItem(
        id: '123',
        title: 'Mirzapur: The Movie [CAM]',
        mediaType: MediaType.movie,
      );
      expect(item.cleanTitle, 'Mirzapur: The Movie');
      expect(item.isCam, isTrue);
      expect(item.qualityTag, 'CAM');
    });

    test('MediaDetails getters reflect MediaItem parseTitleTags', () {
      const details = MediaDetails(
        id: '456',
        title: 'Mirzapur: The Movie [CAM]',
        mediaType: MediaType.movie,
      );
      expect(details.cleanTitle, 'Mirzapur: The Movie');
      expect(details.isCam, isTrue);
      expect(details.qualityTag, 'CAM');
    });
  });
}
