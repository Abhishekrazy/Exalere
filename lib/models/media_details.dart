import 'media_item.dart';

enum SkipType { intro, recap, outro }

class SkipInterval {
  final SkipType type;
  final int startSeconds;
  final int endSeconds;
  final String label;

  const SkipInterval({
    required this.type,
    required this.startSeconds,
    required this.endSeconds,
    required this.label,
  });

  bool contains(int positionSeconds) =>
      positionSeconds >= startSeconds && positionSeconds < endSeconds;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'startSeconds': startSeconds,
    'endSeconds': endSeconds,
    'label': label,
  };

  factory SkipInterval.fromJson(Map<String, dynamic> json) {
    final t = SkipType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => SkipType.intro,
    );
    return SkipInterval(
      type: t,
      startSeconds: json['startSeconds'] ?? 0,
      endSeconds: json['endSeconds'] ?? 0,
      label: json['label'] ?? 'Skip',
    );
  }
}

class Episode {
  final int season;
  final int episode;
  final String title;
  final String? thumbnail;
  final String? overview;
  final List<SkipInterval> skipIntervals;

  const Episode({
    required this.season,
    required this.episode,
    required this.title,
    this.thumbnail,
    this.overview,
    this.skipIntervals = const [],
  });

  Episode copyWith({
    int? season,
    int? episode,
    String? title,
    String? thumbnail,
    String? overview,
    List<SkipInterval>? skipIntervals,
  }) {
    return Episode(
      season: season ?? this.season,
      episode: episode ?? this.episode,
      title: title ?? this.title,
      thumbnail: thumbnail ?? this.thumbnail,
      overview: overview ?? this.overview,
      skipIntervals: skipIntervals ?? this.skipIntervals,
    );
  }

  factory Episode.fromJson(Map<String, dynamic> json) {
    final List<SkipInterval> skips = [];
    if (json['skipIntervals'] is List) {
      for (final s in json['skipIntervals']) {
        if (s is Map) {
          skips.add(SkipInterval.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }
    final introStart =
        json['introStart'] ?? json['op_start'] ?? json['headTime'];
    final introEnd = json['introEnd'] ?? json['op_end'];
    final introDuration = json['openingDuration'] ?? json['op_duration'];
    if (introStart != null) {
      final s = int.tryParse(introStart.toString()) ?? 0;
      int? e;
      if (introEnd != null) {
        final parsedEnd = int.tryParse(introEnd.toString()) ?? 0;
        if (parsedEnd > s) {
          e = parsedEnd;
        } else if (parsedEnd > 0) {
          e = s + parsedEnd;
        }
      } else if (introDuration != null) {
        final parsedDur = int.tryParse(introDuration.toString());
        if (parsedDur != null && parsedDur > 0) {
          e = s + parsedDur;
        }
      }
      if (e != null && e > s) {
        skips.add(
          SkipInterval(
            type: SkipType.intro,
            startSeconds: s,
            endSeconds: e,
            label: 'Skip Intro',
          ),
        );
      }
    }
    final outroStart =
        json['outroStart'] ?? json['ed_start'] ?? json['tailTime'];
    final outroEnd = json['outroEnd'] ?? json['ed_end'];
    if (outroStart != null) {
      final s = int.tryParse(outroStart.toString()) ?? 0;
      final e = outroEnd != null
          ? (int.tryParse(outroEnd.toString()) ?? (s + 90))
          : (s + 90);
      if (e > s) {
        skips.add(
          SkipInterval(
            type: SkipType.outro,
            startSeconds: s,
            endSeconds: e,
            label: 'Next Episode',
          ),
        );
      }
    }

    return Episode(
      season: json['season'] ?? json['se'] ?? 1,
      episode: json['episode'] ?? json['ep'] ?? json['number'] ?? 1,
      title:
          json['title'] ??
          'Episode ${json['episode'] ?? json['ep'] ?? json['number'] ?? 1}',
      thumbnail: json['thumbnail'],
      overview: json['overview'],
      skipIntervals: skips,
    );
  }

  Map<String, dynamic> toJson() => {
    'season': season,
    'episode': episode,
    'title': title,
    'thumbnail': thumbnail,
    'overview': overview,
    'skipIntervals': skipIntervals.map((s) => s.toJson()).toList(),
  };
}

class Season {
  final int seasonNumber;
  final int episodeCount;
  final List<Episode> episodes;

  const Season({
    required this.seasonNumber,
    required this.episodeCount,
    required this.episodes,
  });

  Season copyWith({
    int? seasonNumber,
    int? episodeCount,
    List<Episode>? episodes,
  }) {
    return Season(
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeCount: episodeCount ?? this.episodeCount,
      episodes: episodes ?? this.episodes,
    );
  }

  factory Season.fromMovieBoxJson(Map<dynamic, dynamic> json) {
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

  Map<String, dynamic> toJson() => {
    'seasonNumber': seasonNumber,
    'episodeCount': episodeCount,
    'episodes': episodes.map((e) => e.toJson()).toList(),
  };
}

class AudioTrackOption {
  final String subjectId;
  final String language;
  final String label;

  const AudioTrackOption({
    required this.subjectId,
    required this.language,
    required this.label,
  });

  factory AudioTrackOption.fromJson(Map<String, dynamic> json) =>
      AudioTrackOption(
        subjectId: json['subjectId']?.toString() ?? '',
        language: json['language']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
    'subjectId': subjectId,
    'language': language,
    'label': label,
  };
}

class MediaDetails {
  final String id;
  final String title;
  final MediaType mediaType;
  final String? year;
  final String? description;
  final String? tagline;
  final String? imdbRating;
  final String? director;
  final String? stars;
  final String? posterUrl;
  final String? backdropUrl;
  final String? duration;
  final List<String> genres;
  final List<Season> seasons;
  final List<AudioTrackOption> dubs;
  final ProviderType provider;
  final String? languageTag;

  const MediaDetails({
    required this.id,
    required this.title,
    required this.mediaType,
    this.year,
    this.description,
    this.tagline,
    this.imdbRating,
    this.director,
    this.stars,
    this.posterUrl,
    this.backdropUrl,
    this.duration,
    this.genres = const [],
    this.seasons = const [],
    this.dubs = const [],
    this.provider = ProviderType.movieBox,
    this.languageTag,
  });

  MediaDetails copyWith({
    String? id,
    String? title,
    MediaType? mediaType,
    String? year,
    String? description,
    String? tagline,
    String? imdbRating,
    String? director,
    String? stars,
    String? posterUrl,
    String? backdropUrl,
    String? duration,
    List<String>? genres,
    List<Season>? seasons,
    List<AudioTrackOption>? dubs,
    ProviderType? provider,
    String? languageTag,
  }) {
    return MediaDetails(
      id: id ?? this.id,
      title: title ?? this.title,
      mediaType: mediaType ?? this.mediaType,
      year: year ?? this.year,
      description: description ?? this.description,
      tagline: tagline ?? this.tagline,
      imdbRating: imdbRating ?? this.imdbRating,
      director: director ?? this.director,
      stars: stars ?? this.stars,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      duration: duration ?? this.duration,
      genres: genres ?? this.genres,
      seasons: seasons ?? this.seasons,
      dubs: dubs ?? this.dubs,
      provider: provider ?? this.provider,
      languageTag: languageTag ?? this.languageTag,
    );
  }

  bool get isSeries => mediaType == MediaType.series || seasons.isNotEmpty;

  String get cleanTitle => MediaItem.parseTitleTags(title).cleanTitle;

  String? get effectiveLanguageTag =>
      languageTag ?? MediaItem.parseTitleTags(title).languageTag;

  bool get isCam => MediaItem.parseTitleTags(title).isCam;

  String? get qualityTag => MediaItem.parseTitleTags(title).qualityTag;

  MediaItem toMediaItem() => MediaItem(
    id: id,
    title: title,
    mediaType: mediaType,
    year: year,
    posterUrl: posterUrl,
    backdropUrl: backdropUrl,
    rating: imdbRating != null ? double.tryParse(imdbRating!) : null,
    genre: genres.isNotEmpty ? genres.first : null,
    seasonCount: seasons.length,
    provider: provider,
    languageTag: languageTag,
  );

  factory MediaDetails.fromMovieBoxJson(Map<dynamic, dynamic> json) {
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
        seasonsList.add(Season.fromMovieBoxJson(s));
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
      mediaType: mediaType,
      year: year,
      description: desc?.toString(),
      tagline: tagline?.toString(),
      imdbRating: imdb,
      director: director?.toString(),
      stars: stars?.toString(),
      posterUrl: poster?.toString(),
      backdropUrl: backdrop?.toString(),
      duration: duration,
      genres: genres,
      seasons: seasonsList,
      dubs: dubsList,
      provider: ProviderType.movieBox,
      languageTag: languageTag,
    );
  }
}
