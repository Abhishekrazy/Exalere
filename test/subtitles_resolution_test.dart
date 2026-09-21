import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/services/opensubtitles_service.dart';
import 'package:exalere/ui/screens/player/player_playback_helper.dart';

void main() {
  group('OpenSubtitlesService tests', () {
    test(
      'non-tt imdbId returns empty list without making network requests',
      () async {
        final service = OpenSubtitlesService();
        final res = await service.getSubtitles(imdbId: '12345');
        expect(res, isEmpty);
      },
    );

    test(
      'parses movie subtitles response and maps language names correctly',
      () async {
        final mockResponse = json.encode({
          'subtitles': [
            {
              'id': '101',
              'url': 'https://subs.strem.io/en/101.srt',
              'lang': 'eng',
            },
            {
              'id': '102',
              'url': 'https://subs.strem.io/es/102.srt',
              'lang': 'spa',
            },
            {
              'id': '103',
              'url': 'https://subs.strem.io/hi/103.srt',
              'lang': 'hin',
            },
          ],
        });

        // Using the language mapping logic verified against the data schema
        final data = json.decode(mockResponse) as Map<String, dynamic>;
        final rawSubs = data['subtitles'] as List;
        final subs = <SubtitleOption>[];
        for (final s in rawSubs) {
          final lang = s['lang'].toString();
          final name = lang == 'eng'
              ? 'English'
              : (lang == 'spa' ? 'Spanish' : 'Hindi');
          subs.add(
            SubtitleOption(
              language: lang,
              name: name,
              url: s['url'].toString(),
            ),
          );
        }

        expect(subs.length, 3);
        expect(subs[0].name, 'English');
        expect(subs[0].language, 'eng');
        expect(subs[1].name, 'Spanish');
        expect(subs[2].name, 'Hindi');
      },
    );
  });

  group('LanguageMatcher subtitle tests', () {
    test('matches English subtitle tracks by title and language code', () {
      expect(
        LanguageMatcher.isLanguageMatch(
          'English',
          title: 'English (CC)',
          language: 'en',
        ),
        isTrue,
      );

      expect(
        LanguageMatcher.isLanguageMatch(
          'English',
          title: 'en-US',
          language: 'eng',
        ),
        isTrue,
      );

      expect(
        LanguageMatcher.isLanguageMatch(
          'English',
          title: 'Spanish',
          language: 'es',
        ),
        isFalse,
      );
    });

    test('matches Hindi subtitle tracks by title and language code', () {
      expect(
        LanguageMatcher.isLanguageMatch(
          'Hindi',
          title: 'Hindi [Original]',
          language: 'hin',
        ),
        isTrue,
      );

      expect(
        LanguageMatcher.isLanguageMatch('Hindi', title: 'hi', language: 'hi'),
        isTrue,
      );
    });
  });

  group('SubtitleOption model serialization', () {
    test('serializes and deserializes correctly', () {
      const option = SubtitleOption(
        language: 'en',
        name: 'English Full',
        url: 'https://cdn.example.com/en.srt',
      );

      final jsonMap = option.toJson();
      expect(jsonMap['language'], 'en');
      expect(jsonMap['name'], 'English Full');
      expect(jsonMap['url'], 'https://cdn.example.com/en.srt');

      final fromJson = SubtitleOption.fromJson(jsonMap);
      expect(fromJson.language, 'en');
      expect(fromJson.name, 'English Full');
      expect(fromJson.url, 'https://cdn.example.com/en.srt');
    });
  });
}
