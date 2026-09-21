import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/exalere_plugin.dart';
import '../../../providers/plugin_provider.dart';
import '../../../providers/app_provider.dart';
import '../../../services/storage_service.dart';
import '../../theme/app_themes.dart';
import '../initial_language_dialog.dart';
import '../tv/tv_donate_dialog.dart';
import '../tv_focusable.dart';
import '../update_dialog.dart';
import 'tv_settings_menu_item.dart';
import 'tv_settings_subpage.dart';

typedef TvSubpageBuilder = Widget Function(BuildContext context);

class _TvSettingsSubpageEntry {
  final TvSubpageBuilder builder;
  final FocusNode? callerFocusNode;

  const _TvSettingsSubpageEntry({required this.builder, this.callerFocusNode});
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
  final FocusNode _cornerStyleFocus = FocusNode(
    debugLabel: 'tv_setting_corner_style',
  );
  final FocusNode _tvModeFocus = FocusNode(debugLabel: 'tv_setting_tv_mode');
  final FocusNode _parentalFocus = FocusNode(debugLabel: 'tv_setting_parental');
  final FocusNode _externalPlayerFocus = FocusNode(
    debugLabel: 'tv_setting_external_player',
  );
  final FocusNode _audioLanguageFocus = FocusNode(
    debugLabel: 'tv_setting_audio_language',
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
  final FocusNode _onlyShowAvailableFocus = FocusNode(
    debugLabel: 'tv_setting_only_show_available',
  );
  final FocusNode _iptvFocus = FocusNode(debugLabel: 'tv_setting_iptv');
  final FocusNode _addonsFocus = FocusNode(debugLabel: 'tv_setting_addons');
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
    _trackFocus(_cornerStyleFocus);
    _trackFocus(_tvModeFocus);
    _trackFocus(_parentalFocus);
    _trackFocus(_externalPlayerFocus);
    _trackFocus(_audioLanguageFocus);
    _trackFocus(_autoSkipIntroFocus);
    _trackFocus(_autoNextEpisodeFocus);
    _trackFocus(_autoPlayTrailersFocus);
    _trackFocus(_onlyShowAvailableFocus);
    _trackFocus(_iptvFocus);
    _trackFocus(_addonsFocus);
    _trackFocus(_upstreamSyncFocus);
    _trackFocus(_updateCheckFocus);
    _trackFocus(_autoCheckUpdatesFocus);
    _trackFocus(_donateFocus);
    _trackFocus(_aboutFocus);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          context.read<AppProvider>().setSettingsSubpageDepth(
            _subpageStack.length,
          );
        } catch (_) {}
        if (_themeFocus.canRequestFocus) {
          _themeFocus.requestFocus();
        }
      }
    });
  }

  @override
  void dispose() {
    _themeFocus.dispose();
    _uiScaleFocus.dispose();
    _cornerStyleFocus.dispose();
    _tvModeFocus.dispose();
    _parentalFocus.dispose();
    _externalPlayerFocus.dispose();
    _audioLanguageFocus.dispose();
    _autoSkipIntroFocus.dispose();
    _autoNextEpisodeFocus.dispose();
    _autoPlayTrailersFocus.dispose();
    _onlyShowAvailableFocus.dispose();
    _iptvFocus.dispose();
    _addonsFocus.dispose();
    _upstreamSyncFocus.dispose();
    _updateCheckFocus.dispose();
    _autoCheckUpdatesFocus.dispose();
    _donateFocus.dispose();
    _aboutFocus.dispose();
    try {
      context.read<AppProvider>().setSettingsSubpageDepth(0);
    } catch (_) {}
    super.dispose();
  }

  void _pushSubpage(dynamic subpage, [FocusNode? callerFocusNode]) {
    final caller = callerFocusNode ?? FocusManager.instance.primaryFocus;
    final TvSubpageBuilder builder;
    if (subpage is TvSubpageBuilder) {
      builder = subpage;
    } else if (subpage is Widget Function(BuildContext)) {
      builder = subpage;
    } else if (subpage is Function) {
      builder = (ctx) => (subpage as dynamic)(ctx) as Widget;
    } else if (subpage is Widget) {
      builder = (_) => subpage;
    } else {
      builder = (_) => subpage as Widget;
    }
    setState(() {
      _subpageStack.add(
        _TvSettingsSubpageEntry(builder: builder, callerFocusNode: caller),
      );
    });
    context.read<AppProvider>().setSettingsSubpageDepth(_subpageStack.length);
  }

  void _popSubpage() {
    if (_subpageStack.isNotEmpty) {
      final popped = _subpageStack.removeLast();
      final app = context.read<AppProvider>();
      app.recordSettingsSubpagePop();
      app.setSettingsSubpageDepth(_subpageStack.length);
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

  bool _isBackKey(KeyEvent event) {
    final key = event.logicalKey;
    return key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.browserBack ||
        key.keyId == 0x00200000004;
  }

  String _cornerStyleLabel(CornerStyle style) {
    switch (style) {
      case CornerStyle.rounded:
        return 'Rounded';
      case CornerStyle.sharp:
        return 'Sharp (90°)';
      case CornerStyle.cut:
        return 'Cut (Bevel)';
    }
  }

  KeyEventResult _handleRootKeyEvent(FocusNode node, KeyEvent event) {
    if (_isBackKey(event)) {
      if (_subpageStack.isNotEmpty) {
        if (event is KeyUpEvent) {
          _popSubpage();
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final tokens = context.tokens;
    final theme = Theme.of(context);

    if (app.settingsSubpageDepth != _subpageStack.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            context.read<AppProvider>().setSettingsSubpageDepth(
              _subpageStack.length,
            );
          } catch (_) {}
        }
      });
    }

    // Main Settings Menu is persistently mounted inside an Offstage wrapper
    // so scroll position and all 15 FocusNodes remain intact when subpages are open.
    final mainList = SingleChildScrollView(
      clipBehavior: Clip.none,
      padding: const EdgeInsets.fromLTRB(36, 16, 36, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Appearance & Themes
          _buildSectionHeader('APPEARANCE & THEMES'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TvSettingsMenuItem(
                  focusNode: _themeFocus,
                  icon: Icons.palette_outlined,
                  title: 'App Theme',
                  subtitle: 'Select color scheme and ambiance',
                  valueText: app.currentThemeIndex == 0
                      ? 'Follow System'
                      : app.currentThemeIndex == 2
                      ? 'Light Mode'
                      : 'Dark Mode',
                  onTap: () => _pushSubpage((BuildContext ctx) {
                    final app = ctx.read<AppProvider>();
                    return TvSettingsSubpage<int>(
                      title: 'App Theme',
                      description: 'Choose the color palette and visual atmosphere of Exalere.',
                      selectedValue: app.currentThemeIndex,
                      choices: const [
                        TvSettingChoice<int>(
                          label: 'Follow System',
                          description: 'Automatically adapt based on device system appearance',
                          value: 0,
                          icon: Icons.brightness_auto_rounded,
                        ),
                        TvSettingChoice<int>(
                          label: 'Dark Mode',
                          description: 'Solid dark interface',
                          value: 1,
                          icon: Icons.dark_mode_rounded,
                        ),
                        TvSettingChoice<int>(
                          label: 'Light Mode',
                          description: 'Solid light interface',
                          value: 2,
                          icon: Icons.light_mode_rounded,
                        ),
                      ],
                      onSelected: (idx) => app.setThemeIndex(idx),
                      onBack: _popSubpage,
                      onPushSubpage: _pushSubpage,
                    );
                  }, _themeFocus),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TvSettingsMenuItem(
                  focusNode: _uiScaleFocus,
                  icon: Icons.aspect_ratio_rounded,
                  title: 'Interface Scale',
                  subtitle:
                      'Adjust card and font dimensions for viewing distance',
                  valueText: '${(app.uiScale * 100).round()}%',
                  onTap: () => _pushSubpage((BuildContext ctx) {
                    final app = ctx.read<AppProvider>();
                    return TvSettingsSubpage<double>(
                      title: 'Interface Scale',
                      description: 'Choose the scaling factor for UI cards, posters, and text.',
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
                          description:
                              'Enhanced visibility for distant screens',
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
                    );
                  }, _uiScaleFocus),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TvSettingsMenuItem(
                  focusNode: _cornerStyleFocus,
                  icon: Icons.rounded_corner_rounded,
                  title: 'Corner Style',
                  subtitle: 'Customize corner geometry across all UI cards and buttons',
                  valueText: _cornerStyleLabel(app.cornerStyle),
                  onTap: () => _pushSubpage((BuildContext ctx) {
                    final app = ctx.read<AppProvider>();
                    return TvSettingsSubpage<CornerStyle>(
                      title: 'Corner Style',
                      description: 'Choose the corner geometry for cards, buttons, dialogs, and focus indicators.',
                      selectedValue: app.cornerStyle,
                      choices: const [
                        TvSettingChoice(
                          label: 'Rounded',
                          description:
                              'Smooth organic rounded corners (Default)',
                          value: CornerStyle.rounded,
                          icon: Icons.rounded_corner_rounded,
                        ),
                        TvSettingChoice(
                          label: 'Sharp (90°)',
                          description: 'Crisp, modern squared-off corners',
                          value: CornerStyle.sharp,
                          icon: Icons.square_outlined,
                        ),
                        TvSettingChoice(
                          label: 'Cut (Bevel)',
                          description:
                              'Angled chamfered corners with sci-fi aesthetics',
                          value: CornerStyle.cut,
                          icon: Icons.hexagon_outlined,
                        ),
                      ],
                      onSelected: (val) => app.setCornerStyle(val),
                      onBack: _popSubpage,
                      onPushSubpage: _pushSubpage,
                    );
                  }, _cornerStyleFocus),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TvSettingsMenuItem(
                  focusNode: _tvModeFocus,
                  icon: Icons.tv_rounded,
                  title: 'TV Interface Mode',
                  subtitle: 'Optimized 10-foot UI with D-Pad focus graph',
                  valueText: app.isTvMode ? 'Yes' : 'No',
                  onTap: () => _pushSubpage((BuildContext ctx) {
                    final app = ctx.read<AppProvider>();
                    return TvSettingsSubpage<bool>(
                      title: 'TV Interface Mode',
                      description: 'Enable or disable the 10-foot Leanback interface designed for TV remotes.',
                      selectedValue: app.isTvMode,
                      choices: const [
                        TvSettingChoice(
                          label: 'Yes',
                          description:
                              'Enabled (Optimal for Android TV and Fire TV)',
                          value: true,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                        TvSettingChoice(
                          label: 'No',
                          description:
                              'Disabled (Standard touch / desktop layout)',
                          value: false,
                          icon: Icons.cancel_outlined,
                        ),
                      ],
                      onSelected: (val) => app.setTvMode(val),
                      onBack: _popSubpage,
                      onPushSubpage: _pushSubpage,
                    );
                  }, _tvModeFocus),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2. Content & Playback
          _buildSectionHeader('CONTENT & PLAYBACK'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TvSettingsMenuItem(
                  focusNode: _parentalFocus,
                  icon: Icons.family_restroom_rounded,
                  title: 'Parental Controls',
                  subtitle: 'Filter 18+ titles from catalogues and search',
                  valueText: app.filterAdultContent ? 'Yes' : 'No',
                  onTap: () => _pushSubpage((BuildContext ctx) {
                    final app = ctx.read<AppProvider>();
                    return TvSettingsSubpage<bool>(
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
                    );
                  }, _parentalFocus),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TvSettingsMenuItem(
                  focusNode: _externalPlayerFocus,
                  icon: Icons.open_in_new_rounded,
                  title: 'External Player Handoff',
                  subtitle: 'Forward streams to VLC or Just Player',
                  valueText: app.useExternalPlayer ? 'Yes' : 'No',
                  onTap: () => _pushSubpage((BuildContext ctx) {
                    final app = ctx.read<AppProvider>();
                    return TvSettingsSubpage<bool>(
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
                    );
                  }, _externalPlayerFocus),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TvSettingsMenuItem(
                  focusNode: _audioLanguageFocus,
                  icon: Icons.translate_rounded,
                  title: 'Default Audio Language',
                  subtitle: 'Auto-select language for movies & series',
                  valueText: () {
                    final saved = (app.defaultAudioLanguage ?? 'Hindi')
                        .trim()
                        .toLowerCase();
                    final match = InitialLanguageDialog.supportedLanguages
                        .cast<LanguageOption?>()
                        .firstWhere(
                          (l) =>
                              l!.name.toLowerCase() == saved ||
                              l.code.toLowerCase() == saved ||
                              l.nativeName.toLowerCase() == saved,
                          orElse: () => null,
                        );
                    return match?.name ?? (app.defaultAudioLanguage ?? 'Hindi');
                  }(),
                  onTap: () => _pushSubpage((BuildContext ctx) {
                    final app = ctx.read<AppProvider>();
                    final saved = (app.defaultAudioLanguage ?? 'Hindi')
                        .trim()
                        .toLowerCase();
                    final match = InitialLanguageDialog.supportedLanguages
                        .cast<LanguageOption?>()
                        .firstWhere(
                          (l) =>
                              l!.name.toLowerCase() == saved ||
                              l.code.toLowerCase() == saved ||
                              l.nativeName.toLowerCase() == saved,
                          orElse: () => null,
                        );
                    final resolvedName =
                        match?.name ?? (app.defaultAudioLanguage ?? 'Hindi');

                    return TvSettingsSubpage<String>(
                      title: 'Default Audio Language',
                      description: 'Select your preferred audio dubbing or spoken language for streams.',
                      selectedValue: resolvedName,
                      choices: InitialLanguageDialog.supportedLanguages.map((
                        l,
                      ) {
                        return TvSettingChoice<String>(
                          label: '${l.name} (${l.nativeName})',
                          description: 'Auto-play in ${l.name}',
                          value: l.name,
                          icon: Icons.record_voice_over_rounded,
                        );
                      }).toList(),
                      onSelected: (val) => app.setDefaultAudioLanguage(val),
                      onBack: _popSubpage,
                      onPushSubpage: _pushSubpage,
                    );
                  }, _audioLanguageFocus),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TvSettingsMenuItem(
                  focusNode: _autoSkipIntroFocus,
                  icon: Icons.skip_next_rounded,
                  title: 'Auto Skip Intro',
                  subtitle: 'Skip opening themes automatically',
                  valueText: app.autoSkipIntro ? 'Yes' : 'No',
                  onTap: () => _pushSubpage((BuildContext ctx) {
                    final app = ctx.read<AppProvider>();
                    return TvSettingsSubpage<bool>(
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
                    );
                  }, _autoSkipIntroFocus),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TvSettingsMenuItem(
                  focusNode: _autoNextEpisodeFocus,
                  icon: Icons.playlist_play_rounded,
                  title: 'Auto Next Episode',
                  subtitle:
                      'Automatically advance to next episode when current ends',
                  valueText: app.autoSkipOutro ? 'Yes' : 'No',
                  onTap: () => _pushSubpage((BuildContext ctx) {
                    final app = ctx.read<AppProvider>();
                    return TvSettingsSubpage<bool>(
                      title: 'Auto Next Episode',
                      description: 'Seamlessly start the next episode as the closing credits begin.',
                      selectedValue: app.autoSkipOutro,
                      choices: const [
                        TvSettingChoice(
                          label: 'Yes',
                          description:
                              'Queue and play next episode automatically',
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
                    );
                  }, _autoNextEpisodeFocus),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TvSettingsMenuItem(
                  focusNode: _autoPlayTrailersFocus,
                  icon: Icons.smart_display_outlined,
                  title: 'Auto-Play Trailers',
                  subtitle: 'Play backdrop trailers on details screen',
                  valueText: app.autoPlayTrailers ? 'Yes' : 'No',
                  onTap: () => _pushSubpage((BuildContext ctx) {
                    final app = ctx.read<AppProvider>();
                    return TvSettingsSubpage<bool>(
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
                    );
                  }, _autoPlayTrailersFocus),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TvSettingsMenuItem(
                  focusNode: _onlyShowAvailableFocus,
                  icon: Icons.filter_list_rounded,
                  title: 'Only Available Content',
                  subtitle:
                      'Filter feeds and search to active streaming plugins',
                  valueText: app.onlyShowAvailableOnProviders ? 'Yes' : 'No',
                  onTap: () => _pushSubpage((BuildContext ctx) {
                    final app = ctx.read<AppProvider>();
                    return TvSettingsSubpage<bool>(
                      title: 'Only Available Content',
                      description: 'Filter Home feeds and Search strictly to titles available on active streaming plugins.',
                      selectedValue: app.onlyShowAvailableOnProviders,
                      choices: const [
                        TvSettingChoice(
                          label: 'Yes',
                          description: 'Only show streamable content from active providers',
                          value: true,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                        TvSettingChoice(
                          label: 'No',
                          description:
                              'Show complete global TMDB catalog discovery',
                          value: false,
                          icon: Icons.public_rounded,
                        ),
                      ],
                      onSelected: (val) =>
                          app.setOnlyShowAvailableOnProviders(val),
                      onBack: _popSubpage,
                      onPushSubpage: _pushSubpage,
                    );
                  }, _onlyShowAvailableFocus),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 24),

          // 3. Live TV & Extensions
          _buildSectionHeader('LIVE TV & STREAM PLUGINS'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TvSettingsMenuItem(
                  focusNode: _iptvFocus,
                  icon: Icons.live_tv_rounded,
                  title: 'Custom M3U Playlist',
                  subtitle: widget.iptvController.text.isNotEmpty
                      ? widget.iptvController.text
                      : 'Using standard default global channels',
                  valueText: widget.iptvController.text.isNotEmpty
                      ? 'Custom URL'
                      : 'Default',
                  onTap: () => _pushSubpage((context) {
                    return TvSettingsSubpage<bool>(
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
                    );
                  }, _iptvFocus),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TvSettingsMenuItem(
                  focusNode: _addonsFocus,
                  icon: Icons.extension_rounded,
                  title: 'Add-ons',
                  subtitle: 'Manage community add-ons',
                  valueText:
                      '${Provider.of<PluginProvider?>(context)?.plugins.length ?? 0} Installed',
                  onTap: () => _pushSubpage((BuildContext ctx) {
                    return _TvPluginsSubpage(onBack: _popSubpage);
                  }, _addonsFocus),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 4. Upstream & Updates
          _buildSectionHeader('UPSTREAM & UPDATES'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TvSettingsMenuItem(
                  focusNode: _upstreamSyncFocus,
                  icon: Icons.sync_rounded,
                  title: 'Sync MovieBox-TUI Endpoints',
                  subtitle: 'Fetch live streaming API host mirrors from GitHub upstream',
                  valueText: widget.isSyncingUpstream ? 'Syncing...' : 'Sync',
                  onTap: widget.isSyncingUpstream
                      ? () {}
                      : () => widget.onSyncUpstream(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TvSettingsMenuItem(
                  focusNode: _updateCheckFocus,
                  icon: Icons.system_update_rounded,
                  title: 'Check for Updates',
                  subtitle: 'Current version v${app.currentVersion}',
                  valueText: app.isCheckingUpdate ? 'Checking...' : 'Check',
                  onTap: app.isCheckingUpdate
                      ? () {}
                      : () async {
                          final update = await app.checkForUpdates(
                            manual: true,
                          );
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
                                  app.updateCheckError ??
                                      'Exalere is up to date (v${app.currentVersion})',
                                ),
                                backgroundColor: tokens.liveColor,
                              ),
                            );
                          }
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TvSettingsMenuItem(
                  focusNode: _autoCheckUpdatesFocus,
                  icon: Icons.update_rounded,
                  title: 'Auto-Check for Updates',
                  subtitle: 'Check for new releases automatically on startup',
                  valueText: app.autoCheckUpdates ? 'Yes' : 'No',
                  onTap: () => _pushSubpage((BuildContext ctx) {
                    final app = ctx.read<AppProvider>();
                    return TvSettingsSubpage<bool>(
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
                    );
                  }, _autoCheckUpdatesFocus),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 24),

          // 5. Support & About
          _buildSectionHeader('SUPPORT & ABOUT'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TvSettingsMenuItem(
                  focusNode: _donateFocus,
                  icon: Icons.favorite_rounded,
                  title: 'Support & Donate',
                  subtitle:
                      'Scan QR code from mobile to donate via UPI / Crypto',
                  valueText: 'Donate',
                  onTap: () async {
                    await TvDonateDialog.show(context);
                    if (mounted && _donateFocus.canRequestFocus) {
                      _donateFocus.requestFocus();
                    }
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TvSettingsMenuItem(
                  focusNode: _aboutFocus,
                  icon: Icons.info_outline_rounded,
                  title: 'About Exalere',
                  subtitle:
                      'v${app.currentVersion} • PolyForm Noncommercial 1.0.0',
                  valueText: 'Info',
                  onTap: () => _pushSubpage((BuildContext ctx) {
                    final app = ctx.read<AppProvider>();
                    return TvSettingsSubpage<int>(
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
                    );
                  }, _aboutFocus),
                ),
              ),
            ],
          ),
        ],
      ),
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
            child: FocusScope(
              autofocus: true,
              child: Container(
                color: theme.scaffoldBackgroundColor,
                padding: const EdgeInsets.fromLTRB(36, 20, 36, 24),
                child: Builder(
                  builder: (subCtx) => _subpageStack.last.builder(subCtx),
                ),
              ),
            ),
          ),
      ],
    );

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (_isBackKey(event)) {
          if (_subpageStack.isNotEmpty) {
            if (event is KeyUpEvent) {
              _popSubpage();
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
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

class _TvPluginsSubpage extends StatefulWidget {
  final VoidCallback onBack;

  const _TvPluginsSubpage({required this.onBack});

  @override
  State<_TvPluginsSubpage> createState() => _TvPluginsSubpageState();
}

class _TvPluginsSubpageState extends State<_TvPluginsSubpage> {
  final FocusNode _backFocusNode = FocusNode(debugLabel: 'tv_plugins_back');
  final FocusNode _addBtnFocusNode = FocusNode(
    debugLabel: 'tv_plugins_add_btn',
  );
  String? _installingPluginId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _backFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _backFocusNode.dispose();
    _addBtnFocusNode.dispose();
    super.dispose();
  }

  void _showTvInstallDialog(BuildContext context) {
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
              shape: tokens.getShapeBorder(
                radius: tokens.cardRadius * 1.35,
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
                TvFocusable(
                  onTap: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  shape: tokens.shapeSm,
                  borderRadius: tokens.borderRadiusSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                  ),
                ),
                TvFocusable(
                  autofocus: true,
                  onTap: isSubmitting
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

                          final provider = Provider.of<PluginProvider?>(
                            dialogCtx,
                            listen: false,
                          );
                          final success =
                              await provider?.installPlugin(url) ?? false;

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
                                  provider?.errorMessage ??
                                  'Failed to connect to add-on.';
                            });
                          }
                        },
                  shape: tokens.shapeSm,
                  borderRadius: tokens.borderRadiusSm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: tokens.getShapeDecoration(
                      color: theme.colorScheme.primary,
                      radius: tokens.cardRadius * 0.5,
                    ),
                    child: isSubmitting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : Text(
                            'Install',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
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
        shape: tokens.getShapeBorder(
          radius: tokens.cardRadius * 1.35,
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
          TvFocusable(
            autofocus: true,
            onTap: () => Navigator.pop(dialogCtx),
            shape: tokens.shapeSm,
            borderRadius: tokens.borderRadiusSm,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'Cancel',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
          ),
          TvFocusable(
            onTap: () async {
              Navigator.pop(dialogCtx);
              await Provider.of<PluginProvider?>(
                context,
                listen: false,
              )?.uninstallPlugin(plugin.id);
            },
            shape: tokens.shapeSm,
            borderRadius: tokens.borderRadiusSm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: tokens.getShapeDecoration(
                color: tokens.errorColor,
                radius: tokens.cardRadius * 0.5,
              ),
              child: Text(
                'Remove',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _installCommunityPlugin(CommunityPluginItem item) async {
    final tokens = context.tokens;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _installingPluginId = item.id);

    try {
      final provider = Provider.of<PluginProvider?>(context, listen: false);
      final success = await provider?.installPlugin(item.manifestUrl) ?? false;

      if (mounted) {
        setState(() => _installingPluginId = null);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Installed "${item.name}" successfully!'
                  : (provider?.errorMessage ??
                        'Failed to install ${item.name}'),
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

    return Focus(
      onKeyEvent: (node, event) {
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.goBack ||
            key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.backspace ||
            key == LogicalKeyboardKey.browserBack) {
          if (event is KeyUpEvent) {
            widget.onBack();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) widget.onBack();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(36, 16, 36, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Back Button
              Row(
                children: [
                  TvFocusable(
                    autofocus: true,
                    focusNode: _backFocusNode,
                    onTap: widget.onBack,
                    scaleFactor: 1.08,
                    shape: tokens.shapePill,
                    borderRadius: tokens.borderRadiusPill,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: tokens.getShapeDecoration(
                        color: tokens.surfaceElevated.withValues(alpha: 0.6),
                        radius: tokens.cardRadius * 2,
                        side: BorderSide(color: tokens.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
                            color: tokens.textPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Back',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Text(
                    'Add-ons',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Install and manage community add-ons for Exalere.',
                style: TextStyle(color: tokens.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 18),

              // Scrollable content area
              Expanded(
                child: SingleChildScrollView(
                  clipBehavior: Clip.none,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Add Plugin by URL Button
                      Row(
                        children: [
                          TvFocusable(
                            focusNode: _addBtnFocusNode,
                            scaleFactor: 1.04,
                            shape: tokens.shapeSm,
                            borderRadius: tokens.borderRadiusSm,
                            onTap: () => _showTvInstallDialog(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              decoration: tokens.getShapeDecoration(
                                color: theme.colorScheme.primary,
                                radius: tokens.cardRadius * 0.6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    color: theme.colorScheme.onPrimary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add Add-on by URL',
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
                        ],
                      ),
                      const SizedBox(height: 22),

                      // Section: Community Add-ons
                      Row(
                        children: [
                          Icon(
                            Icons.explore_outlined,
                            color: theme.colorScheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'COMMUNITY ADD-ONS (1-CLICK INSTALL)',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: tokens.getShapeDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.15,
                              ),
                              radius: tokens.cardRadius * 0.3,
                            ),
                            child: Text(
                              'Zero Typing',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Horizontal shelf for Community Plugins
                      SizedBox(
                        height: 165,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.hardEdge,
                          cacheExtent: 350.0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          itemCount: communityCatalog.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 14),
                          itemBuilder: (context, index) {
                            final item = communityCatalog[index];
                            final isInstalled =
                                pluginProvider?.isPluginInstalled(
                                  item.id,
                                  item.manifestUrl,
                                ) ??
                                false;
                            final isCurrentInstalling =
                                _installingPluginId == item.id;

                            return TvFocusable(
                              scaleFactor: 1.05,
                              shape: tokens.shapeSm,
                              borderRadius: tokens.borderRadiusSm,
                              onTap: () {
                                if (isInstalled) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${item.name} is already installed!',
                                      ),
                                      backgroundColor: tokens.surfaceElevated,
                                    ),
                                  );
                                } else if (!isCurrentInstalling &&
                                    _installingPluginId == null) {
                                  _installCommunityPlugin(item);
                                }
                              },
                              child: Container(
                                width: 260,
                                padding: const EdgeInsets.all(14),
                                decoration: tokens.getShapeDecoration(
                                  color: tokens.surfaceCard,
                                  radius: tokens.cardRadius * 0.7,
                                  side: BorderSide(
                                    color: isInstalled
                                        ? tokens.liveColor.withValues(
                                            alpha: 0.35,
                                          )
                                        : tokens.borderSubtle,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: tokens.getShapeDecoration(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.12),
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                        const SizedBox(width: 6),
                                        if (isInstalled)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: tokens
                                                .getShapeDecoration(
                                                  color: tokens.liveColor
                                                      .withValues(alpha: 0.15),
                                                  radius:
                                                      tokens.cardRadius * 0.3,
                                                  side: BorderSide(
                                                    color: tokens.liveColor
                                                        .withValues(
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
                                                  size: 12,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'Installed',
                                                  style: TextStyle(
                                                    color: tokens.liveColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else if (isCurrentInstalling)
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: theme.colorScheme.primary,
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: tokens
                                                .getShapeDecoration(
                                                  color: theme
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.15),
                                                  radius:
                                                      tokens.cardRadius * 0.3,
                                                ),
                                            child: Text(
                                              'Install',
                                              style: TextStyle(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
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
                                              color: tokens.borderSubtle
                                                  .withValues(alpha: 0.5),
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
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 26),

                      // Section: Installed Plugins
                      Row(
                        children: [
                          Icon(
                            Icons.extension_rounded,
                            color: theme.colorScheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'INSTALLED ADD-ONS (${plugins.length})',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (plugins.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 28,
                            horizontal: 20,
                          ),
                          decoration: tokens.getShapeDecoration(
                            color: tokens.surfaceCard.withValues(alpha: 0.5),
                            radius: tokens.cardRadius,
                            side: BorderSide(color: tokens.borderSubtle),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.extension_off_rounded,
                                color: tokens.textMuted,
                                size: 36,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No Add-ons Installed',
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Select any add-on from the Community Add-ons above to install it with 1-click.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...plugins.map((plugin) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              decoration: tokens.getShapeDecoration(
                                color: tokens.surfaceCard,
                                radius: tokens.cardRadius * 0.7,
                                side: BorderSide(
                                  color: plugin.isEnabled
                                      ? tokens.borderSubtle
                                      : tokens.borderSubtle.withValues(
                                          alpha: 0.3,
                                        ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: tokens.getShapeDecoration(
                                      color: plugin.isEnabled
                                          ? theme.colorScheme.primary
                                                .withValues(alpha: 0.15)
                                          : tokens.surfaceElevated,
                                      radius: tokens.cardRadius * 0.5,
                                    ),
                                    child: Icon(
                                      _getIconForPlugin(plugin.id),
                                      color: plugin.isEnabled
                                          ? theme.colorScheme.primary
                                          : tokens.textMuted,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              plugin.name,
                                              style: TextStyle(
                                                color: tokens.textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            if (plugin.manifest?.version !=
                                                null) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: tokens
                                                    .getShapeDecoration(
                                                      color: tokens
                                                          .surfaceElevated,
                                                      radius:
                                                          tokens.cardRadius *
                                                          0.3,
                                                    ),
                                                child: Text(
                                                  'v${plugin.manifest!.version}',
                                                  style: TextStyle(
                                                    color: tokens.textSecondary,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: tokens
                                                  .getShapeDecoration(
                                                    color: plugin.isEnabled
                                                        ? tokens.liveColor
                                                              .withValues(
                                                                alpha: 0.2,
                                                              )
                                                        : tokens.textMuted
                                                              .withValues(
                                                                alpha: 0.2,
                                                              ),
                                                    radius:
                                                        tokens.cardRadius * 0.3,
                                                  ),
                                              child: Text(
                                                plugin.isEnabled
                                                    ? 'Active'
                                                    : 'Disabled',
                                                style: TextStyle(
                                                  color: plugin.isEnabled
                                                      ? tokens.liveColor
                                                      : tokens.textMuted,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
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
                                  const SizedBox(width: 14),
                                  TvFocusable(
                                    scaleFactor: 1.06,
                                    shape: tokens.shapeSm,
                                    borderRadius: tokens.borderRadiusSm,
                                    onTap: () {
                                      Provider.of<PluginProvider?>(
                                        context,
                                        listen: false,
                                      )?.togglePlugin(
                                        plugin.id,
                                        !plugin.isEnabled,
                                      );
                                      Provider.of<AppProvider?>(
                                        context,
                                        listen: false,
                                      )?.loadHomeFeeds();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: tokens.getShapeDecoration(
                                        color: tokens.surfaceElevated,
                                        radius: tokens.cardRadius * 0.4,
                                        side: BorderSide(
                                          color: tokens.borderSubtle,
                                        ),
                                      ),
                                      child: Text(
                                        plugin.isEnabled ? 'Disable' : 'Enable',
                                        style: TextStyle(
                                          color: plugin.isEnabled
                                              ? tokens.textSecondary
                                              : theme.colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TvFocusable(
                                    scaleFactor: 1.06,
                                    shape: tokens.shapeSm,
                                    borderRadius: tokens.borderRadiusSm,
                                    onTap: () =>
                                        _confirmDelete(context, plugin),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: tokens.getShapeDecoration(
                                        color: tokens.errorColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        radius: tokens.cardRadius * 0.4,
                                        side: BorderSide(
                                          color: tokens.errorColor.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Remove',
                                        style: TextStyle(
                                          color: tokens.errorColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
