import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/extractors/stream_extractors.dart';

/// These helpers decide whether a scraped page yields a playable URL, but they
/// used to be private to one provider and had no coverage at all. A wrong result
/// here is invisible to the user until playback fails, so each one is pinned.
void main() {
  group('rot13', () {
    test('rotates letters and leaves everything else alone', () {
      expect(StreamExtractors.rot13('abc'), 'nop');
      expect(StreamExtractors.rot13('NOP'), 'ABC');
      expect(StreamExtractors.rot13('a1-_Z'), 'n1-_M');
    });

    test('is its own inverse', () {
      const original = 'https://cdn.example/file.mp4?token=AbC123';
      expect(
        StreamExtractors.rot13(StreamExtractors.rot13(original)),
        original,
      );
    });

    test('handles empty input', () {
      expect(StreamExtractors.rot13(''), '');
    });
  });

  group('greenmotors payload', () {
    test('extracts the packed payload from a script call', () {
      const html = '<script>s(\'o\',\'eyJhIjoxfQ==\')</script>';
      expect(StreamExtractors.extractGreenmotorsPayload(html), 'eyJhIjoxfQ==');
    });

    test('accepts double quotes and extra spacing', () {
      const html = 's( "o" , "payload-value" )';
      expect(StreamExtractors.extractGreenmotorsPayload(html), 'payload-value');
    });

    test('returns null when the call is absent', () {
      expect(
        StreamExtractors.extractGreenmotorsPayload('<html></html>'),
        isNull,
      );
    });

    test('decodes the full base64/rot13/base64/json chain', () {
      // Round-trip: build the encoding exactly as the decoder expects it, so a
      // regression in any single layer fails here rather than in playback.
      const url = 'https://cdn.example/movie.mp4?token=abc';
      final inner = base64.encode(utf8.encode(url));
      final jsonStr = json.encode({'o': inner});
      final step3 = base64.encode(utf8.encode(jsonStr));
      final step2 = StreamExtractors.rot13(step3);
      final step1Str = base64.encode(utf8.encode(step2));
      final payload = base64.encode(utf8.encode(step1Str));

      expect(StreamExtractors.decodeGreenmotorsPayload(payload), url);
    });

    test('returns null for garbage instead of throwing', () {
      expect(
        StreamExtractors.decodeGreenmotorsPayload('not base64 at all'),
        isNull,
      );
      expect(StreamExtractors.decodeGreenmotorsPayload(''), isNull);
      expect(
        StreamExtractors.decodeGreenmotorsPayload(
          base64.encode(utf8.encode('x')),
        ),
        isNull,
      );
    });

    test('returns null when the JSON has no target field', () {
      final step3 = base64.encode(utf8.encode(json.encode({'other': 'x'})));
      final step2 = StreamExtractors.rot13(step3);
      final step1Str = base64.encode(utf8.encode(step2));
      final payload = base64.encode(utf8.encode(step1Str));
      expect(StreamExtractors.decodeGreenmotorsPayload(payload), isNull);
    });
  });

  group('hubcloud', () {
    test('finds the drive page link', () {
      const html =
          '<a href="https://hubcloud.xyz/drive/abc123?token=1">Download</a>';
      expect(
        StreamExtractors.extractHubcloudDriveUrl(html),
        'https://hubcloud.xyz/drive/abc123?token=1',
      );
    });

    test('ignores non-hubcloud links and missing href', () {
      expect(
        StreamExtractors.extractHubcloudDriveUrl(
          '<a href="https://example.com/drive/abc">x</a>',
        ),
        isNull,
      );
      expect(StreamExtractors.extractHubcloudDriveUrl('<a>x</a>'), isNull);
    });

    test('finds the resolver download anchor', () {
      expect(
        StreamExtractors.extractHubcloudResolverUrl(
          '<a class="btn" href="https://gamerxyt.com/dl/abc">Get</a>',
        ),
        'https://gamerxyt.com/dl/abc',
      );
      expect(
        StreamExtractors.extractHubcloudResolverUrl(
          '<a href="https://site.example/download/abc">Get</a>',
        ),
        'https://site.example/download/abc',
      );
    });

    test('rejects a relative resolver link', () {
      // A relative href cannot be handed to the player as-is.
      expect(
        StreamExtractors.extractHubcloudResolverUrl(
          '<a href="/download/abc">x</a>',
        ),
        isNull,
      );
    });
  });

  group('pixeldrain', () {
    test('maps a share page to the direct file URL', () {
      expect(
        StreamExtractors.pixeldrainApiUrl('https://pixeldrain.com/u/abcd1234'),
        'https://pixeldrain.com/api/file/abcd1234?download',
      );
      expect(
        StreamExtractors.pixeldrainApiUrl('https://pixeldrain.dev/u/abcd1234'),
        'https://pixeldrain.com/api/file/abcd1234?download',
      );
    });

    test('normalises an existing api URL', () {
      expect(
        StreamExtractors.pixeldrainApiUrl(
          'https://pixeldrain.com/api/file/abcd1234',
        ),
        'https://pixeldrain.com/api/file/abcd1234?download',
      );
    });

    test('rejects other hosts and empty ids', () {
      expect(
        StreamExtractors.pixeldrainApiUrl('https://example.com/u/abc'),
        isNull,
      );
      expect(
        StreamExtractors.pixeldrainApiUrl('https://pixeldrain.com/u/'),
        isNull,
      );
      expect(StreamExtractors.pixeldrainApiUrl('not a url'), isNull);
    });

    test('collects links referenced inside inline scripts', () {
      const html = '''
        <script>
          var a = "https://pixeldrain.com/u/one111";
          var b = 'https://pixeldrain.dev/u/two222';
        </script>
        <a href="https://pixeldrain.com/u/one111">dup</a>
      ''';
      final urls = StreamExtractors.extractScriptPixeldrainUrls(html);

      expect(urls, [
        'https://pixeldrain.com/api/file/one111?download',
        'https://pixeldrain.com/api/file/two222?download',
      ]);
    });

    test('returns nothing when there are no links', () {
      expect(
        StreamExtractors.extractScriptPixeldrainUrls('<html></html>'),
        isEmpty,
      );
    });
  });

  group('watch-online wrapper', () {
    test('unwraps a base64 target from a pages.dev redirector', () {
      const target = 'https://cdn.example/stream.m3u8';
      final encoded = base64.encode(utf8.encode(target));
      expect(
        StreamExtractors.unwrapWatchOnlineUrl(
          'https://player.pages.dev/watch?u=$encoded',
        ),
        target,
      );
    });

    test('rejects other hosts, missing params and bad payloads', () {
      final encoded = base64.encode(utf8.encode('https://cdn.example/a'));
      expect(
        StreamExtractors.unwrapWatchOnlineUrl(
          'https://example.com/watch?u=$encoded',
        ),
        isNull,
      );
      expect(
        StreamExtractors.unwrapWatchOnlineUrl('https://player.pages.dev/watch'),
        isNull,
      );
      expect(
        StreamExtractors.unwrapWatchOnlineUrl(
          'https://player.pages.dev/watch?u=!!!',
        ),
        isNull,
      );
    });

    test('rejects a decoded value that is not a URL', () {
      final encoded = base64.encode(utf8.encode('javascript:alert(1)'));
      expect(
        StreamExtractors.unwrapWatchOnlineUrl(
          'https://player.pages.dev/watch?u=$encoded',
        ),
        isNull,
      );
    });
  });

  group('findMediaUrls', () {
    test('finds direct media and manifest URLs', () {
      const html = '''
        <video src="https://cdn.example/movie.mp4"></video>
        var hls = "https://cdn.example/master.m3u8?token=1";
        var dash = 'https://cdn.example/manifest.mpd';
      ''';
      expect(StreamExtractors.findMediaUrls(html), [
        'https://cdn.example/movie.mp4',
        'https://cdn.example/master.m3u8?token=1',
        'https://cdn.example/manifest.mpd',
      ]);
    });

    test('handles JSON-escaped and unicode-escaped slashes', () {
      const html = r'''
        {"a":"https:\/\/cdn.example\/one.mp4"}
        {"b":"https:\u002F\u002Fcdn.example\u002Ftwo.m3u8"}
      ''';
      final urls = StreamExtractors.findMediaUrls(html);
      expect(urls, contains('https://cdn.example/one.mp4'));
      expect(urls, contains('https://cdn.example/two.m3u8'));
    });

    test('de-duplicates while keeping document order', () {
      const html = '''
        "https://cdn.example/a.mp4"
        "https://cdn.example/b.m3u8"
        "https://cdn.example/a.mp4"
      ''';
      expect(StreamExtractors.findMediaUrls(html), [
        'https://cdn.example/a.mp4',
        'https://cdn.example/b.m3u8',
      ]);
    });

    test('ignores non-media links', () {
      const html = '<a href="https://cdn.example/page.html">x</a>';
      expect(StreamExtractors.findMediaUrls(html), isEmpty);
    });

    test('handles empty input', () {
      expect(StreamExtractors.findMediaUrls(''), isEmpty);
    });
  });

  group('format and quality inference', () {
    test('classifies format from the URL', () {
      expect(StreamExtractors.guessFormat('https://x/a.m3u8'), 'HLS');
      expect(StreamExtractors.guessFormat('https://x/a.mpd'), 'DASH');
      expect(StreamExtractors.guessFormat('https://x/a.mp4'), 'MP4');
      expect(StreamExtractors.guessFormat('https://x/a.mkv'), 'MP4');
    });

    test('infers quality from surrounding text', () {
      expect(StreamExtractors.guessQuality('Movie 2160p WEB-DL'), '2160p');
      expect(StreamExtractors.guessQuality('Movie 4K HDR'), '2160p');
      expect(StreamExtractors.guessQuality('Movie 1080p'), '1080p');
      expect(StreamExtractors.guessQuality('Movie 720p'), '720p');
    });

    test(
      "returns 'Auto' rather than guessing when nothing is recognisable",
      () {
        expect(StreamExtractors.guessQuality('Movie'), 'Auto');
      },
    );

    test('maps quality to a resolution label', () {
      expect(StreamExtractors.resolutionForQuality('1080p'), '1920x1080');
      expect(StreamExtractors.resolutionForQuality('720p'), '1280x720');
      expect(StreamExtractors.resolutionForQuality('Auto'), 'Unknown');
    });
  });
}
