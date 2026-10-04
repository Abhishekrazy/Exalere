import 'dart:ui';

import 'package:flutter/material.dart';

import '../../services/watch_party_service.dart';
import '../theme/app_tokens.dart';
import 'tv_focusable.dart';

/// Modal dialog for hosting or joining a LAN Watch Party.
class WatchPartyDialog extends StatefulWidget {
  final String mediaTitle;
  final String mediaId;
  final int currentPositionMs;
  final bool isPlaying;
  final VoidCallback? onStateChanged;

  const WatchPartyDialog({
    super.key,
    required this.mediaTitle,
    required this.mediaId,
    required this.currentPositionMs,
    required this.isPlaying,
    this.onStateChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String mediaTitle,
    required String mediaId,
    required int currentPositionMs,
    required bool isPlaying,
    VoidCallback? onStateChanged,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: context.tokens.shadowColor.withValues(alpha: 0.85),
      builder: (_) => WatchPartyDialog(
        mediaTitle: mediaTitle,
        mediaId: mediaId,
        currentPositionMs: currentPositionMs,
        isPlaying: isPlaying,
        onStateChanged: onStateChanged,
      ),
    );
  }

  @override
  State<WatchPartyDialog> createState() => _WatchPartyDialogState();
}

class _WatchPartyDialogState extends State<WatchPartyDialog> {
  final WatchPartyService _partyService = WatchPartyService();
  final TextEditingController _pinController = TextEditingController();
  bool _isHostingTab = true;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _startHost() async {
    setState(() => _isConnecting = true);
    await _partyService.startHosting(
      hostName: 'Host Device',
      mediaId: widget.mediaId,
      mediaTitle: widget.mediaTitle,
    );
    _partyService.broadcastState(
      hostName: 'Host Device',
      mediaId: widget.mediaId,
      mediaTitle: widget.mediaTitle,
      positionMs: widget.currentPositionMs,
      isPlaying: widget.isPlaying,
    );
    if (!mounted) return;
    setState(() {
      _isConnecting = false;
    });
    widget.onStateChanged?.call();
  }

  Future<void> _joinParty() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;
    setState(() => _isConnecting = true);
    final ok = await _partyService.joinParty(pin: pin);
    if (!mounted) return;
    setState(() => _isConnecting = false);
    if (ok) {
      widget.onStateChanged?.call();
      Navigator.of(context).pop();
    }
  }

  Future<void> _leaveParty() async {
    await _partyService.stopParty();
    if (!mounted) return;
    setState(() {});
    widget.onStateChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width * 0.8).clamp(340.0, 520.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: tokens.borderRadiusLg,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: dialogWidth,
            padding: const EdgeInsets.all(26),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceElevated.withValues(alpha: 0.94),
              radius: tokens.cardRadius * 1.5,
              side: BorderSide(
                color: tokens.borderFocus.withValues(alpha: 0.5),
                width: 1.2,
              ),
              shadows: [
                BoxShadow(
                  color: tokens.shadowColor.withValues(alpha: 0.5),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.groups_rounded,
                          color: tokens.primaryAccent,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Watch Party',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    TvFocusable(
                      onTap: () => Navigator.of(context).pop(),
                      scaleFactor: 1.1,
                      shape: tokens.shapeSm,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: tokens.surfaceCard,
                          borderRadius: tokens.borderRadiusSm,
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: tokens.textSecondary,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Subtitle
                Text(
                  'Synchronize playback across TVs, phones, and PCs on your local Wi-Fi.',
                  style: TextStyle(fontSize: 13, color: tokens.textMuted),
                ),
                const SizedBox(height: 20),

                // Tab Switcher (Host vs Join)
                if (!_partyService.isInParty)
                  Container(
                    decoration: BoxDecoration(
                      color: tokens.surfaceCard,
                      borderRadius: tokens.borderRadiusSm,
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TvFocusable(
                            onTap: () => setState(() => _isHostingTab = true),
                            shape: tokens.shapeSm,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isHostingTab
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: tokens.borderRadiusSm,
                              ),
                              child: Center(
                                child: Text(
                                  'Host Session',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _isHostingTab
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: _isHostingTab
                                        ? theme.colorScheme.onPrimary
                                        : tokens.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TvFocusable(
                            onTap: () => setState(() => _isHostingTab = false),
                            shape: tokens.shapeSm,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isHostingTab
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: tokens.borderRadiusSm,
                              ),
                              child: Center(
                                child: Text(
                                  'Join Party',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: !_isHostingTab
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: !_isHostingTab
                                        ? theme.colorScheme.onPrimary
                                        : tokens.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                // Content
                if (_partyService.isInParty) ...[
                  // Active Party Status
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tokens.surfaceCard,
                      borderRadius: tokens.borderRadiusMd,
                      border: Border.all(color: tokens.borderFocus),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _partyService.isHosting
                              ? 'Party Code (PIN)'
                              : 'Connected to Party',
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _partyService.currentPartyPin ?? '----',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            color: tokens.primaryAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tokens.primaryAccent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _partyService.isHosting
                                  ? '${_partyService.connectedClientsCount} device(s) synchronized'
                                  : 'Syncing with host playback',
                              style: TextStyle(
                                fontSize: 13,
                                color: tokens.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TvFocusable(
                      autofocus: true,
                      onTap: _leaveParty,
                      shape: tokens.shapeSm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          borderRadius: tokens.borderRadiusSm,
                        ),
                        child: Text(
                          _partyService.isHosting
                              ? 'End Watch Party'
                              : 'Leave Party',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onError,
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else if (_isHostingTab) ...[
                  // Host CTA
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Your device will act as the playback conductor. Other screens on your Wi-Fi can join via your PIN.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TvFocusable(
                          autofocus: true,
                          scaleFactor: 1.05,
                          shape: tokens.shapeSm,
                          onTap: _startHost,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: tokens.borderRadiusSm,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_circle_fill_rounded,
                                  size: 18,
                                  color: theme.colorScheme.onPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isConnecting
                                      ? 'Starting...'
                                      : 'Start Watch Party',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Join input
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: tokens.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Enter 4-digit Party PIN',
                      hintStyle: TextStyle(color: tokens.textMuted),
                      filled: true,
                      fillColor: tokens.surfaceCard,
                      border: OutlineInputBorder(
                        borderRadius: tokens.borderRadiusSm,
                        borderSide: BorderSide(color: tokens.borderSubtle),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TvFocusable(
                      autofocus: true,
                      scaleFactor: 1.05,
                      shape: tokens.shapeSm,
                      onTap: _joinParty,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: tokens.borderRadiusSm,
                        ),
                        child: Text(
                          _isConnecting ? 'Connecting...' : 'Join Now',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
