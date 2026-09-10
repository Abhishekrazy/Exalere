class LiveChannel {
  final String id;
  final String name;
  final String? logoUrl;
  final String category;
  final String streamUrl;
  final String? country;
  final String? resolution;

  const LiveChannel({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.category,
    required this.streamUrl,
    this.country,
    this.resolution,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'logoUrl': logoUrl,
    'category': category,
    'streamUrl': streamUrl,
    'country': country,
    'resolution': resolution,
  };

  factory LiveChannel.fromJson(Map<String, dynamic> json) => LiveChannel(
    id: json['id'] ?? '',
    name: json['name'] ?? 'Channel',
    logoUrl: json['logoUrl'],
    category: json['category'] ?? 'General',
    streamUrl: json['streamUrl'] ?? '',
    country: json['country'],
    resolution: json['resolution'],
  );
}
