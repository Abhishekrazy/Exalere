import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/live_channel.dart';
import '../models/stream_source.dart';

class IptvCountry {
  final String code;
  final String name;
  final String flag;

  const IptvCountry({
    required this.code,
    required this.name,
    required this.flag,
  });

  factory IptvCountry.fromJson(Map<String, dynamic> json) {
    return IptvCountry(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      flag: json['flag']?.toString() ?? '🌐',
    );
  }

  Map<String, dynamic> toJson() => {'code': code, 'name': name, 'flag': flag};
}

class IptvLanguage {
  final String code;
  final String name;
  final String nativeName;

  const IptvLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
  });

  factory IptvLanguage.fromJson(Map<String, dynamic> json) {
    return IptvLanguage(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nativeName: json['nativeName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'nativeName': nativeName,
  };
}

class IptvProvider {
  // Free public verified legal IPTV playlists (iptv-org curated streams)
  static const String defaultPlaylistUrl =
      'https://iptv-org.github.io/iptv/index.m3u';

  static const List<IptvLanguage> popularLanguages = [
    IptvLanguage(code: 'ALL', name: 'All Languages', nativeName: 'All'),
    IptvLanguage(code: 'HIN', name: 'Hindi', nativeName: 'हिन्दी'),
    IptvLanguage(code: 'ENG', name: 'English', nativeName: 'English'),
    IptvLanguage(code: 'TAM', name: 'Tamil', nativeName: 'தமிழ்'),
    IptvLanguage(code: 'TEL', name: 'Telugu', nativeName: 'తెలుగు'),
    IptvLanguage(code: 'MAL', name: 'Malayalam', nativeName: 'മലയാളം'),
    IptvLanguage(code: 'KAN', name: 'Kannada', nativeName: 'ಕನ್ನಡ'),
    IptvLanguage(code: 'BEN', name: 'Bengali', nativeName: 'বাংলা'),
    IptvLanguage(code: 'MAR', name: 'Marathi', nativeName: 'मराठी'),
    IptvLanguage(code: 'PAN', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ'),
    IptvLanguage(code: 'GUJ', name: 'Gujarati', nativeName: 'ગુજરાતી'),
    IptvLanguage(code: 'URD', name: 'Urdu', nativeName: 'اردو'),
    IptvLanguage(code: 'SPA', name: 'Spanish', nativeName: 'Español'),
    IptvLanguage(code: 'FRA', name: 'French', nativeName: 'Français'),
    IptvLanguage(code: 'DEU', name: 'German', nativeName: 'Deutsch'),
    IptvLanguage(code: 'ARA', name: 'Arabic', nativeName: 'العربية'),
    IptvLanguage(code: 'JPN', name: 'Japanese', nativeName: '日本語'),
    IptvLanguage(code: 'KOR', name: 'Korean', nativeName: '한국어'),
    IptvLanguage(code: 'POR', name: 'Portuguese', nativeName: 'Português'),
    IptvLanguage(code: 'RUS', name: 'Russian', nativeName: 'Русский'),
    IptvLanguage(code: 'ITA', name: 'Italian', nativeName: 'Italiano'),
    IptvLanguage(code: 'ZHO', name: 'Chinese', nativeName: '中文'),
  ];

  static const List<String> popularKeywords = [
    // India Top News
    'aaj tak', 'abp news', 'ndtv', 'india today', 'republic',
    'zee news', 'news18', 'times now', 'dd news', 'dd national',
    'dd sports', 'dd india', 'sansad tv', 'tv9', 'news 24',
    // India Entertainment & Music
    '9xm', '9x', 'b4u', 'mastiii', 'mtv', 'zoom', 'sony',
    'colors', 'zee', 'star plus', 'dangal', 'shemaroo', 'goldmines',
    // International Top News
    'bbc news', 'cnn', 'sky news', 'bloomberg', 'al jazeera',
    'euronews', 'france 24', 'dw', 'cnbc', 'abc news', 'cbs news',
    // Sports & Nature
    'red bull tv', 'nasa tv', 'discovery', 'nat geo',
  ];

  static const List<IptvCountry> popularCountries = [
    IptvCountry(code: 'IN', name: 'India', flag: '🇮🇳'),
    IptvCountry(code: 'US', name: 'United States', flag: '🇺🇸'),
    IptvCountry(code: 'UK', name: 'United Kingdom', flag: '🇬🇧'),
    IptvCountry(code: 'CA', name: 'Canada', flag: '🇨🇦'),
    IptvCountry(code: 'AU', name: 'Australia', flag: '🇦🇺'),
    IptvCountry(code: 'DE', name: 'Germany', flag: '🇩🇪'),
    IptvCountry(code: 'FR', name: 'France', flag: '🇫🇷'),
    IptvCountry(code: 'ES', name: 'Spain', flag: '🇪🇸'),
    IptvCountry(code: 'IT', name: 'Italy', flag: '🇮🇹'),
    IptvCountry(code: 'JP', name: 'Japan', flag: '🇯🇵'),
    IptvCountry(code: 'KR', name: 'South Korea', flag: '🇰🇷'),
    IptvCountry(code: 'BR', name: 'Brazil', flag: '🇧🇷'),
    IptvCountry(code: 'PK', name: 'Pakistan', flag: '🇵🇰'),
    IptvCountry(code: 'BD', name: 'Bangladesh', flag: '🇧🇩'),
    IptvCountry(code: 'AE', name: 'United Arab Emirates', flag: '🇦🇪'),
    IptvCountry(code: 'ALL', name: 'All Countries', flag: '🌐'),
  ];

  static List<IptvCountry>? _cachedCountryList;

  List<LiveChannel> _cachedChannels = [];
  final Map<String, List<LiveChannel>> _countryCache = {};

  List<LiveChannel> get cachedChannels => _cachedChannels;

  List<String> get categories {
    final cats = _cachedChannels.map((c) => c.category).toSet().toList()
      ..sort();
    return ['All', ...cats];
  }

  Future<List<IptvCountry>> fetchCountries() async {
    if (_cachedCountryList != null && _cachedCountryList!.isNotEmpty) {
      return _cachedCountryList!;
    }
    try {
      final resp = await http
          .get(Uri.parse('https://iptv-org.github.io/api/countries.json'))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(resp.body);
        final countries = list
            .map((e) => IptvCountry.fromJson(Map<String, dynamic>.from(e)))
            .where((c) => c.code.isNotEmpty && c.name.isNotEmpty)
            .toList();

        // Sort alphabetically by name
        countries.sort((a, b) => a.name.compareTo(b.name));

        // Place India and ALL at the front
        final List<IptvCountry> fullList = [
          const IptvCountry(code: 'IN', name: 'India', flag: '🇮🇳'),
          const IptvCountry(code: 'ALL', name: 'All Countries', flag: '🌐'),
          ...countries.where((c) => c.code.toUpperCase() != 'IN'),
        ];
        _cachedCountryList = fullList;
        return fullList;
      }
    } catch (e) {
      debugPrint('Error loading IPTV countries: $e');
    }

    _cachedCountryList = popularCountries;
    return popularCountries;
  }

  Future<List<LiveChannel>> fetchChannels({
    String? customUrl,
    String? countryCode,
    String? languageCode,
    bool forceRefresh = false,
  }) async {
    final effectiveCountry = (countryCode ?? 'IN').toUpperCase();
    final effectiveLanguage = (languageCode ?? 'ALL').toUpperCase();
    final cacheKey =
        '${customUrl ?? effectiveCountry}_${effectiveLanguage.toLowerCase()}';

    if (!forceRefresh &&
        _countryCache.containsKey(cacheKey) &&
        _countryCache[cacheKey]!.isNotEmpty) {
      _cachedChannels = _countryCache[cacheKey]!;
      return _cachedChannels;
    }

    String url;
    if (customUrl != null && customUrl.isNotEmpty) {
      url = customUrl;
    } else if (effectiveCountry != 'ALL') {
      url =
          'https://iptv-org.github.io/iptv/countries/${effectiveCountry.toLowerCase()}.m3u';
    } else if (effectiveLanguage != 'ALL') {
      url =
          'https://iptv-org.github.io/iptv/languages/${effectiveLanguage.toLowerCase()}.m3u';
    } else {
      url = defaultPlaylistUrl;
    }

    try {
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final parsed = parseM3u(
          resp.body,
          defaultCountry: effectiveCountry,
          combineServers: true,
        );

        List<LiveChannel> filtered = parsed;
        if (effectiveLanguage != 'ALL') {
          filtered = parsed.where((c) {
            final l = (c.language ?? '').toUpperCase();
            if (l.contains(effectiveLanguage)) return true;
            final n = c.name.toLowerCase();
            if (effectiveLanguage == 'HIN' &&
                (n.contains('hindi') ||
                    n.contains('hindustan') ||
                    n.contains('aaj tak') ||
                    n.contains('abp') ||
                    n.contains('zee') ||
                    n.contains('ndtv') ||
                    n.contains('india today') ||
                    n.contains('republic bharat') ||
                    n.contains('dd news') ||
                    n.contains('9xm') ||
                    n.contains('mastiii'))) {
              return true;
            }
            if (effectiveLanguage == 'ENG' &&
                (n.contains('english') ||
                    n.contains('news') ||
                    n.contains('bloomberg') ||
                    n.contains('cnn') ||
                    n.contains('bbc') ||
                    n.contains('sky') ||
                    n.contains('cnbc'))) {
              return true;
            }
            if (effectiveLanguage == 'TAM' && n.contains('tamil')) return true;
            if (effectiveLanguage == 'TEL' && n.contains('telugu')) return true;
            if (effectiveLanguage == 'MAL' && n.contains('malayalam')) {
              return true;
            }
            if (effectiveLanguage == 'KAN' && n.contains('kannada')) {
              return true;
            }
            if (effectiveLanguage == 'BEN' &&
                (n.contains('bengali') || n.contains('bangla'))) {
              return true;
            }
            if (effectiveLanguage == 'MAR' && n.contains('marathi')) {
              return true;
            }
            if (effectiveLanguage == 'PAN' && n.contains('punjabi')) {
              return true;
            }
            if (effectiveLanguage == 'GUJ' && n.contains('gujarati')) {
              return true;
            }
            if (effectiveLanguage == 'URD' && n.contains('urdu')) return true;
            return false;
          }).toList();
        }

        if (filtered.isNotEmpty) {
          _countryCache[cacheKey] = filtered;
          _cachedChannels = filtered;
          return _cachedChannels;
        }
      }
    } catch (e) {
      debugPrint('Error fetching IPTV channels for $cacheKey: $e');
    }

    // Fallback verified streams if offline or playlist fetch fails
    if (effectiveCountry == 'IN') {
      _cachedChannels = deduplicateAndRank(_getIndianFallbackChannels());
    } else {
      _cachedChannels = deduplicateAndRank(_getFallbackChannels());
    }
    _countryCache[cacheKey] = _cachedChannels;
    return _cachedChannels;
  }

  static String cleanCategory(String? rawGroup) {
    if (rawGroup == null || rawGroup.trim().isEmpty) return 'General';
    final parts = rawGroup
        .split(RegExp(r'[;/]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'General';
    final cat = parts.first;
    if (cat.length > 1) {
      return cat[0].toUpperCase() + cat.substring(1);
    }
    return cat.toUpperCase();
  }

  static String extractChannelName(String line) {
    final lastCommaIdx = line.lastIndexOf(',');
    if (lastCommaIdx != -1 && lastCommaIdx < line.length - 1) {
      var name = line.substring(lastCommaIdx + 1).trim();
      if (name.startsWith('"') && !name.endsWith('"')) {
        name = name.substring(1).trim();
      }
      return name.isNotEmpty ? name : 'Live Channel';
    }
    return 'Live Channel';
  }

  static String normalizeChannelName(String name) {
    var clean = name
        .replaceAll(
          RegExp(
            r'\s*[\(\[]?\b(?:4k|2160p|1080p|720p|576p|480p|360p|270p|fhd|uhd|hd|sd|not 24\/7|backup|stream \d+|server \d+)\b[\)\]]?',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    clean = clean.replaceAll(RegExp(r'[\s\-\:]+$'), '').trim();
    return clean.isNotEmpty ? clean : name;
  }

  static String normalizeLanguageCode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'ALL';
    final lower = raw.trim().toLowerCase();
    if (lower.contains('hin')) return 'HIN';
    if (lower.contains('eng')) return 'ENG';
    if (lower.contains('tam')) return 'TAM';
    if (lower.contains('tel')) return 'TEL';
    if (lower.contains('mal')) return 'MAL';
    if (lower.contains('kan')) return 'KAN';
    if (lower.contains('ben')) return 'BEN';
    if (lower.contains('mar')) return 'MAR';
    if (lower.contains('pan') || lower.contains('pun')) return 'PAN';
    if (lower.contains('guj')) return 'GUJ';
    if (lower.contains('urd')) return 'URD';
    if (lower.contains('spa')) return 'SPA';
    if (lower.contains('fra') || lower.contains('fre')) return 'FRA';
    if (lower.contains('deu') || lower.contains('ger')) return 'DEU';
    if (lower.contains('ara')) return 'ARA';
    if (lower.contains('jpn')) return 'JPN';
    if (lower.contains('kor')) return 'KOR';
    if (lower.contains('por')) return 'POR';
    if (lower.contains('rus')) return 'RUS';
    if (lower.contains('ita')) return 'ITA';
    if (lower.contains('zho') || lower.contains('chi')) return 'ZHO';
    return raw.toUpperCase();
  }

  static String? extractResolution(String name) {
    final resRegex = RegExp(
      r'\b(4K|2160p|1080p|720p|576p|480p|360p|270p|FHD|UHD|HD|SD)\b',
      caseSensitive: false,
    );
    final match = resRegex.firstMatch(name);
    return match?.group(1)?.toUpperCase();
  }

  static int _resolutionRank(String? res) {
    if (res == null) return 0;
    final r = res.toUpperCase();
    if (r.contains('4K') || r.contains('2160')) return 100;
    if (r.contains('1080') || r.contains('FHD')) return 80;
    if (r.contains('720') || r.contains('HD')) return 60;
    if (r.contains('576') || r.contains('480')) return 40;
    if (r.contains('360')) return 20;
    return 10;
  }

  static int _popularityScore(LiveChannel ch) {
    int score = 0;
    final lowerName = ch.name.toLowerCase();

    for (int i = 0; i < popularKeywords.length; i++) {
      if (lowerName.contains(popularKeywords[i])) {
        // Earlier in list = higher priority
        score += (popularKeywords.length - i) * 10;
        break;
      }
    }

    if (ch.logoUrl != null && ch.logoUrl!.isNotEmpty) {
      score += 5;
    }
    if (ch.sources.length > 1) {
      score += 3;
    }
    return score;
  }

  static List<LiveChannel> deduplicateAndRank(List<LiveChannel> channels) {
    if (channels.isEmpty) return [];

    final Map<String, List<LiveChannel>> grouped = {};

    for (final ch in channels) {
      final normName = normalizeChannelName(ch.name).toLowerCase();
      final country = (ch.country ?? '').toLowerCase();
      final key = '${normName}_$country';
      grouped.putIfAbsent(key, () => []).add(ch);
    }

    final List<LiveChannel> result = [];

    for (final entry in grouped.entries) {
      final group = entry.value;
      if (group.length == 1) {
        final single = group.first;
        final cleanName = normalizeChannelName(single.name);
        result.add(
          single.copyWith(
            name: cleanName.isNotEmpty ? cleanName : single.name,
            sources: single.sources.isNotEmpty
                ? single.sources
                : [
                    StreamSource(
                      quality: single.resolution ?? 'HD',
                      resolution: single.resolution ?? '1080p',
                      format: 'HLS Live',
                      url: single.streamUrl,
                    ),
                  ],
          ),
        );
      } else {
        // Multi-server channel: group all sources
        final logo = group
            .firstWhere(
              (c) => c.logoUrl != null && c.logoUrl!.isNotEmpty,
              orElse: () => group.first,
            )
            .logoUrl;

        final cleanName = normalizeChannelName(group.first.name);

        // Sort streams: prefer 1080p, 720p, etc.
        group.sort((a, b) {
          final resA = _resolutionRank(a.resolution);
          final resB = _resolutionRank(b.resolution);
          return resB.compareTo(resA);
        });

        final List<StreamSource> sources = [];
        final Set<String> seenUrls = {};

        for (final item in group) {
          if (seenUrls.contains(item.streamUrl)) continue;
          seenUrls.add(item.streamUrl);

          final label = item.resolution != null
              ? '${item.resolution} (Server ${sources.length + 1})'
              : 'Server ${sources.length + 1}';

          sources.add(
            StreamSource(
              quality: label,
              resolution: item.resolution ?? '1080p',
              format: 'HLS Live',
              url: item.streamUrl,
            ),
          );
        }

        final best = group.first;
        result.add(
          LiveChannel(
            id: best.id,
            name: cleanName.isNotEmpty ? cleanName : best.name,
            logoUrl: logo,
            category: best.category,
            streamUrl: sources.isNotEmpty ? sources.first.url : best.streamUrl,
            country: best.country,
            resolution: best.resolution,
            language: best.language,
            sources: sources,
          ),
        );
      }
    }

    // Sort by Popularity score descending, then alphabetical
    result.sort((a, b) {
      final scoreA = _popularityScore(a);
      final scoreB = _popularityScore(b);
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return result;
  }

  static List<LiveChannel> parseM3u(
    String content, {
    String? defaultCountry,
    bool combineServers = false,
  }) {
    final List<LiveChannel> channels = [];
    final lines = const LineSplitter().convert(content);

    String? currentName;
    String? currentLogo;
    String? currentGroup;
    String? currentCountry;
    String? currentLanguage;

    final regLogo = RegExp(r'tvg-logo="([^"]*)"');
    final regGroup = RegExp(r'group-title="([^"]*)"');
    final regCountry = RegExp(r'tvg-country="([^"]*)"');
    final regLanguage = RegExp(r'tvg-language="([^"]*)"');
    final regTvgId = RegExp(r'tvg-id="([^"]*)"');
    final regIdCountry = RegExp(
      r'\.([a-z]{2})@[A-Za-z0-9]+',
      caseSensitive: false,
    );

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        currentName = extractChannelName(line);

        final logoMatch = regLogo.firstMatch(line);
        currentLogo = logoMatch?.group(1);

        final groupMatch = regGroup.firstMatch(line);
        currentGroup = cleanCategory(groupMatch?.group(1));

        final countryMatch = regCountry.firstMatch(line);
        currentCountry = countryMatch?.group(1);

        final langMatch = regLanguage.firstMatch(line);
        currentLanguage = normalizeLanguageCode(langMatch?.group(1));

        if (currentCountry == null || currentCountry.isEmpty) {
          final idMatch = regTvgId.firstMatch(line);
          if (idMatch != null) {
            final rawId = idMatch.group(1) ?? '';
            final cMatch = regIdCountry.firstMatch(rawId);
            if (cMatch != null) {
              currentCountry = cMatch.group(1)?.toUpperCase();
            }
          }
        }

        if ((currentCountry == null || currentCountry.isEmpty) &&
            defaultCountry != null &&
            defaultCountry != 'ALL') {
          currentCountry = defaultCountry.toUpperCase();
        }
      } else if (!line.startsWith('#') && line.startsWith('http')) {
        if (currentName != null) {
          final res = extractResolution(currentName);
          channels.add(
            LiveChannel(
              id: 'channel_${channels.length + 1}',
              name: currentName,
              logoUrl: (currentLogo != null && currentLogo.isNotEmpty)
                  ? currentLogo
                  : null,
              category: (currentGroup != null && currentGroup.isNotEmpty)
                  ? currentGroup
                  : 'General',
              streamUrl: line,
              country: currentCountry,
              resolution: res,
              language: currentLanguage,
            ),
          );
        }
        currentName = null;
        currentLogo = null;
        currentGroup = null;
        currentCountry = null;
        currentLanguage = null;
      }
    }

    if (combineServers) {
      return deduplicateAndRank(channels);
    }

    return channels;
  }

  static List<LiveChannel> _getIndianFallbackChannels() {
    return const [
      LiveChannel(
        id: 'in_c1',
        name: '4TV News',
        logoUrl: 'https://jiotvimages.cdn.jio.com/dare_images/images/4_TV.png',
        category: 'News',
        streamUrl: 'https://cdn-4.pishow.tv/live/1007/master.m3u8',
        country: 'IN',
        resolution: '576P',
      ),
      LiveChannel(
        id: 'in_c2',
        name: '9X Jalwa',
        logoUrl: 'https://i.imgur.com/xO8q2vC.png',
        category: 'Music',
        streamUrl: 'https://9xjalwa.akamaized.net/hls/live/2021655/9XJalwa/master.m3u8',
        country: 'IN',
        resolution: '576P',
      ),
      LiveChannel(
        id: 'in_c3',
        name: '9XM',
        logoUrl: 'https://i.imgur.com/xO8q2vC.png',
        category: 'Music',
        streamUrl: 'https://9xm.akamaized.net/hls/live/2021654/9XM/master.m3u8',
        country: 'IN',
        resolution: '576P',
      ),
      LiveChannel(
        id: 'in_c4',
        name: 'DD News HD',
        logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cb/DD_News_Logo.png/512px-DD_News_Logo.png',
        category: 'News',
        streamUrl:
            'https://ddnews.akamaized.net/hls/live/2021650/ddnews/master.m3u8',
        country: 'IN',
        resolution: '1080P',
      ),
    ];
  }

  static List<LiveChannel> _getFallbackChannels() {
    return const [
      LiveChannel(
        id: 'c1',
        name: 'Bloomberg TV News',
        logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/56/Bloomberg_Television_logo.svg/512px-Bloomberg_Television_logo.svg.png',
        category: 'News',
        streamUrl: 'https://live-bloomberg-us.simplestreamcdn.com/live/bloomberg_us/bitrate1.isml/live.m3u8',
      ),
      LiveChannel(
        id: 'c2',
        name: 'Sky News Live',
        logoUrl: 'https://upload.wikimedia.org/wikipedia/en/thumb/e/e0/Sky_News_logo_2015.svg/512px-Sky_News_logo_2015.svg.png',
        category: 'News',
        streamUrl: 'https://skynewsau-live.akamaized.net/hls/live/2002689/skynewsau-extra1/master.m3u8',
      ),
      LiveChannel(
        id: 'c3',
        name: 'Red Bull TV',
        logoUrl: 'https://upload.wikimedia.org/wikipedia/en/thumb/f/f5/Red_Bull_TV_logo.svg/512px-Red_Bull_TV_logo.svg.png',
        category: 'Sports',
        streamUrl: 'https://rbmn-live.akamaized.net/hls/live/590964/BoRB-AT/master.m3u8',
      ),
      LiveChannel(
        id: 'c4',
        name: 'NASA TV Public',
        logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e5/NASA_logo.svg/512px-NASA_logo.svg.png',
        category: 'Science',
        streamUrl: 'https://ntv1.akamaized.net/hls/live/2014075/NASA-NTV1-HLS/master.m3u8',
      ),
      LiveChannel(
        id: 'c5',
        name: 'Euronews English',
        logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4c/Euronews_2016_logo.svg/512px-Euronews_2016_logo.svg.png',
        category: 'News',
        streamUrl: 'https://euronews-euronews-world-1-au.samsung.wurl.tv/playlist.m3u8',
      ),
      LiveChannel(
        id: 'c6',
        name: 'Classic Cinema Movies',
        logoUrl: 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=500&auto=format&fit=crop&q=60',
        category: 'Movies',
        streamUrl:
            'https://stream-relay.koddos.com/live/classicmovies/index.m3u8',
      ),
      LiveChannel(
        id: 'c7',
        name: 'Rakuten TV Action Movies',
        logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/Rakuten_TV_logo.svg/512px-Rakuten_TV_logo.svg.png',
        category: 'Movies',
        streamUrl:
            'https://rakuten-actionmovies-1-eu.rakuten.wurl.tv/playlist.m3u8',
      ),
    ];
  }
}
