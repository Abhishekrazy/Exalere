import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/stremio_addon.dart';
import '../../../providers/addon_provider.dart';
import '../../theme/app_tokens.dart';

/// Settings section for managing external Stremio-compatible stream add-ons
/// on Mobile and Desktop platforms.
class AddonsSettingsSection extends StatelessWidget {
  const AddonsSettingsSection({super.key});

  void _showInstallDialog(BuildContext context) {
    final controller = TextEditingController();
    final tokens = context.tokens;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isSubmitting = false;
        String? localError;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: tokens.surfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: tokens.borderRadiusLg,
                side: BorderSide(color: tokens.borderSubtle),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Install Stream Add-on',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter any Stremio-compatible Add-on URL (e.g. https://.../manifest.json or stremio://...)',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                      autofocus: true,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        hintText: 'https://my-addon.example.com/manifest.json',
                        hintStyle: TextStyle(color: tokens.textMuted),
                        filled: true,
                        fillColor: tokens.surfaceCard,
                        border: OutlineInputBorder(
                          borderRadius: tokens.borderRadiusSm,
                          borderSide: BorderSide(color: tokens.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: tokens.borderRadiusSm,
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        localError!,
                        style: TextStyle(
                          color: tokens.errorColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogCtx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: tokens.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: tokens.borderRadiusSm,
                    ),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final url = controller.text.trim();
                          if (url.isEmpty) {
                            setDialogState(
                              () => localError = 'Please enter a valid URL.',
                            );
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            localError = null;
                          });

                          final provider = dialogCtx.read<AddonProvider>();
                          final success = await provider.installAddon(url);

                          if (success) {
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Add-on installed successfully!',
                                  ),
                                  backgroundColor: tokens.liveColor,
                                ),
                              );
                            }
                          } else {
                            setDialogState(() {
                              isSubmitting = false;
                              localError =
                                  provider.errorMessage ??
                                  'Failed to connect to add-on.';
                            });
                          }
                        },
                  child: isSubmitting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Text('Install'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, StremioAddonConfig addon) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: tokens.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: tokens.borderRadiusLg,
          side: BorderSide(color: tokens.borderSubtle),
        ),
        title: Text(
          'Remove Add-on?',
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to uninstall "${addon.name}"?',
          style: TextStyle(color: tokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: TextStyle(color: tokens.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.errorColor,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: tokens.borderRadiusSm,
              ),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await context.read<AddonProvider>().uninstallAddon(addon.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Removed ${addon.name}'),
                    backgroundColor: tokens.surfaceElevated,
                  ),
                );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final addonProvider = Provider.of<AddonProvider?>(context);
    final addons = addonProvider?.addons ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.extension_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'Stream Add-ons & Plugins',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: tokens.borderRadiusSm,
                ),
              ),
              onPressed: () => _showInstallDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Plugin'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Install external community Stremio-compatible add-ons to resolve and play video streams.',
          style: TextStyle(color: tokens.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 14),

        if (addons.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceCard.withValues(alpha: 0.5),
              radius: tokens.cardRadius,
              side: BorderSide(color: tokens.borderSubtle),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.extension_off_rounded,
                  color: tokens.textMuted,
                  size: 36,
                ),
                const SizedBox(height: 8),
                Text(
                  'No add-ons installed',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Exalere acts as a personal media manager. Tap "Add Plugin" to add custom streaming sources.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: addons.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final addon = addons[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: tokens.getShapeDecoration(
                  color: tokens.surfaceCard,
                  radius: tokens.cardRadius * 0.7,
                  side: BorderSide(
                    color: addon.isEnabled
                        ? tokens.borderSubtle
                        : tokens.borderSubtle.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: tokens.getShapeDecoration(
                        color: addon.isEnabled
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : tokens.surfaceElevated,
                        radius: tokens.cardRadius * 0.5,
                      ),
                      child: Icon(
                        Icons.extension_rounded,
                        color: addon.isEnabled
                            ? theme.colorScheme.primary
                            : tokens.textMuted,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                addon.name,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (addon.manifest?.version != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: tokens.getShapeDecoration(
                                    color: tokens.surfaceElevated,
                                    radius: tokens.cardRadius * 0.3,
                                  ),
                                  child: Text(
                                    'v${addon.manifest!.version}',
                                    style: TextStyle(
                                      color: tokens.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            addon.baseUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: addon.isEnabled,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (val) {
                        context.read<AddonProvider>().toggleAddon(
                          addon.id,
                          val,
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: tokens.errorColor,
                        size: 20,
                      ),
                      tooltip: 'Remove',
                      onPressed: () => _confirmDelete(context, addon),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
