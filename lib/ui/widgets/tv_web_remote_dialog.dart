import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/web_remote_service.dart';
import '../theme/app_tokens.dart';
import 'tv_focusable.dart';

/// Modal dialog showing the Web Companion TV Remote connection link,
/// QR-friendly instructions, and live status.
class TvWebRemoteDialog extends StatefulWidget {
  const TvWebRemoteDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const TvWebRemoteDialog(),
    );
  }

  @override
  State<TvWebRemoteDialog> createState() => _TvWebRemoteDialogState();
}

class _TvWebRemoteDialogState extends State<TvWebRemoteDialog> {
  final WebRemoteService _remoteService = WebRemoteService();
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _remoteService.addListener(_onServiceUpdate);
    if (!_remoteService.isRunning) {
      _remoteService.startServer();
    }
  }

  @override
  void dispose() {
    _remoteService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _copyUrl() async {
    final url = _remoteService.remoteUrl;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      setState(() => _copied = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copied = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final isRunning = _remoteService.isRunning;
    final url = _remoteService.remoteUrl;

    return Dialog(
      backgroundColor: tokens.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.cardRadius * 1.5),
        side: BorderSide(color: tokens.borderSubtle, width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: tokens.borderRadiusMd,
                    ),
                    child: Icon(
                      Icons.phonelink_ring_rounded,
                      color: theme.colorScheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Web Companion TV Remote',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Control your TV directly from your smartphone browser',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Server URL Box
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: tokens.borderRadiusMd,
                  border: Border.all(
                    color: isRunning
                        ? theme.colorScheme.primary.withValues(alpha: 0.3)
                        : tokens.borderSubtle,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isRunning
                                ? theme.colorScheme.primary
                                : tokens.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isRunning ? 'Server Active' : 'Server Stopped',
                          style: TextStyle(
                            color: isRunning
                                ? theme.colorScheme.primary
                                : tokens.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (isRunning)
                          Text(
                            'Port ${_remoteService.port}',
                            style: TextStyle(
                              color: tokens.textMuted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      url,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 19,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Instructions
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated.withValues(alpha: 0.5),
                  borderRadius: tokens.borderRadiusSm,
                ),
                child: Column(
                  children: [
                    _buildStep(
                      context,
                      '1',
                      'Connect your phone to the same Wi-Fi network.',
                    ),
                    const SizedBox(height: 8),
                    _buildStep(
                      context,
                      '2',
                      'Open Chrome or Safari on your phone and visit the link above.',
                    ),
                    const SizedBox(height: 8),
                    _buildStep(
                      context,
                      '3',
                      'Use touch D-Pad, media buttons, or type on your phone to search on TV!',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TvFocusable(
                    scaleFactor: 1.05,
                    shape: tokens.shapeSm,
                    onTap: () => _remoteService.toggleServer(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceElevated,
                        borderRadius: tokens.borderRadiusSm,
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Text(
                        isRunning ? 'Stop Server' : 'Start Server',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TvFocusable(
                    scaleFactor: 1.05,
                    shape: tokens.shapeSm,
                    onTap: _copyUrl,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceElevated,
                        borderRadius: tokens.borderRadiusSm,
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Text(
                        _copied ? 'Copied!' : 'Copy Link',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TvFocusable(
                    autofocus: true,
                    scaleFactor: 1.05,
                    shape: tokens.shapeSm,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: tokens.borderRadiusSm,
                      ),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, String number, String text) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
