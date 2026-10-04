import 'media_item.dart';

/// Full biographical and filmography details for an actor or director.
class PersonDetails {
  final int id;
  final String name;
  final String? biography;
  final String? birthday;
  final String? deathday;
  final String? placeOfBirth;
  final String? profilePath;
  final String? knownForDepartment;
  final List<MediaItem> movieCredits;
  final List<MediaItem> tvCredits;

  const PersonDetails({
    required this.id,
    required this.name,
    this.biography,
    this.birthday,
    this.deathday,
    this.placeOfBirth,
    this.profilePath,
    this.knownForDepartment,
    this.movieCredits = const [],
    this.tvCredits = const [],
  });

  String? get profileUrl => profilePath != null && profilePath!.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w500$profilePath'
      : null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (biography != null) 'biography': biography,
    if (birthday != null) 'birthday': birthday,
    if (deathday != null) 'deathday': deathday,
    if (placeOfBirth != null) 'placeOfBirth': placeOfBirth,
    if (profilePath != null) 'profilePath': profilePath,
    if (knownForDepartment != null) 'knownForDepartment': knownForDepartment,
    'movieCredits': movieCredits.map((m) => m.toJson()).toList(),
    'tvCredits': tvCredits.map((t) => t.toJson()).toList(),
  };

  factory PersonDetails.fromJson(Map<String, dynamic> json) {
    final List<MediaItem> movies = [];
    final List<MediaItem> tv = [];

    final credits = json['combined_credits'] is Map
        ? json['combined_credits'] as Map
        : json['credits'] is Map
        ? json['credits'] as Map
        : null;

    if (credits != null && credits['cast'] is List) {
      for (final item in credits['cast']) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final mediaType = map['media_type']?.toString().toLowerCase();
          final isMovie = mediaType != 'tv';
          final id = map['id']?.toString() ?? '';
          final title =
              map['title']?.toString() ?? map['name']?.toString() ?? '';
          final poster =
              map['poster_path']?.toString() ?? map['posterPath']?.toString();
          final backdrop =
              map['backdrop_path']?.toString() ??
              map['backdropPath']?.toString();
          final releaseDate =
              map['release_date']?.toString() ??
              map['first_air_date']?.toString();
          final year = releaseDate != null && releaseDate.length >= 4
              ? releaseDate.substring(0, 4)
              : null;
          final rating = (map['vote_average'] is num)
              ? (map['vote_average'] as num).toDouble()
              : null;

          // Filter out unreleased titles for cleaner filmography
          if (title.isEmpty || (poster == null && backdrop == null)) continue;

          final media = MediaItem(
            id: id,
            title: title,
            mediaType: isMovie ? MediaType.movie : MediaType.series,
            year: year,
            posterUrl: poster != null && poster.isNotEmpty
                ? 'https://image.tmdb.org/t/p/w500$poster'
                : null,
            backdropUrl: backdrop != null && backdrop.isNotEmpty
                ? 'https://image.tmdb.org/t/p/w780$backdrop'
                : null,
            rating: rating,
            provider: ProviderType.plugins,
          );

          if (isMovie) {
            movies.add(media);
          } else {
            tv.add(media);
          }
        }
      }

      // Sort by year descending (latest first)
      movies.sort((a, b) => (b.year ?? '0000').compareTo(a.year ?? '0000'));
      tv.sort((a, b) => (b.year ?? '0000').compareTo(a.year ?? '0000'));
    }

    return PersonDetails(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Unknown Actor',
      biography: json['biography']?.toString(),
      birthday: json['birthday']?.toString(),
      deathday: json['deathday']?.toString(),
      placeOfBirth:
          json['place_of_birth']?.toString() ??
          json['placeOfBirth']?.toString(),
      profilePath:
          json['profile_path']?.toString() ?? json['profilePath']?.toString(),
      knownForDepartment:
          json['known_for_department']?.toString() ??
          json['knownForDepartment']?.toString(),
      movieCredits: movies,
      tvCredits: tv,
    );
  }
}
