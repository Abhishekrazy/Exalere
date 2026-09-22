import 'package:flutter/material.dart';

import '../../../services/moviebox_config_service.dart';
import '../../theme/app_tokens.dart';
import '../app_surface.dart';
import '../tv_focusable.dart';

class UpstreamSyncSection extends StatelessWidget {
  final bool isSyncingUpstream;
  final VoidCallback onSyncUpstream;

  const UpstreamSyncSection({
    super.key,
    required this.isSyncingUpstream,
    required this.onSyncUpstream,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final configService = MovieBoxConfigService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            'UPSTREAM API SYNCHRONIZATION (MovieBox-TUI)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: tokens.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upstream Source Repository',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'github.com/${MovieBoxConfigService.upstreamRepo}',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  TvFocusable(
                    onTap: isSyncingUpstream ? null : onSyncUpstream,
                    borderRadius: tokens.borderRadiusSm,
                    scaleFactor: 1.05,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.primaryAccent,
                        borderRadius: tokens.borderRadiusSm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSyncingUpstream)
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          else
                            Icon(
                              Icons.sync_rounded,
                              size: 16,
                              color: theme.colorScheme.onPrimary,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            isSyncingUpstream ? 'Syncing...' : 'Sync Now',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: tokens.borderRadiusSm,
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.dns_rounded,
                          size: 16,
                          color: tokens.liveColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Active Host Pool: ${configService.hostPool.length} endpoints available',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hosts: ${configService.hostPool.map((h) => h.replaceFirst("https://", "")).join(", ")}',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.vpn_key_rounded,
                          size: 16,
                          color: tokens.vipColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'HMAC Secret: ${configService.secretKey.substring(0, 6)}...${configService.secretKey.substring(configService.secretKey.length - 4)}',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 16,
                          color: tokens.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          configService.lastSyncTimestamp > 0
                              ? 'Last synced: ${DateTime.fromMillisecondsSinceEpoch(configService.lastSyncTimestamp).toLocal().toString().split(".")[0]}'
                              : 'Status: Using built-in resilient host configuration',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
