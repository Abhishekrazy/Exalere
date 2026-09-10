enum MediaType {
  movie,
  series,
}

enum ProviderType {
  movieBox,
  fourKHdHub,
  liveTv,
  addons,
}

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
  });

  bool get isSeries => mediaType == MediaType.series;

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
    );
  }

  factory MediaItem.fromMovieBoxJson(Map<dynamic, dynamic> json) {
    final rawId = json['subjectId'] ?? json['id'] ?? '';
    final title = json['title'] ?? json['name'] ?? 'Untitled';
    final stype = json['subjectType'] ?? json['stype'] ?? 1;
    final mediaType = (stype == 2) ? MediaType.series : MediaType.movie;

    String? year;
    final releaseDate = json['releaseDate'] ?? json['year'] ?? json['releaseInfo'];
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
    } else if (json['horizontalCoverList'] is List && (json['horizontalCoverList'] as List).isNotEmpty) {
      final first = (json['horizontalCoverList'] as List).first;
      if (first is Map) {
        backdrop = first['url'];
      } else if (first is String) {
        backdrop = first;
      }
    }
    backdrop ??= json['horizontalCoverUrl'] ??
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

    String? genre;
    if (json['genre'] is String) {
      genre = json['genre'];
    } else if (json['genre'] is List && (json['genre'] as List).isNotEmpty) {
      genre = (json['genre'] as List).first.toString();
    }

    int? seasonCount;
    if (json['season'] != null) {
      seasonCount = int.tryParse(json['season'].toString());
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
  };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    mediaType: json['mediaType'] == 'series' ? MediaType.series : MediaType.movie,
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
  );
}
