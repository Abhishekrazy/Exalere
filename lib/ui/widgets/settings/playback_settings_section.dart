import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/app_provider.dart';
import '../../theme/app_tokens.dart';
import '../app_surface.dart';
import '../initial_language_dialog.dart';
import '../tv/tv_popup_scope.dart';
import '../tv_focusable.dart';
import 'tv_setting_tile.dart';

class PlaybackSettingsSection extends StatelessWidget {
  final List<String> detectedPlayers;

  const PlaybackSettingsSection({super.key, required this.detectedPlayers});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final tokens = context.tokens;
    final isTv = app.isTvMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Playback & Engine
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            'PLAYBACK & ENGINE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: tokens.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              TvSettingSwitchTile(
                icon: Icons.open_in_new_rounded,
                title: 'Launch in External Player (VLC / Just Player / MPV)',
                subtitle: 'Forward streaming links directly to your media player when preferred',
                value: app.useExternalPlayer,
                onChanged: (val) => app.setUseExternalPlayer(val),
              ),
              if (detectedPlayers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: tokens.liveColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Detected on system: ${detectedPlayers.join(", ")}',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Mobile/Desktop-only features (hidden in TV mode)
              if (!isTv) ...[
                const SizedBox(height: 6),
                TvSettingSwitchTile(
                  icon: Icons.headphones_rounded,
                  title: 'Background Playback (Audio / Video)',
                  subtitle: 'Continue audio/video playback when minimizing the app or locking the screen',
                  value: app.backgroundPlayback,
                  onChanged: (val) => app.setBackgroundPlayback(val),
                ),
                const SizedBox(height: 6),
                TvSettingSwitchTile(
                  icon: Icons.picture_in_picture_alt_rounded,
                  title: 'Popup Screen / Picture-in-Picture (PiP)',
                  subtitle: 'Enable floating miniature player window when navigating outside the application',
                  value: app.pipEnabled,
                  onChanged: (val) => app.setPipEnabled(val),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 2. Series & Playback Automation
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            'SERIES & PLAYBACK CONTROLS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: tokens.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              TvSettingSwitchTile(
                icon: Icons.fast_forward_rounded,
                title: 'Auto-Skip Intro',
                subtitle: 'Automatically jump past TV series opening titles without clicking',
                value: app.autoSkipIntro,
                onChanged: (val) => app.setAutoSkipIntro(val),
              ),
              const SizedBox(height: 6),
              TvSettingSwitchTile(
                icon: Icons.skip_next_rounded,
                title: 'Auto-Skip Outro / Next Episode',
                subtitle: 'Automatically proceed to next episode when closing credits begin',
                value: app.autoSkipOutro,
                onChanged: (val) => app.setAutoSkipOutro(val),
              ),
              const SizedBox(height: 6),
              TvSettingSwitchTile(
                icon: Icons.bookmark_added_rounded,
                title: 'Enable Smart Skip Markers',
                subtitle: 'Detects typical TV intro duration when no exact provider metadata is present',
                value: app.enableSmartSkip,
                onChanged: (val) => app.setEnableSmartSkip(val),
              ),
              const SizedBox(height: 6),
              TvSettingActionTile(
                icon: Icons.translate_rounded,
                title: 'Default Audio Language',
                subtitle:
                    'Auto-play videos in this language whenever available (${app.defaultAudioLanguage ?? 'English'})',
                onTap: () => InitialLanguageDialog.show(
                  context,
                  isModalFromSettings: true,
                ),
              ),
              const SizedBox(height: 6),
              TvSettingSwitchTile(
                icon: Icons.smart_display_rounded,
                title: 'Auto-Play Trailers in Details',
                subtitle: 'Automatically play official trailers in details screen after 10 seconds. Keep disabled to pause trailers by default.',
                value: app.autoPlayTrailers,
                onChanged: (val) => app.setAutoPlayTrailers(val),
              ),
              // Desktop Keyboard shortcuts: only visible on Desktop / Non-TV
              if (!isTv) ...[
                const SizedBox(height: 6),
                TvSettingActionTile(
                  icon: Icons.keyboard_rounded,
                  title: 'Keyboard Shortcuts Cheat Sheet',
                  subtitle: 'View desktop player hotkeys (Space, Esc, F, Arrows, C, S, M)',
                  onTap: () => _showKeyboardShortcutsDialog(context),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showKeyboardShortcutsDialog(BuildContext context) {
    final tokens = context.tokens;
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
      builder: (ctx) => TvPopupScope(
        child: AlertDialog(
          backgroundColor: tokens.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: tokens.borderRadiusLg,
            side: BorderSide(color: tokens.borderSubtle),
          ),
          title: Row(
            children: [
              Icon(Icons.keyboard_rounded, color: tokens.textPrimary, size: 22),
              const SizedBox(width: 10),
              Text(
                'Desktop Keyboard Shortcuts',
                style: TextStyle(
                  color: tokens.textPrimary,
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
                          color: tokens.surfaceElevated,
                          borderRadius: tokens.borderRadiusSm,
                          border: Border.all(
                            color: tokens.borderSubtle,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          s.$1,
                          style: TextStyle(
                            color: tokens.textPrimary,
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
                            color: tokens.textSecondary,
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
            TvFocusable(
              autofocus: true,
              borderRadius: tokens.borderRadiusSm,
              onTap: () => Navigator.of(ctx).pop(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: tokens.textPrimary,
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
}
