import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../services/external_player_service.dart';
import '../../services/moviebox_config_service.dart';
import '../../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/settings/appearance_settings_section.dart';
import '../widgets/settings/live_tv_settings_section.dart';
import '../widgets/settings/playback_settings_section.dart';
import '../widgets/settings/tv_interface_settings_section.dart';
import '../widgets/settings/tv_settings_view.dart';
import '../widgets/settings/updates_and_about_section.dart';
import '../widgets/settings/upstream_sync_section.dart';

/// Settings screen for Exalere.
/// Modularized and optimized for touch, mouse, and 10-foot TV D-Pad navigation.
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
    final isDesktop = MediaQuery.of(context).size.width >= 800 || app.isTvMode;

    if (app.isTvMode) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          toolbarHeight: 52,
          title: const Text(
            'Settings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
        body: TvSettingsView(
          detectedPlayers: _detectedPlayers,
          isSyncingUpstream: _isSyncingUpstream,
          onSyncUpstream: _syncUpstream,
          iptvController: _iptvController,
          storageService: _storageService,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        toolbarHeight: 52,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SafeArea(
        left: !isDesktop && !app.isTvMode,
        right: !isDesktop && !app.isTvMode,
        top: false,
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, isDesktop ? 48 : 110),
          children: [
            // 1. Appearance & Themes (with D-Pad focusable theme cards & styles)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                'APPEARANCE & THEMES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: context.tokens.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const AppearanceSettingsSection(),
            const SizedBox(height: 24),

            // 2. TV & Leanback Interface & Parental Controls
            const TvInterfaceSettingsSection(),
            const SizedBox(height: 24),

            // 3. Playback Engine & Series Controls (filtered for TV mode)
            PlaybackSettingsSection(detectedPlayers: _detectedPlayers),
            const SizedBox(height: 24),

            // 4. Live TV Playlist (M3U)
            LiveTvSettingsSection(
              iptvController: _iptvController,
              storageService: _storageService,
            ),
            const SizedBox(height: 24),

            // 5. Upstream API Synchronization
            UpstreamSyncSection(
              isSyncingUpstream: _isSyncingUpstream,
              onSyncUpstream: _syncUpstream,
            ),
            const SizedBox(height: 24),

            // 6. Updates, About & Support
            const UpdatesAndAboutSection(),
          ],
        ),
      ),
    );
  }
}
