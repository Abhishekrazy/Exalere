import 'package:flutter/material.dart';

/// Categories grouping Exalere's built-in features.
enum FeatureCategory {
  playback('Playback Engine', Icons.play_circle_filled_rounded),
  audioSubtitles('Audio & Subtitles', Icons.subtitles_rounded),
  tvNavigation('10-Foot TV Experience', Icons.tv_rounded),
  profilesSync('Profiles & LAN Sync', Icons.people_alt_rounded),
  discovery('Discovery & Franchises', Icons.explore_rounded),
  bingeSkipping('Binge & Smart Skip', Icons.fast_forward_rounded),
  backupRestore('Backup & Migration', Icons.cloud_sync_rounded),
  downloads('Offline Downloads', Icons.download_done_rounded),
  liveTv('Live TV & IPTV', Icons.live_tv_rounded),
  theming('Themes & UI Styling', Icons.palette_rounded),
  plugins('Universal Addons', Icons.extension_rounded);

  final String label;
  final IconData icon;
  const FeatureCategory(this.label, this.icon);
}

/// Represents an individual feature or capability within Exalere.
class AppFeature {
  final String id;
  final String title;
  final String description;
  final FeatureCategory category;
  final IconData icon;
  final bool isNew;
  final bool isHighlight;

  const AppFeature({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    this.isNew = false,
    this.isHighlight = false,
  });
}

/// Definitive in-app catalog of all features and capabilities in Exalere.
class AppFeaturesCatalog {
  AppFeaturesCatalog._();

  static const List<AppFeature> allFeatures = [
    // 1. Playback Engine
    AppFeature(
      id: 'multi_source_streaming',
      title: 'Multi-Source Streaming Engine',
      description:
          'Aggregates and resolves streams across MovieBox, 4KHDHub, Stremio addons, P2P/Torrentio, and community plugins.',
      category: FeatureCategory.playback,
      icon: Icons.hub_rounded,
      isHighlight: true,
    ),
    AppFeature(
      id: 'libmpv_hwdec',
      title: 'Hardware-Accelerated Playback (libmpv)',
      description:
          'Powered by libmpv utilizing native GPU hardware decoding (MediaCodec on Android, D3D11VA on Windows).',
      category: FeatureCategory.playback,
      icon: Icons.memory_rounded,
      isHighlight: true,
    ),
    AppFeature(
      id: 'external_player',
      title: 'External Player Handoff',
      description:
          'One-tap fallback to launch external video players (VLC, Just Player, MX Player) with position forwarding.',
      category: FeatureCategory.playback,
      icon: Icons.open_in_new_rounded,
    ),
    AppFeature(
      id: 'variable_speed',
      title: 'Variable Playback Speed & Pitch Correction',
      description:
          'Speed adjustment from 0.5x to 2.0x with automatic audio pitch compensation so voices sound natural.',
      category: FeatureCategory.playback,
      icon: Icons.speed_rounded,
      isNew: true,
    ),
    AppFeature(
      id: 'dialogue_boost',
      title: 'Dialogue Boost & Night Mode (DRC)',
      description:
          'Dynamic Range Compression boosting low dialogue while softening loud explosions and music.',
      category: FeatureCategory.playback,
      icon: Icons.record_voice_over_rounded,
      isNew: true,
    ),
    AppFeature(
      id: 'volume_boost',
      title: 'Volume Amplification (Up to 200%)',
      description:
          'Gain boost above 100% for quiet movie sound mixes and low-volume TV hardware speakers.',
      category: FeatureCategory.playback,
      icon: Icons.volume_up_rounded,
      isNew: true,
    ),
    AppFeature(
      id: 'adaptive_buffer',
      title: 'Adaptive Buffer Bar & Preload Cache',
      description:
          'Configurable network cache sizes with secondary progress indicator displaying ahead buffer depth.',
      category: FeatureCategory.playback,
      icon: Icons.stacked_bar_chart_rounded,
      isNew: true,
    ),
    AppFeature(
      id: 'sleep_timer',
      title: 'In-Player Sleep Timer',
      description:
          'Automatic playback pausing after 15, 30, 45, 60, 90 minutes or at the end of the current media.',
      category: FeatureCategory.playback,
      icon: Icons.bedtime_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'stats_for_nerds',
      title: 'Stats for Nerds (Live Tech HUD)',
      description:
          'Real-time HUD displaying active resolution, framerate, video/audio codecs, bitrate, dropped frames, and hardware decoder state.',
      category: FeatureCategory.playback,
      icon: Icons.analytics_rounded,
      isNew: true,
    ),
    AppFeature(
      id: 'pip_background',
      title: 'Picture-in-Picture & Background Playback',
      description:
          'Android native PiP windowing and optional audio-only background continuation when app is closed.',
      category: FeatureCategory.playback,
      icon: Icons.picture_in_picture_alt_rounded,
    ),
    AppFeature(
      id: 'aspect_ratio_control',
      title: 'Aspect Ratio & Scaling Options',
      description:
          'Instant toggle between Fit, Cover, Fill, 16:9, 4:3, and 21:9 stretch modes.',
      category: FeatureCategory.playback,
      icon: Icons.aspect_ratio_rounded,
    ),

    // 2. Audio & Subtitles
    AppFeature(
      id: 'subtitle_style_customizer',
      title: 'In-Player Subtitle Style Customizer',
      description:
          'Full control over subtitle font sizes (14–32px), color presets, shield opacity, and drop shadows.',
      category: FeatureCategory.audioSubtitles,
      icon: Icons.text_fields_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'subtitle_delay_sync',
      title: 'Subtitle Timing Offset Calibration',
      description:
          'Fine-tune subtitle timing delay from -10.0s to +10.0s in 0.1s increments to fix audio desync.',
      category: FeatureCategory.audioSubtitles,
      icon: Icons.av_timer_rounded,
    ),
    AppFeature(
      id: 'multi_audio_tracks',
      title: 'Multi-Track Audio & Dub Switcher',
      description:
          'Seamlessly switch between original audio tracks, multi-language dubs, and 5.1/7.1 surround tracks.',
      category: FeatureCategory.audioSubtitles,
      icon: Icons.audiotrack_rounded,
    ),
    AppFeature(
      id: 'auto_subtitle_loader',
      title: 'External Subtitles Auto-Loader',
      description:
          'Automatic parsing and loading of WebVTT and SubRip (SRT) subtitle files from stream providers.',
      category: FeatureCategory.audioSubtitles,
      icon: Icons.closed_caption_rounded,
    ),

    // 3. 10-Foot TV Experience
    AppFeature(
      id: 'tv_spatial_navigation',
      title: 'Strict D-Pad Spatial Navigation',
      description:
          'Built from the ground up for 5-way D-Pad remote control without requiring a mouse pointer or touch.',
      category: FeatureCategory.tvNavigation,
      icon: Icons.gamepad_rounded,
      isHighlight: true,
    ),
    AppFeature(
      id: 'tv_focusable_decorations',
      title: 'Cinematic Focus Rings & Scale Glow',
      description:
          'Cards elevate by 1.06x with illuminated focus borders and non-blocking scale animations.',
      category: FeatureCategory.tvNavigation,
      icon: Icons.filter_center_focus_rounded,
    ),
    AppFeature(
      id: 'tv_sidebar',
      title: 'Collapsible Leanback Sidebar',
      description:
          'Quick-access navigation rail that expands on focus and restores previous card selection.',
      category: FeatureCategory.tvNavigation,
      icon: Icons.menu_open_rounded,
    ),
    AppFeature(
      id: 'smart_back_unwind',
      title: 'Smart Back-Key Traversal',
      description:
          'First back press brings controls or sidebar into view; second back press opens exit confirmation without crashing.',
      category: FeatureCategory.tvNavigation,
      icon: Icons.arrow_back_rounded,
    ),
    AppFeature(
      id: 'dpad_seek_acceleration',
      title: 'D-Pad Remote Seek Acceleration',
      description:
          'Progressive seek increments (10s, 30s, 1m, 5m) on continuous remote arrow holding.',
      category: FeatureCategory.tvNavigation,
      icon: Icons.fast_forward_rounded,
    ),
    AppFeature(
      id: 'tv_keypad_input',
      title: 'TV D-Pad Numeric Keypad',
      description:
          'On-screen 3x4 spatial keypad for entering parental PIN codes and stream addresses via TV remote.',
      category: FeatureCategory.tvNavigation,
      icon: Icons.dialpad_rounded,
      isNew: true,
    ),

    // 4. Profiles & LAN Sync
    AppFeature(
      id: 'multi_profiles',
      title: 'Multi-Profile Viewer Management',
      description:
          'Create individual viewer profiles with custom avatars, accent colors, and personalized libraries.',
      category: FeatureCategory.profilesSync,
      icon: Icons.group_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'profile_isolation',
      title: 'Isolated Watch History & Progress',
      description:
          'Each profile maintains its own continue watching list, favorites, and watched episodes.',
      category: FeatureCategory.profilesSync,
      icon: Icons.history_rounded,
    ),
    AppFeature(
      id: 'parental_pin_lock',
      title: 'Parental PIN Security',
      description:
          'Protect profiles with a 4-digit numeric PIN; exiting a Kids Profile requires PIN authorization.',
      category: FeatureCategory.profilesSync,
      icon: Icons.lock_rounded,
      isNew: true,
    ),
    AppFeature(
      id: 'kids_content_filter',
      title: 'Kids Safe Mode & 18+ Filter',
      description:
          'Automatically filters out adult-flagged media and explicit content when in Kids profile mode.',
      category: FeatureCategory.profilesSync,
      icon: Icons.child_care_rounded,
    ),
    AppFeature(
      id: 'local_lan_sync',
      title: 'Local Wi-Fi / LAN P2P Sync',
      description:
          'Zero-cloud local network sync sharing watch history and favorites across devices on the same Wi-Fi.',
      category: FeatureCategory.profilesSync,
      icon: Icons.wifi_protected_setup_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'lan_peer_discovery',
      title: 'Automatic LAN Peer Discovery',
      description:
          'Zero-configuration UDP discovery finding active Exalere apps on the local network automatically.',
      category: FeatureCategory.profilesSync,
      icon: Icons.wifi_tethering_rounded,
      isNew: true,
    ),

    // 5. Binge & Smart Skip
    AppFeature(
      id: 'next_episode_card',
      title: 'Floating Next-Episode Binge Card',
      description:
          'Automatic floating countdown prompt in the last 30s of an episode allowing instant next episode transition.',
      category: FeatureCategory.bingeSkipping,
      icon: Icons.skip_next_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'auto_episode_sequencer',
      title: 'Cross-Season Episode Sequencer',
      description:
          'Automatically transitions from the season finale to S02E01 seamlessly without manual catalog search.',
      category: FeatureCategory.bingeSkipping,
      icon: Icons.queue_play_next_rounded,
    ),
    AppFeature(
      id: 'smart_skip_intro_outro',
      title: 'Auto Skip Intro & Outro',
      description:
          'Skip interval detection powered by community metadata with configurable automatic skipping.',
      category: FeatureCategory.bingeSkipping,
      icon: Icons.double_arrow_rounded,
    ),
    AppFeature(
      id: 'in_player_episode_selector',
      title: 'In-Player Episode Drawer',
      description:
          'Switch seasons and episodes directly during playback without exiting to the details page.',
      category: FeatureCategory.bingeSkipping,
      icon: Icons.video_library_rounded,
    ),

    // 6. Backup & Migration
    AppFeature(
      id: 'full_offline_backup',
      title: 'Full Offline Backup Bundles',
      description:
          'Export structured JSON bundles capturing profiles, favorites, watch progress, and settings.',
      category: FeatureCategory.backupRestore,
      icon: Icons.backup_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'local_file_backup',
      title: 'Local Storage File Exporter & Scanner',
      description:
          'Auto-detect and save backups directly to device Downloads/Documents folders.',
      category: FeatureCategory.backupRestore,
      icon: Icons.folder_zip_rounded,
    ),
    AppFeature(
      id: 'clipboard_migration',
      title: 'Instant Clipboard Migration',
      description:
          'One-click copy and paste of backup configurations across apps or devices.',
      category: FeatureCategory.backupRestore,
      icon: Icons.content_paste_rounded,
    ),
    AppFeature(
      id: 'merge_restore_strategy',
      title: 'Smart Merge vs Replace Restore',
      description:
          'Choose between unioning new data with existing libraries or performing a clean slate overwrite.',
      category: FeatureCategory.backupRestore,
      icon: Icons.call_merge_rounded,
    ),

    // 7. Offline Downloads
    AppFeature(
      id: 'direct_stream_player',
      title: 'Direct Stream & Link Player',
      description:
          'Play direct MP4, HLS (.m3u8), DASH (.mpd), or magnet links with full player capabilities.',
      category: FeatureCategory.downloads,
      icon: Icons.link_rounded,
    ),
    AppFeature(
      id: 'batch_download_queue',
      title: 'Background Multi-Stream Downloader',
      description:
          'Download full series seasons and movies with chunking, pause/resume, and speed metrics.',
      category: FeatureCategory.downloads,
      icon: Icons.downloading_rounded,
    ),
    AppFeature(
      id: 'offline_hub',
      title: 'Dedicated Offline Media Hub',
      description:
          'Manage downloaded files, check device storage footprint, and watch offline with resume tracking.',
      category: FeatureCategory.downloads,
      icon: Icons.offline_pin_rounded,
      isNew: true,
      isHighlight: true,
    ),

    // 8. Live TV & IPTV
    AppFeature(
      id: 'multi_m3u_playlists',
      title: 'Multi-Playlist M3U Manager',
      description:
          'Add, label, and manage multiple IPTV M3U playlists and regional channel feeds.',
      category: FeatureCategory.liveTv,
      icon: Icons.playlist_add_check_rounded,
      isNew: true,
    ),
    AppFeature(
      id: 'channel_favorites',
      title: 'Live TV Channel Favorites',
      description:
          'Pin your most-watched channels to the top of the TV guide for instant access.',
      category: FeatureCategory.liveTv,
      icon: Icons.star_rounded,
      isNew: true,
    ),
    AppFeature(
      id: 'country_language_filters',
      title: 'Global Country & Language Filtering',
      description:
          'Filter through thousands of free global channels by country flags and broadcast languages.',
      category: FeatureCategory.liveTv,
      icon: Icons.flag_rounded,
    ),
    AppFeature(
      id: 'in_player_channel_zapper',
      title: 'In-Player Channel Zapper',
      description:
          'Browse and switch live TV channels in real-time without leaving full-screen playback.',
      category: FeatureCategory.liveTv,
      icon: Icons.tune_rounded,
    ),

    // 9. Themes & UI Styling
    AppFeature(
      id: 'dynamic_theme_engine',
      title: 'Cinematic Theme Engine',
      description:
          'Curated themes including Netflix Black, Midnight Slate, OLED True Black, and Cyberpunk Neon.',
      category: FeatureCategory.theming,
      icon: Icons.color_lens_rounded,
    ),
    AppFeature(
      id: 'corner_geometry',
      title: 'Card Corner Geometry Customizer',
      description:
          'Customize corner radius styling across all UI elements between Sharp, Rounded, and Pill.',
      category: FeatureCategory.theming,
      icon: Icons.rounded_corner_rounded,
    ),
    AppFeature(
      id: 'surface_morphism',
      title: 'Glassmorphic Surface Blur',
      description:
          'Toggle between Standard, Glassmorphic frosted glass, and Flat UI surface modes.',
      category: FeatureCategory.theming,
      icon: Icons.blur_on_rounded,
    ),
    AppFeature(
      id: 'ui_scale_multiplier',
      title: 'Granular UI Scale Multiplier',
      description:
          'Scale entire application layout (0.8x to 1.3x) for optimal visibility from 10 feet away.',
      category: FeatureCategory.theming,
      icon: Icons.zoom_in_rounded,
    ),
    AppFeature(
      id: 'custom_font_family',
      title: 'Dynamic System Font Selector',
      description:
          'Switch typography between Inter, Roboto, Outfit, and monospace fonts.',
      category: FeatureCategory.theming,
      icon: Icons.font_download_rounded,
    ),
    AppFeature(
      id: 'theme_token_system',
      title: 'Semantic Design Token Architecture',
      description:
          '100% tokenized color and spacing system ensuring perfect contrast across dark rooms and bright panels.',
      category: FeatureCategory.theming,
      icon: Icons.palette_outlined,
    ),

    // 10. Universal Addons
    AppFeature(
      id: 'stremio_addon_protocol',
      title: 'Stremio Addon Protocol Compatibility',
      description:
          'Full support for standard Stremio v3 HTTP protocol addon manifests and stream endpoints.',
      category: FeatureCategory.plugins,
      icon: Icons.extension_rounded,
      isHighlight: true,
    ),
    AppFeature(
      id: 'direct_stream_resolver',
      title: 'Direct Stream Resolver Engine',
      description:
          'Universal stream resolution pipeline supporting direct MP4, MKV, HLS, and DASH streams.',
      category: FeatureCategory.plugins,
      icon: Icons.alt_route_rounded,
      isHighlight: true,
    ),
    AppFeature(
      id: 'community_addon_catalog',
      title: 'Curated Community Plugin Store',
      description:
          'Explore, install, toggle, and auto-update verified community extensions with one tap.',
      category: FeatureCategory.plugins,
      icon: Icons.storefront_rounded,
    ),
    AppFeature(
      id: 'zero_proprietary_sdks',
      title: 'PolyForm Noncommercial Compliance',
      description:
          '100% open-source architecture with zero proprietary tracker SDKs or telemetry.',
      category: FeatureCategory.plugins,
      icon: Icons.verified_user_rounded,
    ),
    // 11. Discovery, Playlists, Fine-Tuning & Voice
    AppFeature(
      id: 'audio_delay_sync',
      title: 'Audio & Subtitle Sync Delay Fine-Tuning',
      description:
          'Micro-delay offset steppers (±100ms, ±500ms, Reset) in player audio sheet to eliminate lipsync drift and timing mismatch.',
      category: FeatureCategory.audioSubtitles,
      icon: Icons.tune_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'aspect_ratio_zoom_fit',
      title: 'Aspect Ratio & Letterbox Crop/Zoom',
      description:
          'Cycle across 4 modes (Original Fit, Zoom & Crop to remove black bars, 16:9 Stretch Fill, and Fit Width) with instant toast feedback.',
      category: FeatureCategory.playback,
      icon: Icons.aspect_ratio_rounded,
      isNew: true,
    ),
    AppFeature(
      id: 'movie_franchises_hub',
      title: 'Franchise Universes & Movie Collections Hub',
      description:
          'Chronologically ordered franchise universes (Marvel Cinematic Universe, Harry Potter, Star Wars) on Movie Details with instant streaming.',
      category: FeatureCategory.discovery,
      icon: Icons.movie_filter_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'cast_filmography_deep_dive',
      title: 'Cast & Crew Filmography Deep-Dive',
      description:
          'Interactive actor and director profile pages with biographical details, headshots, and categorized filmography shelves.',
      category: FeatureCategory.discovery,
      icon: Icons.recent_actors_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'custom_user_playlists',
      title: 'Custom User Playlists & Curated Lists',
      description:
          'Create, curate, rename, and manage custom watchlists and playlists scoped per user profile with one-tap add/remove.',
      category: FeatureCategory.profilesSync,
      icon: Icons.playlist_add_check_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'voice_search_dpad',
      title: 'Voice Search for TV & Mobile (Speech-to-Text)',
      description:
          'Hands-free voice recognition with live speech-to-text transcription, pulsing microphone waveform, and D-Pad focus integration.',
      category: FeatureCategory.tvNavigation,
      icon: Icons.mic_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'video_picture_tuner',
      title: 'In-Player Video Picture Tuner (Calibration)',
      description:
          'Real-time picture calibration inside playback with presets (Standard, Cinema Warm, Vivid OLED, Shadow Boost, High Contrast) and precision stepper tuning.',
      category: FeatureCategory.playback,
      icon: Icons.tune_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'web_companion_remote',
      title: 'Web Companion TV Remote (Zero-Install)',
      description:
          'Turn any smartphone into a responsive TV remote over local Wi-Fi with D-Pad trackpad, media controls, and direct phone keyboard typing into TV.',
      category: FeatureCategory.tvNavigation,
      icon: Icons.phonelink_ring_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'deep_discovery_filter',
      title: 'Deep Catalog Discovery & Multi-Filter Engine',
      description:
          'Explore media across decades, multi-genre combinations, minimum TMDB ratings, and customizable sort orders in an adaptive TV grid.',
      category: FeatureCategory.discovery,
      icon: Icons.explore_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'reviews_and_ratings_hub',
      title: 'Rotten Tomatoes, Metacritic & Reviews Hub',
      description:
          'Multi-source score aggregation with Tomatometer and Metascore estimates, content certification advisories, and readable community reviews on details screens.',
      category: FeatureCategory.discovery,
      icon: Icons.rate_review_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'quick_switcher_overlay',
      title: 'Quick Switcher (Media Multitasker Overlay)',
      description:
          'Slide-out multitasking overlay providing instant Continue Watching resumption with progress indicators and one-tap teleports across the app.',
      category: FeatureCategory.tvNavigation,
      icon: Icons.bolt_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'storage_hygiene_cleaner',
      title: 'Storage Hygiene & Stream Cache Cleaner',
      description:
          'Clean stream buffer fragments, purge image and poster caches, inspect storage footprint, and maintain device health on storage-constrained TV and mobile devices.',
      category: FeatureCategory.backupRestore,
      icon: Icons.cleaning_services_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'voice_search_overlay',
      title: 'Smart Voice Search & Dictation Overlay',
      description:
          'Search across all catalogs with microphone speech recognition, pulsating waveform feedback, and instant transcription chips on TV, Mobile, and Desktop.',
      category: FeatureCategory.discovery,
      icon: Icons.mic_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'smart_intro_outro_detector',
      title: 'Smart Intro & Outro ("Skip Intro") Auto-Detector',
      description:
          'Intelligent heuristic intro/credits detector with floating D-Pad focusable Skip pill, auto-skip intro preference, and seamless episode binge progression.',
      category: FeatureCategory.bingeSkipping,
      icon: Icons.fast_forward_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'watch_party_sync',
      title: 'Watch Together / Virtual Watch Party (LAN Sync)',
      description:
          'Synchronize playback across multiple devices on your local Wi-Fi with host conductor controls, client drift compensation, and 4-digit PIN pairing.',
      category: FeatureCategory.profilesSync,
      icon: Icons.groups_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'audio_equalizer_clarity',
      title: 'Audio Equalizer & Volume Normalizer (Dialog Boost & Night Mode)',
      description:
          'Hardware audio DSP with Dynamic Normalizer for explosive dynamic range suppression, vocal dialog frequency enhancement (2.5 kHz), bass boost, and pre-amp volume scaling.',
      category: FeatureCategory.audioSubtitles,
      icon: Icons.graphic_eq_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'audio_only_ambient_mode',
      title: 'Background Audio-Only Mode & Ambient Screen Saver',
      description:
          'Stream concerts, podcasts, and music in low-power audio-only mode, turning off GPU video surfaces and rendering a dimmed cinematic ambient artwork carousel.',
      category: FeatureCategory.playback,
      icon: Icons.music_note_rounded,
      isNew: true,
      isHighlight: true,
    ),
    AppFeature(
      id: 'viewing_habits_insights',
      title: 'Viewing Habits, Statistics & "Year in Review" Insights',
      description:
          'Private, offline-first personal streaming stats dashboard featuring total watch time, movies vs series breakdown, top genres distribution, and peak viewing habits.',
      category: FeatureCategory.discovery,
      icon: Icons.insights_rounded,
      isNew: true,
      isHighlight: true,
    ),
  ];

  static int get totalCount => allFeatures.length;

  static List<AppFeature> getBy(FeatureCategory category) =>
      allFeatures.where((f) => f.category == category).toList();

  static List<AppFeature> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return allFeatures;
    return allFeatures
        .where(
          (f) =>
              f.title.toLowerCase().contains(q) ||
              f.description.toLowerCase().contains(q) ||
              f.category.label.toLowerCase().contains(q),
        )
        .toList();
  }
}
