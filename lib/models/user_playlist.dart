import 'media_item.dart';

/// Represents a custom user-created playlist or watchlist scoped to a user profile.
class UserPlaylist {
  final String id;
  final String name;
  final String profileId;
  final int createdAt;
  final int updatedAt;
  final List<MediaItem> items;

  const UserPlaylist({
    required this.id,
    required this.name,
    required this.profileId,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  int get itemCount => items.length;

  String? get coverPosterUrl => items.isNotEmpty ? items.first.posterUrl : null;

  String? get coverBackdropUrl =>
      items.isNotEmpty ? items.first.backdropUrl : null;

  UserPlaylist copyWith({
    String? id,
    String? name,
    String? profileId,
    int? createdAt,
    int? updatedAt,
    List<MediaItem>? items,
  }) {
    return UserPlaylist(
      id: id ?? this.id,
      name: name ?? this.name,
      profileId: profileId ?? this.profileId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'profileId': profileId,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory UserPlaylist.fromJson(Map<String, dynamic> json) {
    final List<MediaItem> list = [];
    if (json['items'] is List) {
      for (final item in json['items']) {
        if (item is Map) {
          list.add(MediaItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return UserPlaylist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'My Playlist',
      profileId: json['profileId']?.toString() ?? 'default',
      createdAt: json['createdAt'] is int
          ? json['createdAt'] as int
          : DateTime.now().millisecondsSinceEpoch,
      updatedAt: json['updatedAt'] is int
          ? json['updatedAt'] as int
          : DateTime.now().millisecondsSinceEpoch,
      items: list,
    );
  }
}
