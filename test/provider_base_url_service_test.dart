import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/services/provider_base_url_service.dart';

/// These cover the domain-resolution layer that keeps a scraped provider working
/// after its site moves to a new mirror — the failure mode that used to require
/// shipping an app update.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProviderBaseUrlService.instance.resetForTest();
  });

  group('ProviderBaseUrlService.normalizeUrl', () {
    test('adds https when the scheme is missing', () {
      expect(
        ProviderBaseUrlService.normalizeUrl('hdhub4u.cl'),
        'https://hdhub4u.cl',
      );
    });

    test('reduces a deep URL to its origin', () {
      expect(
        ProviderBaseUrlService.normalizeUrl('https://hdhub4u.cl/movies/2026/'),
        'https://hdhub4u.cl',
        reason: 'callers append their own paths, so a trailing / doubles up',
      );
    });

    test('trims whitespace and trailing slashes', () {
      expect(
        ProviderBaseUrlService.normalizeUrl('  https://a.example///  '),
        'https://a.example',
      );
    });

    test('preserves an explicit port', () {
      expect(
        ProviderBaseUrlService.normalizeUrl('http://127.0.0.1:8090/api'),
        'http://127.0.0.1:8090',
      );
    });

    test('rejects unusable values', () {
      expect(ProviderBaseUrlService.normalizeUrl(''), isNull);
      expect(ProviderBaseUrlService.normalizeUrl('   '), isNull);
      expect(ProviderBaseUrlService.normalizeUrl('ftp://a.example'), isNull);
    });
  });

  group('ProviderBaseUrlService.parseBaseUrlMap', () {
    test('parses the flat shape', () {
      final map = ProviderBaseUrlService.parseBaseUrlMap(
        '{"hdhub":"https://new8.hdhub4u.cl","uhd":"https://uhdmovies.us.org"}',
      );
      expect(map['hdhub'], 'https://new8.hdhub4u.cl');
      expect(map['uhd'], 'https://uhdmovies.us.org');
    });

    test('parses the nested shape the upstream file actually uses', () {
      final map = ProviderBaseUrlService.parseBaseUrlMap(
        '{"hdhub":{"name":"hdhub4u","url":"https://new8.hdhub4u.cl"}}',
      );
      expect(map['hdhub'], 'https://new8.hdhub4u.cl');
    });

    test('skips entries with no usable URL instead of failing the map', () {
      final map = ProviderBaseUrlService.parseBaseUrlMap(
        '{"good":"https://a.example","empty":"","nested":{},"bad":"ftp://x"}',
      );
      expect(map['good'], 'https://a.example');
      expect(map.containsKey('empty'), isFalse);
      expect(map.containsKey('nested'), isFalse);
      expect(map.containsKey('bad'), isFalse);
    });

    test('returns empty for invalid JSON rather than throwing', () {
      expect(ProviderBaseUrlService.parseBaseUrlMap('not json'), isEmpty);
      expect(ProviderBaseUrlService.parseBaseUrlMap(''), isEmpty);
      expect(ProviderBaseUrlService.parseBaseUrlMap('[]'), isEmpty);
    });

    test('survives a mixed real-world payload', () {
      final map = ProviderBaseUrlService.parseBaseUrlMap('''
      {
        "Moviesmod": {"name": "Moviesmod", "url": "https://moviesmod.uk.com"},
        "hdhub": {"name": "hdhub4u", "url": "https://new8.hdhub4u.cl"},
        "broken": {"name": "x"}
      }
      ''');
      expect(map.length, 2);
      expect(map['Moviesmod'], 'https://moviesmod.uk.com');
      expect(map['hdhub'], 'https://new8.hdhub4u.cl');
    });
  });

  group('ProviderBaseUrlService.baseUrlFor', () {
    test('falls back to the bundled map before anything is loaded', () {
      expect(
        ProviderBaseUrlService.instance.baseUrlFor('4khdhub'),
        ProviderBaseUrlService.fallbackUrls['4khdhub'],
      );
    });

    test('returns the caller fallback for an unknown key', () {
      expect(
        ProviderBaseUrlService.instance.baseUrlFor(
          'nope',
          fallback: 'https://x',
        ),
        'https://x',
      );
    });

    test('returns null when neither the map nor a fallback has the key', () {
      expect(ProviderBaseUrlService.instance.baseUrlFor('nope'), isNull);
    });

    test('a loaded remote map overrides the bundled URL', () async {
      // Seed the cache the way a previous successful refresh would have.
      SharedPreferences.setMockInitialValues({
        'exalere_provider_base_urls_v1':
            '{"4khdhub":{"url":"https://4khdhub.two"}}',
        'exalere_provider_base_urls_at_v1':
            DateTime.now().millisecondsSinceEpoch,
      });

      await ProviderBaseUrlService.instance.initialize();

      expect(
        ProviderBaseUrlService.instance.baseUrlFor('4khdhub'),
        'https://4khdhub.two',
        reason: 'a rotated domain must win over the baked-in one',
      );
      // Keys absent from the remote map keep their bundled value.
      expect(
        ProviderBaseUrlService.instance.baseUrlFor('hdhub'),
        ProviderBaseUrlService.fallbackUrls['hdhub'],
      );
    });

    test('a fresh cache avoids a network refresh', () async {
      SharedPreferences.setMockInitialValues({
        'exalere_provider_base_urls_v1': '{"4khdhub":"https://cached.example"}',
        'exalere_provider_base_urls_at_v1':
            DateTime.now().millisecondsSinceEpoch,
      });

      await ProviderBaseUrlService.instance.initialize();

      expect(ProviderBaseUrlService.instance.hasRemoteMap, isTrue);
      expect(
        ProviderBaseUrlService.instance.baseUrlFor('4khdhub'),
        'https://cached.example',
      );
    });
  });

  group('ProviderBaseUrlService bundled fallbacks', () {
    test('every bundled entry is a valid origin', () {
      ProviderBaseUrlService.fallbackUrls.forEach((key, value) {
        final normalized = ProviderBaseUrlService.normalizeUrl(value);
        expect(
          normalized,
          isNotNull,
          reason: 'fallback for "$key" must be a usable URL',
        );
        expect(
          normalized,
          value,
          reason:
              'fallback for "$key" should already be a bare origin with no '
              'path or trailing slash',
        );
      });
    });

    test('covers the providers this app actually scrapes', () {
      for (final key in ['4khdhub', 'hdhub', 'uhd', 'Moviesmod', 'drive']) {
        expect(
          ProviderBaseUrlService.fallbackUrls.containsKey(key),
          isTrue,
          reason: 'missing a bundled fallback for "$key"',
        );
      }
    });
  });
}
