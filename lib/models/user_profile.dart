import 'package:flutter/material.dart';

/// Pre-defined avatar options available for viewer profiles.
class ProfileAvatarOption {
  final String id;
  final String label;
  final IconData icon;

  const ProfileAvatarOption({
    required this.id,
    required this.label,
    required this.icon,
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

  static const List<ProfileAvatarOption> availableAvatars = [
    ProfileAvatarOption(id: 'face', label: 'Smile', icon: Icons.face_rounded),
    ProfileAvatarOption(
      id: 'person',
      label: 'Person',
      icon: Icons.person_rounded,
    ),
    ProfileAvatarOption(
      id: 'movie',
      label: 'Cinema',
      icon: Icons.local_movies_rounded,
    ),
    ProfileAvatarOption(id: 'tv', label: 'Television', icon: Icons.tv_rounded),
    ProfileAvatarOption(
      id: 'game',
      label: 'Gamer',
      icon: Icons.sports_esports_rounded,
    ),
    ProfileAvatarOption(
      id: 'rocket',
      label: 'Explorer',
      icon: Icons.rocket_launch_rounded,
    ),
    ProfileAvatarOption(id: 'star', label: 'VIP', icon: Icons.star_rounded),
    ProfileAvatarOption(
      id: 'kids',
      label: 'Kids',
      icon: Icons.child_care_rounded,
    ),
  ];

  static IconData getIconForAvatar(String avatarId) {
    for (final opt in availableAvatars) {
      if (opt.id == avatarId) return opt.icon;
    }
    return Icons.face_rounded;
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
