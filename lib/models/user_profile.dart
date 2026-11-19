import 'package:flutter/material.dart';

/// Pre-defined avatar options available for viewer profiles.
class ProfileAvatarOption {
  final String id;
  final String label;
  final IconData icon;

  /// Bundled artwork for this avatar. Ignored (with the [icon] shown instead)
  /// when the asset is missing, so an old profile never renders blank.
  final String asset;

  const ProfileAvatarOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.asset,
  });
}

/// Represents an individual viewer profile (e.g. Adult, Kids, Family members).
class UserProfile {
  final String id;
  final String name;
  final String avatarIcon;
  final int avatarColorIndex;
  final bool isKids;
  final String? pin;
  final int createdAt;
  final int lastActiveAt;

  const UserProfile({
    required this.id,
    required this.name,
    this.avatarIcon = 'face',
    this.avatarColorIndex = 0,
    this.isKids = false,
    this.pin,
    required this.createdAt,
    required this.lastActiveAt,
  });

  bool get isPinProtected => pin != null && pin!.length == 4;

  /// Compact label for places where the full name does not fit (the rail's
  /// profile tab, the settings row). "Abhishek Razy" -> "AR"; a single-word
  /// name keeps its first two letters.
  String get initials {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final word = words.first;
      return word.substring(0, word.length < 2 ? word.length : 2).toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  static const String avatarAssetDirectory = 'assets/images/profiles';

  static const List<ProfileAvatarOption> availableAvatars = [
    ProfileAvatarOption(
      id: 'face',
      label: 'Smile',
      icon: Icons.face_rounded,
      asset: '$avatarAssetDirectory/profile_face.png',
    ),
    ProfileAvatarOption(
      id: 'boy',
      label: 'Boy',
      icon: Icons.boy_rounded,
      asset: '$avatarAssetDirectory/profile_boy.png',
    ),
    ProfileAvatarOption(
      id: 'girl',
      label: 'Girl',
      icon: Icons.girl_rounded,
      asset: '$avatarAssetDirectory/profile_girl.png',
    ),
    ProfileAvatarOption(
      id: 'mother',
      label: 'Mother',
      icon: Icons.woman_rounded,
      asset: '$avatarAssetDirectory/profile_mother.png',
    ),
    ProfileAvatarOption(
      id: 'father',
      label: 'Father',
      icon: Icons.man_rounded,
      asset: '$avatarAssetDirectory/profile_father.png',
    ),
    ProfileAvatarOption(
      id: 'grandma',
      label: 'Grandma',
      icon: Icons.elderly_rounded,
      asset: '$avatarAssetDirectory/profile_grandma.png',
    ),
    ProfileAvatarOption(
      id: 'grandpa',
      label: 'Grandpa',
      icon: Icons.elderly_rounded,
      asset: '$avatarAssetDirectory/profile_grandpa.png',
    ),
    ProfileAvatarOption(
      id: 'dog',
      label: 'Dog',
      icon: Icons.pets_rounded,
      asset: '$avatarAssetDirectory/profile_dog.png',
    ),
    ProfileAvatarOption(
      id: 'cat',
      label: 'Cat',
      icon: Icons.pets_rounded,
      asset: '$avatarAssetDirectory/profile_cat.png',
    ),
    ProfileAvatarOption(
      id: 'person',
      label: 'Person',
      icon: Icons.person_rounded,
      asset: '$avatarAssetDirectory/profile_person.png',
    ),
    ProfileAvatarOption(
      id: 'movie',
      label: 'Cinema',
      icon: Icons.local_movies_rounded,
      asset: '$avatarAssetDirectory/profile_movie.png',
    ),
    ProfileAvatarOption(
      id: 'tv',
      label: 'Television',
      icon: Icons.tv_rounded,
      asset: '$avatarAssetDirectory/profile_tv.png',
    ),
    ProfileAvatarOption(
      id: 'game',
      label: 'Gamer',
      icon: Icons.sports_esports_rounded,
      asset: '$avatarAssetDirectory/profile_game.png',
    ),
    ProfileAvatarOption(
      id: 'rocket',
      label: 'Explorer',
      icon: Icons.rocket_launch_rounded,
      asset: '$avatarAssetDirectory/profile_rocket.png',
    ),
    ProfileAvatarOption(
      id: 'star',
      label: 'VIP',
      icon: Icons.star_rounded,
      asset: '$avatarAssetDirectory/profile_star.png',
    ),
    ProfileAvatarOption(
      id: 'kids',
      label: 'Kids',
      icon: Icons.child_care_rounded,
      asset: '$avatarAssetDirectory/profile_kids.png',
    ),
  ];

  static IconData getIconForAvatar(String avatarId) {
    for (final opt in availableAvatars) {
      if (opt.id == avatarId) return opt.icon;
    }
    return Icons.face_rounded;
  }

  /// Bundled avatar artwork for [avatarId], or `null` when the id is unknown.
  static String? getAssetForAvatar(String avatarId) {
    for (final opt in availableAvatars) {
      if (opt.id == avatarId) return opt.asset;
    }
    return null;
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? avatarIcon,
    int? avatarColorIndex,
    bool? isKids,
    String? pin,
    bool clearPin = false,
    int? createdAt,
    int? lastActiveAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      avatarColorIndex: avatarColorIndex ?? this.avatarColorIndex,
      isKids: isKids ?? this.isKids,
      pin: clearPin ? null : (pin ?? this.pin),
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatarIcon': avatarIcon,
    'avatarColorIndex': avatarColorIndex,
    'isKids': isKids,
    'pin': pin,
    'createdAt': createdAt,
    'lastActiveAt': lastActiveAt,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String? ?? 'default',
    name: json['name'] as String? ?? 'Default',
    avatarIcon: json['avatarIcon'] as String? ?? 'face',
    avatarColorIndex: json['avatarColorIndex'] as int? ?? 0,
    isKids: json['isKids'] as bool? ?? false,
    pin: json['pin'] as String?,
    createdAt: json['createdAt'] as int? ?? 0,
    lastActiveAt: json['lastActiveAt'] as int? ?? 0,
  );

  static UserProfile createDefault() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return UserProfile(
      id: 'default',
      name: 'Default',
      avatarIcon: 'face',
      avatarColorIndex: 0,
      isKids: false,
      createdAt: now,
      lastActiveAt: now,
    );
  }
}
