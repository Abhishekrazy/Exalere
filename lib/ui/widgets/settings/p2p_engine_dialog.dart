import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/app_provider.dart';
import '../../../services/torrent_service.dart';
import '../../theme/app_tokens.dart';
import '../tv/tv_popup_scope.dart';
import '../tv_focusable.dart';

/// Configures which torrent engine resolves magnet links.
///
/// A BitTorrent engine cannot ship as a downloadable plugin — it is native code,
/// and both Dart's inability to load new native libraries at runtime and Google
/// Play's ban on downloading executable code rule that out. So peer-to-peer
/// support comes from one of two places:
///
///  * the engine bundled into the GitHub build (nothing to configure), or
///  * a separate engine service on this device, reached over loopback HTTP.
///
/// This dialog sets the second, which is how the Play build gets P2P without
/// containing any torrent code itself.
class P2pEngineDialog extends StatefulWidget {
  const P2pEngineDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const P2pEngineDialog(),
    );
  }

  @override
  State<P2pEngineDialog> createState() => _P2pEngineDialogState();
}

class _P2pEngineDialogState extends State<P2pEngineDialog> {
  late final TextEditingController _controller;
  bool _isTesting = false;
  String? _status;
  bool _statusOk = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<AppProvider>().p2pEngineUrl,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = context.read<AppProvider>();
    await app.setP2pEngineUrl(_controller.text);
    if (!mounted) return;
    setState(() {
      _statusOk = true;
      _status = app.usesExternalP2pEngine
          ? 'Saved. Magnets will use the external engine.'
          : 'Cleared. Magnets will use the bundled engine when available.';
    });
  }

  Future<void> _test() async {
    setState(() {
      _isTesting = true;
      _status = null;
    });

    // Test exactly what the player would use, so a typo is caught here.
    final app = context.read<AppProvider>();
    final previous = app.p2pEngineUrl;
    await app.setP2pEngineUrl(_controller.text);
    final available = await TorrentService.instance.isAvailable();
    final kind = TorrentService.instance.engineKind;
    await app.setP2pEngineUrl(previous);

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _statusOk = available;
      _status = switch (kind) {
        TorrentEngineKind.external =>
          available
              ? 'External engine answered and is ready.'
              : 'Could not reach that address. Check the engine is running and '
                    'the port is correct.',
        TorrentEngineKind.bundled =>
          'Address cleared; the bundled engine is available.',
        TorrentEngineKind.none =>
          'No engine is reachable. Install or start a torrent engine service, '
              'then enter its address.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final app = context.watch<AppProvider>();

    return TvPopupScope(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
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
                Row(
                  children: [
                    Icon(
                      Icons.hub_rounded,
                      size: 22,
                      color: tokens.primaryAccent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'P2P Engine',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Peer-to-peer playback needs a torrent engine, which cannot be '
                  'installed as a plugin because it is native code. Point Exalere '
                  'at a separate engine service on this device (for example '
                  '127.0.0.1:8090), or leave it empty to use the engine bundled '
                  'into the GitHub build.',
                  style: TextStyle(fontSize: 12.5, color: tokens.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.url,
                  style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '127.0.0.1:8090',
                    hintStyle: TextStyle(color: tokens.textMuted),
                    filled: true,
                    fillColor: tokens.surfaceCard,
                    border: OutlineInputBorder(
                      borderRadius: tokens.borderRadiusSm,
                      borderSide: BorderSide(color: tokens.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: tokens.borderRadiusSm,
                      borderSide: BorderSide(color: tokens.borderSubtle),
                    ),
                  ),
                ),
                if (_status != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _statusOk
                            ? Icons.check_circle_outline_rounded
                            : Icons.error_outline_rounded,
                        size: 16,
                        color: _statusOk
                            ? tokens.liveColor
                            : tokens.secondaryAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _status!,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        app.usesExternalP2pEngine
                            ? 'Current: external engine'
                            : 'Current: bundled engine',
                        style: TextStyle(fontSize: 12, color: tokens.textMuted),
                      ),
                    ),
                    TvFocusable(
                      borderRadius: tokens.borderRadiusSm,
                      onTap: _isTesting ? () {} : _test,
                      child: _button(
                        tokens,
                        label: _isTesting ? 'Testing…' : 'Test',
                        filled: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Exactly one autofocus: the primary, safe action.
                    TvFocusable(
                      autofocus: true,
                      borderRadius: tokens.borderRadiusSm,
                      onTap: _save,
                      child: _button(tokens, label: 'Save', filled: true),
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

  Widget _button(
    AppTokens tokens, {
    required String label,
    required bool filled,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: filled ? tokens.primaryAccent : tokens.surfaceCard,
        borderRadius: tokens.borderRadiusSm,
        border: Border.all(
          color: filled ? tokens.borderFocus : tokens.borderSubtle,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: filled ? tokens.canvasBackground : tokens.textPrimary,
        ),
      ),
    );
  }
}
