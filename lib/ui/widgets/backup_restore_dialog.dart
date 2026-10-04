import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/backup_restore_service.dart';
import '../theme/app_tokens.dart';
import 'tv_focusable.dart';

/// Modal dialog for exporting and importing complete Exalere data backups.
class BackupRestoreDialog extends StatefulWidget {
  const BackupRestoreDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: context.tokens.shadowColor.withValues(alpha: 0.85),
      builder: (ctx) => const BackupRestoreDialog(),
    );
  }

  @override
  State<BackupRestoreDialog> createState() => _BackupRestoreDialogState();
}

class _BackupRestoreDialogState extends State<BackupRestoreDialog>
    with SingleTickerProviderStateMixin {
  final BackupRestoreService _backupService = BackupRestoreService();
  late TabController _tabController;

  bool _isLoading = false;
  String? _statusMessage;
  bool _statusIsSuccess = true;

  List<BackupFileInfo> _localBackups = [];
  bool _mergeWithExisting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLocalBackups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalBackups() async {
    final backups = await _backupService.listLocalBackups();
    if (mounted) {
      setState(() {
        _localBackups = backups;
      });
    }
  }

  Future<void> _handleExportToFile() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final path = await _backupService.exportBackupToFile();
      await _loadLocalBackups();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusIsSuccess = true;
          _statusMessage = 'Backup saved to:\n$path';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusIsSuccess = false;
          _statusMessage = 'Failed to create backup: $e';
        });
      }
    }
  }

  Future<void> _handleCopyToClipboard() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      await _backupService.copyBackupToClipboard();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusIsSuccess = true;
          _statusMessage = 'Backup JSON copied to clipboard!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusIsSuccess = false;
          _statusMessage = 'Failed to copy backup: $e';
        });
      }
    }
  }

  Future<void> _handleRestoreBundle(Map<String, dynamic> bundle) async {
    final validation = _backupService.validateBackupBundle(bundle);
    if (!validation.isValid) {
      setState(() {
        _statusIsSuccess = false;
        _statusMessage = validation.errorMessage ?? 'Invalid backup file.';
      });
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Confirm Restore',
      message:
          'Restore backup with ${validation.profileCount} profiles and ${validation.totalFavorites} watchlist items?\n\n'
          'Mode: ${_mergeWithExisting ? "Merge with existing data" : "Complete replacement"}',
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final result = await _backupService.restoreBackupBundle(
        bundle,
        mergeWithExisting: _mergeWithExisting,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusIsSuccess = result.success;
          _statusMessage = result.message;
        });

        if (result.success) {
          // Refresh active providers with newly restored data
          final profileProvider = context.read<ProfileProvider>();
          final libraryProvider = context.read<LibraryProvider>();
          final appProvider = context.read<AppProvider>();
          await profileProvider.init();
          await libraryProvider.init();
          await appProvider.init();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusIsSuccess = false;
          _statusMessage = 'Error restoring backup: $e';
        });
      }
    }
  }

  Future<void> _handleRestoreFromClipboard() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    final bundle = await _backupService.readBackupFromClipboard();
    setState(() {
      _isLoading = false;
    });

    if (bundle == null) {
      setState(() {
        _statusIsSuccess = false;
        _statusMessage = 'Clipboard does not contain a valid Exalere backup.';
      });
      return;
    }

    await _handleRestoreBundle(bundle);
  }

  Future<void> _handleRestoreFromFile(BackupFileInfo info) async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    final bundle = await _backupService.readBackupFile(info.filePath);
    setState(() {
      _isLoading = false;
    });

    if (bundle == null) {
      setState(() {
        _statusIsSuccess = false;
        _statusMessage = 'Could not read backup file.';
      });
      return;
    }

    await _handleRestoreBundle(bundle);
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
  }) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return showDialog<bool>(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: tokens.surfaceElevated,
          shape: tokens.shapeMd,
          title: Text(
            title,
            style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(color: tokens.textSecondary, height: 1.4),
          ),
          actions: [
            TvFocusable(
              borderRadius: tokens.borderRadiusSm,
              onTap: () => Navigator.of(ctx).pop(false),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            TvFocusable(
              autofocus: true,
              borderRadius: tokens.borderRadiusSm,
              onTap: () => Navigator.of(ctx).pop(true),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: tokens.borderRadiusSm,
                ),
                child: Text(
                  'Proceed',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final profileProv = context.watch<ProfileProvider>();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 580,
          constraints: const BoxConstraints(maxHeight: 650),
          decoration: tokens.getShapeDecoration(
            color: tokens.canvasBackground.withValues(alpha: 0.94),
            radius: tokens.cardRadius * 1.5,
            side: BorderSide(
              color: tokens.borderSubtle.withValues(alpha: 0.8),
              width: 1.2,
            ),
            shadows: [
              BoxShadow(
                color: tokens.shadowColor.withValues(alpha: 0.65),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: tokens.borderRadiusSm,
                      ),
                      child: Icon(
                        Icons.settings_backup_restore_rounded,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BACKUP & RESTORE',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Migrate profiles, watch history, and library offline',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: tokens.textSecondary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated.withValues(alpha: 0.5),
                  borderRadius: tokens.borderRadiusSm,
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.25),
                    borderRadius: tokens.borderRadiusSm,
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                  ),
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: tokens.textSecondary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.upload_rounded, size: 18),
                      text: 'Create Backup',
                    ),
                    Tab(
                      icon: Icon(Icons.download_rounded, size: 18),
                      text: 'Restore Backup',
                    ),
                  ],
                ),
              ),

              // Status Banner
              if (_statusMessage != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _statusIsSuccess
                        ? theme.colorScheme.primary.withValues(alpha: 0.12)
                        : theme.colorScheme.error.withValues(alpha: 0.12),
                    borderRadius: tokens.borderRadiusSm,
                    border: Border.all(
                      color: _statusIsSuccess
                          ? theme.colorScheme.primary.withValues(alpha: 0.4)
                          : theme.colorScheme.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _statusIsSuccess
                            ? Icons.check_circle_rounded
                            : Icons.error_outline_rounded,
                        color: _statusIsSuccess
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Tab View Content
              Flexible(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Create Backup
                    _buildCreateBackupTab(context, profileProv),

                    // Tab 2: Restore Backup
                    _buildRestoreBackupTab(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateBackupTab(
    BuildContext context,
    ProfileProvider profileProv,
  ) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Data summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceCard.withValues(alpha: 0.5),
              radius: tokens.cardRadius,
              side: BorderSide(color: tokens.borderSubtle, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.folder_shared_rounded,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'BACKUP SUMMARY',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol(
                      context,
                      label: 'PROFILES',
                      val: '${profileProv.profiles.length}',
                    ),
                    Container(width: 1, height: 28, color: tokens.borderSubtle),
                    _buildStatCol(
                      context,
                      label: 'ACTIVE',
                      val: profileProv.activeProfile.name,
                    ),
                    Container(width: 1, height: 28, color: tokens.borderSubtle),
                    _buildStatCol(context, label: 'SETTINGS', val: 'Included'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Export to file button
          TvFocusable(
            autofocus: true,
            scaleFactor: 1.04,
            borderRadius: tokens.borderRadiusSm,
            onTap: _isLoading ? () {} : _handleExportToFile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: tokens.borderRadiusSm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoading) ...[
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ] else ...[
                    Icon(
                      Icons.save_rounded,
                      color: theme.colorScheme.onPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    'Export & Save to File',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Copy JSON to clipboard button
          TvFocusable(
            scaleFactor: 1.04,
            borderRadius: tokens.borderRadiusSm,
            onTap: _isLoading ? () {} : _handleCopyToClipboard,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: tokens.getShapeDecoration(
                color: tokens.surfaceCard.withValues(alpha: 0.6),
                radius: tokens.cardRadius * 0.9,
                side: BorderSide(color: tokens.borderSubtle, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.copy_rounded,
                    color: tokens.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Copy Backup to Clipboard',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreBackupTab(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mode Toggle (Merge vs Replace)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceCard.withValues(alpha: 0.5),
              radius: tokens.cardRadius,
              side: BorderSide(color: tokens.borderSubtle, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.merge_type_rounded,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Merge with existing data',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _mergeWithExisting
                            ? 'Retains existing profiles and merges history'
                            : 'Completely replaces all profiles & data',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _mergeWithExisting,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) {
                    setState(() {
                      _mergeWithExisting = val;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Restore from Clipboard CTA
          TvFocusable(
            scaleFactor: 1.04,
            borderRadius: tokens.borderRadiusSm,
            onTap: _isLoading ? () {} : _handleRestoreFromClipboard,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: tokens.getShapeDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                radius: tokens.cardRadius * 0.9,
                side: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.paste_rounded,
                    color: theme.colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Restore from Clipboard JSON',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Local backups header
          Row(
            children: [
              Text(
                'LOCAL BACKUPS ON DEVICE',
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  color: tokens.textSecondary,
                  size: 18,
                ),
                onPressed: _loadLocalBackups,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Local backups list
          if (_localBackups.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No local backups found in Documents / Downloads folder.',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                ),
              ),
            )
          else
            ..._localBackups.map((b) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TvFocusable(
                  scaleFactor: 1.03,
                  borderRadius: tokens.borderRadiusSm,
                  onTap: () => _handleRestoreFromFile(b),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: tokens.getShapeDecoration(
                      color: tokens.surfaceCard.withValues(alpha: 0.6),
                      radius: tokens.cardRadius * 0.9,
                      side: BorderSide(color: tokens.borderSubtle, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${b.profileCount} profiles • ${b.formattedSize} • ${b.modifiedTime.toLocal().toString().split('.')[0]}',
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: tokens.borderRadiusXs,
                          ),
                          child: Text(
                            'Restore',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStatCol(
    BuildContext context, {
    required String label,
    required String val,
  }) {
    final tokens = context.tokens;
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
