import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/app_provider.dart';
import '../../theme/app_tokens.dart';
import '../app_surface.dart';
import '../tv/tv_donate_dialog.dart';
import '../tv_focusable.dart';
import '../update_dialog.dart';
import 'tv_setting_tile.dart';

class UpdatesAndAboutSection extends StatelessWidget {
  const UpdatesAndAboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Updates & Release
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            'UPDATES & RELEASE',
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
          border: BorderSide(
            color: app.availableUpdate != null
                ? tokens.primaryAccent.withValues(alpha: 0.5)
                : tokens.borderSubtle,
            width: app.availableUpdate != null ? 1.4 : 1.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: app.availableUpdate != null
                          ? tokens.primaryAccent.withValues(alpha: 0.2)
                          : tokens.surfaceElevated,
                      borderRadius: tokens.borderRadiusSm,
                    ),
                    child: Icon(
                      Icons.system_update_rounded,
                      color: app.availableUpdate != null
                          ? tokens.primaryAccent
                          : tokens.textSecondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Version ${app.currentVersion}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: tokens.textPrimary,
                              ),
                            ),
                            if (app.availableUpdate != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.liveColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: tokens.borderRadiusXs,
                                  border: Border.all(
                                    color: tokens.liveColor.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'v${app.availableUpdate!.version} AVAILABLE',
                                  style: TextStyle(
                                    color: tokens.liveColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          app.availableUpdate != null
                              ? 'New release available directly from GitHub!'
                              : 'You are currently on the latest release',
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TvFocusable(
                onTap: app.isCheckingUpdate
                    ? null
                    : () async {
                        final update = await app.checkForUpdates(manual: true);
                        if (!context.mounted) return;
                        if (update != null && update.isUpdateAvailable) {
                          UpdateDialog.show(
                            context,
                            updateInfo: update,
                            currentVersion: app.currentVersion,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Exalere is up to date (v${app.currentVersion})',
                              ),
                            ),
                          );
                        }
                      },
                borderRadius: tokens.borderRadiusSm,
                scaleFactor: 1.02,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: app.availableUpdate != null
                        ? theme.colorScheme.primary
                        : tokens.surfaceElevated,
                    borderRadius: tokens.borderRadiusSm,
                    border: Border.all(
                      color: app.availableUpdate != null
                          ? theme.colorScheme.primary
                          : tokens.borderSubtle,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: app.isCheckingUpdate
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: app.availableUpdate != null
                                ? theme.colorScheme.onPrimary
                                : tokens.textPrimary,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              app.availableUpdate != null
                                  ? Icons.download_rounded
                                  : Icons.refresh_rounded,
                              size: 16,
                              color: app.availableUpdate != null
                                  ? theme.colorScheme.onPrimary
                                  : tokens.textPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              app.availableUpdate != null
                                  ? 'View & Install Update'
                                  : 'Check for Updates',
                              style: TextStyle(
                                color: app.availableUpdate != null
                                    ? theme.colorScheme.onPrimary
                                    : tokens.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: tokens.borderSubtle, height: 1),
              const SizedBox(height: 4),
              TvSettingSwitchTile(
                title: 'Auto-Check for Updates',
                subtitle:
                    'Automatically checks GitHub for new builds on startup',
                value: app.autoCheckUpdates,
                onChanged: (val) => app.setAutoCheckUpdates(val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 2. About Exalere
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            'ABOUT',
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
              Text(
                'Exalere',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Version ${app.currentVersion} • Powered by MovieBox-TUI architecture',
                style: TextStyle(fontSize: 12, color: tokens.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Features multi-source streaming across MovieBox, 4KHDHub, and Live TV, with hardware-accelerated playback, automatic subtitle synchronization, and offline watch history.',
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 3. Support & Donate
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            'SUPPORT & DONATE',
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
          border: BorderSide(
            color: tokens.primaryAccent.withValues(alpha: 0.3),
            width: 1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tokens.primaryAccent.withValues(alpha: 0.15),
                      borderRadius: tokens.borderRadiusSm,
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: tokens.primaryAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Support Exalere Development',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Help keep Exalere free, open-source, and maintained',
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TvFocusable(
                onTap: () async {
                  if (app.isTvMode) {
                    TvDonateDialog.show(context);
                    return;
                  }
                  final uri = Uri.parse('https://razorpay.me/@abhishekrazy');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    if (context.mounted) {
                      TvDonateDialog.show(context);
                    }
                  }
                },
                borderRadius: tokens.borderRadiusSm,
                scaleFactor: 1.02,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [tokens.primaryAccent, tokens.surfaceElevated],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: tokens.borderRadiusSm,
                    boxShadow: [
                      BoxShadow(
                        color: tokens.primaryAccent.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.volunteer_activism_rounded,
                          color: theme.colorScheme.onPrimary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Donate via Razorpay (UPI, Cards & NetBanking)',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
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
      ],
    );
  }
}
