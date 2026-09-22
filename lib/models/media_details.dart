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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioTrackOption &&
          runtimeType == other.runtimeType &&
          subjectId == other.subjectId &&
          language == other.language;

  @override
  int get hashCode => Object.hash(subjectId, language);
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
    this.provider = ProviderType.plugins,
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
}
