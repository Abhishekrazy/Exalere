import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../models/media_details.dart';
import '../../../models/stream_source.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tv_focusable.dart';

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
    return showModalBottomSheet(
      context: context,
      backgroundColor: context.tokens.surfaceElevated,
      shape: context.tokens.getShapeBorder(
        radius: context.tokens.cardRadius + 8,
      ),
      isScrollControlled: true,
      builder: (ctx) {
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

class _PlayerAudioSubtitlesSheetState extends State<PlayerAudioSubtitlesSheet> {
  AudioTrack? _tempAudioTrack;
  AudioTrackOption? _tempDubOption;
  String _tempAudioLabel = 'Default [Original]';

  bool _tempSubtitlesEnabled = false;
  SubtitleTrack? _tempSubtitleTrack;
  SubtitleOption? _tempExternalSub;
  String _tempSubtitleLabel = 'Off';

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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final isLandscape = screenWidth > screenHeight;
    final isCompact = screenHeight < 550 || screenWidth < 500;
    final modalHeight = isLandscape
        ? (screenHeight * 0.85).clamp(240.0, 380.0)
        : (screenHeight * 0.55).clamp(300.0, 460.0);

    return SafeArea(
      child: SizedBox(
        height: modalHeight,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 18 : 28,
            isCompact ? 16 : 22,
            isCompact ? 18 : 28,
            isCompact ? 12 : 16,
          ),
          child: Column(
            children: [
              // 2-Column Content: Audio on Left, Subtitles on Right
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Audio Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 12),
                            child: Text(
                              'Audio',
                              style: TextStyle(
                                color: context.tokens.textPrimary,
                                fontSize: isCompact ? 16 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              clipBehavior: Clip.none,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 4,
                              ),
                              children: [
                                // Embedded audio tracks
                                ...widget.validAudioTracks.map((track) {
                                  final label =
                                      PlayerAudioSubtitlesSheet.cleanTrackName(
                                        track.title ?? track.language,
                                        isAudio: true,
                                      );
                                  final isSelected =
                                      _tempDubOption == null &&
                                      _tempAudioTrack == track;
                                  return _buildTrackCard(
                                    context: context,
                                    label: label,
                                    isSelected: isSelected,
                                    autofocus: isSelected,
                                    isCompact: isCompact,
                                    onTap: () {
                                      setState(() {
                                        _tempAudioTrack = track;
                                        _tempDubOption = null;
                                        _tempAudioLabel = label;
                                      });
                                    },
                                  );
                                }),

                                // Provider Dubbed Versions
                                ...widget.availableDubs.map((dub) {
                                  final label =
                                      PlayerAudioSubtitlesSheet.cleanTrackName(
                                        dub.label.isNotEmpty
                                            ? dub.label
                                            : dub.language,
                                        isAudio: true,
                                      );
                                  final isSelected = _tempDubOption == dub;
                                  return _buildTrackCard(
                                    context: context,
                                    label: label,
                                    isSelected: isSelected,
                                    isCompact: isCompact,
                                    onTap: () {
                                      setState(() {
                                        _tempDubOption = dub;
                                        _tempAudioTrack = null;
                                        _tempAudioLabel = label;
                                      });
                                    },
                                  );
                                }),

                                if (widget.validAudioTracks.isEmpty &&
                                    widget.availableDubs.isEmpty)
                                  _buildTrackCard(
                                    context: context,
                                    label: 'Default [Original]',
                                    isSelected: true,
                                    isCompact: isCompact,
                                    onTap: () {},
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: isCompact ? 20 : 36),

                    // 2. Subtitles Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 12),
                            child: Text(
                              'Subtitles',
                              style: TextStyle(
                                color: context.tokens.textPrimary,
                                fontSize: isCompact ? 16 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              clipBehavior: Clip.none,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 4,
                              ),
                              children: [
                                // "Off" Option
                                _buildTrackCard(
                                  context: context,
                                  label: 'Off',
                                  isSelected: !_tempSubtitlesEnabled,
                                  autofocus: !_tempSubtitlesEnabled,
                                  isCompact: isCompact,
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
                                  final label =
                                      PlayerAudioSubtitlesSheet.cleanTrackName(
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
                                    isSelected: isSelected,
                                    isCompact: isCompact,
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
                                  final label =
                                      PlayerAudioSubtitlesSheet.cleanTrackName(
                                        sub.name,
                                        isAudio: false,
                                      );
                                  final isSelected =
                                      _tempSubtitlesEnabled &&
                                      _tempExternalSub == sub;
                                  return _buildTrackCard(
                                    context: context,
                                    label: label,
                                    isSelected: isSelected,
                                    isCompact: isCompact,
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
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Footer Action Buttons (Cancel & Apply)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Cancel Button
                  TvFocusable(
                    shape: context.tokens.shapePill,
                    borderRadius: context.tokens.borderRadiusPill,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 18 : 22,
                        vertical: isCompact ? 8 : 10,
                      ),
                      decoration: context.tokens.getShapeDecoration(
                        color: context.tokens.surfaceElevated.withValues(
                          alpha: 0.85,
                        ),
                        radius: context.tokens.cardRadius * 2,
                        side: BorderSide(
                          color: context.tokens.borderSubtle,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: context.tokens.textPrimary,
                          fontSize: isCompact ? 12 : 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Apply Button
                  TvFocusable(
                    shape: context.tokens.shapePill,
                    borderRadius: context.tokens.borderRadiusPill,
                    onTap: () {
                      // 1. Apply audio selection if modified
                      if (_tempDubOption != null) {
                        widget.onSelectDubOption(_tempDubOption!);
                      } else if (_tempAudioTrack != null) {
                        widget.onSelectAudioTrack(
                          _tempAudioTrack!,
                          _tempAudioLabel,
                        );
                      }

                      // 2. Apply subtitle selection
                      if (!_tempSubtitlesEnabled) {
                        widget.onDisableSubtitles();
                      } else if (_tempExternalSub != null) {
                        widget.onSelectExternalSubtitle(_tempExternalSub!);
                      } else if (_tempSubtitleTrack != null) {
                        widget.onSelectSubtitleTrack(
                          _tempSubtitleTrack!,
                          _tempSubtitleLabel,
                        );
                      }

                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 20 : 24,
                        vertical: isCompact ? 8 : 10,
                      ),
                      decoration: context.tokens.getShapeDecoration(
                        color: context.tokens.textPrimary,
                        radius: context.tokens.cardRadius * 2,
                      ),
                      child: Text(
                        'Apply',
                        style: TextStyle(
                          color: theme.colorScheme.surface,
                          fontSize: isCompact ? 12 : 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackCard({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isCompact,
    bool autofocus = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TvFocusable(
        scaleFactor: 1.02,
        autofocus: autofocus,
        shape: context.tokens.shapeSm,
        borderRadius: context.tokens.borderRadiusSm,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 14,
            vertical: isCompact ? 8 : 10,
          ),
          decoration: context.tokens.getShapeDecoration(
            color: isSelected
                ? context.tokens.primaryAccent.withValues(alpha: 0.18)
                : context.tokens.surfaceCard.withValues(alpha: 0.5),
            radius: context.tokens.cardRadius * 0.7,
            side: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary
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
                    ? theme.colorScheme.primary
                    : context.tokens.textMuted.withValues(alpha: 0.6),
                size: isCompact ? 16 : 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? context.tokens.textPrimary
                        : context.tokens.textSecondary,
                    fontSize: isCompact ? 12 : 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
