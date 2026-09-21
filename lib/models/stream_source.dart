class SubtitleOption {
  final String language;
  final String name;
  final String url;

  const SubtitleOption({
    required this.language,
    required this.name,
    required this.url,
  });

  factory SubtitleOption.fromJson(Map<String, dynamic> json) => SubtitleOption(
    language: json['lan'] ?? json['language'] ?? 'en',
    name: json['lanName'] ?? json['name'] ?? 'English',
    url: json['url'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'language': language,
    'name': name,
    'url': url,
  };
}

class StreamSource {
  final String quality; // e.g. "1080p", "720p", "480p", "Multi-Res"
  final String resolution;
  final String format; // "DASH", "HLS", "MP4"
  final String url;
  final Map<String, String> headers;
  final String? codec;
  final int? sizeBytes;
  final List<SubtitleOption> subtitles;
  final String? resourceId;
  final String? server;
  final List<String> availableQualities;

  const StreamSource({
    required this.quality,
    required this.resolution,
    required this.format,
    required this.url,
    this.headers = const {},
    this.codec,
    this.sizeBytes,
    this.subtitles = const [],
    this.resourceId,
    this.server,
    this.availableQualities = const [],
  });

  StreamSource copyWith({
    String? quality,
    String? resolution,
    String? format,
    String? url,
    Map<String, String>? headers,
    String? codec,
    int? sizeBytes,
    List<SubtitleOption>? subtitles,
    String? resourceId,
    String? server,
    List<String>? availableQualities,
  }) {
    return StreamSource(
      quality: quality ?? this.quality,
      resolution: resolution ?? this.resolution,
      format: format ?? this.format,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      codec: codec ?? this.codec,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      subtitles: subtitles ?? this.subtitles,
      resourceId: resourceId ?? this.resourceId,
      server: server ?? this.server,
      availableQualities: availableQualities ?? this.availableQualities,
    );
  }

  factory StreamSource.fromJson(Map<String, dynamic> json) => StreamSource(
    quality: json['quality'] ?? '',
    resolution: json['resolution'] ?? '',
    format: json['format'] ?? '',
    url: json['url'] ?? '',
    headers:
        (json['headers'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v.toString()),
        ) ??
        const {},
    codec: json['codec'] as String?,
    sizeBytes: json['sizeBytes'] as int?,
    subtitles:
        (json['subtitles'] as List<dynamic>?)
            ?.map((s) => SubtitleOption.fromJson(s as Map<String, dynamic>))
            .toList() ??
        const [],
    resourceId: json['resourceId'] as String?,
    server: json['server'] as String?,
    availableQualities:
        (json['availableQualities'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
  );

  Map<String, dynamic> toJson() => {
    'quality': quality,
    'resolution': resolution,
    'format': format,
    'url': url,
    if (headers.isNotEmpty) 'headers': headers,
    if (codec != null) 'codec': codec,
    if (sizeBytes != null) 'sizeBytes': sizeBytes,
    if (subtitles.isNotEmpty)
      'subtitles': subtitles.map((s) => s.toJson()).toList(),
    if (resourceId != null) 'resourceId': resourceId,
    if (server != null) 'server': server,
    if (availableQualities.isNotEmpty) 'availableQualities': availableQualities,
  };

  bool get isDash => format.toUpperCase() == 'DASH' || url.endsWith('.mpd');
  bool get isHls => format.toUpperCase() == 'HLS' || url.endsWith('.m3u8');

  String get formattedSize {
    if (sizeBytes == null || sizeBytes! <= 0) return '';
    final gb = sizeBytes! / (1024 * 1024 * 1024);
    if (gb >= 1.0) {
      return '${gb.toStringAsFixed(1)} GB';
    }
    final mb = sizeBytes! / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB';
  }
}
