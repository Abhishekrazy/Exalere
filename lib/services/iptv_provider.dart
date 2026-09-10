import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/live_channel.dart';

class IptvProvider {
  // Free public verified legal IPTV playlists (iptv-org curated streams)
  static const String defaultPlaylistUrl =
      'https://iptv-org.github.io/iptv/index.m3u';

  List<LiveChannel> _cachedChannels = [];

  List<LiveChannel> get cachedChannels => _cachedChannels;

  List<String> get categories {
    final cats = _cachedChannels.map((c) => c.category).toSet().toList()..sort();
    return ['All', ...cats];
  }

  Future<List<LiveChannel>> fetchChannels({String? customUrl}) async {
    if (_cachedChannels.isNotEmpty && customUrl == null) {
      return _cachedChannels;
    }

    final url = customUrl ?? defaultPlaylistUrl;
    try {
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        _cachedChannels = parseM3u(resp.body);
        if (_cachedChannels.isNotEmpty) {
          return _cachedChannels;
        }
      }
    } catch (e) {
      debugPrint('Error fetching IPTV channels: $e');
    }

    // Fallback verified streams if offline or playlist fetch fails
    _cachedChannels = _getFallbackChannels();
    return _cachedChannels;
  }

  static String cleanCategory(String? rawGroup) {
    if (rawGroup == null || rawGroup.trim().isEmpty) return 'General';
    final parts = rawGroup.split(RegExp(r'[;/]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
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

  static String? extractResolution(String name) {
    final resRegex = RegExp(r'\b(4K|2160p|1080p|720p|576p|480p|360p|270p|FHD|UHD|HD|SD)\b', caseSensitive: false);
    final match = resRegex.firstMatch(name);
    return match?.group(1)?.toUpperCase();
  }

  static List<LiveChannel> parseM3u(String content) {
    final List<LiveChannel> channels = [];
    final lines = const LineSplitter().convert(content);

    String? currentName;
    String? currentLogo;
    String? currentGroup;
    String? currentCountry;

    final regLogo = RegExp(r'tvg-logo="([^"]*)"');
    final regGroup = RegExp(r'group-title="([^"]*)"');
    final regCountry = RegExp(r'tvg-country="([^"]*)"');

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
      } else if (!line.startsWith('#') && line.startsWith('http')) {
        if (currentName != null) {
          final res = extractResolution(currentName);
          channels.add(LiveChannel(
            id: 'channel_${channels.length + 1}',
            name: currentName,
            logoUrl: (currentLogo != null && currentLogo.isNotEmpty) ? currentLogo : null,
            category: (currentGroup != null && currentGroup.isNotEmpty) ? currentGroup : 'General',
            streamUrl: line,
            country: currentCountry,
            resolution: res,
          ));
        }
        currentName = null;
        currentLogo = null;
        currentGroup = null;
        currentCountry = null;
      }
    }

    return channels;
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
        streamUrl: 'https://stream-relay.koddos.com/live/classicmovies/index.m3u8',
      ),
      LiveChannel(
        id: 'c7',
        name: 'Rakuten TV Action Movies',
        logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/Rakuten_TV_logo.svg/512px-Rakuten_TV_logo.svg.png',
        category: 'Movies',
        streamUrl: 'https://rakuten-actionmovies-1-eu.rakuten.wurl.tv/playlist.m3u8',
      ),
    ];
  }
}
