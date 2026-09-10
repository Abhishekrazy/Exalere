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
  });

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
