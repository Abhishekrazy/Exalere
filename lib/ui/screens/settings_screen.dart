import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/storage_service.dart';
import '../../services/external_player_service.dart';
import '../../services/moviebox_config_service.dart';
import '../theme/app_themes.dart';

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
          backgroundColor: success ? const Color(0xFF4CAF50) : Colors.redAccent,
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
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Appearance / Theme
          _buildSectionTitle('APPEARANCE & THEMES'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select App Theme (MovieBox-TUI presets)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
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
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: t.cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel ? t.primaryColor : Colors.white12,
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
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          // TV Mode Settings
          _buildSectionTitle('TV & LEANBACK INTERFACE'),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: const Text(
                'Android TV Mode',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Optimizes the interface for 10-foot viewing, D-pad remote navigation, direct playback, and TV player controls',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              secondary: Icon(Icons.tv_rounded, color: app.isTvMode ? theme.colorScheme.primary : Colors.white54),
              activeThumbColor: theme.colorScheme.primary,
              value: app.isTvMode,
              onChanged: (val) => app.setTvMode(val),
            ),
          ),
          const SizedBox(height: 24),

          // 2. Playback Settings
          _buildSectionTitle('PLAYBACK & ENGINE'),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Launch in External Player (VLC / MPV)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Forward streaming links directly to your desktop or mobile media player',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
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
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Detected on system: ${_detectedPlayers.join(", ")} (Optimized CLI streaming with headers)',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.white38, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Install MPV or VLC for external playback support',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Series & Playback Automation
          _buildSectionTitle('SERIES & PLAYBACK CONTROLS'),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Auto-Skip Intro',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Automatically jump past TV series opening titles without clicking',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  activeThumbColor: theme.colorScheme.primary,
                  value: app.autoSkipIntro,
                  onChanged: (val) => app.setAutoSkipIntro(val),
                ),
                const Divider(color: Colors.white10, height: 1),
                SwitchListTile(
                  title: const Text(
                    'Auto-Skip Outro / Next Episode',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Automatically proceed when closing credits begin',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  activeThumbColor: theme.colorScheme.primary,
                  value: app.autoSkipOutro,
                  onChanged: (val) => app.setAutoSkipOutro(val),
                ),
                const Divider(color: Colors.white10, height: 1),
                SwitchListTile(
                  title: const Text(
                    'Enable Smart Skip Markers',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Detects typical TV intro duration when no exact provider metadata is present',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  activeThumbColor: theme.colorScheme.primary,
                  value: app.enableSmartSkip,
                  onChanged: (val) => app.setEnableSmartSkip(val),
                ),
                const Divider(color: Colors.white10, height: 1),
                SwitchListTile(
                  title: const Text(
                    'Auto-Play Trailers in Details',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Automatically play official trailers in details screen after 10 seconds. Keep disabled to pause trailers by default.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  activeThumbColor: theme.colorScheme.primary,
                  value: app.autoPlayTrailers,
                  onChanged: (val) => app.setAutoPlayTrailers(val),
                ),
                const Divider(color: Colors.white10, height: 1),
                ListTile(
                  leading: const Icon(Icons.keyboard_rounded, color: Colors.white70),
                  title: const Text(
                    'Keyboard Shortcuts Cheat Sheet',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'View desktop player hotkeys (Space, Esc, F, Arrows, C, S, M)',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                  onTap: () => _showKeyboardShortcutsDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Live TV IPTV Settings
          _buildSectionTitle('LIVE TV PLAYLIST (M3U)'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Custom IPTV Playlist URL',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _iptvController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'https://example.com/playlist.m3u',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    await _storageService.setCustomIptvUrl(_iptvController.text.trim());
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('IPTV Playlist URL saved successfully!')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Save Playlist', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. Upstream API Synchronization
          _buildSectionTitle('UPSTREAM API SYNCHRONIZATION (MovieBox-TUI)'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upstream Source Repository',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'github.com/${MovieBoxConfigService.upstreamRepo}',
                            style: TextStyle(fontSize: 12, color: Colors.white54, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isSyncingUpstream ? null : _syncUpstream,
                      icon: _isSyncingUpstream
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.sync_rounded, size: 16, color: Colors.black),
                      label: Text(
                        _isSyncingUpstream ? 'Syncing...' : 'Sync Now',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.dns_rounded, size: 16, color: Color(0xFF4CAF50)),
                          const SizedBox(width: 8),
                          Text(
                            'Active Host Pool: ${MovieBoxConfigService().hostPool.length} endpoints available',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Hosts: ${MovieBoxConfigService().hostPool.map((h) => h.replaceFirst("https://", "")).join(", ")}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.vpn_key_rounded, size: 16, color: Colors.amberAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'HMAC Secret: ${MovieBoxConfigService().secretKey.substring(0, 6)}...${MovieBoxConfigService().secretKey.substring(MovieBoxConfigService().secretKey.length - 4)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.history_rounded, size: 16, color: Colors.white38),
                          const SizedBox(width: 8),
                          Text(
                            MovieBoxConfigService().lastSyncTimestamp > 0
                                ? 'Last synced: ${DateTime.fromMillisecondsSinceEpoch(MovieBoxConfigService().lastSyncTimestamp).toLocal().toString().split(".")[0]}'
                                : 'Status: Using built-in resilient host configuration',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
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

          // 5. About
          _buildSectionTitle('ABOUT'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exalere',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Version 1.0.0 • Powered by MovieBox-TUI architecture',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Features multi-source streaming across MovieBox, 4KHDHub, and Live TV, with hardware-accelerated playback, automatic subtitle synchronization, and offline watch history.',
                  style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
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
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white54,
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
        backgroundColor: const Color(0xFF14171E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Row(
          children: [
            Icon(Icons.keyboard_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text('Desktop Keyboard Shortcuts', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Text(
                        s.$1,
                        style: const TextStyle(
                          color: Colors.white,
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
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
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
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
