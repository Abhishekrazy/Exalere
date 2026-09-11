import 'stream_source.dart';

class LiveChannel {
  final String id;
  final String name;
  final String? logoUrl;
  final String category;
  final String streamUrl;
  final String? country;
  final String? resolution;
  final List<StreamSource> sources;
  final String? language;

  const LiveChannel({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.category,
    required this.streamUrl,
    this.country,
    this.resolution,
    this.sources = const [],
    this.language,
  });

  List<StreamSource> get effectiveSources => sources.isNotEmpty
      ? sources
      : [
          StreamSource(
            quality: resolution ?? 'HD',
            resolution: resolution ?? '1080p',
            format: 'HLS Live',
            url: streamUrl,
          ),
        ];

  LiveChannel copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? category,
    String? streamUrl,
    String? country,
    String? resolution,
    List<StreamSource>? sources,
    String? language,
  }) {
    return LiveChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      category: category ?? this.category,
      streamUrl: streamUrl ?? this.streamUrl,
      country: country ?? this.country,
      resolution: resolution ?? this.resolution,
      sources: sources ?? this.sources,
      language: language ?? this.language,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'logoUrl': logoUrl,
    'category': category,
    'streamUrl': streamUrl,
    'country': country,
    'resolution': resolution,
    'language': language,
    'sources': sources.map((s) => s.toJson()).toList(),
  };

  factory LiveChannel.fromJson(Map<String, dynamic> json) => LiveChannel(
    id: json['id'] ?? '',
    name: json['name'] ?? 'Channel',
    logoUrl: json['logoUrl'],
    category: json['category'] ?? 'General',
    streamUrl: json['streamUrl'] ?? '',
    country: json['country'],
    resolution: json['resolution'],
    language: json['language'],
    sources: json['sources'] != null
        ? (json['sources'] as List)
              .map((s) => StreamSource.fromJson(s as Map<String, dynamic>))
              .toList()
        : const [],
  );
}
