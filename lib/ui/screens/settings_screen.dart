import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../services/external_player_service.dart';
import '../../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/settings/appearance_settings_section.dart';
import '../widgets/settings/live_tv_settings_section.dart';
import '../widgets/settings/playback_settings_section.dart';
import '../widgets/settings/plugins_settings_section.dart';
import '../widgets/settings/tv_interface_settings_section.dart';
import '../widgets/settings/tv_settings_view.dart';
import '../widgets/settings/updates_and_about_section.dart';

/// Settings screen for Exalere.
/// Modularized and optimized for touch, mouse, and 10-foot TV D-Pad navigation.
class SettingsScreen extends StatefulWidget {
  final VoidCallback? onExitToSidebar;

  const SettingsScreen({super.key, this.onExitToSidebar});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storageService = StorageService();
  final TextEditingController _iptvController = TextEditingController();
  List<String> _detectedPlayers = [];

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

  @override
  void dispose() {
    _iptvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTv = context.select<AppProvider, bool>((p) => p.isTvMode);
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 800 || isTv;

    if (isTv) {
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
          iptvController: _iptvController,
          storageService: _storageService,
          onExitToSidebar: widget.onExitToSidebar,
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
        left: !isDesktop && !isTv,
        right: !isDesktop && !isTv,
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

            // 5. Add-ons
            const PluginsSettingsSection(),
            const SizedBox(height: 24),

            // 6. Updates, About & Support
            const UpdatesAndAboutSection(),
          ],
        ),
      ),
    );
  }
}
