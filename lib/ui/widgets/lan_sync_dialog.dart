import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/profile_provider.dart';
import '../../services/lan_sync_service.dart';
import '../theme/app_tokens.dart';
import 'tv/tv_popup_scope.dart';
import 'tv_focusable.dart';

/// Modal dialog for managing zero-cloud Local LAN P2P synchronization across devices.
class LanSyncDialog extends StatefulWidget {
  const LanSyncDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const LanSyncDialog(),
    );
  }

  @override
  State<LanSyncDialog> createState() => _LanSyncDialogState();
}

class _LanSyncDialogState extends State<LanSyncDialog> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isEditingName = false;
  bool _showManualIpInput = false;
  String? _syncStatusMessage;
  bool _isSuccessStatus = true;

  @override
  void initState() {
    super.initState();
    final lanSync = LanSyncService();
    _nameController.text = lanSync.deviceName;
    // Broadcast a fresh beacon to discover any devices immediately
    if (lanSync.isEnabled) {
      lanSync.broadcastBeacon();
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'tv':
        return Icons.tv_rounded;
      case 'mobile':
        return Icons.smartphone_rounded;
      case 'desktop':
        return Icons.laptop_mac_rounded;
      default:
        return Icons.devices_rounded;
    }
  }

  Future<void> _handleSyncPeer(DiscoveredPeer peer) async {
    final lanSync = context.read<LanSyncService>();
    final result = await lanSync.syncWithPeer(peer);
    if (!mounted) return;

    setState(() {
      if (result.success) {
        _isSuccessStatus = true;
        _syncStatusMessage =
            'Synced successfully with ${result.peerName} (${result.syncedProfiles.join(', ')})';
      } else {
        _isSuccessStatus = false;
        _syncStatusMessage = result.errorMessage ?? 'Sync failed';
      }
    });
  }

  Future<void> _handleManualIpSync() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;

    final lanSync = context.read<LanSyncService>();
    final result = await lanSync.syncWithAddress(ip);
    if (!mounted) return;

    setState(() {
      if (result.success) {
        _isSuccessStatus = true;
        _syncStatusMessage =
            'Synced successfully with ${result.peerName} (${result.syncedProfiles.join(', ')})';
        _ipController.clear();
        _showManualIpInput = false;
      } else {
        _isSuccessStatus = false;
        _syncStatusMessage = result.errorMessage ?? 'Could not connect to $ip';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 540 || size.height < 600;
    final lanSync = context.watch<LanSyncService>();
    final profileProvider = context.watch<ProfileProvider>();
    final localProfileNames = profileProvider.profiles
        .map((p) => p.name.trim().toLowerCase())
        .toSet();
    final peers = lanSync.discoveredPeers;

    return TvPopupScope(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: (size.width * 0.9).clamp(340.0, 680.0),
              maxHeight: (size.height * 0.85).clamp(420.0, 720.0),
            ),
            margin: const EdgeInsets.all(20),
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 18 : 26,
              vertical: isCompact ? 18 : 24,
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
                        Icons.wifi_tethering_rounded,
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
                            'Local Wi-Fi Sync',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: isCompact ? 18 : 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Sync watch progress, history & favorites across devices on your local network.',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: isCompact ? 12 : 13,
                            ),
                          ),
                        ],
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
                        tooltip: 'Close',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Sync status banner if any
                if (_syncStatusMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: tokens.getShapeDecoration(
                      color: _isSuccessStatus
                          ? tokens.primaryAccent.withValues(alpha: 0.15)
                          : tokens.errorColor.withValues(alpha: 0.15),
                      radius: tokens.cardRadius * 0.7,
                      side: BorderSide(
                        color: _isSuccessStatus
                            ? tokens.primaryAccent
                            : tokens.errorColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isSuccessStatus
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          color: _isSuccessStatus
                              ? tokens.primaryAccent
                              : tokens.errorColor,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _syncStatusMessage!,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TvFocusable(
                          borderRadius: tokens.borderRadiusPill,
                          onTap: () =>
                              setState(() => _syncStatusMessage = null),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _syncStatusMessage = null),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: tokens.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Scrollable Content
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Local Device Info Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: tokens.getShapeDecoration(
                            color: tokens.surfaceCard,
                            radius: tokens.cardRadius * 0.8,
                            side: BorderSide(color: tokens.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _getDeviceIcon(lanSync.deviceType),
                                    size: 20,
                                    color: tokens.primaryAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _isEditingName
                                        ? TextField(
                                            controller: _nameController,
                                            autofocus: true,
                                            style: TextStyle(
                                              color: tokens.textPrimary,
                                              fontSize: 13.5,
                                            ),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      tokens.cardRadius * 0.5,
                                                    ),
                                                borderSide: BorderSide(
                                                  color: tokens.borderFocus,
                                                ),
                                              ),
                                            ),
                                            onSubmitted: (v) async {
                                              await lanSync.setCustomDeviceName(
                                                v,
                                              );
                                              setState(
                                                () => _isEditingName = false,
                                              );
                                            },
                                          )
                                        : Text(
                                            'This Device: ${lanSync.deviceName}',
                                            style: TextStyle(
                                              color: tokens.textPrimary,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                  TvFocusable(
                                    borderRadius: tokens.borderRadiusPill,
                                    onTap: () async {
                                      if (_isEditingName) {
                                        await lanSync.setCustomDeviceName(
                                          _nameController.text,
                                        );
                                        setState(() => _isEditingName = false);
                                      } else {
                                        setState(() => _isEditingName = true);
                                      }
                                    },
                                    child: IconButton(
                                      icon: Icon(
                                        _isEditingName
                                            ? Icons.check_rounded
                                            : Icons.edit_rounded,
                                        size: 16,
                                        color: tokens.textSecondary,
                                      ),
                                      onPressed: () async {
                                        if (_isEditingName) {
                                          await lanSync.setCustomDeviceName(
                                            _nameController.text,
                                          );
                                          setState(
                                            () => _isEditingName = false,
                                          );
                                        } else {
                                          setState(() => _isEditingName = true);
                                        }
                                      },
                                      tooltip: _isEditingName
                                          ? 'Save Name'
                                          : 'Rename Device',
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  TvFocusable(
                                    borderRadius: tokens.borderRadiusPill,
                                    onTap: () =>
                                        lanSync.setEnabled(!lanSync.isEnabled),
                                    child: Switch.adaptive(
                                      value: lanSync.isEnabled,
                                      activeColor: tokens.primaryAccent,
                                      onChanged: (val) =>
                                          lanSync.setEnabled(val),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'Status: ',
                                    style: TextStyle(
                                      color: tokens.textMuted,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  Text(
                                    lanSync.isEnabled
                                        ? 'Active (Port ${lanSync.httpPort})'
                                        : 'Disabled',
                                    style: TextStyle(
                                      color: lanSync.isEnabled
                                          ? tokens.primaryAccent
                                          : tokens.textMuted,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (lanSync.isEnabled)
                                    TvFocusable(
                                      borderRadius: BorderRadius.circular(
                                        tokens.cardRadius * 0.5,
                                      ),
                                      onTap: () => lanSync.broadcastBeacon(),
                                      child: TextButton.icon(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                        ),
                                        onPressed: () =>
                                            lanSync.broadcastBeacon(),
                                        icon: Icon(
                                          Icons.refresh_rounded,
                                          size: 14,
                                          color: tokens.primaryAccent,
                                        ),
                                        label: Text(
                                          'Broadcast',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: tokens.primaryAccent,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Discovered Peers Section Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Discovered Local Devices',
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TvFocusable(
                              borderRadius: BorderRadius.circular(
                                tokens.cardRadius * 0.5,
                              ),
                              onTap: () => setState(
                                () => _showManualIpInput = !_showManualIpInput,
                              ),
                              child: TextButton.icon(
                                onPressed: () => setState(
                                  () =>
                                      _showManualIpInput = !_showManualIpInput,
                                ),
                                icon: Icon(
                                  _showManualIpInput
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.add_link_rounded,
                                  size: 16,
                                  color: tokens.textSecondary,
                                ),
                                label: Text(
                                  _showManualIpInput
                                      ? 'Hide IP Input'
                                      : 'Direct IP Sync',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Manual IP Input (if toggled)
                        if (_showManualIpInput) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: tokens.getShapeDecoration(
                              color: tokens.canvasBackground,
                              radius: tokens.cardRadius * 0.7,
                              side: BorderSide(color: tokens.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _ipController,
                                    style: TextStyle(
                                      color: tokens.textPrimary,
                                      fontSize: 13,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'e.g. 192.168.1.55',
                                      hintStyle: TextStyle(
                                        color: tokens.textMuted,
                                      ),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 10,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          tokens.cardRadius * 0.5,
                                        ),
                                        borderSide: BorderSide(
                                          color: tokens.borderSubtle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TvFocusable(
                                  borderRadius: BorderRadius.circular(
                                    tokens.cardRadius * 0.5,
                                  ),
                                  onTap: lanSync.isSyncing
                                      ? null
                                      : _handleManualIpSync,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: tokens.primaryAccent
                                          .withValues(alpha: 0.85),
                                      foregroundColor: tokens.canvasBackground,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          tokens.cardRadius * 0.5,
                                        ),
                                      ),
                                    ),
                                    onPressed: lanSync.isSyncing
                                        ? null
                                        : _handleManualIpSync,
                                    child: lanSync.isSyncing
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Connect'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Peers List
                        if (peers.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            decoration: tokens.getShapeDecoration(
                              color: tokens.canvasBackground.withValues(
                                alpha: 0.4,
                              ),
                              radius: tokens.cardRadius * 0.7,
                              side: BorderSide(color: tokens.borderSubtle),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.wifi_find_rounded,
                                  size: 38,
                                  color: tokens.textMuted.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Scanning for Exalere devices on local Wi-Fi...',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Open Exalere on your TV, phone, or PC connected to the same Wi-Fi.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: tokens.textMuted,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: peers.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final peer = peers[index];
                              final matchingProfiles = peer.profileNames
                                  .where(
                                    (name) => localProfileNames.contains(
                                      name.trim().toLowerCase(),
                                    ),
                                  )
                                  .toList();

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: tokens.getShapeDecoration(
                                  color: tokens.surfaceCard,
                                  radius: tokens.cardRadius * 0.7,
                                  side: BorderSide(color: tokens.borderSubtle),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: tokens.getShapeDecoration(
                                        color: tokens.primaryAccent.withValues(
                                          alpha: 0.15,
                                        ),
                                        radius: 999.0,
                                      ),
                                      child: Icon(
                                        _getDeviceIcon(peer.deviceType),
                                        color: tokens.primaryAccent,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            peer.name,
                                            style: TextStyle(
                                              color: tokens.textPrimary,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${peer.address}:${peer.port} • Profiles: ${peer.profileNames.join(', ')}',
                                            style: TextStyle(
                                              color: tokens.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                          if (matchingProfiles.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              'Matching: ${matchingProfiles.join(', ')}',
                                              style: TextStyle(
                                                color: tokens.secondaryAccent,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TvFocusable(
                                      borderRadius: BorderRadius.circular(
                                        tokens.cardRadius * 0.5,
                                      ),
                                      onTap: lanSync.isSyncing
                                          ? null
                                          : () => _handleSyncPeer(peer),
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: tokens.primaryAccent
                                              .withValues(alpha: 0.85),
                                          foregroundColor:
                                              tokens.canvasBackground,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              tokens.cardRadius * 0.5,
                                            ),
                                          ),
                                        ),
                                        onPressed: lanSync.isSyncing
                                            ? null
                                            : () => _handleSyncPeer(peer),
                                        icon: lanSync.isSyncing
                                            ? const SizedBox(
                                                width: 12,
                                                height: 12,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.sync_rounded,
                                                size: 14,
                                              ),
                                        label: const Text(
                                          'Sync Now',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Footer Close Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TvFocusable(
                      autofocus: true,
                      borderRadius: BorderRadius.circular(
                        tokens.cardRadius * 0.6,
                      ),
                      onTap: () => Navigator.of(context).pop(),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.surfaceCard,
                          foregroundColor: tokens.textPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              tokens.cardRadius * 0.6,
                            ),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
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
