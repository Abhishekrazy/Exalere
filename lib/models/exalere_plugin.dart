import 'stream_source.dart';

/// Representation of an Exalere Plugin manifest conforming to the Exalere Plugin Protocol.
class ExalerePluginManifest {
  final String id;
  final String name;
  final String version;
  final String description;
  final List<String> resources;
  final List<String> types;
  final List<String> idPrefixes;
  final String? icon;
  final String? background;

  const ExalerePluginManifest({
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

  factory ExalerePluginManifest.fromJson(Map<String, dynamic> json) {
    // Resources can be a list of strings or list of objects e.g. [{"name": "stream", ...}]
    final rawResources = json['resources'] as List<dynamic>? ?? const [];
    final parsedResources = rawResources
        .map<String>((r) {
          if (r is String) return r;
          if (r is Map && r['name'] != null) {
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

    return ExalerePluginManifest(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Plugin',
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

/// A playable media stream resolved from an Exalere Plugin or Stremio Addon.
class ExalerePluginStream {
  final String? name;
  final String? title;
  final String? description;
  final String url;
  final String? ytId;
  final String? externalUrl;
  final String? infoHash;
  final int? fileIdx;
  final Map<String, String> requestHeaders;
  final List<SubtitleOption> subtitles;
  final Map<String, dynamic>? behaviorHints;

  const ExalerePluginStream({
    this.name,
    this.title,
    this.description,
    required this.url,
    this.ytId,
    this.externalUrl,
    this.infoHash,
    this.fileIdx,
    this.requestHeaders = const {},
    this.subtitles = const [],
    this.behaviorHints,
  });

  factory ExalerePluginStream.fromJson(Map<String, dynamic> json) {
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

    final rawUrl = json['url']?.toString() ?? '';
    final ytId = json['ytId']?.toString();
    final externalUrl = json['externalUrl']?.toString();
    final infoHash = json['infoHash']?.toString();
    final fileIdx = json['fileIdx'] is int ? json['fileIdx'] as int : null;

    String resolvedUrl = rawUrl;
    if (resolvedUrl.isEmpty) {
      if (externalUrl != null && externalUrl.isNotEmpty) {
        resolvedUrl = externalUrl;
      } else if (ytId != null && ytId.isNotEmpty) {
        resolvedUrl = 'https://www.youtube.com/watch?v=$ytId';
      }
    }

    return ExalerePluginStream(
      name: json['name']?.toString(),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      url: resolvedUrl,
      ytId: ytId,
      externalUrl: externalUrl,
      infoHash: infoHash,
      fileIdx: fileIdx,
      requestHeaders: headers,
      subtitles: parsedSubs,
      behaviorHints: json['behaviorHints'] as Map<String, dynamic>?,
    );
  }

  /// Convert ExalerePluginStream to Exalere's native [StreamSource] model.
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
    } else if (ytId != null && ytId!.isNotEmpty) {
      format = 'YouTube';
    }

    // Prefer clean name / provider title
    final displayName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : (fallbackName ?? 'Stream');

    final qualityLabel = (title != null && title!.trim().isNotEmpty)
        ? '$displayName - ${title!.trim()}'
        : '$displayName $quality'.trim();

    return StreamSource(
      quality: qualityLabel,
      resolution: resolution,
      format: format,
      url: url,
      headers: requestHeaders,
      subtitles: subtitles,
      server: displayName,
    );
  }
}

/// Persisted configuration for an installed Exalere Plugin.
class ExalerePluginConfig {
  final String id;
  final String name;
  final String baseUrl;
  final bool isEnabled;
  final DateTime addedAt;
  final ExalerePluginManifest? manifest;

  const ExalerePluginConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.isEnabled = true,
    required this.addedAt,
    this.manifest,
  });

  ExalerePluginConfig copyWith({
    String? id,
    String? name,
    String? baseUrl,
    bool? isEnabled,
    DateTime? addedAt,
    ExalerePluginManifest? manifest,
  }) => ExalerePluginConfig(
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

  factory ExalerePluginConfig.fromJson(Map<String, dynamic> json) =>
      ExalerePluginConfig(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Plugin',
        baseUrl: json['baseUrl']?.toString() ?? '',
        isEnabled: json['isEnabled'] as bool? ?? true,
        addedAt: json['addedAt'] != null
            ? DateTime.tryParse(json['addedAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        manifest: json['manifest'] != null
            ? ExalerePluginManifest.fromJson(
                json['manifest'] as Map<String, dynamic>,
              )
            : null,
      );
}

/// A community-maintained or recommended plugin available for 1-click installation.
class CommunityPluginItem {
  final String id;
  final String name;
  final String description;
  final String manifestUrl;
  final String? icon;
  final String author;
  final bool isFeatured;
  final List<String> tags;

  const CommunityPluginItem({
    required this.id,
    required this.name,
    required this.description,
    required this.manifestUrl,
    this.icon,
    this.author = 'Community',
    this.isFeatured = false,
    this.tags = const [],
  });

  factory CommunityPluginItem.fromJson(Map<String, dynamic> json) =>
      CommunityPluginItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        manifestUrl: json['manifestUrl']?.toString() ?? '',
        icon: json['icon']?.toString(),
        author: json['author']?.toString() ?? 'Community',
        isFeatured: json['isFeatured'] == true,
        tags:
            (json['tags'] as List<dynamic>?)
                ?.map((t) => t.toString())
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'manifestUrl': manifestUrl,
    if (icon != null) 'icon': icon,
    'author': author,
    'isFeatured': isFeatured,
    'tags': tags,
  };
}
