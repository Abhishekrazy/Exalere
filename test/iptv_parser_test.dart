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
      expect(
        channels[1].streamUrl,
        'https://live.example.com/espn/stream.m3u8',
      );
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

    test('correctly parses country from tvg-country and tvg-id', () {
      const countryM3u = '''
#EXTM3U
#EXTINF:-1 tvg-id="4TVNews.in@SD" tvg-country="IN" tvg-logo="https://example.com/4tv.png" group-title="News",4TV News
https://live.example.com/4tv.m3u8
#EXTINF:-1 tvg-id="Bloomberg.us@HD" tvg-logo="https://example.com/bloomberg.png" group-title="News",Bloomberg US
https://live.example.com/bloomberg.m3u8
#EXTINF:-1 tvg-logo="https://example.com/unknown.png" group-title="Movies",Classic Cinema
https://live.example.com/classic.m3u8
''';

      final channels = IptvProvider.parseM3u(countryM3u, defaultCountry: 'IN');
      expect(channels.length, 3);

      expect(channels[0].name, '4TV News');
      expect(channels[0].country, 'IN');

      expect(channels[1].name, 'Bloomberg US');
      expect(channels[1].country, 'US');

      // Falls back to defaultCountry
      expect(channels[2].name, 'Classic Cinema');
      expect(channels[2].country, 'IN');
    });

    test('IptvCountry popularCountries includes India as primary', () {
      expect(IptvProvider.popularCountries.first.code, 'IN');
      expect(IptvProvider.popularCountries.first.name, 'India');
      expect(IptvProvider.popularCountries.first.flag, '🇮🇳');
    });

    test('combines duplicate channels into multi-server sources', () {
      const multiServerM3u = '''
#EXTM3U
#EXTINF:-1 tvg-id="AajTak.in@HD" tvg-country="IN" tvg-language="Hindi" tvg-logo="https://example.com/aajtak.png" group-title="News",Aaj Tak (1080p)
https://live.example.com/aajtak_1080p.m3u8
#EXTINF:-1 tvg-id="AajTak.in@SD" tvg-country="IN" tvg-language="hin" tvg-logo="https://example.com/aajtak.png" group-title="News",Aaj Tak (720p)
https://live.example.com/aajtak_720p.m3u8
#EXTINF:-1 tvg-id="AajTak.in" tvg-country="IN" tvg-language="Hindi" group-title="News",Aaj Tak [Not 24/7]
https://live.example.com/aajtak_backup.m3u8
#EXTINF:-1 tvg-id="NDTV.in@HD" tvg-country="IN" tvg-language="English" group-title="News",NDTV 24x7
https://live.example.com/ndtv.m3u8
''';

      final channels = IptvProvider.parseM3u(
        multiServerM3u,
        defaultCountry: 'IN',
        combineServers: true,
      );

      // 3 Aaj Tak streams should combine into 1 card + 1 NDTV card = 2 channels total
      expect(channels.length, 2);

      final aajTak = channels.firstWhere((c) => c.name == 'Aaj Tak');
      expect(aajTak.sources.length, 3);
      expect(
        aajTak.sources[0].url,
        'https://live.example.com/aajtak_1080p.m3u8',
      );
      expect(
        aajTak.sources[1].url,
        'https://live.example.com/aajtak_720p.m3u8',
      );
      expect(
        aajTak.sources[2].url,
        'https://live.example.com/aajtak_backup.m3u8',
      );
      expect(aajTak.logoUrl, 'https://example.com/aajtak.png');
      expect(aajTak.language, 'HIN');

      final ndtv = channels.firstWhere((c) => c.name == 'NDTV 24x7');
      expect(ndtv.sources.length, 1);
      expect(ndtv.language, 'ENG');
    });

    test('IptvLanguage popularLanguages includes ALL, HIN, ENG', () {
      expect(IptvProvider.popularLanguages.first.code, 'ALL');
      final hindi = IptvProvider.popularLanguages.firstWhere(
        (l) => l.code == 'HIN',
      );
      expect(hindi.name, 'Hindi');
      expect(hindi.nativeName, 'हिन्दी');
      final english = IptvProvider.popularLanguages.firstWhere(
        (l) => l.code == 'ENG',
      );
      expect(english.name, 'English');
    });

    test('popular channel ranking prioritizes known brand channels', () {
      const mixedM3u = '''
#EXTM3U
#EXTINF:-1 tvg-country="IN" group-title="General",Random Unknown Channel
https://live.example.com/random.m3u8
#EXTINF:-1 tvg-country="IN" group-title="News",Aaj Tak HD
https://live.example.com/aajtak.m3u8
#EXTINF:-1 tvg-country="IN" group-title="Music",9XM
https://live.example.com/9xm.m3u8
''';

      final channels = IptvProvider.parseM3u(
        mixedM3u,
        defaultCountry: 'IN',
        combineServers: true,
      );

      // Aaj Tak and 9XM should appear before Random Unknown Channel
      final aajTakIndex = channels.indexWhere(
        (c) => c.name.contains('Aaj Tak'),
      );
      final nineXmIndex = channels.indexWhere((c) => c.name.contains('9XM'));
      final randomIndex = channels.indexWhere((c) => c.name.contains('Random'));

      expect(aajTakIndex, lessThan(randomIndex));
      expect(nineXmIndex, lessThan(randomIndex));
    });
  });
}
