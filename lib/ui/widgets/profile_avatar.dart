import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../theme/app_tokens.dart';

/// Circular profile picture backed by the bundled avatar artwork.
///
/// The artwork is generated per avatar option; a profile that still points at an
/// unknown or missing id falls back to the matching Material icon, so an old
/// profile or a stripped build never renders a blank circle.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.avatarId,
    this.size = 38,
    this.fallbackColor,
  });

  final String avatarId;
  final double size;

  /// Colour for the icon fallback; defaults to the primary accent.
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = fallbackColor ?? tokens.primaryAccent;

    Widget iconFallback() => Icon(
      UserProfile.getIconForAvatar(avatarId),
      size: size * 0.55,
      color: color,
    );

    final asset = UserProfile.getAssetForAvatar(avatarId);

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: asset == null
            ? iconFallback()
            : Image.asset(
                asset,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => iconFallback(),
              ),
      ),
    );
  }
}
