import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import '../../../models/media_details.dart';
import '../../../models/stream_source.dart';
import '../../../providers/app_provider.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_button.dart';
import '../../widgets/tv_focusable.dart';

/// Full-screen modal screen for selecting Audio Languages, Dubs, and Subtitles.
///
/// Provides a clean, 10-foot TV D-Pad navigable experience across both landscape
/// and portrait orientations.
class PlayerAudioSubtitlesSheet extends StatefulWidget {
  final List<AudioTrack> validAudioTracks;
  final List<AudioTrackOption> availableDubs;
  final List<SubtitleTrack> validSubtitleTracks;
  final List<SubtitleOption> externalSubtitles;
  final AudioTrack? initialAudioTrack;
  final AudioTrackOption? initialDubOption;
  final String? initialAudioLabel;
  final bool initialSubtitlesEnabled;
  final SubtitleTrack? initialSubtitleTrack;
  final SubtitleOption? initialExternalSubtitle;
  final double initialSubtitleDelay;
  final double initialAudioDelay;

  final void Function(AudioTrackOption dub) onSelectDubOption;
  final void Function(AudioTrack track, String label) onSelectAudioTrack;
  final void Function() onDisableSubtitles;
  final void Function(SubtitleOption externalSub) onSelectExternalSubtitle;
  final void Function(SubtitleTrack track, String label) onSelectSubtitleTrack;
  final void Function(double delay)? onAdjustSubtitleDelay;
  final void Function(double delay)? onAdjustAudioDelay;

  final bool isNightMode;
  final void Function(bool enabled)? onToggleNightMode;
  final double audioVolume;
  final void Function(double volume)? onVolumeBoostChanged;
  final double playbackSpeed;
  final void Function(double speed)? onSpeedSelected;

  const PlayerAudioSubtitlesSheet({
    super.key,
    required this.validAudioTracks,
    required this.availableDubs,
    required this.validSubtitleTracks,
    required this.externalSubtitles,
    this.initialAudioTrack,
    this.initialDubOption,
    this.initialAudioLabel,
    required this.initialSubtitlesEnabled,
    this.initialSubtitleTrack,
    this.initialExternalSubtitle,
    this.initialSubtitleDelay = 0.0,
    this.initialAudioDelay = 0.0,
    required this.onSelectDubOption,
    required this.onSelectAudioTrack,
    required this.onDisableSubtitles,
    required this.onSelectExternalSubtitle,
    required this.onSelectSubtitleTrack,
    this.onAdjustSubtitleDelay,
    this.onAdjustAudioDelay,
    this.isNightMode = false,
    this.onToggleNightMode,
    this.audioVolume = 100.0,
    this.onVolumeBoostChanged,
    this.playbackSpeed = 1.0,
    this.onSpeedSelected,
  });

  /// Displays the full-screen Audio & Subtitles language selector route.
  static Future<void> show({
    required BuildContext context,
    required List<AudioTrack> validAudioTracks,
    required List<AudioTrackOption> availableDubs,
    required List<SubtitleTrack> validSubtitleTracks,
    required List<SubtitleOption> externalSubtitles,
    AudioTrack? initialAudioTrack,
    AudioTrackOption? initialDubOption,
    String? initialAudioLabel,
    required bool initialSubtitlesEnabled,
    SubtitleTrack? initialSubtitleTrack,
    SubtitleOption? initialExternalSubtitle,
    double initialSubtitleDelay = 0.0,
    double initialAudioDelay = 0.0,
    required void Function(AudioTrackOption dub) onSelectDubOption,
    required void Function(AudioTrack track, String label) onSelectAudioTrack,
    required void Function() onDisableSubtitles,
    required void Function(SubtitleOption externalSub) onSelectExternalSubtitle,
    required void Function(SubtitleTrack track, String label)
    onSelectSubtitleTrack,
    void Function(double delay)? onAdjustSubtitleDelay,
    void Function(double delay)? onAdjustAudioDelay,
    bool isNightMode = false,
    void Function(bool enabled)? onToggleNightMode,
    double audioVolume = 100.0,
    void Function(double volume)? onVolumeBoostChanged,
    double playbackSpeed = 1.0,
    void Function(double speed)? onSpeedSelected,
  }) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: context.tokens.shadowColor.withValues(alpha: 0.85),
        pageBuilder: (ctx, animation, secondaryAnimation) {
          return PlayerAudioSubtitlesSheet(
            validAudioTracks: validAudioTracks,
            availableDubs: availableDubs,
            validSubtitleTracks: validSubtitleTracks,
            externalSubtitles: externalSubtitles,
            initialAudioTrack: initialAudioTrack,
            initialDubOption: initialDubOption,
            initialAudioLabel: initialAudioLabel,
            initialSubtitlesEnabled: initialSubtitlesEnabled,
            initialSubtitleTrack: initialSubtitleTrack,
            initialExternalSubtitle: initialExternalSubtitle,
            initialSubtitleDelay: initialSubtitleDelay,
            initialAudioDelay: initialAudioDelay,
            onSelectDubOption: onSelectDubOption,
            onSelectAudioTrack: onSelectAudioTrack,
            onDisableSubtitles: onDisableSubtitles,
            onSelectExternalSubtitle: onSelectExternalSubtitle,
            onSelectSubtitleTrack: onSelectSubtitleTrack,
            onAdjustSubtitleDelay: onAdjustSubtitleDelay,
            onAdjustAudioDelay: onAdjustAudioDelay,
            isNightMode: isNightMode,
            onToggleNightMode: onToggleNightMode,
            audioVolume: audioVolume,
            onVolumeBoostChanged: onVolumeBoostChanged,
            playbackSpeed: playbackSpeed,
            onSpeedSelected: onSpeedSelected,
          );
        },
        transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  static String cleanTrackName(String? raw, {bool isAudio = true}) {
    if (raw == null || raw.trim().isEmpty) {
      return isAudio ? 'Default [Original]' : 'Unknown';
    }
    final trimmed = raw.trim();
    final lower = trimmed.toLowerCase();

    if (lower.contains('auto') || lower == 'default' || lower == 'und') {
      return 'Default [Original]';
    }

    const languages = {
      'hin': 'Hindi',
      'hi': 'Hindi',
      'hindi': 'Hindi',
      'eng': 'English',
      'en': 'English',
      'english': 'English',
      'tam': 'Tamil',
      'ta': 'Tamil',
      'tamil': 'Tamil',
      'tel': 'Telugu',
      'te': 'Telugu',
      'telugu': 'Telugu',
      'mal': 'Malayalam',
      'ml': 'Malayalam',
      'malayalam': 'Malayalam',
      'kan': 'Kannada',
      'kn': 'Kannada',
      'kannada': 'Kannada',
      'ben': 'Bengali',
      'bn': 'Bengali',
      'bengali': 'Bengali',
      'mar': 'Marathi',
      'mr': 'Marathi',
      'pan': 'Punjabi',
      'pa': 'Punjabi',
      'guj': 'Gujarati',
      'gu': 'Gujarati',
      'spa': 'Spanish',
      'es': 'Spanish',
      'spanish': 'Spanish',
      'fre': 'French',
      'fra': 'French',
      'fr': 'French',
      'french': 'French',
      'ger': 'German',
      'deu': 'German',
      'de': 'German',
      'german': 'German',
      'ita': 'Italian',
      'it': 'Italian',
      'italian': 'Italian',
      'jpn': 'Japanese',
      'ja': 'Japanese',
      'japanese': 'Japanese',
      'kor': 'Korean',
      'ko': 'Korean',
      'korean': 'Korean',
      'chi': 'Chinese',
      'zho': 'Chinese',
      'zh': 'Chinese',
      'chinese': 'Chinese',
      'rus': 'Russian',
      'ru': 'Russian',
      'russian': 'Russian',
      'ara': 'Arabic',
      'ar': 'Arabic',
      'arabic': 'Arabic',
      'por': 'Portuguese',
      'pt': 'Portuguese',
      'portuguese': 'Portuguese',
      'tha': 'Thai',
      'th': 'Thai',
      'vie': 'Vietnamese',
      'vi': 'Vietnamese',
      'ind': 'Indonesian',
      'id': 'Indonesian',
      'tur': 'Turkish',
      'tr': 'Turkish',
    };

    if (languages.containsKey(lower)) {
      return languages[lower]!;
    }

    for (final entry in languages.entries) {
      if (lower == entry.key ||
          lower.startsWith('${entry.key} ') ||
          lower.startsWith('${entry.key}-') ||
          lower.startsWith('${entry.key}_') ||
          lower.startsWith('${entry.key}(') ||
          lower.startsWith('${entry.key}[')) {
        if (lower.contains('original') || lower.contains('orig')) {
          return '${entry.value} [Original]';
        }
        if (lower.contains('audio description') ||
            lower.contains('descriptive') ||
            lower.contains('ad')) {
          return '${entry.value} - Audio Description';
        }
        if (lower.contains('cc') || lower.contains('sdh')) {
          return '${entry.value} (CC)';
        }
        return entry.value;
      }
    }

    if (lower.contains('original') || lower.contains('orig')) {
      final base = trimmed
          .replaceAll(RegExp(r'\[.*?\]|\(.*?\)', caseSensitive: false), '')
          .trim();
      return base.isNotEmpty ? '$base [Original]' : 'Original Audio';
    }

    final trackMatch = RegExp(
      r'Audio Track\s*\((.*?)\)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (trackMatch != null) {
      final inner = trackMatch.group(1)?.trim() ?? '';
      if (inner.toLowerCase() == 'auto') return 'Default [Original]';
      if (languages.containsKey(inner.toLowerCase())) {
        return languages[inner.toLowerCase()]!;
      }
      return 'Track $inner';
    }

    return trimmed;
  }

  @override
  State<PlayerAudioSubtitlesSheet> createState() =>
      _PlayerAudioSubtitlesSheetState();
}

class _PlayerAudioSubtitlesSheetState extends State<PlayerAudioSubtitlesSheet>
    with SingleTickerProviderStateMixin {
  AudioTrack? _tempAudioTrack;
  AudioTrackOption? _tempDubOption;
  String _tempAudioLabel = 'Default [Original]';

  bool _tempSubtitlesEnabled = false;
  SubtitleTrack? _tempSubtitleTrack;
  SubtitleOption? _tempExternalSub;
  String _tempSubtitleLabel = 'Off';
  late double _tempSubtitleDelay;
  late double _tempAudioDelay;
  bool _isAudioEnhancementsExpanded = false;
  bool _isAudioDelayExpanded = false;
  bool _isPlaybackSpeedExpanded = false;
  bool _isSubtitleDelayExpanded = false;
  bool _isStyleExpanded = false;

  late bool _tempNightMode;
  late double _tempAudioVolume;
  late double _tempPlaybackSpeed;

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tempAudioTrack = widget.initialAudioTrack;
    _tempDubOption = widget.initialDubOption;
    _tempSubtitlesEnabled = widget.initialSubtitlesEnabled;
    _tempSubtitleTrack = widget.initialSubtitleTrack;
    _tempExternalSub = widget.initialExternalSubtitle;
    _tempSubtitleDelay = widget.initialSubtitleDelay;
    _tempAudioDelay = widget.initialAudioDelay;
    _tempNightMode = widget.isNightMode;
    _tempAudioVolume = widget.audioVolume;
    _tempPlaybackSpeed = widget.playbackSpeed;
    if (!_tempSubtitlesEnabled) {
      _tempSubtitleLabel = 'Off';
    }

    // Resolve initial label for audio
    if (widget.initialAudioLabel != null &&
        widget.initialAudioLabel!.isNotEmpty) {
      _tempAudioLabel = widget.initialAudioLabel!;
    } else if (_tempDubOption != null) {
      _tempAudioLabel = PlayerAudioSubtitlesSheet.cleanTrackName(
        _tempDubOption!.label.isNotEmpty
            ? _tempDubOption!.label
            : _tempDubOption!.language,
        isAudio: true,
      );
    } else if (_tempAudioTrack != null) {
      _tempAudioLabel = PlayerAudioSubtitlesSheet.cleanTrackName(
        _tempAudioTrack!.title ?? _tempAudioTrack!.language,
        isAudio: true,
      );
    }

    // Resolve initial label for subtitles
    if (_tempSubtitlesEnabled) {
      if (_tempExternalSub != null) {
        _tempSubtitleLabel = PlayerAudioSubtitlesSheet.cleanTrackName(
          _tempExternalSub!.name,
          isAudio: false,
        );
      } else if (_tempSubtitleTrack != null) {
        _tempSubtitleLabel = PlayerAudioSubtitlesSheet.cleanTrackName(
          _tempSubtitleTrack!.title ?? _tempSubtitleTrack!.language,
          isAudio: false,
        );
      }
    }

    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _applyAndClose() {
    // 1. Apply audio selection if modified
    if (_tempDubOption != null) {
      widget.onSelectDubOption(_tempDubOption!);
    } else if (_tempAudioTrack != null) {
      widget.onSelectAudioTrack(_tempAudioTrack!, _tempAudioLabel);
    }

    // 2. Apply subtitle selection
    if (!_tempSubtitlesEnabled) {
      widget.onDisableSubtitles();
    } else if (_tempExternalSub != null) {
      widget.onSelectExternalSubtitle(_tempExternalSub!);
    } else if (_tempSubtitleTrack != null) {
      widget.onSelectSubtitleTrack(_tempSubtitleTrack!, _tempSubtitleLabel);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isLandscape = screenWidth > screenHeight;
    final isWide = screenWidth >= 640;

    bool isTv = false;
    try {
      isTv = context.watch<AppProvider>().isTvMode;
    } catch (_) {}

    return FocusScope(
      autofocus: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // 1. Dark frosted glass backdrop
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  color: context.tokens.canvasBackground.withValues(
                    alpha: 0.94,
                  ),
                ),
              ),
            ),

            // 2. Full-screen content layout
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopBar(context),
                  const Divider(height: 1),
                  Expanded(
                    child: isWide || isLandscape
                        ? _buildTwoColumnLayout(context, isTv: isTv)
                        : _buildTabLayout(context, isTv: isTv),
                  ),
                  if (!isTv) ...[
                    const Divider(height: 1),
                    _buildBottomBar(context),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Back / Close Button
          TvFocusable(
            autofocus: true,
            borderRadius: context.tokens.borderRadiusPill,
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.tokens.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: context.tokens.borderSubtle),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: context.tokens.textPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Icon badge
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.tokens.primaryAccent,
              borderRadius: context.tokens.borderRadiusSm,
            ),
            child: Icon(
              Icons.translate_rounded,
              color: theme.colorScheme.onPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Title & active selection subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audio & Subtitles',
                  style: TextStyle(
                    color: context.tokens.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Audio: $_tempAudioLabel  •  Subtitles: $_tempSubtitleLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.tokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Close button on far right
          TvFocusable(
            borderRadius: context.tokens.borderRadiusPill,
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.tokens.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: context.tokens.borderSubtle),
              ),
              child: Icon(
                Icons.close_rounded,
                color: context.tokens.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoColumnLayout(BuildContext context, {bool isTv = false}) {
    final totalAudio =
        widget.validAudioTracks.length + widget.availableDubs.length;
    final totalSubs =
        widget.validSubtitleTracks.length + widget.externalSubtitles.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Audio & Languages Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildColumnHeader(
                  context,
                  title: 'AUDIO & LANGUAGES',
                  count: totalAudio,
                  icon: Icons.record_voice_over_rounded,
                  accentColor: context.tokens.primaryAccent,
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildAudioList(context, isTv: isTv)),
              ],
            ),
          ),

          // Vertical separator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: VerticalDivider(
              width: 1,
              color: context.tokens.borderSubtle,
            ),
          ),

          // 2. Subtitles Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildColumnHeader(
                  context,
                  title: 'SUBTITLES',
                  count: totalSubs,
                  icon: Icons.subtitles_rounded,
                  accentColor: context.tokens.secondaryAccent,
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildSubtitlesList(context, isTv: isTv)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabLayout(BuildContext context, {bool isTv = false}) {
    final totalAudio =
        widget.validAudioTracks.length + widget.availableDubs.length;
    final totalSubs =
        widget.validSubtitleTracks.length + widget.externalSubtitles.length;

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: context.tokens.primaryAccent,
          indicatorWeight: 3,
          labelColor: context.tokens.textPrimary,
          unselectedLabelColor: context.tokens.textMuted,
          tabs: [
            Tab(text: 'Audio ($totalAudio)'),
            Tab(text: 'Subtitles ($totalSubs)'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildAudioList(context, isTv: isTv),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildSubtitlesList(context, isTv: isTv),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColumnHeader(
    BuildContext context, {
    required String title,
    required int count,
    required IconData icon,
    required Color accentColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accentColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: context.tokens.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: context.tokens.borderRadiusXs,
            border: Border.all(
              color: accentColor.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccordionSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    String? badgeText,
    required Widget child,
  }) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: tokens.getShapeDecoration(
        color: tokens.surfaceCard.withValues(alpha: 0.5),
        radius: tokens.cardRadius * 1.2,
        side: BorderSide(
          color: isExpanded
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : tokens.borderSubtle,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TvFocusable(
            scaleFactor: 1.02,
            borderRadius: tokens.borderRadiusSm,
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isExpanded
                        ? theme.colorScheme.primary
                        : tokens.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  if (badgeText != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: tokens.borderRadiusXs,
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.4,
                          ),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: tokens.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: child,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioEnhancementsContent(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Night Mode (Dialogue Boost) Row
        Row(
          children: [
            Icon(
              Icons.record_voice_over_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NIGHT MODE (DIALOGUE BOOST)',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Compresses dynamic audio range so quiet dialogue is clear.',
                    style: TextStyle(color: tokens.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TvFocusable(
              onTap: () {
                final next = !_tempNightMode;
                setState(() => _tempNightMode = next);
                widget.onToggleNightMode?.call(next);
              },
              child: Switch.adaptive(
                value: _tempNightMode,
                activeColor: theme.colorScheme.primary,
                onChanged: (val) {
                  setState(() => _tempNightMode = val);
                  widget.onToggleNightMode?.call(val);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 10),

        // 2. Audio Gain Volume Boost
        Row(
          children: [
            Icon(
              Icons.volume_up_rounded,
              size: 15,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'VOLUME GAIN BOOST',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            Text(
              '${_tempAudioVolume.toInt()}%',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [100.0, 125.0, 150.0, 200.0].map((vol) {
            final isSel = (_tempAudioVolume - vol).abs() < 1.0;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: TvFocusable(
                  onTap: () {
                    setState(() => _tempAudioVolume = vol);
                    widget.onVolumeBoostChanged?.call(vol);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: tokens.getShapeDecoration(
                      color: isSel
                          ? theme.colorScheme.primary.withValues(alpha: 0.22)
                          : tokens.surfaceElevated,
                      radius: tokens.cardRadius,
                      side: BorderSide(
                        color: isSel
                            ? theme.colorScheme.primary
                            : tokens.borderSubtle,
                        width: isSel ? 1.2 : 0.8,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${vol.toInt()}%',
                      style: TextStyle(
                        color: isSel
                            ? tokens.textPrimary
                            : tokens.textSecondary,
                        fontSize: 11,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPlaybackSpeedContent(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.speed_rounded,
              size: 15,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'PLAYBACK SPEED',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            Text(
              '${_tempPlaybackSpeed}x',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((rate) {
            final isSel = (_tempPlaybackSpeed - rate).abs() < 0.05;
            return TvFocusable(
              onTap: () {
                setState(() => _tempPlaybackSpeed = rate);
                widget.onSpeedSelected?.call(rate);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: tokens.getShapeDecoration(
                  color: isSel
                      ? theme.colorScheme.primary.withValues(alpha: 0.22)
                      : tokens.surfaceElevated,
                  radius: tokens.cardRadius,
                  side: BorderSide(
                    color: isSel
                        ? theme.colorScheme.primary
                        : tokens.borderSubtle,
                    width: isSel ? 1.2 : 0.8,
                  ),
                ),
                child: Text(
                  '${rate}x',
                  style: TextStyle(
                    color: isSel ? tokens.textPrimary : tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAudioList(BuildContext context, {bool isTv = false}) {
    final hasAudioTracks =
        widget.validAudioTracks.isNotEmpty || widget.availableDubs.isNotEmpty;

    return ListView(
      clipBehavior: Clip.none,
      cacheExtent: 350.0,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        // 1. Embedded Audio Tracks
        if (!hasAudioTracks)
          _buildTrackCard(
            context: context,
            label: 'Default [Original]',
            badgeLabel: 'DEFAULT',
            isSelected: true,
            onTap: () {},
          )
        else ...[
          ...widget.validAudioTracks.map((track) {
            final label = PlayerAudioSubtitlesSheet.cleanTrackName(
              track.title ?? track.language,
              isAudio: true,
            );
            final isSelected =
                _tempDubOption == null &&
                (_tempAudioTrack?.id == track.id ||
                    ((_tempAudioTrack == null ||
                            _tempAudioTrack?.id == 'auto') &&
                        track == widget.validAudioTracks.firstOrNull));
            final isOriginal =
                label.toLowerCase().contains('original') ||
                label.toLowerCase().contains('default');

            return _buildTrackCard(
              context: context,
              label: label,
              badgeLabel: isOriginal ? 'ORIGINAL' : 'EMBEDDED',
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  _tempAudioTrack = track;
                  _tempDubOption = null;
                  _tempAudioLabel = label;
                });
                if (isTv) {
                  widget.onSelectAudioTrack(track, label);
                }
              },
            );
          }),

          // 2. Provider Dubbed Audio Versions
          ...widget.availableDubs.map((dub) {
            final label = PlayerAudioSubtitlesSheet.cleanTrackName(
              dub.label.isNotEmpty ? dub.label : dub.language,
              isAudio: true,
            );
            final isSelected =
                _tempDubOption == dub ||
                (_tempDubOption?.subjectId == dub.subjectId &&
                    _tempDubOption?.language == dub.language);

            return _buildTrackCard(
              context: context,
              label: label,
              badgeLabel: 'DUB',
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  _tempDubOption = dub;
                  _tempAudioTrack = null;
                  _tempAudioLabel = label;
                });
                if (isTv) {
                  widget.onSelectDubOption(dub);
                }
              },
            );
          }),
        ],

        const SizedBox(height: 8),

        // 3. Collapsible Audio Settings Accordions
        _buildAccordionSection(
          context: context,
          title: 'AUDIO ENHANCEMENTS',
          icon: Icons.graphic_eq_rounded,
          badgeText: _tempNightMode
              ? 'Night Mode'
              : (_tempAudioVolume != 100.0
                    ? '${_tempAudioVolume.toInt()}%'
                    : null),
          isExpanded: _isAudioEnhancementsExpanded,
          onToggle: () {
            setState(() {
              _isAudioEnhancementsExpanded = !_isAudioEnhancementsExpanded;
            });
          },
          child: _buildAudioEnhancementsContent(context),
        ),
        _buildAccordionSection(
          context: context,
          title: 'AUDIO SYNC DELAY',
          icon: Icons.sync_rounded,
          badgeText: _tempAudioDelay != 0.0
              ? '${_tempAudioDelay > 0 ? '+' : ''}${_tempAudioDelay.toStringAsFixed(1)}s'
              : null,
          isExpanded: _isAudioDelayExpanded,
          onToggle: () {
            setState(() {
              _isAudioDelayExpanded = !_isAudioDelayExpanded;
            });
          },
          child: _buildAudioDelayControl(context, isTv: isTv),
        ),
        _buildAccordionSection(
          context: context,
          title: 'PLAYBACK SPEED',
          icon: Icons.speed_rounded,
          badgeText: _tempPlaybackSpeed != 1.0
              ? '${_tempPlaybackSpeed}x'
              : null,
          isExpanded: _isPlaybackSpeedExpanded,
          onToggle: () {
            setState(() {
              _isPlaybackSpeedExpanded = !_isPlaybackSpeedExpanded;
            });
          },
          child: _buildPlaybackSpeedContent(context),
        ),
      ],
    );
  }

  void _adjustSubtitleDelay(double delta) {
    final next = double.parse(
      (_tempSubtitleDelay + delta).clamp(-10.0, 10.0).toStringAsFixed(2),
    );
    setState(() {
      _tempSubtitleDelay = next;
    });
    widget.onAdjustSubtitleDelay?.call(next);
  }

  void _resetSubtitleDelay() {
    setState(() {
      _tempSubtitleDelay = 0.0;
    });
    widget.onAdjustSubtitleDelay?.call(0.0);
  }

  void _adjustAudioDelay(double delta) {
    final next = double.parse(
      (_tempAudioDelay + delta).clamp(-5.0, 5.0).toStringAsFixed(2),
    );
    setState(() {
      _tempAudioDelay = next;
    });
    widget.onAdjustAudioDelay?.call(next);
  }

  void _resetAudioDelay() {
    setState(() {
      _tempAudioDelay = 0.0;
    });
    widget.onAdjustAudioDelay?.call(0.0);
  }

  Widget _buildAudioDelayControl(BuildContext context, {bool isTv = false}) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    final String delayText;
    if (_tempAudioDelay == 0.0) {
      delayText = '0.0s (In Sync)';
    } else if (_tempAudioDelay > 0) {
      delayText = '+${_tempAudioDelay.toStringAsFixed(1)}s (Delayed)';
    } else {
      delayText = '${_tempAudioDelay.toStringAsFixed(1)}s (Advanced)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.sync_rounded,
              size: 15,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'AUDIO SYNC DELAY',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _tempAudioDelay == 0.0
                    ? tokens.surfaceElevated
                    : theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: tokens.borderRadiusXs,
                border: Border.all(
                  color: _tempAudioDelay == 0.0
                      ? tokens.borderSubtle
                      : theme.colorScheme.primary.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Text(
                delayText,
                style: TextStyle(
                  color: _tempAudioDelay == 0.0
                      ? tokens.textMuted
                      : theme.colorScheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildDelayButton(
              context,
              label: '-0.5s',
              onTap: () => _adjustAudioDelay(-0.5),
            ),
            const SizedBox(width: 6),
            _buildDelayButton(
              context,
              label: '-0.1s',
              onTap: () => _adjustAudioDelay(-0.1),
            ),
            const SizedBox(width: 6),
            _buildDelayButton(
              context,
              label: 'Reset',
              isReset: true,
              onTap: _resetAudioDelay,
            ),
            const SizedBox(width: 6),
            _buildDelayButton(
              context,
              label: '+0.1s',
              onTap: () => _adjustAudioDelay(0.1),
            ),
            const SizedBox(width: 6),
            _buildDelayButton(
              context,
              label: '+0.5s',
              onTap: () => _adjustAudioDelay(0.5),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubtitleDelayControl(BuildContext context, {bool isTv = false}) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    final String delayText;
    if (_tempSubtitleDelay == 0.0) {
      delayText = '0.0s (In Sync)';
    } else if (_tempSubtitleDelay > 0) {
      delayText = '+${_tempSubtitleDelay.toStringAsFixed(1)}s (Delayed)';
    } else {
      delayText = '${_tempSubtitleDelay.toStringAsFixed(1)}s (Advanced)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.sync_rounded,
              size: 15,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'SYNC TIMING OFFSET',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _tempSubtitleDelay == 0.0
                    ? tokens.surfaceElevated
                    : theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: tokens.borderRadiusXs,
                border: Border.all(
                  color: _tempSubtitleDelay == 0.0
                      ? tokens.borderSubtle
                      : theme.colorScheme.primary.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Text(
                delayText,
                style: TextStyle(
                  color: _tempSubtitleDelay == 0.0
                      ? tokens.textMuted
                      : theme.colorScheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildDelayButton(
              context,
              label: '-0.5s',
              onTap: () => _adjustSubtitleDelay(-0.5),
            ),
            const SizedBox(width: 6),
            _buildDelayButton(
              context,
              label: '-0.1s',
              onTap: () => _adjustSubtitleDelay(-0.1),
            ),
            const SizedBox(width: 6),
            _buildDelayButton(
              context,
              label: 'Reset',
              isReset: true,
              onTap: _resetSubtitleDelay,
            ),
            const SizedBox(width: 6),
            _buildDelayButton(
              context,
              label: '+0.1s',
              onTap: () => _adjustSubtitleDelay(0.1),
            ),
            const SizedBox(width: 6),
            _buildDelayButton(
              context,
              label: '+0.5s',
              onTap: () => _adjustSubtitleDelay(0.5),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDelayButton(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
    bool isReset = false,
  }) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Expanded(
      child: TvFocusable(
        scaleFactor: 1.05,
        borderRadius: tokens.borderRadiusSm,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: tokens.getShapeDecoration(
            color: isReset
                ? tokens.surfaceElevated.withValues(alpha: 0.7)
                : theme.colorScheme.primary.withValues(alpha: 0.1),
            radius: tokens.cardRadius,
            side: BorderSide(
              color: isReset
                  ? tokens.borderSubtle
                  : theme.colorScheme.primary.withValues(alpha: 0.3),
              width: 0.8,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isReset ? tokens.textSecondary : tokens.textPrimary,
                fontSize: 11.5,
                fontWeight: isReset ? FontWeight.w600 : FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitleAppearanceControl(
    BuildContext context, {
    bool isTv = false,
  }) {
    final tokens = context.tokens;
    final appProv = context.watch<AppProvider>();
    final style = appProv.subtitleStyle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Subtitle Preview Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: tokens.canvasBackground.withValues(alpha: 0.85),
            borderRadius: tokens.borderRadiusSm,
            border: Border.all(
              color: tokens.borderSubtle.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: style.resolveBackgroundColor(),
                borderRadius: tokens.borderRadiusXs,
              ),
              child: Text(
                'Exalere Subtitle Preview Text',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: (style.fontSize * (isTv ? 1.05 : 0.85)).clamp(
                    13.0,
                    32.0,
                  ),
                  color: style.resolveTextColor(context),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  shadows: style.resolveShadows(tokens.shadowColor),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 1. Font Size
        Text(
          'TEXT SIZE',
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildStyleOptionChip(
              context,
              label: 'Small',
              isSelected: style.fontSize <= 18.5,
              onTap: () =>
                  appProv.setSubtitleStyle(style.copyWith(fontSize: 18.0)),
            ),
            const SizedBox(width: 6),
            _buildStyleOptionChip(
              context,
              label: 'Medium',
              isSelected: style.fontSize > 18.5 && style.fontSize <= 23.0,
              onTap: () =>
                  appProv.setSubtitleStyle(style.copyWith(fontSize: 22.0)),
            ),
            const SizedBox(width: 6),
            _buildStyleOptionChip(
              context,
              label: 'Large',
              isSelected: style.fontSize > 23.0 && style.fontSize <= 27.5,
              onTap: () =>
                  appProv.setSubtitleStyle(style.copyWith(fontSize: 26.0)),
            ),
            const SizedBox(width: 6),
            _buildStyleOptionChip(
              context,
              label: 'Extra Large',
              isSelected: style.fontSize > 27.5,
              onTap: () =>
                  appProv.setSubtitleStyle(style.copyWith(fontSize: 30.0)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 2. Font Color
        Text(
          'TEXT COLOR',
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildStyleOptionChip(
              context,
              label: 'White',
              isSelected: style.colorPreset.toLowerCase() == 'white',
              onTap: () => appProv.setSubtitleStyle(
                style.copyWith(colorPreset: 'white'),
              ),
            ),
            const SizedBox(width: 6),
            _buildStyleOptionChip(
              context,
              label: 'Yellow',
              isSelected: style.colorPreset.toLowerCase() == 'yellow',
              onTap: () => appProv.setSubtitleStyle(
                style.copyWith(colorPreset: 'yellow'),
              ),
            ),
            const SizedBox(width: 6),
            _buildStyleOptionChip(
              context,
              label: 'Cyan',
              isSelected: style.colorPreset.toLowerCase() == 'cyan',
              onTap: () =>
                  appProv.setSubtitleStyle(style.copyWith(colorPreset: 'cyan')),
            ),
            const SizedBox(width: 6),
            _buildStyleOptionChip(
              context,
              label: 'Green',
              isSelected: style.colorPreset.toLowerCase() == 'green',
              onTap: () => appProv.setSubtitleStyle(
                style.copyWith(colorPreset: 'green'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 3. Background Box Opacity
        Text(
          'BACKGROUND SHIELD',
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildStyleOptionChip(
              context,
              label: 'None',
              isSelected: style.backgroundOpacity <= 0.05,
              onTap: () => appProv.setSubtitleStyle(
                style.copyWith(backgroundOpacity: 0.0),
              ),
            ),
            const SizedBox(width: 6),
            _buildStyleOptionChip(
              context,
              label: 'Subtle (35%)',
              isSelected:
                  style.backgroundOpacity > 0.05 &&
                  style.backgroundOpacity <= 0.5,
              onTap: () => appProv.setSubtitleStyle(
                style.copyWith(backgroundOpacity: 0.35),
              ),
            ),
            const SizedBox(width: 6),
            _buildStyleOptionChip(
              context,
              label: 'Dark (70%)',
              isSelected: style.backgroundOpacity > 0.5,
              onTap: () => appProv.setSubtitleStyle(
                style.copyWith(backgroundOpacity: 0.70),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 4. Shadow / Outline
        Text(
          'OUTLINE & SHADOW',
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildStyleOptionChip(
              context,
              label: 'None',
              isSelected: style.shadowStrength.toLowerCase() == 'none',
              onTap: () => appProv.setSubtitleStyle(
                style.copyWith(shadowStrength: 'none'),
              ),
            ),
            const SizedBox(width: 6),
            _buildStyleOptionChip(
              context,
              label: 'Subtle',
              isSelected: style.shadowStrength.toLowerCase() == 'subtle',
              onTap: () => appProv.setSubtitleStyle(
                style.copyWith(shadowStrength: 'subtle'),
              ),
            ),
            const SizedBox(width: 6),
            _buildStyleOptionChip(
              context,
              label: 'Strong',
              isSelected: style.shadowStrength.toLowerCase() == 'strong',
              onTap: () => appProv.setSubtitleStyle(
                style.copyWith(shadowStrength: 'strong'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStyleOptionChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Expanded(
      child: TvFocusable(
        scaleFactor: 1.05,
        borderRadius: tokens.borderRadiusSm,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: tokens.getShapeDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.22)
                : tokens.surfaceElevated.withValues(alpha: 0.6),
            radius: tokens.cardRadius * 0.8,
            side: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary
                  : tokens.borderSubtle,
              width: isSelected ? 1.2 : 0.8,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? theme.colorScheme.primary
                    : tokens.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitlesList(BuildContext context, {bool isTv = false}) {
    return ListView(
      clipBehavior: Clip.none,
      cacheExtent: 350.0,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        // "Off" Option
        _buildTrackCard(
          context: context,
          label: 'Off',
          badgeLabel: 'DISABLED',
          isSelected: !_tempSubtitlesEnabled,
          onTap: () {
            setState(() {
              _tempSubtitlesEnabled = false;
              _tempSubtitleTrack = null;
              _tempExternalSub = null;
              _tempSubtitleLabel = 'Off';
            });
            if (isTv) {
              widget.onDisableSubtitles();
            }
          },
        ),

        // Embedded Subtitle Tracks
        ...widget.validSubtitleTracks.map((track) {
          final label = PlayerAudioSubtitlesSheet.cleanTrackName(
            track.title ?? track.language,
            isAudio: false,
          );
          final isSelected =
              _tempSubtitlesEnabled &&
              _tempExternalSub == null &&
              _tempSubtitleTrack?.id == track.id;

          return _buildTrackCard(
            context: context,
            label: label,
            badgeLabel: 'EMBEDDED',
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _tempSubtitlesEnabled = true;
                _tempSubtitleTrack = track;
                _tempExternalSub = null;
                _tempSubtitleLabel = label;
              });
              if (isTv) {
                widget.onSelectSubtitleTrack(track, label);
              }
            },
          );
        }),

        // External Subtitles
        ...widget.externalSubtitles.map((sub) {
          final label = PlayerAudioSubtitlesSheet.cleanTrackName(
            sub.name,
            isAudio: false,
          );
          final isSelected =
              _tempSubtitlesEnabled &&
              (_tempExternalSub == sub || _tempExternalSub?.url == sub.url);

          return _buildTrackCard(
            context: context,
            label: label,
            badgeLabel: 'ONLINE',
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _tempSubtitlesEnabled = true;
                _tempExternalSub = sub;
                _tempSubtitleTrack = null;
                _tempSubtitleLabel = label;
              });
              if (isTv) {
                widget.onSelectExternalSubtitle(sub);
              }
            },
          );
        }),

        const SizedBox(height: 8),

        // Collapsible Accordions for Subtitle Settings
        _buildAccordionSection(
          context: context,
          title: 'SUBTITLE SYNC DELAY',
          icon: Icons.sync_rounded,
          badgeText: _tempSubtitleDelay != 0.0
              ? '${_tempSubtitleDelay > 0 ? '+' : ''}${_tempSubtitleDelay.toStringAsFixed(1)}s'
              : null,
          isExpanded: _isSubtitleDelayExpanded,
          onToggle: () {
            setState(() {
              _isSubtitleDelayExpanded = !_isSubtitleDelayExpanded;
            });
          },
          child: _buildSubtitleDelayControl(context, isTv: isTv),
        ),
        _buildAccordionSection(
          context: context,
          title: 'SUBTITLE APPEARANCE & STYLING',
          icon: Icons.palette_rounded,
          isExpanded: _isStyleExpanded,
          onToggle: () {
            setState(() {
              _isStyleExpanded = !_isStyleExpanded;
            });
          },
          child: _buildSubtitleAppearanceControl(context, isTv: isTv),
        ),
      ],
    );
  }

  Widget _buildTrackCard({
    required BuildContext context,
    required String label,
    required String badgeLabel,
    required bool isSelected,
    required VoidCallback onTap,
    bool autofocus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TvFocusable(
        scaleFactor: 1.02,
        autofocus: autofocus,
        borderRadius: context.tokens.borderRadiusSm,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? context.tokens.primaryAccent.withValues(alpha: 0.16)
                : context.tokens.surfaceCard,
            borderRadius: context.tokens.borderRadiusSm,
            border: Border.all(
              color: isSelected
                  ? context.tokens.primaryAccent
                  : context.tokens.borderSubtle,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? context.tokens.primaryAccent
                    : context.tokens.textMuted.withValues(alpha: 0.5),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected
                        ? context.tokens.textPrimary
                        : context.tokens.textSecondary,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.tokens.primaryAccent.withValues(alpha: 0.2)
                      : context.tokens.surfaceElevated,
                  borderRadius: context.tokens.borderRadiusXs,
                  border: Border.all(
                    color: isSelected
                        ? context.tokens.primaryAccent.withValues(alpha: 0.4)
                        : context.tokens.borderSubtle,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: isSelected
                        ? context.tokens.primaryAccent
                        : context.tokens.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: context.tokens.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Select audio language and subtitles, then tap Apply to resume playback.',
              style: TextStyle(color: context.tokens.textMuted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 16),
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.sm,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 10),
          AppButton.primary(
            label: 'Apply',
            icon: const Icon(Icons.check_rounded),
            size: AppButtonSize.sm,
            onTap: _applyAndClose,
          ),
        ],
      ),
    );
  }
}
