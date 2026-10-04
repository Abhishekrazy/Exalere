import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
import '../../providers/profile_provider.dart';
import '../theme/app_tokens.dart';
import 'tv/tv_popup_scope.dart';
import 'tv_focusable.dart';

/// Interactive modal allowing viewers to switch, create, edit, or delete profiles.
class ProfileSelectionDialog extends StatefulWidget {
  const ProfileSelectionDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const ProfileSelectionDialog(),
    );
  }

  @override
  State<ProfileSelectionDialog> createState() => _ProfileSelectionDialogState();
}

class _ProfileSelectionDialogState extends State<ProfileSelectionDialog> {
  bool _isManageMode = false;

  Color _getProfileColor(int index, AppDesignTokens tokens) {
    switch (index % 4) {
      case 1:
        return tokens.secondaryAccent;
      case 2:
        return tokens.vipColor;
      case 3:
        return tokens.liveColor;
      case 0:
      default:
        return tokens.primaryAccent;
    }
  }

  Future<bool> _promptPin(String expectedPin, String title) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) =>
          _ProfilePinVerificationDialog(expectedPin: expectedPin, title: title),
    );
    return result == true;
  }

  void _showAddOrEditDialog({UserProfile? profileToEdit}) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _AddOrEditProfileModal(profileToEdit: profileToEdit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 540 || size.height < 600;
    final profileProvider = context.watch<ProfileProvider>();
    final profiles = profileProvider.profiles;
    final activeId = profileProvider.activeProfile.id;

    return TvPopupScope(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: (size.width * 0.9).clamp(340.0, 720.0),
              maxHeight: (size.height * 0.85).clamp(380.0, 680.0),
            ),
            margin: const EdgeInsets.all(20),
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 20 : 28,
              vertical: isCompact ? 20 : 26,
            ),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceElevated,
              radius: tokens.cardRadius,
              side: BorderSide(color: tokens.borderSubtle, width: 1.5),
              shadows: tokens.getCardShadows(),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: tokens.getShapeDecoration(
                        color: tokens.primaryAccent.withValues(alpha: 0.15),
                        radius: 999.0,
                      ),
                      child: Icon(
                        _isManageMode
                            ? Icons.manage_accounts_rounded
                            : Icons.account_circle_rounded,
                        color: tokens.primaryAccent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isManageMode
                                ? "Manage Profiles"
                                : "Who's Watching?",
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: isCompact ? 18 : 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _isManageMode
                                ? 'Select a profile to customize details, PIN, or delete.'
                                : 'Switch viewer profile to personalize continue watching & favorites.',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: isCompact ? 12 : 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TvFocusable(
                      borderRadius: tokens.borderRadiusPill,
                      onTap: () =>
                          setState(() => _isManageMode = !_isManageMode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: tokens.getShapeDecoration(
                          color: _isManageMode
                              ? tokens.primaryAccent
                              : tokens.surfaceCard,
                          radius: 999.0,
                          side: BorderSide(
                            color: _isManageMode
                                ? tokens.primaryAccent
                                : tokens.borderSubtle,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isManageMode
                                  ? Icons.check_rounded
                                  : Icons.edit_rounded,
                              size: 14,
                              color: _isManageMode
                                  ? tokens.canvasBackground
                                  : tokens.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isManageMode ? 'Done' : 'Manage',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _isManageMode
                                    ? tokens.canvasBackground
                                    : tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TvFocusable(
                      borderRadius: tokens.borderRadiusPill,
                      onTap: () => Navigator.of(context).pop(),
                      child: IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: tokens.textMuted,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Profiles Grid / List
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        ...profiles.map((profile) {
                          final isActive = profile.id == activeId;
                          final profileColor = _getProfileColor(
                            profile.avatarColorIndex,
                            tokens,
                          );

                          return TvFocusable(
                            autofocus: isActive,
                            borderRadius: BorderRadius.circular(
                              tokens.cardRadius,
                            ),
                            onTap: () async {
                              if (_isManageMode) {
                                if (profile.isPinProtected) {
                                  final verified = await _promptPin(
                                    profile.pin!,
                                    profile.name,
                                  );
                                  if (!verified) return;
                                } else if (profileProvider.isKidsActive) {
                                  final masterPinProfile = profileProvider
                                      .profiles
                                      .firstWhere(
                                        (p) => p.isPinProtected,
                                        orElse: () => profile,
                                      );
                                  if (masterPinProfile.isPinProtected) {
                                    final verified = await _promptPin(
                                      masterPinProfile.pin!,
                                      'Parental Shield (${masterPinProfile.name})',
                                    );
                                    if (!verified) return;
                                  }
                                }
                                _showAddOrEditDialog(profileToEdit: profile);
                                return;
                              }

                              if (!isActive) {
                                if (profile.isPinProtected) {
                                  final verified = await _promptPin(
                                    profile.pin!,
                                    profile.name,
                                  );
                                  if (!verified) return;
                                } else if (profileProvider.isKidsActive) {
                                  final masterPinProfile = profileProvider
                                      .profiles
                                      .firstWhere(
                                        (p) => p.isPinProtected,
                                        orElse: () => profile,
                                      );
                                  if (masterPinProfile.isPinProtected) {
                                    final verified = await _promptPin(
                                      masterPinProfile.pin!,
                                      'Parental Shield (${masterPinProfile.name})',
                                    );
                                    if (!verified) return;
                                  }
                                }
                                await profileProvider.switchProfile(profile.id);
                              }
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: Container(
                              width: isCompact ? 120 : 140,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 14,
                              ),
                              decoration: tokens.getShapeDecoration(
                                color: isActive
                                    ? tokens.surfaceCard
                                    : tokens.canvasBackground.withValues(
                                        alpha: 0.5,
                                      ),
                                radius: tokens.cardRadius,
                                side: BorderSide(
                                  color: isActive
                                      ? profileColor
                                      : tokens.borderSubtle,
                                  width: isActive ? 2.0 : 1.0,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Avatar circle
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: isCompact ? 64 : 76,
                                        height: isCompact ? 64 : 76,
                                        decoration: tokens.getShapeDecoration(
                                          color: profileColor.withValues(
                                            alpha: 0.25,
                                          ),
                                          radius: 999.0,
                                          side: BorderSide(
                                            color: profileColor,
                                            width: 2.0,
                                          ),
                                        ),
                                        child: Icon(
                                          UserProfile.getIconForAvatar(
                                            profile.avatarIcon,
                                          ),
                                          size: isCompact ? 36 : 42,
                                          color: profileColor,
                                        ),
                                      ),
                                      if (_isManageMode)
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: tokens.canvasBackground
                                                  .withValues(alpha: 0.65),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Icon(
                                                Icons.edit_rounded,
                                                color: tokens.primaryAccent,
                                                size: isCompact ? 24 : 30,
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (profile.isPinProtected &&
                                          !_isManageMode)
                                        Positioned(
                                          top: -2,
                                          right: -2,
                                          child: Container(
                                            padding: const EdgeInsets.all(3.5),
                                            decoration: tokens
                                                .getShapeDecoration(
                                                  color: tokens.surfaceElevated,
                                                  radius: 999.0,
                                                  side: BorderSide(
                                                    color: tokens.borderSubtle,
                                                    width: 1.2,
                                                  ),
                                                ),
                                            child: Icon(
                                              Icons.lock_rounded,
                                              size: 11,
                                              color: tokens.vipColor,
                                            ),
                                          ),
                                        ),
                                      if (isActive && !_isManageMode)
                                        Positioned(
                                          right: -2,
                                          bottom: -2,
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: tokens
                                                .getShapeDecoration(
                                                  color: profileColor,
                                                  radius: 999.0,
                                                ),
                                            child: Icon(
                                              Icons.check_rounded,
                                              size: 14,
                                              color: tokens.canvasBackground,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Name
                                  Text(
                                    profile.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: tokens.textPrimary,
                                      fontSize: isCompact ? 13 : 15,
                                      fontWeight: isActive
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // Kids badge or Edit label
                                  if (_isManageMode)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: tokens.getShapeDecoration(
                                        color: tokens.surfaceElevated,
                                        radius: tokens.cardRadius * 0.7,
                                        side: BorderSide(
                                          color: tokens.primaryAccent
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.edit_rounded,
                                            size: 11,
                                            color: tokens.primaryAccent,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Edit',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: tokens.primaryAccent,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (profile.isKids)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: tokens.getShapeDecoration(
                                        color: tokens.secondaryAccent
                                            .withValues(alpha: 0.2),
                                        radius: 999.0,
                                      ),
                                      child: Text(
                                        'KIDS',
                                        style: TextStyle(
                                          color: tokens.secondaryAccent,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          );
                        }),

                        // Add Profile Card
                        TvFocusable(
                          borderRadius: BorderRadius.circular(
                            tokens.cardRadius,
                          ),
                          onTap: () async {
                            if (profileProvider.isKidsActive) {
                              final masterPinProfile = profileProvider.profiles
                                  .firstWhere(
                                    (p) => p.isPinProtected,
                                    orElse: () => profileProvider.activeProfile,
                                  );
                              if (masterPinProfile.isPinProtected) {
                                final verified = await _promptPin(
                                  masterPinProfile.pin!,
                                  'Parental Shield (${masterPinProfile.name})',
                                );
                                if (!verified) return;
                              }
                            }
                            _showAddOrEditDialog();
                          },
                          child: Container(
                            width: isCompact ? 120 : 140,
                            height: isCompact ? 172 : 192,
                            decoration: tokens.getShapeDecoration(
                              color: tokens.surfaceCard.withValues(alpha: 0.4),
                              radius: tokens.cardRadius,
                              side: BorderSide(
                                color: tokens.borderSubtle,
                                width: 1.0,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: isCompact ? 56 : 64,
                                  height: isCompact ? 56 : 64,
                                  decoration: tokens.getShapeDecoration(
                                    color: tokens.surfaceElevated,
                                    radius: 999.0,
                                    side: BorderSide(
                                      color: tokens.borderSubtle,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.add_rounded,
                                    size: isCompact ? 32 : 36,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Add Profile',
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: isCompact ? 13 : 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // TV D-Pad Accessible Manage / Done Action Button
                Center(
                  child: TvFocusable(
                    borderRadius: tokens.borderRadiusPill,
                    onTap: () => setState(() => _isManageMode = !_isManageMode),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: tokens.getShapeDecoration(
                        color: _isManageMode
                            ? tokens.primaryAccent
                            : tokens.surfaceCard,
                        radius: 999.0,
                        side: BorderSide(
                          color: _isManageMode
                              ? tokens.primaryAccent
                              : tokens.borderSubtle,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isManageMode
                                ? Icons.check_rounded
                                : Icons.edit_rounded,
                            size: 16,
                            color: _isManageMode
                                ? tokens.canvasBackground
                                : tokens.textPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isManageMode
                                ? 'Done Managing'
                                : 'Manage Profiles (Edit / Delete)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _isManageMode
                                  ? tokens.canvasBackground
                                  : tokens.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal for adding a new profile or editing an existing one.
class _AddOrEditProfileModal extends StatefulWidget {
  final UserProfile? profileToEdit;

  const _AddOrEditProfileModal({this.profileToEdit});

  @override
  State<_AddOrEditProfileModal> createState() => _AddOrEditProfileModalState();
}

class _AddOrEditProfileModalState extends State<_AddOrEditProfileModal> {
  late TextEditingController _nameController;
  late TextEditingController _pinController;
  late String _selectedAvatar;
  late int _selectedColorIndex;
  late bool _isKids;
  late bool _pinEnabled;

  @override
  void initState() {
    super.initState();
    final p = widget.profileToEdit;
    _nameController = TextEditingController(text: p?.name ?? '');
    _pinController = TextEditingController(text: p?.pin ?? '');
    _selectedAvatar = p?.avatarIcon ?? 'face';
    _selectedColorIndex = p?.avatarColorIndex ?? 0;
    _isKids = p?.isKids ?? false;
    _pinEnabled = p?.isPinProtected ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Color _getColor(int index, AppDesignTokens tokens) {
    switch (index % 4) {
      case 1:
        return tokens.secondaryAccent;
      case 2:
        return tokens.vipColor;
      case 3:
        return tokens.liveColor;
      case 0:
      default:
        return tokens.primaryAccent;
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final pin = _pinEnabled && _pinController.text.trim().length == 4
        ? _pinController.text.trim()
        : null;

    final provider = context.read<ProfileProvider>();
    if (widget.profileToEdit != null) {
      final updated = widget.profileToEdit!.copyWith(
        name: name,
        avatarIcon: _selectedAvatar,
        avatarColorIndex: _selectedColorIndex,
        isKids: _isKids,
        pin: pin,
        clearPin: !_pinEnabled,
      );
      await provider.updateProfile(updated);
    } else {
      await provider.createProfile(
        name: name,
        avatarIcon: _selectedAvatar,
        avatarColorIndex: _selectedColorIndex,
        isKids: _isKids,
        pin: pin,
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    if (widget.profileToEdit == null) return;
    final provider = context.read<ProfileProvider>();
    if (provider.profiles.length <= 1) return;

    await provider.deleteProfile(widget.profileToEdit!.id);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 540 || size.height < 600;
    final isEditing = widget.profileToEdit != null;
    final canDelete =
        isEditing && context.watch<ProfileProvider>().profiles.length > 1;

    return TvPopupScope(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: (size.width * 0.85).clamp(320.0, 520.0),
              maxHeight: (size.height * 0.85).clamp(360.0, 620.0),
            ),
            margin: const EdgeInsets.all(20),
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 18 : 24,
              vertical: isCompact ? 18 : 22,
            ),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceElevated,
              radius: tokens.cardRadius,
              side: BorderSide(color: tokens.borderSubtle, width: 1.5),
              shadows: tokens.getCardShadows(),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Profile' : 'New Profile',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: isCompact ? 17 : 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TvFocusable(
                      borderRadius: tokens.borderRadiusPill,
                      onTap: () => Navigator.of(context).pop(),
                      child: IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: tokens.textMuted,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name Field
                        Text(
                          'Profile Name',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameController,
                          autofocus: true,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Living Room, Mom, Kids',
                            hintStyle: TextStyle(color: tokens.textMuted),
                            filled: true,
                            fillColor: tokens.canvasBackground,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                tokens.cardRadius * 0.7,
                              ),
                              borderSide: BorderSide(
                                color: tokens.borderSubtle,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                tokens.cardRadius * 0.7,
                              ),
                              borderSide: BorderSide(
                                color: tokens.borderSubtle,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                tokens.cardRadius * 0.7,
                              ),
                              borderSide: BorderSide(
                                color: tokens.borderFocus,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Avatar Icon Selector
                        Text(
                          'Choose Avatar',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 52,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            cacheExtent: 350.0,
                            itemCount: UserProfile.availableAvatars.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final opt = UserProfile.availableAvatars[index];
                              final isSelected = opt.id == _selectedAvatar;
                              final color = _getColor(
                                _selectedColorIndex,
                                tokens,
                              );

                              return TvFocusable(
                                borderRadius: tokens.borderRadiusPill,
                                onTap: () =>
                                    setState(() => _selectedAvatar = opt.id),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: tokens.getShapeDecoration(
                                    color: isSelected
                                        ? color.withValues(alpha: 0.25)
                                        : tokens.surfaceCard,
                                    radius: 999.0,
                                    side: BorderSide(
                                      color: isSelected
                                          ? color
                                          : tokens.borderSubtle,
                                      width: isSelected ? 2.0 : 1.0,
                                    ),
                                  ),
                                  child: Icon(
                                    opt.icon,
                                    color: isSelected
                                        ? color
                                        : tokens.textSecondary,
                                    size: 24,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Avatar Color Accent
                        Text(
                          'Accent Color',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(4, (i) {
                            final isSelected = i == _selectedColorIndex;
                            final color = _getColor(i, tokens);

                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: TvFocusable(
                                borderRadius: tokens.borderRadiusPill,
                                onTap: () =>
                                    setState(() => _selectedColorIndex = i),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: tokens.getShapeDecoration(
                                    color: color,
                                    radius: 999.0,
                                    side: BorderSide(
                                      color: isSelected
                                          ? tokens.textPrimary
                                          : Colors.transparent,
                                      width: 2.0,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Icon(
                                          Icons.check_rounded,
                                          size: 20,
                                          color: tokens.canvasBackground,
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 18),

                        // Kids Mode Toggle
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: tokens.getShapeDecoration(
                            color: tokens.surfaceCard,
                            radius: tokens.cardRadius * 0.7,
                            side: BorderSide(color: tokens.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Kids Profile',
                                      style: TextStyle(
                                        color: tokens.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Safe mode for children and younger viewers.',
                                      style: TextStyle(
                                        color: tokens.textMuted,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TvFocusable(
                                borderRadius: tokens.borderRadiusPill,
                                onTap: () => setState(() => _isKids = !_isKids),
                                child: Switch.adaptive(
                                  value: _isKids,
                                  activeColor: tokens.primaryAccent,
                                  onChanged: (val) =>
                                      setState(() => _isKids = val),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Parental PIN Lock
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: tokens.getShapeDecoration(
                            color: tokens.surfaceCard,
                            radius: tokens.cardRadius * 0.7,
                            side: BorderSide(color: tokens.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    color: tokens.primaryAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Parental PIN Lock',
                                          style: TextStyle(
                                            color: tokens.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Require a 4-digit PIN to switch to or edit this profile.',
                                          style: TextStyle(
                                            color: tokens.textMuted,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TvFocusable(
                                    borderRadius: tokens.borderRadiusPill,
                                    onTap: () => setState(
                                      () => _pinEnabled = !_pinEnabled,
                                    ),
                                    child: Switch.adaptive(
                                      value: _pinEnabled,
                                      activeColor: tokens.primaryAccent,
                                      onChanged: (val) =>
                                          setState(() => _pinEnabled = val),
                                    ),
                                  ),
                                ],
                              ),
                              if (_pinEnabled) ...[
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 10),
                                Text(
                                  '4-Digit Numeric PIN',
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _pinController,
                                  keyboardType: TextInputType.number,
                                  obscureText: true,
                                  maxLength: 4,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  style: TextStyle(
                                    color: tokens.textPrimary,
                                    fontSize: 16,
                                    letterSpacing: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    hintText: '••••',
                                    hintStyle: TextStyle(
                                      color: tokens.textMuted,
                                      letterSpacing: 8,
                                    ),
                                    filled: true,
                                    fillColor: tokens.canvasBackground,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        tokens.cardRadius * 0.7,
                                      ),
                                      borderSide: BorderSide(
                                        color: tokens.borderSubtle,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        tokens.cardRadius * 0.7,
                                      ),
                                      borderSide: BorderSide(
                                        color: tokens.borderSubtle,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        tokens.cardRadius * 0.7,
                                      ),
                                      borderSide: BorderSide(
                                        color: tokens.borderFocus,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (canDelete) ...[
                      TvFocusable(
                        borderRadius: BorderRadius.circular(
                          tokens.cardRadius * 0.6,
                        ),
                        onTap: _delete,
                        child: TextButton.icon(
                          onPressed: _delete,
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: tokens.errorColor,
                            size: 18,
                          ),
                          label: Text(
                            'Delete',
                            style: TextStyle(color: tokens.errorColor),
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                    TvFocusable(
                      borderRadius: BorderRadius.circular(
                        tokens.cardRadius * 0.6,
                      ),
                      onTap: () => Navigator.of(context).pop(),
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: tokens.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TvFocusable(
                      borderRadius: BorderRadius.circular(
                        tokens.cardRadius * 0.7,
                      ),
                      onTap: _save,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.primaryAccent.withValues(
                            alpha: 0.85,
                          ),
                          foregroundColor: tokens.canvasBackground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              tokens.cardRadius * 0.7,
                            ),
                          ),
                        ),
                        onPressed: _save,
                        child: Text(
                          isEditing ? 'Save Changes' : 'Create Profile',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// TV D-Pad & touch-friendly 4-digit PIN verification modal.
class _ProfilePinVerificationDialog extends StatefulWidget {
  final String expectedPin;
  final String title;

  const _ProfilePinVerificationDialog({
    required this.expectedPin,
    required this.title,
  });

  @override
  State<_ProfilePinVerificationDialog> createState() =>
      _ProfilePinVerificationDialogState();
}

class _ProfilePinVerificationDialogState
    extends State<_ProfilePinVerificationDialog> {
  String _entered = '';
  String? _error;
  final FocusNode _keyboardFocusNode = FocusNode(
    debugLabel: 'pin_keyboard_focus',
  );

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _addDigit(String d) {
    if (_entered.length >= 4) return;
    setState(() {
      _error = null;
      _entered += d;
    });

    if (_entered.length == 4) {
      if (_entered == widget.expectedPin) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = 'Incorrect PIN. Try again.';
        });
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            setState(() {
              _entered = '';
              _error = null;
            });
          }
        });
      }
    }
  }

  void _backspace() {
    if (_entered.isNotEmpty) {
      setState(() {
        _error = null;
        _entered = _entered.substring(0, _entered.length - 1);
      });
    }
  }

  void _clear() {
    setState(() {
      _error = null;
      _entered = '';
    });
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final keyLabel = event.character;
    if (keyLabel != null && RegExp(r'^[0-9]$').hasMatch(keyLabel)) {
      _addDigit(keyLabel);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _backspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop(false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return TvPopupScope(
      child: Focus(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(24),
              decoration: tokens.getShapeDecoration(
                color: tokens.surfaceElevated,
                radius: tokens.cardRadius,
                side: BorderSide(color: tokens.borderSubtle, width: 1.5),
                shadows: tokens.getCardShadows(),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lock Icon
                  Container(
                    width: 52,
                    height: 52,
                    decoration: tokens.getShapeDecoration(
                      color: tokens.primaryAccent.withValues(alpha: 0.15),
                      radius: 999.0,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      color: tokens.primaryAccent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Enter Profile PIN',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4 Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final isFilled = i < _entered.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 16,
                        height: 16,
                        decoration: tokens.getShapeDecoration(
                          color: isFilled
                              ? tokens.primaryAccent
                              : tokens.canvasBackground,
                          radius: 999.0,
                          side: BorderSide(
                            color: isFilled
                                ? tokens.primaryAccent
                                : tokens.borderSubtle,
                            width: 1.5,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 20,
                    child: _error != null
                        ? Text(
                            _error!,
                            style: TextStyle(
                              color: tokens.errorColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // Keypad grid 3x4
                  Column(
                    children: [
                      _buildKeyRow(['1', '2', '3']),
                      const SizedBox(height: 8),
                      _buildKeyRow(['4', '5', '6']),
                      const SizedBox(height: 8),
                      _buildKeyRow(['7', '8', '9']),
                      const SizedBox(height: 8),
                      _buildBottomKeyRow(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Cancel Button
                  TvFocusable(
                    borderRadius: BorderRadius.circular(
                      tokens.cardRadius * 0.6,
                    ),
                    onTap: () => Navigator.of(context).pop(false),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: tokens.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((d) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _buildKeyButton(label: d, onTap: () => _addDigit(d)),
        );
      }).toList(),
    );
  }

  Widget _buildBottomKeyRow() {
    final tokens = context.tokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _buildKeyButton(
            child: Icon(Icons.clear_rounded, size: 18, color: tokens.textMuted),
            onTap: _clear,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _buildKeyButton(label: '0', onTap: () => _addDigit('0')),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _buildKeyButton(
            child: Icon(
              Icons.backspace_outlined,
              size: 18,
              color: tokens.textSecondary,
            ),
            onTap: _backspace,
          ),
        ),
      ],
    );
  }

  Widget _buildKeyButton({
    String? label,
    Widget? child,
    required VoidCallback onTap,
  }) {
    final tokens = context.tokens;
    return TvFocusable(
      borderRadius: tokens.borderRadiusPill,
      onTap: onTap,
      child: Container(
        width: 56,
        height: 44,
        decoration: tokens.getShapeDecoration(
          color: tokens.surfaceCard,
          radius: tokens.cardRadius * 0.7,
          side: BorderSide(color: tokens.borderSubtle),
        ),
        alignment: Alignment.center,
        child:
            child ??
            Text(
              label!,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
      ),
    );
  }
}
