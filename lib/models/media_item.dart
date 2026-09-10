enum MediaType { movie, series }

enum ProviderType { movieBox, fourKHdHub, liveTv, addons }

extension ProviderTypeExtension on ProviderType {
  String get label {
    switch (this) {
      case ProviderType.movieBox:
        return 'MovieBox';
      case ProviderType.fourKHdHub:
        return '4KHDHub';
      case ProviderType.liveTv:
        return 'Live TV';
      case ProviderType.addons:
        return 'Addons';
    }
  }

  String get shortId {
    switch (this) {
      case ProviderType.movieBox:
        return 'moviebox';
      case ProviderType.fourKHdHub:
        return 'fourkhdhub';
      case ProviderType.liveTv:
        return 'livetv';
      case ProviderType.addons:
        return 'addons';
    }
  }
}

class MediaItem {
  final String id;
  final String title;
  final MediaType mediaType;
  final String? year;
  final String? posterUrl;
  final String? backdropUrl;
  final double? rating;
  final String? genre;
  final int? seasonCount;
  final ProviderType provider;
  final bool isAdult;
  final String? languageTag;

  const MediaItem({
    required this.id,
    required this.title,
    required this.mediaType,
    this.year,
    this.posterUrl,
    this.backdropUrl,
    this.rating,
    this.genre,
    this.seasonCount,
    this.provider = ProviderType.movieBox,
    this.isAdult = false,
    this.languageTag,
  });

  bool get isSeries => mediaType == MediaType.series;

  /// Checks if this item belongs to a specific genre or curated category
  bool matchesCategory(String category) {
    final catLower = category.trim().toLowerCase();
    if (catLower.isEmpty) return false;

    final titleLower = title.toLowerCase();
    final genreLower = genre?.toLowerCase() ?? '';
    final langLower = (languageTag ?? '').toLowerCase();

    // 1. Marvel / MCU
    if (catLower == 'marvel') {
      const marvelKeywords = [
        'marvel',
        'avengers',
        'spider-man',
        'spiderman',
        'iron man',
        'thor',
        'captain america',
        'deadpool',
        'wolverine',
        'x-men',
        'guardians of the galaxy',
        'black panther',
        'ant-man',
        'doctor strange',
        'loki',
        'mcu',
        'wakanda',
        'thunderbolts',
        'daredevil',
        'fantastic four',
        'hulk',
        'venom',
      ];
      return marvelKeywords.any(
        (kw) => titleLower.contains(kw) || genreLower.contains(kw),
      );
    }

    // 2. Bollywood / Indian cinema
    if (catLower == 'bollywood') {
      return langLower.contains('hindi') ||
          titleLower.contains('hindi') ||
          genreLower.contains('bollywood') ||
          genreLower.contains('indian') ||
          genreLower.contains('hindi');
    }

    // 3. Anime
    if (catLower == 'anime') {
      return genreLower.contains('anime') ||
          genreLower.contains('animation') ||
          titleLower.contains('anime') ||
          langLower.contains('japanese');
    }

    // 4. Sci-Fi & Fantasy
    if (catLower == 'sci-fi' ||
        catLower == 'scifi' ||
        catLower == 'science fiction' ||
        catLower == 'fantasy') {
      const sciFiKeywords = [
        'sci-fi',
        'science fiction',
        'scifi',
        'fantasy',
        'supernatural',
        'alien',
        'space',
        'futuristic',
        'dystopian',
        'cyberpunk',
        'multiverse',
        'time travel',
      ];
      return sciFiKeywords.any(
        (kw) => genreLower.contains(kw) || titleLower.contains(kw),
      );
    }

    // 5. Horror & Supernatural
    if (catLower == 'horror' || catLower == 'scary') {
      const horrorKeywords = [
        'horror',
        'scary',
        'ghost',
        'haunted',
        'evil',
        'exorcist',
        'exorcism',
        'conjuring',
        'paranormal',
        'creepy',
        'slasher',
        'zombie',
        'demon',
        'demonic',
        'occult',
        'curse',
        'witch',
        'nightmare',
      ];
      return horrorKeywords.any(
        (kw) => genreLower.contains(kw) || titleLower.contains(kw),
      );
    }

    // 6. Documentary & True Stories
    if (catLower == 'documentary' ||
        catLower == 'docuseries' ||
        catLower == 'docu') {
      const docuKeywords = [
        'documentary',
        'docuseries',
        'docu',
        'biography',
        'biographical',
        'history',
        'historical',
        'true story',
        'nature',
        'wildlife',
        'planet',
        'investigative',
      ];
      return docuKeywords.any(
        (kw) => genreLower.contains(kw) || titleLower.contains(kw),
      );
    }

    // 7. Action & Adventure
    if (catLower == 'action' || catLower == 'adventure') {
      const actionKeywords = [
        'action',
        'adventure',
        'martial arts',
        'superhero',
        'assassin',
        'combat',
        'warfare',
        'spy',
        'heist',
      ];
      return actionKeywords.any(
        (kw) => genreLower.contains(kw) || titleLower.contains(kw),
      );
    }

    // 8. Comedy
    if (catLower == 'comedy' || catLower == 'funny') {
      const comedyKeywords = [
        'comedy',
        'humor',
        'funny',
        'sitcom',
        'stand-up',
        'satire',
        'parody',
        'hilarious',
      ];
      return comedyKeywords.any(
        (kw) => genreLower.contains(kw) || titleLower.contains(kw),
      );
    }

    // 9. Thriller / Mystery / Crime
    if (catLower == 'thriller' ||
        catLower == 'mystery' ||
        catLower == 'crime') {
      return genreLower.contains('thriller') ||
          genreLower.contains('mystery') ||
          genreLower.contains('crime') ||
          genreLower.contains('suspense') ||
          titleLower.contains('thriller') ||
          titleLower.contains('mystery') ||
          titleLower.contains('crime');
    }

    // 10. Romance
    if (catLower == 'romance' || catLower == 'romantic') {
      return genreLower.contains('romance') ||
          genreLower.contains('romantic') ||
          titleLower.contains('love') ||
          titleLower.contains('romance');
    }

    // 11. Generic genre match
    return genreLower.contains(catLower) || titleLower.contains(catLower);
  }

  String get cleanTitle => parseTitleTags(title).cleanTitle;
  String? get effectiveLanguageTag =>
      languageTag ?? parseTitleTags(title).languageTag;
  bool get isCam => parseTitleTags(title).isCam;
  String? get qualityTag => parseTitleTags(title).qualityTag;

  /// Extracts language/audio tags like [Hindi], [Dual Audio], (English)
  /// and quality tags like [CAM], [HD-CAM], [TS],
  /// and returns a clean title and the extracted tags.
  static ({
    String cleanTitle,
    String? languageTag,
    bool isCam,
    String? qualityTag,
  })
  parseTitleTags(String raw) {
    if (raw.isEmpty) {
      return (
        cleanTitle: raw,
        languageTag: null,
        isCam: false,
        qualityTag: null,
      );
    }

    // 1. Bracketed or parenthesized language/audio tags:
    final tagRegex = RegExp(
      r'[\[\(]\s*(Hindi(?:\s*Dubbed)?|Dual\s*Audio|Multi(?:\s*Audio)?|English(?:\s*Dubbed)?|Tamil(?:\s*Dubbed)?|Telugu(?:\s*Dubbed)?|Malayalam|Kannada|Bengali|Korean|Japanese|Chinese|Spanish|French|German|Russian|Dubbed)\s*[\]\)]',
      caseSensitive: false,
    );

    // 2. Bracketed, separated, or standalone CAM / Telesync / Pre-DVD tags:
    final camRegex = RegExp(
      r'([\[\(]\s*(CAM(?:\s*-?\s*RIP)?|HD(?:\s*-?\s*CAM)|Pre-?DVD|TELESYNC|TS|HQ-?CAM)\s*[\]\)]|[-–—:]\s*\b(CAM(?:\s*-?\s*RIP)?|HD(?:\s*-?\s*CAM)|Pre-?DVD|TELESYNC|TS|HQ-?CAM)\b|\b(CAM(?:\s*-?\s*RIP)?|HD(?:\s*-?\s*CAM)|Pre-?DVD|TELESYNC|TS|HQ-?CAM)\b)',
      caseSensitive: false,
    );

    String? extractedTag;
    final match = tagRegex.firstMatch(raw);
    if (match != null) {
      extractedTag = match.group(1)?.trim();
    }

    // Trailing language suffix: " - Hindi Dubbed", " - Dual Audio", " : Hindi"
    if (extractedTag == null) {
      final trailRegex = RegExp(
        r'[-–—:]\s*\b(Hindi(?:\s*Dubbed)?|Dual\s*Audio|Multi(?:\s*Audio)?|English(?:\s*Dubbed)?|Tamil(?:\s*Dubbed)?|Telugu(?:\s*Dubbed)?|Malayalam|Kannada|Dubbed)\b\s*$',
        caseSensitive: false,
      );
      final trailMatch = trailRegex.firstMatch(raw);
      if (trailMatch != null) {
        extractedTag = trailMatch.group(1)?.trim();
      }
    }

    bool isCam = false;
    String? qualityTag;
    final camMatch = camRegex.firstMatch(raw);
    if (camMatch != null) {
      isCam = true;
      final rawQ = camMatch.group(0)?.trim().toUpperCase() ?? 'CAM';
      qualityTag = (rawQ.contains('TS') || rawQ.contains('TELESYNC'))
          ? 'TELESYNC'
          : 'CAM';
    }

    // 3. Clean up title (remove language tags, CAM tags, and extra spaces)
    var cleaned = raw
        .replaceAll(tagRegex, ' ')
        .replaceAll(camRegex, ' ')
        .replaceAll(
          RegExp(
            r'[-–—:]\s*\b(Hindi(?:\s*Dubbed)?|Dual\s*Audio|Multi(?:\s*Audio)?|English(?:\s*Dubbed)?|Tamil(?:\s*Dubbed)?|Telugu(?:\s*Dubbed)?|Malayalam|Kannada|Dubbed)\b\s*$',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (extractedTag != null && extractedTag.isNotEmpty) {
      extractedTag = extractedTag
          .split(' ')
          .map((w) {
            if (w.isEmpty) return w;
            return w[0].toUpperCase() + w.substring(1).toLowerCase();
          })
          .join(' ');
    }

    return (
      cleanTitle: cleaned.isNotEmpty ? cleaned : raw.trim(),
      languageTag: extractedTag,
      isCam: isCam,
      qualityTag: qualityTag,
    );
  }

  MediaItem copyWith({
    String? id,
    String? title,
    MediaType? mediaType,
    String? year,
    String? posterUrl,
    String? backdropUrl,
    double? rating,
    String? genre,
    int? seasonCount,
    ProviderType? provider,
    bool? isAdult,
    String? languageTag,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      mediaType: mediaType ?? this.mediaType,
      year: year ?? this.year,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      rating: rating ?? this.rating,
      genre: genre ?? this.genre,
      seasonCount: seasonCount ?? this.seasonCount,
      provider: provider ?? this.provider,
      isAdult: isAdult ?? this.isAdult,
      languageTag: languageTag ?? this.languageTag,
    );
  }

  factory MediaItem.fromMovieBoxJson(Map<dynamic, dynamic> json) {
    final rawId = json['subjectId'] ?? json['id'] ?? '';
    final rawTitle = (json['title'] ?? json['name'] ?? 'Untitled').toString();
    final parsed = parseTitleTags(rawTitle);
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
      isAdult: isAdult,
      languageTag: languageTag,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'mediaType': mediaType.name,
    'year': year,
    'posterUrl': posterUrl,
    'backdropUrl': backdropUrl,
    'rating': rating,
    'genre': genre,
    'seasonCount': seasonCount,
    'provider': provider.name,
    'isAdult': isAdult,
    'languageTag': languageTag,
  };

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final rawTitle = (json['title'] ?? '').toString();
    final parsed = parseTitleTags(rawTitle);
    final title = parsed.cleanTitle;
    final languageTag = json['languageTag']?.toString() ?? parsed.languageTag;

    return MediaItem(
      id: json['id'] ?? '',
      title: title,
      mediaType: json['mediaType'] == 'series'
          ? MediaType.series
          : MediaType.movie,
      year: json['year'],
      posterUrl: json['posterUrl'],
      backdropUrl: json['backdropUrl'],
      rating: (json['rating'] as num?)?.toDouble(),
      genre: json['genre'],
      seasonCount: json['seasonCount'],
      provider: ProviderType.values.firstWhere(
        (e) => e.name == json['provider'],
        orElse: () => ProviderType.movieBox,
      ),
      isAdult: json['isAdult'] == true,
      languageTag: languageTag,
    );
  }
}
