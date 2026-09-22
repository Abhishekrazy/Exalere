enum MediaType { movie, series }

enum ProviderType { movieBox, fourKHdHub, liveTv, plugins }

extension ProviderTypeExtension on ProviderType {
  String get label {
    switch (this) {
      case ProviderType.movieBox:
        return 'MovieBox';
      case ProviderType.fourKHdHub:
        return '4KHDHub';
      case ProviderType.liveTv:
        return 'Live TV';
      case ProviderType.plugins:
        return 'Plugins';
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
      case ProviderType.plugins:
        return 'plugins';
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
  final String? providerId;
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
    this.provider = ProviderType.plugins,
    this.providerId,
    this.isAdult = false,
    this.languageTag,
  });

  String get effectiveProviderId => providerId ?? provider.shortId;

  bool get isSeries => mediaType == MediaType.series;

  bool get isTmdb => int.tryParse(id) != null || providerId == 'tmdb';

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
    String? providerId,
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
      providerId: providerId ?? this.providerId,
      isAdult: isAdult ?? this.isAdult,
      languageTag: languageTag ?? this.languageTag,
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
    if (providerId != null) 'providerId': providerId,
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
        orElse: () => ProviderType.plugins,
      ),
      providerId: json['providerId'] as String?,
      isAdult: json['isAdult'] == true,
      languageTag: languageTag,
    );
  }

  /// Normalizes a media title for cross-provider matching by stripping
  /// parenthesized years, bracketed audio tags, punctuation, and extra whitespace.
  static String normalizeTitleForMatching(String raw) {
    if (raw.isEmpty) return '';
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'\(\s*\d{4}\s*\)'), ' ')
        .replaceAll(RegExp(r'\[.*?\]'), ' ')
        .replaceAll(RegExp(r'\(.*?\)'), ' ')
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Computes a matching score between a [candidate] MediaItem and target metadata
  /// (title, release year, and media type).
  ///
  /// Higher scores indicate a stronger match.
  static int calculateMatchScore({
    required MediaItem candidate,
    required String targetTitle,
    String? targetYear,
    bool? isSeries,
  }) {
    final candNorm = normalizeTitleForMatching(
      candidate.cleanTitle.isNotEmpty ? candidate.cleanTitle : candidate.title,
    );
    final targetNorm = normalizeTitleForMatching(targetTitle);

    if (candNorm.isEmpty || targetNorm.isEmpty) return 0;

    int score = 0;

    // 1. Media type agreement (movie vs series)
    if (isSeries != null) {
      if (candidate.isSeries == isSeries) {
        score += 120;
      } else {
        // Severe penalty for mismatching media type
        score -= 200;
      }
    }

    // 2. Release Year matching
    final candY = int.tryParse(candidate.year ?? '');
    final tgtY = int.tryParse(targetYear ?? '');
    if (candY != null && tgtY != null) {
      final diff = (candY - tgtY).abs();
      if (diff == 0) {
        score += 150; // Exact release year match
      } else if (diff == 1) {
        score += 80; // International release discrepancy (e.g. festival year vs theatrical year)
      } else if (diff <= 2) {
        score += 20;
      } else {
        score -=
            100; // Distant release year (remake or different franchise title)
      }
    }

    // 3. Title matching
    if (candNorm == targetNorm) {
      score += 250; // Exact normalized title match
    } else if (candNorm.startsWith(targetNorm) ||
        targetNorm.startsWith(candNorm)) {
      score += 140;
    } else if (candNorm.contains(targetNorm) || targetNorm.contains(candNorm)) {
      score += 100;
    }

    // 4. Token overlap (Jaccard similarity)
    final candWords = candNorm.split(' ').where((w) => w.length > 1).toSet();
    final targetWords = targetNorm
        .split(' ')
        .where((w) => w.length > 1)
        .toSet();
    if (candWords.isNotEmpty && targetWords.isNotEmpty) {
      final intersection = candWords.intersection(targetWords).length;
      final union = candWords.union(targetWords).length;
      score += (intersection / union * 100).toInt();
    }

    return score;
  }

  /// Selects the best matching [MediaItem] from [candidates] based on title,
  /// release year, and media type.
  ///
  /// Solves cross-provider identifier mismatches (e.g. MovieBox internal subjectId
  /// vs 4KHDHub path slugs vs TMDB numeric IDs).
  static MediaItem? findBestMatch({
    required List<MediaItem> candidates,
    required String title,
    String? year,
    bool? isSeries,
    int minScoreThreshold = 50,
  }) {
    if (candidates.isEmpty) return null;

    MediaItem? bestItem;
    int bestScore = -999999;

    for (final cand in candidates) {
      final score = calculateMatchScore(
        candidate: cand,
        targetTitle: title,
        targetYear: year,
        isSeries: isSeries,
      );
      if (score > bestScore) {
        bestScore = score;
        bestItem = cand;
      }
    }

    if (bestScore >= minScoreThreshold) {
      return bestItem;
    }
    return null;
  }
}
