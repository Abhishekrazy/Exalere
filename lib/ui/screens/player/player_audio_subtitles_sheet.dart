import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../models/media_details.dart';
import '../../../models/stream_source.dart';
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
  final bool initialSubtitlesEnabled;
  final SubtitleTrack? initialSubtitleTrack;
  final SubtitleOption? initialExternalSubtitle;

  final void Function(AudioTrackOption dub) onSelectDubOption;
  final void Function(AudioTrack track, String label) onSelectAudioTrack;
  final void Function() onDisableSubtitles;
  final void Function(SubtitleOption externalSub) onSelectExternalSubtitle;
  final void Function(SubtitleTrack track, String label) onSelectSubtitleTrack;

  const PlayerAudioSubtitlesSheet({
    super.key,
    required this.validAudioTracks,
    required this.availableDubs,
    required this.validSubtitleTracks,
    required this.externalSubtitles,
    this.initialAudioTrack,
    required this.initialSubtitlesEnabled,
    this.initialSubtitleTrack,
    this.initialExternalSubtitle,
    required this.onSelectDubOption,
    required this.onSelectAudioTrack,
    required this.onDisableSubtitles,
    required this.onSelectExternalSubtitle,
    required this.onSelectSubtitleTrack,
  });

  /// Displays the full-screen Audio & Subtitles language selector route.
  static Future<void> show({
    required BuildContext context,
    required List<AudioTrack> validAudioTracks,
    required List<AudioTrackOption> availableDubs,
    required List<SubtitleTrack> validSubtitleTracks,
    required List<SubtitleOption> externalSubtitles,
    AudioTrack? initialAudioTrack,
    required bool initialSubtitlesEnabled,
    SubtitleTrack? initialSubtitleTrack,
    SubtitleOption? initialExternalSubtitle,
    required void Function(AudioTrackOption dub) onSelectDubOption,
    required void Function(AudioTrack track, String label) onSelectAudioTrack,
    required void Function() onDisableSubtitles,
    required void Function(SubtitleOption externalSub) onSelectExternalSubtitle,
    required void Function(SubtitleTrack track, String label)
    onSelectSubtitleTrack,
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
            initialSubtitlesEnabled: initialSubtitlesEnabled,
            initialSubtitleTrack: initialSubtitleTrack,
            initialExternalSubtitle: initialExternalSubtitle,
            onSelectDubOption: onSelectDubOption,
            onSelectAudioTrack: onSelectAudioTrack,
            onDisableSubtitles: onDisableSubtitles,
            onSelectExternalSubtitle: onSelectExternalSubtitle,
            onSelectSubtitleTrack: onSelectSubtitleTrack,
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

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tempAudioTrack = widget.initialAudioTrack;
    _tempSubtitlesEnabled = widget.initialSubtitlesEnabled;
    _tempSubtitleTrack = widget.initialSubtitleTrack;
    _tempExternalSub = widget.initialExternalSubtitle;
    if (!_tempSubtitlesEnabled) {
      _tempSubtitleLabel = 'Off';
    }

    // Resolve initial label for audio
    if (_tempAudioTrack != null) {
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
                        ? _buildTwoColumnLayout(context)
                        : _buildTabLayout(context),
                  ),
                  const Divider(height: 1),
                  _buildBottomBar(context),
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
              gradient: LinearGradient(
                colors: [
                  context.tokens.primaryAccent,
                  context.tokens.secondaryAccent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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

  Widget _buildTwoColumnLayout(BuildContext context) {
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
                Expanded(child: _buildAudioList(context)),
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
                Expanded(child: _buildSubtitlesList(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabLayout(BuildContext context) {
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
                child: _buildAudioList(context),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildSubtitlesList(context),
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

  Widget _buildAudioList(BuildContext context) {
    final hasAudioTracks =
        widget.validAudioTracks.isNotEmpty || widget.availableDubs.isNotEmpty;

    if (!hasAudioTracks) {
      return ListView(
        clipBehavior: Clip.none,
        cacheExtent: 350.0,
        children: [
          _buildTrackCard(
            context: context,
            label: 'Default [Original]',
            badgeLabel: 'DEFAULT',
            isSelected: true,
            onTap: () {},
          ),
        ],
      );
    }

    return ListView(
      clipBehavior: Clip.none,
      cacheExtent: 350.0,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        // 1. Embedded Audio Tracks
        ...widget.validAudioTracks.map((track) {
          final label = PlayerAudioSubtitlesSheet.cleanTrackName(
            track.title ?? track.language,
            isAudio: true,
          );
          final isSelected = _tempDubOption == null && _tempAudioTrack == track;
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
            },
          );
        }),

        // 2. Provider Dubbed Audio Versions
        ...widget.availableDubs.map((dub) {
          final label = PlayerAudioSubtitlesSheet.cleanTrackName(
            dub.label.isNotEmpty ? dub.label : dub.language,
            isAudio: true,
          );
          final isSelected = _tempDubOption == dub;

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
            },
          );
        }),
      ],
    );
  }

  Widget _buildSubtitlesList(BuildContext context) {
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
              _tempSubtitleTrack == track;

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
            },
          );
        }),

        // External Subtitles
        ...widget.externalSubtitles.map((sub) {
          final label = PlayerAudioSubtitlesSheet.cleanTrackName(
            sub.name,
            isAudio: false,
          );
          final isSelected = _tempSubtitlesEnabled && _tempExternalSub == sub;

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
            },
          );
        }),
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
