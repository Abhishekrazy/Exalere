import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/app_installer_service.dart';
import '../../services/update_service.dart';
import '../theme/app_tokens.dart';
import 'app_button.dart';
import 'app_surface.dart';

enum _UpdateStage {
  idle,
  downloading,
  permissionRequired,
  readyToInstall,
  error,
}

/// Modal dialog presented when a newer release of Exalere is available on GitHub.
///
/// Supports direct in-app download with live progress and automatic native package
/// installation on Android (via FileProvider and REQUEST_INSTALL_PACKAGES) and Windows Desktop.
class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final String currentVersion;
  final AppInstallerService? installerService;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.currentVersion,
    this.installerService,
  });

  static Future<void> show(
    BuildContext context, {
    required UpdateInfo updateInfo,
    required String currentVersion,
    AppInstallerService? installerService,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => UpdateDialog(
        updateInfo: updateInfo,
        currentVersion: currentVersion,
        installerService: installerService,
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog>
    with WidgetsBindingObserver {
  late final AppInstallerService _installerService;
  _UpdateStage _stage = _UpdateStage.idle;
  DownloadProgress? _downloadProgress;
  DownloadCancelToken? _cancelToken;
  File? _downloadedFile;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _installerService = widget.installerService ?? AppInstallerService();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelToken?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _stage == _UpdateStage.permissionRequired) {
      _checkPermissionAfterResume();
    }
  }

  Future<void> _checkPermissionAfterResume() async {
    final canInstall = await _installerService.canRequestPackageInstalls();
    if (canInstall && mounted) {
      setState(() {
        _stage = _UpdateStage.readyToInstall;
      });
      _triggerInstall();
    }
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

  bool get _canSelfUpdate {
    if (!_installerService.isSupported) return false;
    final downloadUrl = widget.updateInfo.downloadUrl;
    if (downloadUrl == null || downloadUrl.isEmpty) return false;
    return widget.updateInfo.isDirectApk ||
        (widget.updateInfo.assetName?.toLowerCase().endsWith('.exe') ?? false);
  }

  Future<void> _startDownload() async {
    final downloadUrl = widget.updateInfo.downloadUrl;
    if (downloadUrl == null || downloadUrl.isEmpty) {
      _launchUrl(context, widget.updateInfo.htmlUrl);
      return;
    }

    final fileName =
        widget.updateInfo.assetName ??
        (widget.updateInfo.isDirectApk
            ? 'exalere-update.apk'
            : 'exalere-update.exe');

    final cancelToken = DownloadCancelToken();
    setState(() {
      _stage = _UpdateStage.downloading;
      _downloadProgress = null;
      _cancelToken = cancelToken;
      _errorMessage = null;
    });

    try {
      final file = await _installerService.downloadUpdate(
        url: downloadUrl,
        fileName: fileName,
        onProgress: (progress) {
          if (mounted && !cancelToken.isCancelled) {
            setState(() {
              _downloadProgress = progress;
            });
          }
        },
        cancelToken: cancelToken,
      );

      if (!mounted) return;

      _downloadedFile = file;

      // Check Android install permission if running on Android
      final canInstall = await _installerService.canRequestPackageInstalls();
      if (!canInstall && mounted) {
        setState(() {
          _stage = _UpdateStage.permissionRequired;
        });
      } else if (mounted) {
        setState(() {
          _stage = _UpdateStage.readyToInstall;
        });
        _triggerInstall();
      }
    } catch (e) {
      if (cancelToken.isCancelled) {
        if (mounted) {
          setState(() {
            _stage = _UpdateStage.idle;
            _downloadProgress = null;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _stage = _UpdateStage.error;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _cancelDownload() {
    _cancelToken?.cancel();
    setState(() {
      _stage = _UpdateStage.idle;
      _downloadProgress = null;
    });
  }

  Future<void> _triggerInstall() async {
    final file = _downloadedFile;
    if (file == null || !await file.exists()) {
      setState(() {
        _stage = _UpdateStage.error;
        _errorMessage = 'Downloaded update file was not found.';
      });
      return;
    }

    final success = await _installerService.installPackage(file.path);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not automatically start the installer.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _openPermissionSettings() async {
    await _installerService.openInstallPermissionSettings();
  }

  @override
  Widget build(BuildContext context) {
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
              _buildHeader(context),
              const Divider(height: 1),
              _buildVersionStrip(context),
              const Divider(height: 1),
              _buildContentBody(context),
              const SizedBox(height: 12),
              const Divider(height: 1),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isNewReady = _stage == _UpdateStage.readyToInstall;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isNewReady
                    ? [context.tokens.liveColor, context.tokens.primaryAccent]
                    : [
                        context.tokens.primaryAccent,
                        context.tokens.secondaryAccent,
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: context.tokens.borderRadiusMd,
              boxShadow: [
                BoxShadow(
                  color:
                      (isNewReady
                              ? context.tokens.liveColor
                              : context.tokens.primaryAccent)
                          .withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              isNewReady
                  ? Icons.check_circle_outline_rounded
                  : Icons.system_update_rounded,
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
                      _getHeaderTitle(),
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
                        color: context.tokens.liveColor.withValues(alpha: 0.15),
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
                  _getHeaderSubtitle(),
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
    );
  }

  String _getHeaderTitle() {
    switch (_stage) {
      case _UpdateStage.idle:
        return 'Update Available!';
      case _UpdateStage.downloading:
        return 'Downloading Update';
      case _UpdateStage.permissionRequired:
        return 'Permission Required';
      case _UpdateStage.readyToInstall:
        return 'Ready to Install';
      case _UpdateStage.error:
        return 'Download Failed';
    }
  }

  String _getHeaderSubtitle() {
    switch (_stage) {
      case _UpdateStage.idle:
        return 'A new release of Exalere is ready to install.';
      case _UpdateStage.downloading:
        return 'Downloading package in-app...';
      case _UpdateStage.permissionRequired:
        return 'Install unknown apps permission is required.';
      case _UpdateStage.readyToInstall:
        return 'Update package downloaded and verified.';
      case _UpdateStage.error:
        return 'An error occurred during update download.';
    }
  }

  Widget _buildVersionStrip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: context.tokens.surfaceCard,
      child: Row(
        children: [
          _buildVersionPill(
            context,
            label: 'Installed',
            version: 'v${widget.currentVersion}',
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
            version: 'v${widget.updateInfo.version}',
            isCurrent: false,
          ),
          const Spacer(),
          if (widget.updateInfo.isDirectApk)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    widget.updateInfo.archLabel.isNotEmpty
                        ? widget.updateInfo.archLabel
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
    );
  }

  Widget _buildContentBody(BuildContext context) {
    switch (_stage) {
      case _UpdateStage.downloading:
        return _buildDownloadingBody(context);
      case _UpdateStage.permissionRequired:
        return _buildPermissionBody(context);
      case _UpdateStage.readyToInstall:
        return _buildReadyToInstallBody(context);
      case _UpdateStage.error:
        return _buildErrorBody(context);
      case _UpdateStage.idle:
        return _buildReleaseNotesBody(context);
    }
  }

  Widget _buildDownloadingBody(BuildContext context) {
    final progress = _downloadProgress;
    final fraction = progress?.progress ?? 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DOWNLOADING ASSET',
                style: TextStyle(
                  color: context.tokens.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                progress?.formattedProgress ?? '0%',
                style: TextStyle(
                  color: context.tokens.primaryAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: context.tokens.borderRadiusPill,
            child: LinearProgressIndicator(
              value: fraction > 0 ? fraction : null,
              minHeight: 8,
              backgroundColor: context.tokens.surfaceCard,
              valueColor: AlwaysStoppedAnimation<Color>(
                context.tokens.primaryAccent,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.updateInfo.assetName ?? 'Exalere update package',
                style: TextStyle(
                  color: context.tokens.textSecondary,
                  fontSize: 11,
                ),
              ),
              Text(
                progress?.formattedSize ?? 'Preparing...',
                style: TextStyle(
                  color: context.tokens.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.tokens.surfaceCard,
          borderRadius: context.tokens.borderRadiusSm,
          border: Border.all(
            color: context.tokens.vipColor.withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.security_rounded,
                  color: context.tokens.vipColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Installation Permission Required',
                  style: TextStyle(
                    color: context.tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Android requires permission to install apps from within Exalere. '
              'Tap "Allow Permission" below, enable "Install unknown apps" for Exalere, and return to continue.',
              style: TextStyle(
                color: context.tokens.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyToInstallBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.tokens.surfaceCard,
          borderRadius: context.tokens.borderRadiusSm,
          border: Border.all(
            color: context.tokens.liveColor.withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: context.tokens.liveColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Package Ready',
                  style: TextStyle(
                    color: context.tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'The update has been downloaded successfully. Tap "Install Now" to start the installation.',
              style: TextStyle(
                color: context.tokens.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.tokens.surfaceCard,
          borderRadius: context.tokens.borderRadiusSm,
          border: Border.all(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Error Details',
                  style: TextStyle(
                    color: context.tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unable to download update package.',
              style: TextStyle(
                color: context.tokens.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReleaseNotesBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              if (widget.updateInfo.publishedAt != null)
                Text(
                  '${widget.updateInfo.publishedAt!.year}-${widget.updateInfo.publishedAt!.month.toString().padLeft(2, '0')}-${widget.updateInfo.publishedAt!.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: context.tokens.textMuted,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
                widget.updateInfo.releaseNotes.isNotEmpty
                    ? widget.updateInfo.releaseNotes
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
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    switch (_stage) {
      case _UpdateStage.downloading:
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Cancel',
                  icon: const Icon(Icons.close_rounded),
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  autofocus: true,
                  onTap: _cancelDownload,
                ),
              ),
            ],
          ),
        );

      case _UpdateStage.permissionRequired:
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: AppButton(
                  label: 'Later',
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.sm,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: AppButton.primary(
                  label: 'Allow Permission',
                  icon: const Icon(Icons.settings_suggest_rounded),
                  size: AppButtonSize.sm,
                  autofocus: true,
                  onTap: _openPermissionSettings,
                ),
              ),
            ],
          ),
        );

      case _UpdateStage.readyToInstall:
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: AppButton(
                  label: 'Later',
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.sm,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: AppButton.primary(
                  label: 'Install Now',
                  icon: const Icon(Icons.install_mobile_rounded),
                  size: AppButtonSize.sm,
                  autofocus: true,
                  onTap: _triggerInstall,
                ),
              ),
            ],
          ),
        );

      case _UpdateStage.error:
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: AppButton(
                  label: 'Close',
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.sm,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: AppButton.secondary(
                  label: 'Browser',
                  icon: const Icon(Icons.open_in_new_rounded),
                  size: AppButtonSize.sm,
                  onTap: () => _launchUrl(
                    context,
                    widget.updateInfo.downloadUrl ?? widget.updateInfo.htmlUrl,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: AppButton.primary(
                  label: 'Retry',
                  icon: const Icon(Icons.refresh_rounded),
                  size: AppButtonSize.sm,
                  autofocus: true,
                  onTap: _startDownload,
                ),
              ),
            ],
          ),
        );

      case _UpdateStage.idle:
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: AppButton.secondary(
                  label: 'GitHub',
                  icon: const Icon(Icons.open_in_new_rounded),
                  size: AppButtonSize.sm,
                  onTap: () => _launchUrl(context, widget.updateInfo.htmlUrl),
                ),
              ),
              const SizedBox(width: 8),
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
              Expanded(
                flex: 6,
                child: AppButton.primary(
                  label: _canSelfUpdate ? 'Update Now' : 'Download',
                  icon: Icon(
                    _canSelfUpdate
                        ? Icons.download_rounded
                        : Icons.open_in_browser_rounded,
                  ),
                  size: AppButtonSize.sm,
                  autofocus: true,
                  onTap: () {
                    if (_canSelfUpdate) {
                      _startDownload();
                    } else {
                      Navigator.of(context).pop();
                      _launchUrl(
                        context,
                        widget.updateInfo.downloadUrl ??
                            widget.updateInfo.htmlUrl,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
    }
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
