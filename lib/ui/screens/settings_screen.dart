import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/app_provider.dart';
import '../../services/storage_service.dart';
import '../../services/external_player_service.dart';
import '../../services/moviebox_config_service.dart';
import '../theme/app_themes.dart';
import '../widgets/app_button.dart';
import '../widgets/app_surface.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/update_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storageService = StorageService();
  final TextEditingController _iptvController = TextEditingController();
  List<String> _detectedPlayers = [];
  bool _isSyncingUpstream = false;

  @override
  void initState() {
    super.initState();
    _loadIptvUrl();
    _detectPlayers();
  }

  Future<void> _detectPlayers() async {
    final players = await ExternalPlayerService().detectPlayers();
    if (mounted) {
      setState(() => _detectedPlayers = players);
    }
  }

  Future<void> _loadIptvUrl() async {
    final url = await _storageService.getCustomIptvUrl();
    if (url != null) {
      _iptvController.text = url;
    }
  }

  Future<void> _syncUpstream() async {
    setState(() => _isSyncingUpstream = true);
    final success = await MovieBoxConfigService().syncFromUpstream(force: true);
    if (mounted) {
      setState(() => _isSyncingUpstream = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Successfully synced ${MovieBoxConfigService().hostPool.length} hosts from MovieBox-TUI!'
                : 'Could not reach GitHub upstream. Using cached endpoints.',
          ),
          backgroundColor: success
              ? context.tokens.liveColor
              : context.tokens.errorColor,
        ),
      );
    }
  }

  @override
  void dispose() {
    _iptvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          // 1. Appearance / Theme
          _buildSectionTitle('APPEARANCE & THEMES'),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select App Theme (MovieBox-TUI presets)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(AppThemes.allThemes.length, (idx) {
                    final t = AppThemes.allThemes[idx];
                    final isSel = app.currentThemeIndex == idx;
                    return InkWell(
                      onTap: () => app.setThemeIndex(idx),
                      borderRadius: context.tokens.borderRadiusSm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: t.cardColor,
                          borderRadius: context.tokens.borderRadiusSm,
                          border: Border.all(
                            color: isSel
                                ? t.primaryColor
                                : context.tokens.borderSubtle,
                            width: isSel ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: t.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              t.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSel
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: context.tokens.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Corner Geometry Section
                Text(
                  'Corner Geometry Style',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Globally controls card, surface, and button corners across the application',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildCornerOption(
                      context,
                      label: 'Rounded',
                      icon: Icons.rounded_corner_rounded,
                      style: CornerStyle.rounded,
                      isSelected: app.cornerStyle == CornerStyle.rounded,
                      onTap: () => app.setCornerStyle(CornerStyle.rounded),
                    ),
                    const SizedBox(width: 8),
                    _buildCornerOption(
                      context,
                      label: 'Sharp (90°)',
                      icon: Icons.square_outlined,
                      style: CornerStyle.sharp,
                      isSelected: app.cornerStyle == CornerStyle.sharp,
                      onTap: () => app.setCornerStyle(CornerStyle.sharp),
                    ),
                    const SizedBox(width: 8),
                    _buildCornerOption(
                      context,
                      label: 'Cut (Bevel)',
                      icon: Icons.hexagon_outlined,
                      style: CornerStyle.cut,
                      isSelected: app.cornerStyle == CornerStyle.cut,
                      onTap: () => app.setCornerStyle(CornerStyle.cut),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Surface Morphism Effect Section
                Text(
                  'Card Surface Morphism Effect',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dynamic aesthetic effect applied to cards, modals, and interactive surfaces',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMorphismOption(
                      context,
                      label: 'Classic Flat',
                      icon: Icons.layers_outlined,
                      morphism: SurfaceMorphism.standard,
                      isSelected:
                          app.surfaceMorphism == SurfaceMorphism.standard,
                      onTap: () =>
                          app.setSurfaceMorphism(SurfaceMorphism.standard),
                    ),
                    _buildMorphismOption(
                      context,
                      label: 'Apple Glass',
                      icon: Icons.blur_on_rounded,
                      morphism: SurfaceMorphism.glass,
                      isSelected: app.surfaceMorphism == SurfaceMorphism.glass,
                      onTap: () =>
                          app.setSurfaceMorphism(SurfaceMorphism.glass),
                    ),
                    _buildMorphismOption(
                      context,
                      label: 'Neomorphic',
                      icon: Icons.contrast_rounded,
                      morphism: SurfaceMorphism.neomorphic,
                      isSelected:
                          app.surfaceMorphism == SurfaceMorphism.neomorphic,
                      onTap: () =>
                          app.setSurfaceMorphism(SurfaceMorphism.neomorphic),
                    ),
                    _buildMorphismOption(
                      context,
                      label: '3D Clay',
                      icon: Icons.bubble_chart_rounded,
                      morphism: SurfaceMorphism.clay,
                      isSelected: app.surfaceMorphism == SurfaceMorphism.clay,
                      onTap: () => app.setSurfaceMorphism(SurfaceMorphism.clay),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                // Live Interactive Morphism & Corner Preview
                AppSurface(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: context.tokens.primaryAccent,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Live Component Preview',
                              style: TextStyle(
                                color: context.tokens.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${app.surfaceMorphism.name.toUpperCase()} Surface • ${app.cornerStyle.name.toUpperCase()} Corners',
                              style: TextStyle(
                                color: context.tokens.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppButton.primary(
                        label: 'Action',
                        size: AppButtonSize.sm,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // TV Mode & UI Scale Settings
          _buildSectionTitle('TV & LEANBACK INTERFACE'),
          AppCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: Text(
                    'Android TV Mode',
                    style: TextStyle(
                      color: context.tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Optimizes the interface for 10-foot viewing, D-pad remote navigation, direct playback, and TV player controls',
                    style: TextStyle(
                      color: context.tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  secondary: Icon(
                    Icons.tv_rounded,
                    color: app.isTvMode
                        ? theme.colorScheme.primary
                        : context.tokens.textSecondary,
                  ),
                  activeThumbColor: theme.colorScheme.primary,
                  value: app.isTvMode,
                  onChanged: (val) => app.setTvMode(val),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.aspect_ratio_rounded,
                            color: context.tokens.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'UI Scale Density',
                                style: TextStyle(
                                  color: context.tokens.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Scales grid density, card sizes, and text layouts',
                                style: TextStyle(
                                  color: context.tokens.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildScaleChip(
                            context,
                            label: 'Compact (85%)',
                            scale: 0.85,
                            currentScale: app.uiScale,
                            onSelect: () => app.setUiScale(0.85),
                          ),
                          _buildScaleChip(
                            context,
                            label: 'Standard (100%)',
                            scale: 1.0,
                            currentScale: app.uiScale,
                            onSelect: () => app.setUiScale(1.0),
                          ),
                          _buildScaleChip(
                            context,
                            label: 'Comfortable (115%)',
                            scale: 1.15,
                            currentScale: app.uiScale,
                            onSelect: () => app.setUiScale(1.15),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Content & Parental Controls
          _buildSectionTitle('CONTENT & PARENTAL CONTROLS'),
          AppCard(
            padding: const EdgeInsets.all(8),
            child: SwitchListTile(
              secondary: Icon(
                Icons.shield_outlined,
                color: context.tokens.primaryAccent,
              ),
              title: Text(
                'Filter Adult / 18+ Content',
                style: TextStyle(
                  color: context.tokens.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Hide explicit, ecchi, and age-restricted titles from search results and feeds',
                style: TextStyle(
                  color: context.tokens.textSecondary,
                  fontSize: 12,
                ),
              ),
              activeThumbColor: theme.colorScheme.primary,
              value: app.filterAdultContent,
              onChanged: (val) => app.setFilterAdultContent(val),
            ),
          ),
          const SizedBox(height: 24),

          // 3. Playback Settings
          _buildSectionTitle('PLAYBACK & ENGINE'),
          AppCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'Launch in External Player (VLC / MPV)',
                    style: TextStyle(
                      color: context.tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Forward streaming links directly to your desktop or mobile media player',
                    style: TextStyle(
                      color: context.tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: theme.colorScheme.primary,
                  value: app.useExternalPlayer,
                  onChanged: (val) => app.setUseExternalPlayer(val),
                ),
                if (_detectedPlayers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: context.tokens.liveColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Detected on system: ${_detectedPlayers.join(", ")} (Optimized CLI streaming with headers)',
                            style: TextStyle(
                              color: context.tokens.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: context.tokens.textMuted,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Install MPV or VLC for external playback support',
                            style: TextStyle(
                              color: context.tokens.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Divider(color: context.tokens.borderSubtle, height: 1),
                SwitchListTile(
                  secondary: Icon(
                    Icons.headphones_rounded,
                    color: app.backgroundPlayback
                        ? theme.colorScheme.primary
                        : context.tokens.textSecondary,
                  ),
                  title: Text(
                    'Background Playback (Audio / Video)',
                    style: TextStyle(
                      color: context.tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Continue audio/video playback when minimizing the app or locking the screen',
                    style: TextStyle(
                      color: context.tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: theme.colorScheme.primary,
                  value: app.backgroundPlayback,
                  onChanged: (val) => app.setBackgroundPlayback(val),
                ),
                Divider(color: context.tokens.borderSubtle, height: 1),
                SwitchListTile(
                  secondary: Icon(
                    Icons.picture_in_picture_alt_rounded,
                    color: app.pipEnabled
                        ? theme.colorScheme.primary
                        : context.tokens.textSecondary,
                  ),
                  title: Text(
                    'Popup Screen / Picture-in-Picture (PiP)',
                    style: TextStyle(
                      color: context.tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Enable floating miniature player window when navigating outside the application',
                    style: TextStyle(
                      color: context.tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: theme.colorScheme.primary,
                  value: app.pipEnabled,
                  onChanged: (val) => app.setPipEnabled(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Series & Playback Automation
          _buildSectionTitle('SERIES & PLAYBACK CONTROLS'),
          AppCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'Auto-Skip Intro',
                    style: TextStyle(
                      color: context.tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Automatically jump past TV series opening titles without clicking',
                    style: TextStyle(
                      color: context.tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: theme.colorScheme.primary,
                  value: app.autoSkipIntro,
                  onChanged: (val) => app.setAutoSkipIntro(val),
                ),
                Divider(color: context.tokens.borderSubtle, height: 1),
                SwitchListTile(
                  title: Text(
                    'Auto-Skip Outro / Next Episode',
                    style: TextStyle(
                      color: context.tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Automatically proceed when closing credits begin',
                    style: TextStyle(
                      color: context.tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: theme.colorScheme.primary,
                  value: app.autoSkipOutro,
                  onChanged: (val) => app.setAutoSkipOutro(val),
                ),
                Divider(color: context.tokens.borderSubtle, height: 1),
                SwitchListTile(
                  title: Text(
                    'Enable Smart Skip Markers',
                    style: TextStyle(
                      color: context.tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Detects typical TV intro duration when no exact provider metadata is present',
                    style: TextStyle(
                      color: context.tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: theme.colorScheme.primary,
                  value: app.enableSmartSkip,
                  onChanged: (val) => app.setEnableSmartSkip(val),
                ),
                Divider(color: context.tokens.borderSubtle, height: 1),
                SwitchListTile(
                  title: Text(
                    'Auto-Play Trailers in Details',
                    style: TextStyle(
                      color: context.tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Automatically play official trailers in details screen after 10 seconds. Keep disabled to pause trailers by default.',
                    style: TextStyle(
                      color: context.tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: theme.colorScheme.primary,
                  value: app.autoPlayTrailers,
                  onChanged: (val) => app.setAutoPlayTrailers(val),
                ),
                Divider(color: context.tokens.borderSubtle, height: 1),
                ListTile(
                  leading: Icon(
                    Icons.keyboard_rounded,
                    color: context.tokens.textSecondary,
                  ),
                  title: Text(
                    'Keyboard Shortcuts Cheat Sheet',
                    style: TextStyle(
                      color: context.tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'View desktop player hotkeys (Space, Esc, F, Arrows, C, S, M)',
                    style: TextStyle(
                      color: context.tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: context.tokens.textSecondary,
                  ),
                  onTap: () => _showKeyboardShortcutsDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Live TV IPTV Settings
          _buildSectionTitle('LIVE TV PLAYLIST (M3U)'),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Custom IPTV Playlist URL',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _iptvController,
                  style: TextStyle(color: context.tokens.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'https://example.com/playlist.m3u',
                    hintStyle: TextStyle(color: context.tokens.textMuted),
                    filled: true,
                    fillColor: context.tokens.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: context.tokens.borderRadiusSm,
                      borderSide: BorderSide(
                        color: context.tokens.borderSubtle,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: context.tokens.borderRadiusSm,
                      borderSide: BorderSide(
                        color: context.tokens.borderSubtle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    await _storageService.setCustomIptvUrl(
                      _iptvController.text.trim(),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'IPTV Playlist URL saved successfully!',
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: context.tokens.borderRadiusSm,
                    ),
                  ),
                  child: Text(
                    'Save Playlist',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. Upstream API Synchronization
          _buildSectionTitle('UPSTREAM API SYNCHRONIZATION (MovieBox-TUI)'),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upstream Source Repository',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: context.tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'github.com/${MovieBoxConfigService.upstreamRepo}',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.tokens.textSecondary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isSyncingUpstream ? null : _syncUpstream,
                      icon: _isSyncingUpstream
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : Icon(
                              Icons.sync_rounded,
                              size: 16,
                              color: theme.colorScheme.onPrimary,
                            ),
                      label: Text(
                        _isSyncingUpstream ? 'Syncing...' : 'Sync Now',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: context.tokens.borderRadiusSm,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.tokens.surfaceElevated,
                    borderRadius: context.tokens.borderRadiusSm,
                    border: Border.all(color: context.tokens.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.dns_rounded,
                            size: 16,
                            color: context.tokens.liveColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Active Host Pool: ${MovieBoxConfigService().hostPool.length} endpoints available',
                            style: TextStyle(
                              color: context.tokens.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Hosts: ${MovieBoxConfigService().hostPool.map((h) => h.replaceFirst("https://", "")).join(", ")}',
                        style: TextStyle(
                          color: context.tokens.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.vpn_key_rounded,
                            size: 16,
                            color: context.tokens.vipColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'HMAC Secret: ${MovieBoxConfigService().secretKey.substring(0, 6)}...${MovieBoxConfigService().secretKey.substring(MovieBoxConfigService().secretKey.length - 4)}',
                              style: TextStyle(
                                color: context.tokens.textSecondary,
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
                            color: context.tokens.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            MovieBoxConfigService().lastSyncTimestamp > 0
                                ? 'Last synced: ${DateTime.fromMillisecondsSinceEpoch(MovieBoxConfigService().lastSyncTimestamp).toLocal().toString().split(".")[0]}'
                                : 'Status: Using built-in resilient host configuration',
                            style: TextStyle(
                              color: context.tokens.textMuted,
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
          const SizedBox(height: 24),

          // Updates & Release
          _buildSectionTitle('UPDATES & RELEASE'),
          AppCard(
            padding: const EdgeInsets.all(16),
            border: BorderSide(
              color: app.availableUpdate != null
                  ? context.tokens.primaryAccent.withValues(alpha: 0.5)
                  : context.tokens.borderSubtle,
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
                            ? context.tokens.primaryAccent.withValues(
                                alpha: 0.2,
                              )
                            : context.tokens.surfaceElevated,
                        borderRadius: context.tokens.borderRadiusSm,
                      ),
                      child: Icon(
                        Icons.system_update_rounded,
                        color: app.availableUpdate != null
                            ? context.tokens.primaryAccent
                            : context.tokens.textSecondary,
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
                                  color: context.tokens.textPrimary,
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
                                    color: context.tokens.liveColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: context.tokens.borderRadiusXs,
                                    border: Border.all(
                                      color: context.tokens.liveColor
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    'v${app.availableUpdate!.version} AVAILABLE',
                                    style: TextStyle(
                                      color: context.tokens.liveColor,
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
                              color: context.tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TvFocusable(
                        onTap: app.isCheckingUpdate
                            ? null
                            : () async {
                                final update = await app.checkForUpdates(
                                  manual: true,
                                );
                                if (!context.mounted) return;
                                if (update != null &&
                                    update.isUpdateAvailable) {
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
                        borderRadius: context.tokens.borderRadiusSm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: app.availableUpdate != null
                                ? theme.colorScheme.primary
                                : context.tokens.surfaceElevated,
                            borderRadius: context.tokens.borderRadiusSm,
                            border: Border.all(
                              color: app.availableUpdate != null
                                  ? theme.colorScheme.primary
                                  : context.tokens.borderSubtle,
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
                                        : context.tokens.textPrimary,
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
                                          : context.tokens.textPrimary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      app.availableUpdate != null
                                          ? 'View & Install Update'
                                          : 'Check for Updates',
                                      style: TextStyle(
                                        color: app.availableUpdate != null
                                            ? theme.colorScheme.onPrimary
                                            : context.tokens.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: context.tokens.borderSubtle, height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Auto-Check for Updates',
                    style: TextStyle(
                      color: context.tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    'Automatically checks GitHub for new builds on startup',
                    style: TextStyle(
                      color: context.tokens.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  activeThumbColor: theme.colorScheme.primary,
                  value: app.autoCheckUpdates,
                  onChanged: (val) => app.setAutoCheckUpdates(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 5. About
          _buildSectionTitle('ABOUT'),
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
                    color: context.tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version ${app.currentVersion} • Powered by MovieBox-TUI architecture',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Features multi-source streaming across MovieBox, 4KHDHub, and Live TV, with hardware-accelerated playback, automatic subtitle synchronization, and offline watch history.',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.tokens.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 6. Support & Donate
          _buildSectionTitle('SUPPORT & DONATE'),
          AppCard(
            padding: const EdgeInsets.all(16),
            border: BorderSide(
              color: context.tokens.primaryAccent.withValues(alpha: 0.3),
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
                        color: context.tokens.primaryAccent.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: context.tokens.borderRadiusSm,
                      ),
                      child: Icon(
                        Icons.favorite_rounded,
                        color: context.tokens.primaryAccent,
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
                              color: context.tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Help keep Exalere free, open-source, and maintained',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.tokens.textSecondary,
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
                    final uri = Uri.parse('https://razorpay.me/@abhishekrazy');
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  borderRadius: context.tokens.borderRadiusSm,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.tokens.primaryAccent,
                          context.tokens.surfaceElevated,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: context.tokens.borderRadiusSm,
                      boxShadow: [
                        BoxShadow(
                          color: context.tokens.primaryAccent.withValues(
                            alpha: 0.3,
                          ),
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
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: context.tokens.textSecondary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  void _showKeyboardShortcutsDialog(BuildContext context) {
    const shortcuts = [
      ('Space / K', 'Play or Pause playback'),
      ('Esc', 'Exit Fullscreen or Return to Previous Screen'),
      ('Double-Click / F', 'Toggle Fullscreen mode'),
      ('Left Arrow / J', 'Seek backward 10 seconds'),
      ('Right Arrow / L', 'Seek forward 10 seconds'),
      ('Up Arrow', 'Increase volume by 5%'),
      ('Down Arrow', 'Decrease volume by 5%'),
      ('M', 'Mute or Unmute audio'),
      ('C', 'Toggle Subtitles On / Off'),
      ('S', 'Skip Intro / Outro marker (when available)'),
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.tokens.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: context.tokens.borderRadiusLg,
          side: BorderSide(color: context.tokens.borderSubtle),
        ),
        title: Row(
          children: [
            Icon(
              Icons.keyboard_rounded,
              color: context.tokens.textPrimary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              'Desktop Keyboard Shortcuts',
              style: TextStyle(
                color: context.tokens.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: shortcuts.map((s) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.tokens.surfaceElevated,
                        borderRadius: context.tokens.borderRadiusSm,
                        border: Border.all(
                          color: context.tokens.borderSubtle,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        s.$1,
                        style: TextStyle(
                          color: context.tokens.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        s.$2,
                        style: TextStyle(
                          color: context.tokens.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Close',
              style: TextStyle(color: context.tokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScaleChip(
    BuildContext context, {
    required String label,
    required double scale,
    required double currentScale,
    required VoidCallback onSelect,
  }) {
    final isSelected = (currentScale - scale).abs() < 0.05;
    return TvFocusable(
      onTap: onSelect,
      borderRadius: context.tokens.borderRadiusSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? context.tokens.primaryAccent.withValues(alpha: 0.25)
              : context.tokens.surfaceElevated,
          borderRadius: context.tokens.borderRadiusSm,
          border: Border.all(
            color: isSelected
                ? context.tokens.primaryAccent
                : context.tokens.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? context.tokens.primaryAccent
                : context.tokens.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildCornerOption(
    BuildContext context, {
    required String label,
    required IconData icon,
    required CornerStyle style,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final tokens = context.tokens;
    final borderSide = BorderSide(
      color: isSelected ? tokens.primaryAccent : tokens.borderSubtle,
      width: isSelected ? 1.5 : 1.0,
    );

    return Expanded(
      child: TvFocusable(
        onTap: onTap,
        borderRadius: style == CornerStyle.sharp
            ? BorderRadius.zero
            : BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: ShapeDecoration(
            color: isSelected
                ? tokens.primaryAccent.withValues(alpha: 0.2)
                : tokens.surfaceElevated,
            shape: style == CornerStyle.sharp
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                    side: borderSide,
                  )
                : (style == CornerStyle.cut
                      ? BeveledRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: borderSide,
                        )
                      : RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: borderSide,
                        )),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? tokens.primaryAccent : tokens.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? tokens.primaryAccent : tokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMorphismOption(
    BuildContext context, {
    required String label,
    required IconData icon,
    required SurfaceMorphism morphism,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final tokens = context.tokens;
    final borderSide = BorderSide(
      color: isSelected ? tokens.primaryAccent : tokens.borderSubtle,
      width: isSelected ? 1.5 : 1.0,
    );
    return TvFocusable(
      onTap: onTap,
      borderRadius: tokens.borderRadiusSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: tokens.getShapeDecoration(
          color: isSelected
              ? tokens.primaryAccent.withValues(alpha: 0.2)
              : tokens.surfaceElevated,
          side: borderSide,
          radius: tokens.borderRadiusSm.topLeft.x,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? tokens.primaryAccent : tokens.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? tokens.primaryAccent : tokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
