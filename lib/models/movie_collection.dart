import 'media_item.dart';

/// Represents a movie franchise or collection (e.g. Harry Potter Collection,
/// The Dark Knight Trilogy, Marvel Cinematic Universe).
class MovieCollection {
  final int id;
  final String name;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final List<MediaItem> parts;

  const MovieCollection({
    required this.id,
    required this.name,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.parts = const [],
  });

  String? get posterUrl => posterPath != null && posterPath!.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w500$posterPath'
      : null;

  String? get backdropUrl => backdropPath != null && backdropPath!.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w1280$backdropPath'
      : null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (overview != null) 'overview': overview,
    if (posterPath != null) 'posterPath': posterPath,
    if (backdropPath != null) 'backdropPath': backdropPath,
    'parts': parts.map((p) => p.toJson()).toList(),
  };

  factory MovieCollection.fromJson(Map<String, dynamic> json) {
    final List<MediaItem> items = [];
    if (json['parts'] is List) {
      for (final p in json['parts']) {
        if (p is Map) {
          final map = Map<String, dynamic>.from(p);
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

          items.add(
            MediaItem(
              id: id,
              title: title,
              mediaType: MediaType.movie,
              year: year,
              posterUrl: poster != null && poster.isNotEmpty
                  ? 'https://image.tmdb.org/t/p/w500$poster'
                  : null,
              backdropUrl: backdrop != null && backdrop.isNotEmpty
                  ? 'https://image.tmdb.org/t/p/w780$backdrop'
                  : null,
              rating: rating,
              provider: ProviderType.plugins,
            ),
          );
        }
      }
      // Sort parts chronologically by release year
      items.sort((a, b) => (a.year ?? '9999').compareTo(b.year ?? '9999'));
    }

    return MovieCollection(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Franchise Collection',
      overview: json['overview']?.toString(),
      posterPath:
          json['poster_path']?.toString() ?? json['posterPath']?.toString(),
      backdropPath:
          json['backdrop_path']?.toString() ?? json['backdropPath']?.toString(),
      parts: items,
    );
  }
}
