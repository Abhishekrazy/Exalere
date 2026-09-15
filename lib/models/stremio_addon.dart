import 'stream_source.dart';

/// Representation of a Stremio Addon manifest conforming to the Stremio Addon Protocol v1.
class StremioManifest {
  final String id;
  final String name;
  final String version;
  final String description;
  final List<String> resources;
  final List<String> types;
  final List<String> idPrefixes;
  final String? icon;
  final String? background;

  const StremioManifest({
    required this.id,
    required this.name,
    required this.version,
    this.description = '',
    this.resources = const ['stream'],
    this.types = const ['movie', 'series'],
    this.idPrefixes = const [],
    this.icon,
    this.background,
  });

  bool get supportsStreams => resources.contains('stream');
  bool get supportsMovies => types.contains('movie');
  bool get supportsSeries => types.contains('series');

  factory StremioManifest.fromJson(Map<String, dynamic> json) {
    // Resources can be a list of strings or list of objects e.g. [{"name": "stream", ...}]
    final rawResources = json['resources'] as List<dynamic>? ?? const [];
    final parsedResources = rawResources
        .map<String>((r) {
          if (r is String) return r;
          if (r is Map<String, dynamic> && r['name'] != null) {
            return r['name'].toString();
          }
          return '';
        })
        .where((r) => r.isNotEmpty)
        .toList();

    final rawTypes = json['types'] as List<dynamic>? ?? const [];
    final parsedTypes = rawTypes.map((t) => t.toString()).toList();

    final rawPrefixes = json['idPrefixes'] as List<dynamic>? ?? const [];
    final parsedPrefixes = rawPrefixes.map((p) => p.toString()).toList();

    return StremioManifest(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Addon',
      version: json['version']?.toString() ?? '1.0.0',
      description: json['description']?.toString() ?? '',
      resources: parsedResources.isNotEmpty
          ? parsedResources
          : const ['stream'],
      types: parsedTypes.isNotEmpty ? parsedTypes : const ['movie', 'series'],
      idPrefixes: parsedPrefixes,
      icon: json['icon']?.toString() ?? json['logo']?.toString(),
      background: json['background']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'description': description,
    'resources': resources,
    'types': types,
    'idPrefixes': idPrefixes,
    if (icon != null) 'icon': icon,
    if (background != null) 'background': background,
  };
}

/// A playable media stream resolved from a Stremio Addon.
class StremioStream {
  final String? name;
  final String? title;
  final String? description;
  final String url;
  final Map<String, String> requestHeaders;
  final List<SubtitleOption> subtitles;
  final Map<String, dynamic>? behaviorHints;

  const StremioStream({
    this.name,
    this.title,
    this.description,
    required this.url,
    this.requestHeaders = const {},
    this.subtitles = const [],
    this.behaviorHints,
  });

  factory StremioStream.fromJson(Map<String, dynamic> json) {
    final rawHeaders =
        json['behaviorHints']?['proxyHeaders']?['request']
            as Map<String, dynamic>?;
    final headers = <String, String>{};
    if (rawHeaders != null) {
      rawHeaders.forEach((k, v) => headers[k] = v.toString());
    }

    final rawSubs = json['subtitles'] as List<dynamic>? ?? const [];
    final parsedSubs = rawSubs
        .map<SubtitleOption>((s) {
          if (s is Map<String, dynamic>) {
            final lang = s['lang']?.toString() ?? 'en';
            final subUrl = s['url']?.toString() ?? '';
            return SubtitleOption(
              language: lang,
              name: s['name']?.toString() ?? lang.toUpperCase(),
              url: subUrl,
            );
          }
          return const SubtitleOption(language: 'en', name: 'English', url: '');
        })
        .where((s) => s.url.isNotEmpty)
        .toList();

    return StremioStream(
      name: json['name']?.toString(),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      url: json['url']?.toString() ?? '',
      requestHeaders: headers,
      subtitles: parsedSubs,
      behaviorHints: json['behaviorHints'] as Map<String, dynamic>?,
    );
  }

  /// Convert StremioStream to Exalere's native [StreamSource] model.
  StreamSource toStreamSource({String? fallbackName}) {
    final combined = '${name ?? ''} ${title ?? ''} ${description ?? ''}'
        .toLowerCase();

    // Determine quality label & resolution
    String quality = '1080p';
    String resolution = '1920x1080';
    if (combined.contains('4k') || combined.contains('2160p')) {
      quality = '4K';
      resolution = '3840x2160';
    } else if (combined.contains('1080p')) {
      quality = '1080p';
      resolution = '1920x1080';
    } else if (combined.contains('720p')) {
      quality = '720p';
      resolution = '1280x720';
    } else if (combined.contains('480p')) {
      quality = '480p';
      resolution = '854x480';
    }

    // Determine stream format
    String format = 'MP4';
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('.m3u8')) {
      format = 'HLS';
    } else if (lowerUrl.contains('.mpd')) {
      format = 'DASH';
    }

    // Prefer clean name / provider title
    final displayName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : (fallbackName ?? 'Stream');

    return StreamSource(
      quality: '$displayName $quality'.trim(),
      resolution: resolution,
      format: format,
      url: url,
      headers: requestHeaders,
      subtitles: subtitles,
    );
  }
}

/// Persisted configuration for an installed Stremio-compatible Addon.
class StremioAddonConfig {
  final String id;
  final String name;
  final String baseUrl;
  final bool isEnabled;
  final DateTime addedAt;
  final StremioManifest? manifest;

  const StremioAddonConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.isEnabled = true,
    required this.addedAt,
    this.manifest,
  });

  StremioAddonConfig copyWith({
    String? id,
    String? name,
    String? baseUrl,
    bool? isEnabled,
    DateTime? addedAt,
    StremioManifest? manifest,
  }) => StremioAddonConfig(
    id: id ?? this.id,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    isEnabled: isEnabled ?? this.isEnabled,
    addedAt: addedAt ?? this.addedAt,
    manifest: manifest ?? this.manifest,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    'isEnabled': isEnabled,
    'addedAt': addedAt.toIso8601String(),
    if (manifest != null) 'manifest': manifest!.toJson(),
  };

  factory StremioAddonConfig.fromJson(Map<String, dynamic> json) =>
      StremioAddonConfig(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Addon',
        baseUrl: json['baseUrl']?.toString() ?? '',
        isEnabled: json['isEnabled'] as bool? ?? true,
        addedAt: json['addedAt'] != null
            ? DateTime.tryParse(json['addedAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        manifest: json['manifest'] != null
            ? StremioManifest.fromJson(json['manifest'] as Map<String, dynamic>)
            : null,
      );
}
