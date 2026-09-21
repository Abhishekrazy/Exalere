import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/services/moviebox_provider.dart';

void main() {
  group('MovieBox DASH Manifest Resolution', () {
    test('resolves dash manifest from standard CloudFront-Policy cookie', () {
      const policyJson =
          '{"Statement":[{"Resource":"https://sacdn.example.com/dash/12345_0_0_1080_h265_518/*"}]}';
      final b64 = base64Encode(utf8.encode(policyJson));
      final cookie =
          'CloudFront-Policy=$b64; CloudFront-Signature=abc; CloudFront-Key-Pair-Id=xyz;';

      final resolved = MovieBoxProvider.resolveDashManifestFromPolicy(cookie);
      expect(
        resolved,
        'https://sacdn.example.com/dash/12345_0_0_1080_h265_518/index.mpd',
      );
    });

    test('handles custom dash and tilde character substitution', () {
      const policyJson =
          '{"Statement":[{"Resource":"https://sacdn.example.com/stream/999/*"}]}';
      var b64 = base64Encode(utf8.encode(policyJson));
      // Substitute + with -, / with ~
      b64 = b64.replaceAll('+', '-').replaceAll('/', '~');

      final cookie = 'CloudFront-Policy=$b64;';
      final resolved = MovieBoxProvider.resolveDashManifestFromPolicy(cookie);
      expect(resolved, 'https://sacdn.example.com/stream/999/index.mpd');
    });

    test('resolves dash manifest from Edge-Cache-Cookie urlprefix', () {
      const resourceUrl =
          'https://sbcdn3.hakunaymatata.com/dash/8137378744555162280_0_0_1080_h265_744';
      final b64 = base64UrlEncode(utf8.encode(resourceUrl));
      final cookie =
          'Edge-Cache-Cookie=urlprefix=$b64:sign=abc123def456; other=test;';

      final resolved = MovieBoxProvider.resolveDashManifestFromPolicy(cookie);
      expect(
        resolved,
        'https://sbcdn3.hakunaymatata.com/dash/8137378744555162280_0_0_1080_h265_744/index.mpd',
      );
    });

    test('isDeprecationNoticeUrl correctly flags notice and 21s ad URLs', () {
      expect(
        MovieBoxProvider.isDeprecationNoticeUrl(
          'https://macdn.aoneroom.com/other/2026/b164fbfb4347792950bdfbfb563d39d9.mp4',
        ),
        isTrue,
      );
      expect(
        MovieBoxProvider.isDeprecationNoticeUrl(
          'https://cdn.example.com/videos/1c7de0bd3393702d9191801f15f88f8d.mp4',
        ),
        isTrue,
      );
      expect(
        MovieBoxProvider.isDeprecationNoticeUrl(
          'https://cdn.example.com/notice.mp4',
        ),
        isTrue,
      );
      expect(
        MovieBoxProvider.isDeprecationNoticeUrl(
          'https://sbcdn3.hakunaymatata.com/dash/8137378744555162280_0_0_1080_h265_744/index.mpd',
        ),
        isFalse,
      );
      expect(
        MovieBoxProvider.isDeprecationNoticeUrl(
          'https://stream.example.com/movie/real_stream_1080.mp4',
        ),
        isFalse,
      );
    });

    test('returns null for invalid or missing policy cookies', () {
      expect(MovieBoxProvider.resolveDashManifestFromPolicy(''), isNull);
      expect(
        MovieBoxProvider.resolveDashManifestFromPolicy(
          'CloudFront-Policy=invalid!not!b64',
        ),
        isNull,
      );
      expect(
        MovieBoxProvider.resolveDashManifestFromPolicy('SomeOtherCookie=123;'),
        isNull,
      );
    });
  });
}
