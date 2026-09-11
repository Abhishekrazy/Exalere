import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/app_provider.dart';
import '../../../services/storage_service.dart';
import '../../theme/app_themes.dart';
import '../tv/tv_donate_dialog.dart';
import '../tv_focusable.dart';
import '../update_dialog.dart';
import 'tv_settings_menu_item.dart';
import 'tv_settings_subpage.dart';

class _TvSettingsSubpageEntry {
  final Widget widget;
  final FocusNode? callerFocusNode;

  const _TvSettingsSubpageEntry({required this.widget, this.callerFocusNode});
}

/// A 10-foot multi-page D-Pad supportive settings experience for Android TV.
/// Clicking any setting navigates to a dedicated subpage with options stacked
/// vertically (up-down) for intuitive TV remote D-Pad navigation. Supports arbitrary
/// subpage nesting depth and reliably restores focus to the calling setting item.
class TvSettingsView extends StatefulWidget {
  final List<String> detectedPlayers;
  final bool isSyncingUpstream;
  final Future<void> Function() onSyncUpstream;
  final TextEditingController iptvController;
  final StorageService storageService;
  final VoidCallback? onExitToSidebar;

  const TvSettingsView({
    super.key,
    required this.detectedPlayers,
    required this.isSyncingUpstream,
    required this.onSyncUpstream,
    required this.iptvController,
    required this.storageService,
    this.onExitToSidebar,
  });

  @override
  State<TvSettingsView> createState() => _TvSettingsViewState();
}

class _TvSettingsViewState extends State<TvSettingsView> {
  final List<_TvSettingsSubpageEntry> _subpageStack = [];

  // Dedicated focus nodes for root settings tiles so focus is restored reliably
  final FocusNode _themeFocus = FocusNode(debugLabel: 'tv_setting_theme');
  final FocusNode _uiScaleFocus = FocusNode(debugLabel: 'tv_setting_ui_scale');
  final FocusNode _tvModeFocus = FocusNode(debugLabel: 'tv_setting_tv_mode');
  final FocusNode _parentalFocus = FocusNode(debugLabel: 'tv_setting_parental');
  final FocusNode _externalPlayerFocus = FocusNode(
    debugLabel: 'tv_setting_external_player',
  );
  final FocusNode _autoSkipIntroFocus = FocusNode(
    debugLabel: 'tv_setting_auto_skip_intro',
  );
  final FocusNode _autoNextEpisodeFocus = FocusNode(
    debugLabel: 'tv_setting_auto_next_episode',
  );
  final FocusNode _autoPlayTrailersFocus = FocusNode(
    debugLabel: 'tv_setting_auto_play_trailers',
  );
  final FocusNode _iptvFocus = FocusNode(debugLabel: 'tv_setting_iptv');
  final FocusNode _upstreamSyncFocus = FocusNode(
    debugLabel: 'tv_setting_upstream_sync',
  );
  final FocusNode _updateCheckFocus = FocusNode(
    debugLabel: 'tv_setting_update_check',
  );
  final FocusNode _autoCheckUpdatesFocus = FocusNode(
    debugLabel: 'tv_setting_auto_check_updates',
  );
  final FocusNode _donateFocus = FocusNode(debugLabel: 'tv_setting_donate');
  final FocusNode _aboutFocus = FocusNode(debugLabel: 'tv_setting_about');
  FocusNode? _lastFocusedRootNode;

  void _trackFocus(FocusNode node) {
    node.addListener(() {
      if (node.hasFocus) {
        _lastFocusedRootNode = node;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _lastFocusedRootNode = _themeFocus;
    _trackFocus(_themeFocus);
    _trackFocus(_uiScaleFocus);
    _trackFocus(_tvModeFocus);
    _trackFocus(_parentalFocus);
    _trackFocus(_externalPlayerFocus);
    _trackFocus(_autoSkipIntroFocus);
    _trackFocus(_autoNextEpisodeFocus);
    _trackFocus(_autoPlayTrailersFocus);
    _trackFocus(_iptvFocus);
    _trackFocus(_upstreamSyncFocus);
    _trackFocus(_updateCheckFocus);
    _trackFocus(_autoCheckUpdatesFocus);
    _trackFocus(_donateFocus);
    _trackFocus(_aboutFocus);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _themeFocus.canRequestFocus) {
        _themeFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _themeFocus.dispose();
    _uiScaleFocus.dispose();
    _tvModeFocus.dispose();
    _parentalFocus.dispose();
    _externalPlayerFocus.dispose();
    _autoSkipIntroFocus.dispose();
    _autoNextEpisodeFocus.dispose();
    _autoPlayTrailersFocus.dispose();
    _iptvFocus.dispose();
    _upstreamSyncFocus.dispose();
    _updateCheckFocus.dispose();
    _autoCheckUpdatesFocus.dispose();
    _donateFocus.dispose();
    _aboutFocus.dispose();
    super.dispose();
  }

  void _pushSubpage(Widget subpage, [FocusNode? callerFocusNode]) {
    final caller = callerFocusNode ?? FocusManager.instance.primaryFocus;
    setState(() {
      _subpageStack.add(
        _TvSettingsSubpageEntry(widget: subpage, callerFocusNode: caller),
      );
    });
  }

  void _popSubpage() {
    if (_subpageStack.isNotEmpty) {
      final popped = _subpageStack.removeLast();
      setState(() {});
      if (popped.callerFocusNode != null &&
          popped.callerFocusNode!.canRequestFocus) {
        popped.callerFocusNode!.requestFocus();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (popped.callerFocusNode != null &&
              popped.callerFocusNode!.canRequestFocus) {
            popped.callerFocusNode!.requestFocus();
          } else if (_lastFocusedRootNode != null &&
              _lastFocusedRootNode!.canRequestFocus) {
            _lastFocusedRootNode!.requestFocus();
          } else if (_themeFocus.canRequestFocus) {
            _themeFocus.requestFocus();
          }
        }
      });
    }
  }

  void _escapeToSidebar() {
    if (widget.onExitToSidebar != null) {
      widget.onExitToSidebar!();
      return;
    }
    // Search the root scope for the sidebar Settings item
    final context = this.context;
    if (!context.mounted) return;
    FocusScopeNode scope = FocusScope.of(context);
    while (scope.enclosingScope != null) {
      scope = scope.enclosingScope!;
    }
    for (final node in scope.traversalDescendants) {
      if (node.debugLabel != null &&
          (node.debugLabel == 'TvSidebar_4' ||
              node.debugLabel!.startsWith('TvSidebar_'))) {
        if (node.canRequestFocus) {
          node.requestFocus();
          return;
        }
      }
    }
  }

  KeyEventResult _handleRootKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.browserBack) {
      _escapeToSidebar();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final tokens = context.tokens;
    final theme = Theme.of(context);

    // Main Settings Menu is persistently mounted inside an Offstage wrapper
    // so scroll position and all 14 FocusNodes remain intact when subpages are open.
    final mainList = ListView(
      padding: const EdgeInsets.fromLTRB(36, 16, 36, 48),
      children: [
        // 1. Appearance & Themes
        _buildSectionHeader('APPEARANCE & THEMES'),
        TvSettingsMenuItem(
          focusNode: _themeFocus,
          icon: Icons.palette_outlined,
          title: 'App Theme',
          subtitle: 'Select color scheme and ambiance',
          valueText: AppThemes.allThemes[app.currentThemeIndex].name,
          onTap: () => _pushSubpage(
            TvSettingsSubpage<int>(
              title: 'App Theme',
              description:
                  'Choose the color palette and visual atmosphere of Exalere.',
              selectedValue: app.currentThemeIndex,
              choices: List.generate(
                AppThemes.allThemes.length,
                (i) => TvSettingChoice<int>(
                  label: AppThemes.allThemes[i].name,
                  value: i,
                  icon: Icons.circle,
                ),
              ),
              onSelected: (idx) => app.setThemeIndex(idx),
              onBack: _popSubpage,
              onPushSubpage: _pushSubpage,
            ),
            _themeFocus,
          ),
        ),
        const SizedBox(height: 8),
        TvSettingsMenuItem(
          focusNode: _uiScaleFocus,
          icon: Icons.aspect_ratio_rounded,
          title: 'Interface Scale',
          subtitle: 'Adjust card and font dimensions for viewing distance',
          valueText: '${(app.uiScale * 100).round()}%',
          onTap: () => _pushSubpage(
            TvSettingsSubpage<double>(
              title: 'Interface Scale',
              description:
                  'Choose the scaling factor for UI cards, posters, and text.',
              selectedValue: app.uiScale,
              choices: const [
                TvSettingChoice(
                  label: '80% (Compact)',
                  description: 'Shows more rows and titles on screen',
                  value: 0.80,
                ),
                TvSettingChoice(
                  label: '85% (Recommended for TV)',
                  description: 'Optimal balance for 1080p and 4K TVs',
                  value: 0.85,
                ),
                TvSettingChoice(
                  label: '100% (Default)',
                  description: 'Standard sizing',
                  value: 1.0,
                ),
                TvSettingChoice(
                  label: '110% (Large)',
                  description: 'Enhanced visibility for distant screens',
                  value: 1.10,
                ),
                TvSettingChoice(
                  label: '120% (Extra Large)',
                  description: 'Maximum accessibility size',
                  value: 1.20,
                ),
              ],
              onSelected: (val) => app.setUiScale(val),
              onBack: _popSubpage,
              onPushSubpage: _pushSubpage,
            ),
            _uiScaleFocus,
          ),
        ),
        const SizedBox(height: 24),

        // 2. TV & Leanback Interface
        _buildSectionHeader('TV & LEANBACK INTERFACE'),
        TvSettingsMenuItem(
          focusNode: _tvModeFocus,
          icon: Icons.tv_rounded,
          title: 'TV Interface Mode',
          subtitle: 'Optimized 10-foot UI with D-Pad focus graph',
          valueText: app.isTvMode ? 'Yes' : 'No',
          onTap: () => _pushSubpage(
            TvSettingsSubpage<bool>(
              title: 'TV Interface Mode',
              description: 'Enable or disable the 10-foot Leanback interface designed for TV remotes.',
              selectedValue: app.isTvMode,
              choices: const [
                TvSettingChoice(
                  label: 'Yes',
                  description: 'Enabled (Optimal for Android TV and Fire TV)',
                  value: true,
                  icon: Icons.check_circle_outline_rounded,
                ),
                TvSettingChoice(
                  label: 'No',
                  description: 'Disabled (Standard touch / desktop layout)',
                  value: false,
                  icon: Icons.cancel_outlined,
                ),
              ],
              onSelected: (val) => app.setTvMode(val),
              onBack: _popSubpage,
              onPushSubpage: _pushSubpage,
            ),
            _tvModeFocus,
          ),
        ),
        const SizedBox(height: 8),
        TvSettingsMenuItem(
          focusNode: _parentalFocus,
          icon: Icons.family_restroom_rounded,
          title: 'Parental Controls',
          subtitle: 'Filter 18+ titles from catalogues and search',
          valueText: app.filterAdultContent ? 'Yes' : 'No',
          onTap: () => _pushSubpage(
            TvSettingsSubpage<bool>(
              title: 'Parental Controls',
              description: 'Filter out mature and adult content across all catalogue feeds and search results.',
              selectedValue: app.filterAdultContent,
              choices: const [
                TvSettingChoice(
                  label: 'Yes',
                  description: 'Hide 18+ and mature content',
                  value: true,
                  icon: Icons.shield_rounded,
                ),
                TvSettingChoice(
                  label: 'No',
                  description: 'Display all titles without filtering',
                  value: false,
                  icon: Icons.no_adult_content_rounded,
                ),
              ],
              onSelected: (val) => app.setFilterAdultContent(val),
              onBack: _popSubpage,
              onPushSubpage: _pushSubpage,
            ),
            _parentalFocus,
          ),
        ),
        const SizedBox(height: 24),

        // 3. Playback & Streaming Engine
        _buildSectionHeader('PLAYBACK & STREAMING'),
        TvSettingsMenuItem(
          focusNode: _externalPlayerFocus,
          icon: Icons.open_in_new_rounded,
          title: 'External Player Handoff',
          subtitle: 'Forward streams to VLC or Just Player',
          valueText: app.useExternalPlayer ? 'Yes' : 'No',
          onTap: () => _pushSubpage(
            TvSettingsSubpage<bool>(
              title: 'External Player Handoff',
              description: 'Forward video links directly to external media players (VLC, Just Player, MPV).',
              selectedValue: app.useExternalPlayer,
              choices: const [
                TvSettingChoice(
                  label: 'Yes',
                  description: 'Always prompt or launch in external player (VLC / Just Player)',
                  value: true,
                  icon: Icons.open_in_new_rounded,
                ),
                TvSettingChoice(
                  label: 'No',
                  description:
                      'Use built-in libmpv hardware-accelerated player',
                  value: false,
                  icon: Icons.play_circle_outline_rounded,
                ),
              ],
              onSelected: (val) => app.setUseExternalPlayer(val),
              onBack: _popSubpage,
              onPushSubpage: _pushSubpage,
            ),
            _externalPlayerFocus,
          ),
        ),
        const SizedBox(height: 8),
        TvSettingsMenuItem(
          focusNode: _autoSkipIntroFocus,
          icon: Icons.skip_next_rounded,
          title: 'Auto Skip Intro',
          subtitle: 'Skip opening themes automatically',
          valueText: app.autoSkipIntro ? 'Yes' : 'No',
          onTap: () => _pushSubpage(
            TvSettingsSubpage<bool>(
              title: 'Auto Skip Intro',
              description: 'Automatically detect and skip episode opening titles and intros.',
              selectedValue: app.autoSkipIntro,
              choices: const [
                TvSettingChoice(
                  label: 'Yes',
                  description: 'Skip intro automatically when detected',
                  value: true,
                  icon: Icons.fast_forward_rounded,
                ),
                TvSettingChoice(
                  label: 'No',
                  description: 'Disabled (Play intros normally)',
                  value: false,
                  icon: Icons.play_arrow_rounded,
                ),
              ],
              onSelected: (val) => app.setAutoSkipIntro(val),
              onBack: _popSubpage,
              onPushSubpage: _pushSubpage,
            ),
            _autoSkipIntroFocus,
          ),
        ),
        const SizedBox(height: 8),
        TvSettingsMenuItem(
          focusNode: _autoNextEpisodeFocus,
          icon: Icons.playlist_play_rounded,
          title: 'Auto Next Episode',
          subtitle: 'Automatically advance to next episode when current ends',
          valueText: app.autoSkipOutro ? 'Yes' : 'No',
          onTap: () => _pushSubpage(
            TvSettingsSubpage<bool>(
              title: 'Auto Next Episode',
              description: 'Seamlessly start the next episode as the closing credits begin.',
              selectedValue: app.autoSkipOutro,
              choices: const [
                TvSettingChoice(
                  label: 'Yes',
                  description: 'Queue and play next episode automatically',
                  value: true,
                  icon: Icons.fast_forward_rounded,
                ),
                TvSettingChoice(
                  label: 'No',
                  description: 'Disabled (Stop at credits)',
                  value: false,
                  icon: Icons.stop_rounded,
                ),
              ],
              onSelected: (val) => app.setAutoSkipOutro(val),
              onBack: _popSubpage,
              onPushSubpage: _pushSubpage,
            ),
            _autoNextEpisodeFocus,
          ),
        ),
        const SizedBox(height: 8),
        TvSettingsMenuItem(
          focusNode: _autoPlayTrailersFocus,
          icon: Icons.smart_display_outlined,
          title: 'Auto-Play Trailers',
          subtitle: 'Play backdrop trailers on details screen',
          valueText: app.autoPlayTrailers ? 'Yes' : 'No',
          onTap: () => _pushSubpage(
            TvSettingsSubpage<bool>(
              title: 'Auto-Play Trailers',
              description: 'Automatically start trailer video playback in background on details screen.',
              selectedValue: app.autoPlayTrailers,
              choices: const [
                TvSettingChoice(
                  label: 'Yes',
                  description: 'Auto-preview trailers',
                  value: true,
                  icon: Icons.movie_outlined,
                ),
                TvSettingChoice(
                  label: 'No',
                  description: 'Disabled (Static posters only)',
                  value: false,
                  icon: Icons.image_outlined,
                ),
              ],
              onSelected: (val) => app.setAutoPlayTrailers(val),
              onBack: _popSubpage,
              onPushSubpage: _pushSubpage,
            ),
            _autoPlayTrailersFocus,
          ),
        ),
        const SizedBox(height: 24),

        // 4. Live TV (IPTV)
        _buildSectionHeader('LIVE TV (IPTV)'),
        TvSettingsMenuItem(
          focusNode: _iptvFocus,
          icon: Icons.live_tv_rounded,
          title: 'Custom M3U Playlist',
          subtitle: widget.iptvController.text.isNotEmpty
              ? widget.iptvController.text
              : 'Using standard default global channels',
          valueText: widget.iptvController.text.isNotEmpty
              ? 'Custom URL'
              : 'Default',
          onTap: () => _pushSubpage(
            TvSettingsSubpage<bool>(
              title: 'Live TV Playlist',
              description: 'Select whether to use the default curated global channels or reset your custom M3U URL.',
              selectedValue: widget.iptvController.text.isEmpty,
              choices: const [
                TvSettingChoice(
                  label: 'Default Curated Channels',
                  description:
                      'Reset to built-in verified global IPTV playlist',
                  value: true,
                  icon: Icons.public_rounded,
                ),
                TvSettingChoice(
                  label: 'Keep Custom Playlist',
                  description: 'Retain custom user-provided M3U URL',
                  value: false,
                  icon: Icons.link_rounded,
                ),
              ],
              onSelected: (useDefault) async {
                if (useDefault) {
                  widget.iptvController.clear();
                  await widget.storageService.setCustomIptvUrl('');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Live TV playlist reset to default channels.',
                        ),
                        backgroundColor: tokens.liveColor,
                      ),
                    );
                  }
                }
              },
              onBack: _popSubpage,
              onPushSubpage: _pushSubpage,
            ),
            _iptvFocus,
          ),
        ),
        const SizedBox(height: 24),

        // 5. Upstream Sync
        _buildSectionHeader('UPSTREAM SYNCHRONIZATION'),
        TvFocusable(
          focusNode: _upstreamSyncFocus,
          scaleFactor: 1.02,
          borderRadius: tokens.borderRadiusSm,
          onTap: widget.isSyncingUpstream ? null : widget.onSyncUpstream,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: tokens.surfaceElevated.withValues(alpha: 0.45),
              borderRadius: tokens.borderRadiusSm,
              border: Border.all(color: tokens.borderSubtle, width: 0.8),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.primaryAccent.withValues(alpha: 0.12),
                    borderRadius: tokens.borderRadiusXs,
                  ),
                  child: Icon(
                    Icons.sync_rounded,
                    color: tokens.primaryAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sync MovieBox-TUI Endpoints',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Fetch live streaming API host mirrors from GitHub upstream',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isSyncingUpstream)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tokens.primaryAccent,
                    ),
                  )
                else
                  Icon(
                    Icons.cloud_sync_rounded,
                    color: tokens.primaryAccent,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 6. Updates & Support
        _buildSectionHeader('UPDATES & SUPPORT'),
        TvFocusable(
          focusNode: _updateCheckFocus,
          scaleFactor: 1.02,
          borderRadius: tokens.borderRadiusSm,
          onTap: app.isCheckingUpdate
              ? null
              : () async {
                  final update = await app.checkForUpdates(manual: true);
                  if (!context.mounted) return;
                  if (update != null && update.isUpdateAvailable) {
                    await UpdateDialog.show(
                      context,
                      updateInfo: update,
                      currentVersion: app.currentVersion,
                    );
                    if (mounted && _updateCheckFocus.canRequestFocus) {
                      _updateCheckFocus.requestFocus();
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Exalere is up to date (v${app.currentVersion})',
                        ),
                        backgroundColor: tokens.liveColor,
                      ),
                    );
                  }
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: tokens.surfaceElevated.withValues(alpha: 0.45),
              borderRadius: tokens.borderRadiusSm,
              border: Border.all(color: tokens.borderSubtle, width: 0.8),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.primaryAccent.withValues(alpha: 0.12),
                    borderRadius: tokens.borderRadiusXs,
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    color: tokens.primaryAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Check for Updates',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Current version v${app.currentVersion}',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (app.isCheckingUpdate)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tokens.primaryAccent,
                    ),
                  )
                else
                  Icon(
                    Icons.refresh_rounded,
                    color: tokens.textMuted,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TvSettingsMenuItem(
          focusNode: _autoCheckUpdatesFocus,
          icon: Icons.update_rounded,
          title: 'Auto-Check for Updates',
          subtitle: 'Check for new releases automatically on startup',
          valueText: app.autoCheckUpdates ? 'Yes' : 'No',
          onTap: () => _pushSubpage(
            TvSettingsSubpage<bool>(
              title: 'Auto-Check for Updates',
              description: 'Automatically poll GitHub for new Exalere builds whenever the app launches.',
              selectedValue: app.autoCheckUpdates,
              choices: const [
                TvSettingChoice(
                  label: 'Yes',
                  description: 'Check for updates on app startup',
                  value: true,
                  icon: Icons.check_circle_outline_rounded,
                ),
                TvSettingChoice(
                  label: 'No',
                  description: 'Manual update checks only',
                  value: false,
                  icon: Icons.cancel_outlined,
                ),
              ],
              onSelected: (val) => app.setAutoCheckUpdates(val),
              onBack: _popSubpage,
              onPushSubpage: _pushSubpage,
            ),
            _autoCheckUpdatesFocus,
          ),
        ),
        const SizedBox(height: 8),
        // Support & Donate (Opens Phone QR Code Scan Dialog)
        TvFocusable(
          focusNode: _donateFocus,
          scaleFactor: 1.02,
          borderRadius: tokens.borderRadiusSm,
          onKeyEvent: _handleRootKeyEvent,
          onTap: () async {
            await TvDonateDialog.show(context);
            if (mounted && _donateFocus.canRequestFocus) {
              _donateFocus.requestFocus();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: tokens.surfaceElevated.withValues(alpha: 0.45),
              borderRadius: tokens.borderRadiusSm,
              border: Border.all(
                color: tokens.primaryAccent.withValues(alpha: 0.4),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.primaryAccent.withValues(alpha: 0.15),
                    borderRadius: tokens.borderRadiusXs,
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: tokens.primaryAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Support & Donate',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Scan QR code with your phone to support development',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.qr_code_scanner_rounded,
                  color: tokens.primaryAccent,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TvSettingsMenuItem(
          focusNode: _aboutFocus,
          icon: Icons.info_outline_rounded,
          title: 'About Exalere',
          subtitle: 'Version info, architecture, and credits',
          valueText: 'v${app.currentVersion}',
          onTap: () => _pushSubpage(
            TvSettingsSubpage<int>(
              title: 'About Exalere',
              description: 'Exalere is a free, non-commercial open-source media streaming and aggregation application powered by MovieBox-TUI and TMDB architecture.',
              selectedValue: 0,
              choices: [
                TvSettingChoice(
                  label: 'Version ${app.currentVersion}',
                  description: 'PolyForm Noncommercial License 1.0.0',
                  value: 0,
                  icon: Icons.verified_rounded,
                  closeOnSelect: false,
                ),
                const TvSettingChoice(
                  label: 'Hardware Acceleration',
                  description: 'libmpv native rendering engine',
                  value: 1,
                  icon: Icons.speed_rounded,
                  closeOnSelect: false,
                ),
                const TvSettingChoice(
                  label: 'Multi-Source Aggregation',
                  description: 'MovieBox, 4KHDHub, and Live TV Streams',
                  value: 2,
                  icon: Icons.layers_rounded,
                  closeOnSelect: false,
                ),
              ],
              onSelected: (_) {},
              onBack: _popSubpage,
              onPushSubpage: _pushSubpage,
            ),
            _aboutFocus,
          ),
        ),
      ],
    );

    final Widget body = Stack(
      fit: StackFit.expand,
      children: [
        // Main Settings Menu is kept mounted so its scroll offset and focus nodes remain alive
        Offstage(
          offstage: _subpageStack.isNotEmpty,
          child: FocusScope(
            canRequestFocus: _subpageStack.isEmpty,
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: (node, event) {
                if (_subpageStack.isEmpty) {
                  return _handleRootKeyEvent(node, event);
                }
                return KeyEventResult.ignored;
              },
              child: mainList,
            ),
          ),
        ),
        // Subpage Overlay
        if (_subpageStack.isNotEmpty)
          Positioned.fill(
            child: Container(
              color: theme.scaffoldBackgroundColor,
              padding: const EdgeInsets.fromLTRB(36, 20, 36, 24),
              child: _subpageStack.last.widget,
            ),
          ),
      ],
    );

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.goBack ||
              key == LogicalKeyboardKey.escape ||
              key == LogicalKeyboardKey.backspace ||
              key == LogicalKeyboardKey.browserBack) {
            if (_subpageStack.isNotEmpty) {
              _popSubpage();
              return KeyEventResult.handled;
            }
            // On settings home page: Escape to TV sidebar
            _escapeToSidebar();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: PopScope(
        canPop: _subpageStack.isEmpty,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_subpageStack.isNotEmpty) {
            _popSubpage();
          }
        },
        child: body,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: tokens.textSecondary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
