import 'package:flutter/material.dart';

import '../../../models/network_proxy_settings.dart';
import '../../../services/network/network_bypass_service.dart';
import '../../../services/network/warp_service.dart';
import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';
import 'tv_setting_tile.dart';

/// The "Network" settings block: WARP, Anti-DPI, and DNS over HTTPS.
///
/// These are three different answers to ISP interference and are presented
/// together because they are usually used together: anti-DPI defeats inspection
/// of the connection, DoH fixes a poisoned lookup, and WARP would tunnel
/// everything if the native module were present.
class NetworkSettingsSection extends StatelessWidget {
  const NetworkSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final service = NetworkBypassService.instance;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final settings = service.settings;
        final status = service.antiDpiStatus;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.public_rounded,
                  size: 18,
                  color: tokens.primaryAccent,
                ),
                const SizedBox(width: 8),
                Text(
                  'Network',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // WARP: the switch stays disabled and explains itself rather than
            // pretending to tunnel.
            TvSettingSwitchTile(
              icon: Icons.cloud_rounded,
              title: 'WARP Mode',
              subtitle: service.isWarpAvailable
                  ? _warpSubtitle(service)
                  : service.warpUnavailableReason,
              value: settings.warpEnabled,
              onChanged: service.isWarpAvailable
                  ? (value) => service.setWarpEnabled(value)
                  : null,
            ),
            const SizedBox(height: 8),

            TvSettingSwitchTile(
              icon: Icons.shield_moon_rounded,
              title: 'AntiDPI Mode',
              subtitle: settings.antiDpiEnabled
                  ? 'Bypass ISP blocking without VPN · ${status.label}'
                  : 'Bypass ISP blocking without a VPN, by fragmenting the '
                        'TLS handshake',
              value: settings.antiDpiEnabled,
              onChanged: (value) async {
                final ok = await service.setAntiDpiEnabled(value);
                if (!ok && value && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Could not start the anti-DPI proxy: '
                        '${service.antiDpiStatus.error ?? 'unknown error'}',
                      ),
                      backgroundColor: tokens.errorColor,
                    ),
                  );
                }
              },
            ),

            if (settings.antiDpiEnabled) ...[
              const SizedBox(height: 8),
              _ProfilePicker(service: service),
            ],

            const SizedBox(height: 8),
            _DohPicker(service: service),
          ],
        );
      },
    );
  }

  /// Status line for the WARP row: what it does, plus where it currently stands.
  static String _warpSubtitle(NetworkBypassService service) {
    const base = 'Bypass ISP restrictions with Cloudflare WARP VPN';
    final warp = WarpService.instance;
    switch (warp.status) {
      case WarpStatus.error:
        return 'WARP error: ${warp.errorMessage ?? 'unknown'}';
      case WarpStatus.connected:
        return '$base · Connected';
      case WarpStatus.registering:
      case WarpStatus.connecting:
        return '$base · ${warp.status.label}';
      case WarpStatus.idle:
      case WarpStatus.unavailable:
        return base;
    }
  }
}

/// Fragmentation strength, only meaningful while anti-DPI is on.
class _ProfilePicker extends StatelessWidget {
  const _ProfilePicker({required this.service});

  final NetworkBypassService service;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final current = service.settings.antiDpiProfile;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated.withValues(alpha: 0.4),
        borderRadius: tokens.borderRadiusSm,
        border: Border.all(color: tokens.borderSubtle, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fragmentation',
            style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            current.description,
            style: TextStyle(color: tokens.textSecondary, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final profile in AntiDpiProfile.all)
                _Chip(
                  label: profile.label,
                  selected: profile.label == current.label,
                  onTap: () => service.setAntiDpiProfile(profile),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// DNS-over-HTTPS resolver choice.
class _DohPicker extends StatelessWidget {
  const _DohPicker({required this.service});

  final NetworkBypassService service;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final settings = service.settings;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated.withValues(alpha: 0.4),
        borderRadius: tokens.borderRadiusSm,
        border: Border.all(color: tokens.borderSubtle, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.dns_rounded,
                size: 20,
                color: settings.hasDoh
                    ? tokens.textPrimary
                    : tokens.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DNS over HTTPS',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Resolves hostnames securely, alongside AntiDPI',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final provider in DohProvider.values)
                _Chip(
                  label: provider.label,
                  selected: provider == settings.dohProvider,
                  onTap: () => service.setDohProvider(provider),
                ),
            ],
          ),
          if (settings.dohProvider == DohProvider.custom) ...[
            const SizedBox(height: 10),
            _CustomDohField(service: service),
          ],
        ],
      ),
    );
  }
}

/// Text entry for a self-hosted DoH endpoint.
class _CustomDohField extends StatefulWidget {
  const _CustomDohField({required this.service});

  final NetworkBypassService service;

  @override
  State<_CustomDohField> createState() => _CustomDohFieldState();
}

class _CustomDohFieldState extends State<_CustomDohField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.service.settings.customDohUrl,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            style: TextStyle(color: tokens.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'https://dns.example/dns-query',
              hintStyle: TextStyle(color: tokens.textMuted, fontSize: 12),
              filled: true,
              fillColor: tokens.surfaceCard,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: tokens.borderRadiusSm,
                borderSide: BorderSide(color: tokens.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: tokens.borderRadiusSm,
                borderSide: BorderSide(color: tokens.borderSubtle),
              ),
            ),
            onSubmitted: widget.service.setCustomDohUrl,
          ),
        ),
        const SizedBox(width: 8),
        TvFocusable(
          borderRadius: tokens.borderRadiusSm,
          onTap: () => widget.service.setCustomDohUrl(_controller.text),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.primaryAccent,
              borderRadius: tokens.borderRadiusSm,
              border: Border.all(color: tokens.borderFocus),
            ),
            child: Text(
              'Save',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: tokens.canvasBackground,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small selectable chip, D-Pad reachable.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return TvFocusable(
      borderRadius: tokens.borderRadiusPill,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? tokens.primaryAccent.withValues(alpha: 0.16)
              : tokens.surfaceCard,
          borderRadius: tokens.borderRadiusPill,
          border: Border.all(
            color: selected ? tokens.borderFocus : tokens.borderSubtle,
            width: selected ? 1.3 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? tokens.primaryAccent : tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
