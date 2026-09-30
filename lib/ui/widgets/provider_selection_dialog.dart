import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../providers/plugin_provider.dart';
import '../../services/provider_registry.dart';
import '../theme/app_tokens.dart';
import 'tv/tv_popup_scope.dart';
import 'tv_focusable.dart';

class _ProviderOptionItem {
  final String id;
  final String title;
  final String description;
  final String badge;
  final IconData icon;

  const _ProviderOptionItem({
    required this.id,
    required this.title,
    required this.description,
    required this.badge,
    required this.icon,
  });
}

/// Dialog allowing user to select their active discovery & catalog provider.
/// Defaults to TMDB on first install (100% compliant with Google Play Store policies).
class ProviderSelectionDialog extends StatefulWidget {
  final bool isFromSettings;

  const ProviderSelectionDialog({super.key, this.isFromSettings = false});

  static Future<void> show(
    BuildContext context, {
    bool isFromSettings = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: isFromSettings,
      builder: (ctx) => ProviderSelectionDialog(isFromSettings: isFromSettings),
    );
  }

  @override
  State<ProviderSelectionDialog> createState() =>
      _ProviderSelectionDialogState();
}

class _ProviderSelectionDialogState extends State<ProviderSelectionDialog> {
  late String _selectedProviderId;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    _selectedProviderId = app.selectedCatalogProvider;
  }

  List<_ProviderOptionItem> _buildOptions() {
    final pluginProvider = context.read<PluginProvider?>();
    final installedPlugins = pluginProvider?.plugins ?? [];

    final list = <_ProviderOptionItem>[
      const _ProviderOptionItem(
        id: 'tmdb',
        title: 'TMDB (The Movie Database)',
        description:
            'Comprehensive catalog & official trailers. Clean, safe, and 100% compliant with Google Play.',
        badge: 'Recommended • Official',
        icon: Icons.movie_filter_rounded,
      ),
    ];

    for (final p in installedPlugins) {
      if (!p.isEnabled) continue;
      final engine = ProviderRegistry().getProvider(p.id);
      final supportsFeeds = engine?.supportsCatalogFeeds ?? false;

      list.add(
        _ProviderOptionItem(
          id: p.id,
          title: p.name,
          description: supportsFeeds
              ? 'Real-time catalog feeds and direct playable streams.'
              : 'Direct playable stream resolver for titles.',
          badge: supportsFeeds ? 'Feeds + Streams' : 'Streams Only',
          icon: Icons.extension_rounded,
        ),
      );
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 540 || size.height < 600;
    final options = _buildOptions();

    return TvPopupScope(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: (size.width * 0.85).clamp(340.0, 620.0),
              maxHeight: (size.height * 0.85).clamp(380.0, 680.0),
            ),
            margin: const EdgeInsets.all(20),
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 20 : 28,
              vertical: isCompact ? 18 : 24,
            ),
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
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: tokens.getShapeDecoration(
                        color: tokens.primaryAccent.withValues(alpha: 0.15),
                        radius: 999.0,
                      ),
                      child: Icon(
                        Icons.hub_rounded,
                        color: tokens.primaryAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Content Provider',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: isCompact ? 17 : 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Choose which catalog powers Home, Movies, and Series discovery.',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: isCompact ? 12 : 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.isFromSettings)
                      TvFocusable(
                        borderRadius: tokens.borderRadiusPill,
                        onTap: () => Navigator.of(context).pop(),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            color: tokens.textMuted,
                            size: 22,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: isCompact ? 14 : 18),

                // Options List
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    clipBehavior: Clip.none,
                    cacheExtent: 350.0,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final item = options[idx];
                      final isSelected = item.id == _selectedProviderId;

                      return TvFocusable(
                        scaleFactor: 1.03,
                        shape: tokens.shapeSm,
                        borderRadius: tokens.borderRadiusSm,
                        onTap: () {
                          setState(() {
                            _selectedProviderId = item.id;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 12 : 16,
                            vertical: isCompact ? 10 : 14,
                          ),
                          decoration: tokens.getShapeDecoration(
                            color: isSelected
                                ? tokens.primaryAccent.withValues(alpha: 0.14)
                                : tokens.surfaceCard.withValues(alpha: 0.6),
                            radius: tokens.cardRadius * 0.6,
                            side: BorderSide(
                              color: isSelected
                                  ? tokens.primaryAccent
                                  : tokens.borderSubtle,
                              width: isSelected ? 1.6 : 0.8,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: isSelected
                                    ? tokens.primaryAccent
                                    : tokens.textMuted,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            item.title,
                                            style: TextStyle(
                                              color: tokens.textPrimary,
                                              fontSize: isCompact ? 13.5 : 14.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1.5,
                                          ),
                                          decoration: tokens.getShapeDecoration(
                                            color: isSelected
                                                ? tokens.primaryAccent
                                                      .withValues(alpha: 0.2)
                                                : tokens.surfaceElevated,
                                            radius: 999.0,
                                            side: BorderSide(
                                              color: isSelected
                                                  ? tokens.primaryAccent
                                                  : tokens.borderSubtle,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            item.badge,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? tokens.primaryAccent
                                                  : tokens.textSecondary,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.description,
                                      style: TextStyle(
                                        color: tokens.textSecondary,
                                        fontSize: isCompact ? 11 : 12,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: isCompact ? 14 : 18),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.isFromSettings) ...[
                      TvFocusable(
                        borderRadius: tokens.borderRadiusPill,
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 9,
                          ),
                          decoration: tokens.getShapeDecoration(
                            color: tokens.surfaceCard,
                            radius: 999.0,
                            side: BorderSide(
                              color: tokens.borderSubtle,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    TvFocusable(
                      autofocus: true,
                      borderRadius: tokens.borderRadiusPill,
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        final app = context.read<AppProvider>();
                        await app.setSelectedCatalogProvider(
                          _selectedProviderId,
                        );
                        await app.setHasPromptedProviderSelection(true);
                        if (mounted) {
                          navigator.pop();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        decoration: tokens.getShapeDecoration(
                          color: tokens.primaryAccent,
                          radius: 999.0,
                          shadows: [
                            BoxShadow(
                              color: tokens.primaryAccent.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          'Confirm Selection',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
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
      ),
    );
  }
}
