import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/services/iptv_provider.dart';

void main() {
  group('IPTV M3U Parser Tests', () {
    test('parses M3U playlist entries correctly', () {
      const m3uContent = '''
#EXTM3U
#EXTINF:-1 tvg-id="cnn.us" tvg-logo="https://example.com/cnn.png" group-title="News",CNN News Live
https://live.example.com/cnn/index.m3u8
#EXTINF:-1 tvg-id="espn.us" tvg-logo="https://example.com/espn.png" group-title="Sports",ESPN HD
https://live.example.com/espn/stream.m3u8
''';

      final channels = IptvProvider.parseM3u(m3uContent);
      expect(channels.length, 2);

      expect(channels[0].name, 'CNN News Live');
      expect(channels[0].category, 'News');
      expect(channels[0].logoUrl, 'https://example.com/cnn.png');
      expect(channels[0].streamUrl, 'https://live.example.com/cnn/index.m3u8');

      expect(channels[1].name, 'ESPN HD');
      expect(channels[1].category, 'Sports');
      expect(channels[1].logoUrl, 'https://example.com/espn.png');
      expect(channels[1].streamUrl, 'https://live.example.com/espn/stream.m3u8');
    });

    test('handles empty or malformed M3U gracefully', () {
      expect(IptvProvider.parseM3u('').length, 0);
      expect(IptvProvider.parseM3u('#EXTM3U\nInvalid line\n').length, 0);
    });

    test('correctly parses channels with commas in User-Agent and semicolon categories', () {
      const complexM3u = '''
#EXTM3U
#EXTINF:-1 tvg-id="ua.1plus1" tvg-logo="https://example.com/1plus1.png" user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36" group-title="Animation;Classic;Entertainment",1+1 International (720p)
https://live.example.com/stream1.m3u8
''';
      final channels = IptvProvider.parseM3u(complexM3u);
      expect(channels.length, 1);
      expect(channels[0].name, '1+1 International (720p)');
      expect(channels[0].category, 'Animation');
      expect(channels[0].resolution, '720P');
      expect(channels[0].logoUrl, 'https://example.com/1plus1.png');
    });
  });
}
