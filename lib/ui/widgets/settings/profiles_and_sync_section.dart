import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/user_profile.dart';
import '../../../providers/profile_provider.dart';
import '../../../services/lan_sync_service.dart';
import '../../theme/app_tokens.dart';
import '../backup_restore_dialog.dart';
import '../lan_sync_dialog.dart';
import '../profile_selection_dialog.dart';
import '../tv_focusable.dart';
import '../tv_web_remote_dialog.dart';
import 'storage_management_dialog.dart';

/// Settings section allowing users to switch/manage viewer profiles and local Wi-Fi sync.
class ProfilesAndSyncSection extends StatelessWidget {
  const ProfilesAndSyncSection({super.key});

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

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final profileProvider = Provider.of<ProfileProvider?>(context);
    final lanSync = Provider.of<LanSyncService?>(context);
    final activeProfile =
        profileProvider?.activeProfile ?? UserProfile.createDefault();
    final profileColor = _getProfileColor(
      activeProfile.avatarColorIndex,
      tokens,
    );

    return Container(
      decoration: tokens.getShapeDecoration(
        color: tokens.surfaceCard,
        radius: tokens.cardRadius,
        side: BorderSide(color: tokens.borderSubtle),
      ),
      child: Column(
        children: [
          // 1. Active Profile Tile
          TvFocusable(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(tokens.cardRadius),
            ),
            onTap: () => ProfileSelectionDialog.show(context),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: tokens.getShapeDecoration(
                  color: profileColor.withValues(alpha: 0.2),
                  radius: 999.0,
                  side: BorderSide(color: profileColor, width: 1.5),
                ),
                child: Icon(
                  UserProfile.getIconForAvatar(activeProfile.avatarIcon),
                  color: profileColor,
                  size: 24,
                ),
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      activeProfile.name,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (activeProfile.isKids) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: tokens.getShapeDecoration(
                        color: tokens.secondaryAccent.withValues(alpha: 0.2),
                        radius: 999.0,
                      ),
                      child: Text(
                        'KIDS',
                        style: TextStyle(
                          color: tokens.secondaryAccent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                '${profileProvider?.profiles.length ?? 1} profile${(profileProvider?.profiles.length ?? 1) > 1 ? 's' : ''} configured • Tap to switch or edit',
                style: TextStyle(color: tokens.textMuted, fontSize: 12),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: tokens.textMuted,
              ),
            ),
          ),

          Divider(height: 1, thickness: 1, color: tokens.borderSubtle),

          // 2. Local LAN Sync Tile
          TvFocusable(
            borderRadius: BorderRadius.zero,
            onTap: () => LanSyncDialog.show(context),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: tokens.getShapeDecoration(
                  color: tokens.primaryAccent.withValues(alpha: 0.15),
                  radius: 999.0,
                ),
                child: Icon(
                  Icons.wifi_tethering_rounded,
                  color: tokens.primaryAccent,
                  size: 22,
                ),
              ),
              title: Text(
                'Local Wi-Fi Sync',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                (lanSync?.isEnabled ?? false)
                    ? (lanSync!.discoveredPeers.isEmpty
                          ? 'Active • Ready to sync with TV, Phone, or PC'
                          : '${lanSync.discoveredPeers.length} nearby device${lanSync.discoveredPeers.length > 1 ? 's' : ''} found')
                    : 'Disabled',
                style: TextStyle(
                  color: (lanSync?.isEnabled ?? false)
                      ? tokens.textMuted
                      : tokens.errorColor,
                  fontSize: 12,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: tokens.textMuted,
              ),
            ),
          ),

          Divider(height: 1, thickness: 1, color: tokens.borderSubtle),

          // 3. Backup & Restore Tile
          TvFocusable(
            onTap: () => BackupRestoreDialog.show(context),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: tokens.getShapeDecoration(
                  color: tokens.secondaryAccent.withValues(alpha: 0.15),
                  radius: 999.0,
                ),
                child: Icon(
                  Icons.settings_backup_restore_rounded,
                  color: tokens.secondaryAccent,
                  size: 22,
                ),
              ),
              title: Text(
                'Backup & Restore',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Export or import full profiles, history, and library offline',
                style: TextStyle(color: tokens.textMuted, fontSize: 12),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: tokens.textMuted,
              ),
            ),
          ),

          Divider(height: 1, thickness: 1, color: tokens.borderSubtle),

          // 4. Web Companion TV Remote Tile
          TvFocusable(
            onTap: () => TvWebRemoteDialog.show(context),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: tokens.getShapeDecoration(
                  color: tokens.primaryAccent.withValues(alpha: 0.15),
                  radius: 999.0,
                ),
                child: Icon(
                  Icons.phonelink_ring_rounded,
                  color: tokens.primaryAccent,
                  size: 22,
                ),
              ),
              title: Text(
                'Web Companion TV Remote',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Control TV and type search queries directly from your phone',
                style: TextStyle(color: tokens.textMuted, fontSize: 12),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: tokens.textMuted,
              ),
            ),
          ),

          Divider(height: 1, thickness: 1, color: tokens.borderSubtle),

          // 5. Storage Hygiene & Cache Cleaner Tile
          TvFocusable(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(tokens.cardRadius),
            ),
            onTap: () => StorageManagementDialog.show(context),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: tokens.getShapeDecoration(
                  color: tokens.vipColor.withValues(alpha: 0.15),
                  radius: 999.0,
                ),
                child: Icon(
                  Icons.cleaning_services_rounded,
                  color: tokens.vipColor,
                  size: 22,
                ),
              ),
              title: Text(
                'Storage & Cache Hygiene',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Purge video buffering chunks, image caches, and reclaim storage',
                style: TextStyle(color: tokens.textMuted, fontSize: 12),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: tokens.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
