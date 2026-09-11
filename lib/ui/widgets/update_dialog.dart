import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/update_service.dart';
import '../theme/app_tokens.dart';
import 'app_button.dart';
import 'app_surface.dart';

/// Modal dialog presented when a newer release of Exalere is available on GitHub.
class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;
  final String currentVersion;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.currentVersion,
  });

  static Future<void> show(
    BuildContext context, {
    required UpdateInfo updateInfo,
    required String currentVersion,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) =>
          UpdateDialog(updateInfo: updateInfo, currentVersion: currentVersion),
    );
  }

  Future<void> _launchUrl(BuildContext context, String urlStr) async {
    final uri = Uri.tryParse(urlStr);
    if (uri != null) {
      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open download link: $urlStr'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width * 0.85).clamp(320.0, 560.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: AppSurface(
          width: dialogWidth,
          color: context.tokens.surfaceElevated,
          radius: context.tokens.cardRadius * 1.2,
          border: BorderSide(
            color: context.tokens.primaryAccent.withValues(alpha: 0.4),
            width: 1.2,
          ),
          shadows: [
            BoxShadow(
              color: context.tokens.shadowColor.withValues(alpha: 0.6),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: context.tokens.primaryAccent.withValues(alpha: 0.15),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header with Icon & Version Badges
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.tokens.primaryAccent,
                            context.tokens.secondaryAccent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: context.tokens.borderRadiusMd,
                        boxShadow: [
                          BoxShadow(
                            color: context.tokens.primaryAccent.withValues(
                              alpha: 0.4,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.system_update_rounded,
                        color: theme.colorScheme.onPrimary,
                        size: 26,
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
                                'Update Available!',
                                style: TextStyle(
                                  color: context.tokens.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: context.tokens.liveColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: context.tokens.borderRadiusXs,
                                  border: Border.all(
                                    color: context.tokens.liveColor.withValues(
                                      alpha: 0.4,
                                    ),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  'NEW',
                                  style: TextStyle(
                                    color: context.tokens.liveColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'A new release of Exalere is ready to install.',
                            style: TextStyle(
                              color: context.tokens.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 2. Version Comparison Strip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                color: context.tokens.surfaceCard,
                child: Row(
                  children: [
                    _buildVersionPill(
                      context,
                      label: 'Installed',
                      version: 'v$currentVersion',
                      isCurrent: true,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: context.tokens.textMuted,
                      ),
                    ),
                    _buildVersionPill(
                      context,
                      label: 'Latest',
                      version: 'v${updateInfo.version}',
                      isCurrent: false,
                    ),
                    const Spacer(),
                    if (updateInfo.isDirectApk)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.tokens.surfaceElevated,
                          borderRadius: context.tokens.borderRadiusXs,
                          border: Border.all(
                            color: context.tokens.borderSubtle,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.android_rounded,
                              size: 13,
                              color: context.tokens.vipColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              updateInfo.archLabel.isNotEmpty
                                  ? updateInfo.archLabel
                                  : 'Direct APK',
                              style: TextStyle(
                                color: context.tokens.vipColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 3. Changelog / Release Notes preview
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 14,
                      color: context.tokens.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'RELEASE NOTES',
                      style: TextStyle(
                        color: context.tokens.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    if (updateInfo.publishedAt != null)
                      Text(
                        '${updateInfo.publishedAt!.year}-${updateInfo.publishedAt!.month.toString().padLeft(2, '0')}-${updateInfo.publishedAt!.day.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: context.tokens.textMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.tokens.surfaceCard,
                    borderRadius: context.tokens.borderRadiusSm,
                    border: Border.all(
                      color: context.tokens.borderSubtle,
                      width: 0.8,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      updateInfo.releaseNotes.isNotEmpty
                          ? updateInfo.releaseNotes
                          : 'No detailed release notes provided for this release.',
                      style: TextStyle(
                        color: context.tokens.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),

              // 4. Action Buttons (Universal AppButton with TV Focus)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                child: Row(
                  children: [
                    // View on GitHub button
                    Expanded(
                      flex: 4,
                      child: AppButton.secondary(
                        label: 'GitHub',
                        icon: const Icon(Icons.open_in_new_rounded),
                        size: AppButtonSize.sm,
                        onTap: () => _launchUrl(context, updateInfo.htmlUrl),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Remind Later button
                    Expanded(
                      flex: 3,
                      child: AppButton(
                        label: 'Later',
                        variant: AppButtonVariant.ghost,
                        size: AppButtonSize.sm,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Update Now (Direct Download) button
                    Expanded(
                      flex: 6,
                      child: AppButton.primary(
                        label: 'Update Now',
                        icon: const Icon(Icons.download_rounded),
                        size: AppButtonSize.sm,
                        autofocus: true,
                        onTap: () {
                          Navigator.of(context).pop();
                          _launchUrl(
                            context,
                            updateInfo.downloadUrl ?? updateInfo.htmlUrl,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionPill(
    BuildContext context, {
    required String label,
    required String version,
    required bool isCurrent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.tokens.surfaceCard,
        borderRadius: context.tokens.borderRadiusSm,
        border: Border.all(
          color: isCurrent
              ? context.tokens.borderSubtle
              : context.tokens.primaryAccent.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: context.tokens.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            version,
            style: TextStyle(
              color: isCurrent
                  ? context.tokens.textSecondary
                  : context.tokens.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
