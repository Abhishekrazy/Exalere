import 'dart:convert';

import 'package:exalere/services/tmdb_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('YouTube InnerTube VisionOS resolves direct HLS stream in Dart', () async {
    const videoId = 'LdOM0x0XDMo'; // Tenet trailer
    const defaultVisitorId =
        'CgtDaGJqdDZuYTZpOCihz5fVBjIKCgJJThIEGgAgGWLfAgrcAjIxLllUPVhGOTdJVmdIQUt6S3JQOHlNeUFKT1hjNkV0OGpzTnRXSlJrZnRoc3k0cG82aGNZTW50ME9FZ1RmRlEtWnVISjlvZ08xSjlraFlqNmIwZUNnbFJPTzZVZjFHaXVQdzJVYXRIQ1BHZFJ2OGhWWXRFeENYeEh4QzF4SE1FdnRjNzh3RnUtczdoNFhrNkNpdkJUejVDQnItNWxTU2ZzbDRSOGhpRzd2UTl3TG5hZFZkT09LZVNxMVQ4cXAyVkM1NnhuTEt6ZlBBNFdtUEpfVWlZS25aQXVVbVE5MFFQRFZHNzNwWHVXRkxacnRwX3V2cTVBYmE5VUVMeUxtYUZIcHQ3eUt0RFE4Q2pyNE9mXzViajQ4a2Ztd3lhcVdGcWdKLUNyTmlnb2oyU2IxMkNwNVE4WWVSSS1hUV81bGVqd0tEUXJ3X0JzUW4tWkRTRTVzeGtzOGZ1T1NuZw==';

    final apiUrl = Uri.parse(
      'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
    );

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-YouTube-Client-Name': '101',
      'X-YouTube-Client-Version': '1.02',
      'Origin': 'https://www.youtube.com',
      'X-Goog-Visitor-Id': defaultVisitorId,
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15',
    };

    final clientMap = <String, dynamic>{
      'clientName': 'VISIONOS',
      'clientVersion': '1.02',
      'deviceMake': 'Apple',
      'deviceModel': 'RealityDevice17,1',
      'osName': 'visionOS',
      'osVersion': '26.5.23O471',
      'userAgent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15',
      'visitorData': defaultVisitorId,
      'hl': 'en',
      'gl': 'US',
    };

    final body = jsonEncode({
      'context': {'client': clientMap},
      'videoId': videoId,
      'contentCheckOk': true,
      'racyCheckOk': true,
    });

    final stopwatch = Stopwatch()..start();
    final resp = await http.post(apiUrl, headers: headers, body: body);
    stopwatch.stop();

    expect(resp.statusCode, 200);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final playability = data['playabilityStatus'] as Map<String, dynamic>?;
    expect(playability?['status'], 'OK');

    final streamingData = data['streamingData'] as Map<String, dynamic>?;
    final hls = streamingData?['hlsManifestUrl'] as String?;
    expect(hls, isNotNull);
    expect(hls!.startsWith('https://'), isTrue);
  });

  test(
    'TmdbService.resolveTrailerDirectUrl resolves and caches HLS stream',
    () async {
      const videoId = 'LdOM0x0XDMo';
      final service = TmdbService();

      final url = await service.resolveTrailerDirectUrl(videoId);
      expect(url.isNotEmpty, isTrue);
      expect(url.startsWith('https://'), isTrue);
      expect(url.contains('youtube.com'), isFalse);
      expect(url.contains('.m3u8') || url.contains('googlevideo.com'), isTrue);

      // Second call should return instant cached result
      final stopwatch = Stopwatch()..start();
      final cachedUrl = await service.resolveTrailerDirectUrl(videoId);
      stopwatch.stop();
      expect(cachedUrl, url);
      expect(stopwatch.elapsedMilliseconds < 5, isTrue);
    },
  );
}
