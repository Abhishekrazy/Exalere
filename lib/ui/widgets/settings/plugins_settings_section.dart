import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/exalere_plugin.dart';
import '../../../providers/plugin_provider.dart';
import '../../theme/app_tokens.dart';

/// Settings section for managing external Exalere stream plugins
/// and 1-click installation from the Community Catalog on Mobile & Desktop platforms.
class PluginsSettingsSection extends StatefulWidget {
  const PluginsSettingsSection({super.key});

  @override
  State<PluginsSettingsSection> createState() => _PluginsSettingsSectionState();
}

class _PluginsSettingsSectionState extends State<PluginsSettingsSection> {
  String? _installingPluginId;

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
                    'Install Add-on',
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
                      'Enter an Add-on or Stremio Addon manifest URL (e.g. stremio://... or https://.../manifest.json)',
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
                        hintText: 'stremio://torrentio.strem.fun/manifest.json',
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

                          final provider = dialogCtx.read<PluginProvider>();
                          final success = await provider.installPlugin(url);

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

  void _confirmDelete(BuildContext context, ExalerePluginConfig plugin) {
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
          'Are you sure you want to uninstall "${plugin.name}"?',
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
              await context.read<PluginProvider>().uninstallPlugin(plugin.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Removed ${plugin.name}'),
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

  Future<void> _installCommunityPlugin(
    BuildContext context,
    CommunityPluginItem item,
  ) async {
    final tokens = context.tokens;
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<PluginProvider>();
    setState(() => _installingPluginId = item.id);

    try {
      final success = await provider.installPlugin(item.manifestUrl);

      if (mounted) {
        setState(() => _installingPluginId = null);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Installed "${item.name}" successfully!'
                  : (provider.errorMessage ?? 'Failed to install ${item.name}'),
            ),
            backgroundColor: success ? tokens.liveColor : tokens.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _installingPluginId = null);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Installation failed: $e'),
            backgroundColor: tokens.errorColor,
          ),
        );
      }
    }
  }

  IconData _getIconForPlugin(String id) {
    if (id.contains('worker')) return Icons.bolt_rounded;
    if (id.contains('torrentio')) return Icons.stream_rounded;
    if (id.contains('superflix')) return Icons.play_circle_filled_rounded;
    if (id.contains('subtitles')) return Icons.subtitles_rounded;
    return Icons.extension_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final pluginProvider = Provider.of<PluginProvider?>(context);
    final plugins = pluginProvider?.plugins ?? [];
    final communityCatalog = pluginProvider?.communityCatalog ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Section Header
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
                  'Add-ons',
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
              label: const Text('Add Add-on by URL'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Exalere functions as an open media catalog. Connect community add-ons or Stremio addons to resolve and play video streams.',
          style: TextStyle(color: tokens.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),

        // 1. Community Add-ons Catalog
        Row(
          children: [
            Icon(
              Icons.explore_outlined,
              color: theme.colorScheme.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Community Add-ons',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: tokens.getShapeDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                radius: tokens.cardRadius * 0.3,
              ),
              child: Text(
                '1-Click Install',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Popular community add-ons compatible with Exalere and Stremio protocols.',
          style: TextStyle(color: tokens.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),

        // Community Catalog Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 650;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 2 : 1,
                mainAxisExtent: 138,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: communityCatalog.length,
              itemBuilder: (context, index) {
                final item = communityCatalog[index];
                final isInstalled =
                    pluginProvider?.isPluginInstalled(
                      item.id,
                      item.manifestUrl,
                    ) ??
                    false;
                final isCurrentInstalling = _installingPluginId == item.id;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: tokens.getShapeDecoration(
                    color: tokens.surfaceCard,
                    radius: tokens.cardRadius * 0.7,
                    side: BorderSide(
                      color: isInstalled
                          ? tokens.liveColor.withValues(alpha: 0.3)
                          : tokens.borderSubtle,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: tokens.getShapeDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              radius: tokens.cardRadius * 0.4,
                            ),
                            child: Icon(
                              _getIconForPlugin(item.id),
                              color: theme.colorScheme.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: tokens.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                                Text(
                                  'by ${item.author}',
                                  style: TextStyle(
                                    color: tokens.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isInstalled)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: tokens.getShapeDecoration(
                                color: tokens.liveColor.withValues(alpha: 0.15),
                                radius: tokens.cardRadius * 0.4,
                                side: BorderSide(
                                  color: tokens.liveColor.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: tokens.liveColor,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Installed',
                                    style: TextStyle(
                                      color: tokens.liveColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: tokens.borderRadiusSm,
                                ),
                              ),
                              onPressed: (_installingPluginId != null)
                                  ? null
                                  : () =>
                                        _installCommunityPlugin(context, item),
                              child: isCurrentInstalling
                                  ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                    )
                                  : const Text(
                                      'Install',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                        ],
                      ),
                      Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: item.tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: tokens.getShapeDecoration(
                              color: tokens.surfaceElevated,
                              radius: tokens.cardRadius * 0.25,
                              side: BorderSide(
                                color: tokens.borderSubtle.withValues(
                                  alpha: 0.5,
                                ),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 26),

        // 2. Installed Plugins Header
        Row(
          children: [
            Icon(
              Icons.extension_rounded,
              color: theme.colorScheme.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Installed Add-ons (${plugins.length})',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (plugins.isEmpty)
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
                  'Install add-ons from the Community Catalog above or tap "Add Add-on by URL" to add a custom source.',
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
            itemCount: plugins.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final plugin = plugins[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: tokens.getShapeDecoration(
                  color: tokens.surfaceCard,
                  radius: tokens.cardRadius * 0.7,
                  side: BorderSide(
                    color: plugin.isEnabled
                        ? tokens.borderSubtle
                        : tokens.borderSubtle.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: tokens.getShapeDecoration(
                        color: plugin.isEnabled
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : tokens.surfaceElevated,
                        radius: tokens.cardRadius * 0.5,
                      ),
                      child: Icon(
                        _getIconForPlugin(plugin.id),
                        color: plugin.isEnabled
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
                                plugin.name,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (plugin.manifest?.version != null) ...[
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
                                    'v${plugin.manifest!.version}',
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
                            plugin.baseUrl,
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
                      value: plugin.isEnabled,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (val) {
                        context.read<PluginProvider>().togglePlugin(
                          plugin.id,
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
                      onPressed: () => _confirmDelete(context, plugin),
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
