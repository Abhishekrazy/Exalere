import '../../models/media_details.dart';
import '../../models/media_item.dart';

/// Encapsulates vendor-specific JSON parsing for MovieBox responses.
/// Decouples core Exalere models from third-party vendor data schemas.
class MovieBoxParser {
  /// Parses a raw MovieBox JSON item into a standardized [MediaItem].
  static MediaItem parseMediaItem(Map<dynamic, dynamic> json) {
    final rawId = json['subjectId'] ?? json['id'] ?? '';
    final rawTitle = (json['title'] ?? json['name'] ?? 'Untitled').toString();
    final parsed = MediaItem.parseTitleTags(rawTitle);
    final title = parsed.cleanTitle;
    final languageTag = json['languageTag']?.toString() ?? parsed.languageTag;
    final stype = json['subjectType'] ?? json['stype'] ?? 1;
    final mediaType = (stype == 2) ? MediaType.series : MediaType.movie;

    String? year;
    final releaseDate =
        json['releaseDate'] ?? json['year'] ?? json['releaseInfo'];
    if (releaseDate != null) {
      final str = releaseDate.toString();
      final match = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(str);
      year = match?.group(0) ?? (str.length >= 4 ? str.substring(0, 4) : str);
    }

    String? poster;
    if (json['cover'] is Map) {
      poster = json['cover']['url'];
    }
    poster ??= json['coverUrl'] ?? json['poster'] ?? json['pic'];

    String? backdrop;
    if (json['horizontalCover'] is Map) {
      backdrop = json['horizontalCover']['url'];
    } else if (json['banner'] is Map) {
      backdrop = json['banner']['url'];
    } else if (json['horizontalCoverList'] is List &&
        (json['horizontalCoverList'] as List).isNotEmpty) {
      final first = (json['horizontalCoverList'] as List).first;
      if (first is Map) {
        backdrop = first['url'];
      } else if (first is String) {
        backdrop = first;
      }
    }
    backdrop ??=
        json['horizontalCoverUrl'] ??
        json['bannerUrl'] ??
        json['horizontalCover']?.toString() ??
        json['backdrop'] ??
        json['bgPic'] ??
        json['backdropUrl'];

    double? rating;
    final rawRating = json['imdbRatingValue'] ?? json['rating'];
    if (rawRating != null) {
      rating = double.tryParse(rawRating.toString());
    }

    final List<String> extractedGenres = [];
    if (json['genre'] is String &&
        (json['genre'] as String).trim().isNotEmpty) {
      extractedGenres.addAll(
        (json['genre'] as String)
            .split(RegExp(r'[,/|]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty),
      );
    } else if (json['genre'] is List) {
      for (final g in json['genre'] as List) {
        if (g != null && g.toString().trim().isNotEmpty) {
          extractedGenres.add(g.toString().trim());
        }
      }
    }
    if (json['tags'] is List) {
      for (final t in json['tags'] as List) {
        final str = t?.toString().trim() ?? '';
        if (str.isNotEmpty && !extractedGenres.contains(str)) {
          extractedGenres.add(str);
        }
      }
    }
    if (json['tag'] is List) {
      for (final t in json['tag'] as List) {
        final str = t?.toString().trim() ?? '';
        if (str.isNotEmpty && !extractedGenres.contains(str)) {
          extractedGenres.add(str);
        }
      }
    } else if (json['tag'] is String &&
        (json['tag'] as String).trim().isNotEmpty) {
      final str = (json['tag'] as String).trim();
      if (!extractedGenres.contains(str)) {
        extractedGenres.add(str);
      }
    }
    final String? genre = extractedGenres.isNotEmpty
        ? extractedGenres.join(', ')
        : null;

    int? seasonCount;
    if (json['season'] != null) {
      seasonCount = int.tryParse(json['season'].toString());
    }

    // Determine if content is adult / age-restricted
    bool isAdult = false;
    final rawRestrictKid = json['restrictKid'];
    if (rawRestrictKid == 1 ||
        rawRestrictKid == '1' ||
        rawRestrictKid == true ||
        rawRestrictKid == 'true') {
      isAdult = true;
    }

    final List<String> allTagsAndGenres = [];
    if (json['genre'] is String) {
      allTagsAndGenres.add(json['genre'].toString().toLowerCase());
    } else if (json['genre'] is List) {
      for (final g in json['genre'] as List) {
        allTagsAndGenres.add(g.toString().toLowerCase());
      }
    }
    if (json['tag'] is String) {
      allTagsAndGenres.add(json['tag'].toString().toLowerCase());
    } else if (json['tag'] is List) {
      for (final t in json['tag'] as List) {
        allTagsAndGenres.add(t.toString().toLowerCase());
      }
    }
    if (json['tags'] is List) {
      for (final t in json['tags'] as List) {
        allTagsAndGenres.add(t.toString().toLowerCase());
      }
    }

    const adultKeywords = [
      'hentai',
      'ecchi',
      'erotica',
      'erotic',
      'adult',
      'uncensored',
      '18+',
      'nsfw',
      'xxx',
      'smut',
      'r18',
      'r-18',
    ];

    for (final tag in allTagsAndGenres) {
      for (final kw in adultKeywords) {
        if (tag.contains(kw)) {
          isAdult = true;
          break;
        }
      }
      if (isAdult) break;
    }

    final titleStr = title.toString();
    final adultTitleRegex = RegExp(
      r'\b(xxx|porn|erotic|erotica|sex|nsfw|nude|18\+|hentai|ecchi|sensual|uncensored|smut|r18|r-18|anime edition)\b',
      caseSensitive: false,
    );
    if (adultTitleRegex.hasMatch(titleStr)) {
      isAdult = true;
    }

    final resLink = json['resourceLink']?.toString().toLowerCase() ?? '';
    if (resLink.contains('hentai') || resLink.contains('uncensored')) {
      isAdult = true;
    }

    return MediaItem(
      id: rawId.toString(),
      title: title.toString(),
      mediaType: mediaType,
      year: year,
      posterUrl: poster?.toString(),
      backdropUrl: backdrop?.toString(),
      rating: rating,
      genre: genre,
      seasonCount: seasonCount,
      provider: ProviderType.movieBox,
      providerId: 'moviebox',
      isAdult: isAdult,
      languageTag: languageTag,
    );
  }

  /// Parses a raw MovieBox season JSON into a standardized [Season].
  static Season parseSeason(Map<dynamic, dynamic> json) {
    final se = json['se'] ?? json['season'] ?? 1;
    final maxEp = json['maxEp'] ?? json['episodeCount'] ?? 0;
    final List<Episode> eps = [];
    if (json['episodes'] is List) {
      for (final epJson in json['episodes']) {
        eps.add(Episode.fromJson(epJson));
      }
    } else {
      for (int i = 1; i <= (maxEp as int); i++) {
        eps.add(Episode(season: se, episode: i, title: 'Episode $i'));
      }
    }
    return Season(seasonNumber: se, episodeCount: maxEp, episodes: eps);
  }

  /// Parses a raw MovieBox details response into a standardized [MediaDetails].
  static MediaDetails parseMediaDetails(Map<dynamic, dynamic> json) {
    final subject = json['data']?['subject'] ?? json['subject'] ?? json;
    final rawId = subject['subjectId'] ?? subject['id'] ?? '';
    final rawTitle = (subject['title'] ?? subject['name'] ?? 'Untitled')
        .toString();
    final parsed = MediaItem.parseTitleTags(rawTitle);
    final title = parsed.cleanTitle;
    final languageTag = parsed.languageTag;
    final stype = subject['subjectType'] ?? subject['stype'] ?? 1;
    final mediaType = (stype == 2) ? MediaType.series : MediaType.movie;

    String? year;
    final releaseDate = subject['releaseDate'] ?? subject['year'];
    if (releaseDate != null) {
      final str = releaseDate.toString();
      final match = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(str);
      year = match?.group(0) ?? (str.length >= 4 ? str.substring(0, 4) : str);
    }

    final desc = subject['description'] ?? subject['intro'];
    final tagline = subject['tagline'];

    String? imdb;
    final rawRating = subject['imdbRatingValue'] ?? subject['rating'];
    if (rawRating != null) {
      imdb = rawRating.toString();
    }

    final director = subject['director'];
    final stars = subject['stars'];

    String? poster;
    if (subject['cover'] is Map) {
      poster = subject['cover']['url'];
    }
    poster ??= subject['coverUrl'] ?? subject['poster'] ?? subject['pic'];

    String? backdrop;
    if (subject['banner'] is Map) {
      backdrop = subject['banner']['url'];
    } else if (subject['horizontalCover'] is Map) {
      backdrop = subject['horizontalCover']['url'];
    }
    backdrop ??=
        subject['bannerUrl'] ??
        subject['horizontalCoverUrl'] ??
        subject['backdrop'] ??
        subject['bgPic'];

    String? duration;
    final durSec = subject['duration'] ?? subject['durationSeconds'];
    if (durSec != null) {
      final sec = int.tryParse(durSec.toString()) ?? 0;
      if (sec > 0) {
        final mins = (sec / 60).round();
        duration = '${mins}m';
      }
    }

    final List<String> genres = [];
    if (subject['genre'] is List) {
      for (final g in subject['genre']) {
        genres.add(g.toString());
      }
    } else if (subject['genre'] is String) {
      genres.add(subject['genre']);
    }

    final List<Season> seasonsList = [];
    final seasonData = json['seasons'] ?? subject['seasons'];
    if (seasonData is Map && seasonData['seasons'] is List) {
      for (final s in seasonData['seasons']) {
        seasonsList.add(parseSeason(s));
      }
    }

    final List<AudioTrackOption> dubsList = [];
    if (subject['dubs'] is List) {
      for (final d in subject['dubs']) {
        if (d is Map) {
          final sId = (d['subjectId'] ?? d['id'] ?? '').toString();
          final lang = (d['lanName'] ?? d['language'] ?? d['lang'] ?? 'Unknown')
              .toString();
          final label = (d['title'] ?? d['name'] ?? d['lanName'] ?? lang)
              .toString();
          if (sId.isNotEmpty) {
            dubsList.add(
              AudioTrackOption(subjectId: sId, language: lang, label: label),
            );
          }
        }
      }
    }

    return MediaDetails(
      id: rawId.toString(),
      title: title.toString(),
      description: desc?.toString(),
      tagline: tagline?.toString(),
      mediaType: mediaType,
      year: year,
      imdbRating: imdb,
      director: director?.toString(),
      stars: stars?.toString(),
      posterUrl: poster?.toString(),
      backdropUrl: backdrop?.toString(),
      duration: duration,
      genres: genres,
      seasons: seasonsList,
      dubs: dubsList,
      provider: ProviderType.plugins,
      languageTag: languageTag,
    );
  }
}
