import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

import '../../services/voice_search_service.dart';
import '../theme/app_tokens.dart';
import 'tv_focusable.dart';

/// Modal dialog for voice search with pulsating sound waves,
/// real-time transcription, and fallback keyboard dictation.
class VoiceSearchDialog extends StatefulWidget {
  final ValueChanged<String> onQuerySubmitted;

  const VoiceSearchDialog({super.key, required this.onQuerySubmitted});

  static Future<String?> show(
    BuildContext context, {
    required ValueChanged<String> onQuerySubmitted,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: context.tokens.shadowColor.withValues(alpha: 0.85),
      builder: (_) => VoiceSearchDialog(onQuerySubmitted: onQuerySubmitted),
    );
  }

  @override
  State<VoiceSearchDialog> createState() => _VoiceSearchDialogState();
}

class _VoiceSearchDialogState extends State<VoiceSearchDialog>
    with SingleTickerProviderStateMixin {
  final VoiceSearchService _voiceService = VoiceSearchService();
  final TextEditingController _textFallbackController = TextEditingController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _spokenWords = '';
  bool _isListening = false;
  bool _hasError = false;
  String _errorMessage = '';
  double _soundLevel = 0.0;
  Timer? _autoSubmitTimer;

  static const List<String> _quickSuggestions = [
    'Trending Movies',
    'Top Rated Series',
    'Christopher Nolan',
    'Marvel Studios',
    'Anime Action',
    'Sci-Fi 2024',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startListening();
  }

  @override
  void dispose() {
    _autoSubmitTimer?.cancel();
    _pulseController.dispose();
    _textFallbackController.dispose();
    _voiceService.stopListening();
    super.dispose();
  }

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
      _hasError = false;
      _errorMessage = '';
      _spokenWords = '';
    });

    try {
      await _voiceService.startListening(
        onResult: (words, isFinal) {
          if (!mounted) return;
          setState(() {
            _spokenWords = words;
            _textFallbackController.text = words;
          });

          _autoSubmitTimer?.cancel();
          if (isFinal && words.trim().isNotEmpty) {
            _autoSubmitTimer = Timer(const Duration(milliseconds: 900), () {
              if (mounted) _submitQuery(words);
            });
          }
        },
        onSoundLevelChange: (level) {
          if (!mounted) return;
          setState(() {
            _soundLevel = (level / 10.0).clamp(0.0, 1.0);
          });
        },
        onError: (SpeechRecognitionError error) {
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _hasError = true;
            _errorMessage = error.errorMsg;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _hasError = true;
        _errorMessage = 'Could not initialize microphone: $e';
      });
    }
  }

  void _submitQuery(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;
    Navigator.of(context).pop(clean);
    widget.onQuerySubmitted(clean);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width * 0.75).clamp(320.0, 560.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: tokens.borderRadiusLg,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: dialogWidth,
            padding: const EdgeInsets.all(28),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceElevated.withValues(alpha: 0.94),
              radius: tokens.cardRadius * 1.5,
              side: BorderSide(
                color: tokens.borderFocus.withValues(alpha: 0.5),
                width: 1.2,
              ),
              shadows: [
                BoxShadow(
                  color: tokens.shadowColor.withValues(alpha: 0.5),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title & Close
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.mic_rounded,
                          color: tokens.primaryAccent,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Voice Search',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    TvFocusable(
                      onTap: () => Navigator.of(context).pop(),
                      scaleFactor: 1.1,
                      shape: tokens.shapeSm,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: tokens.surfaceCard,
                          borderRadius: tokens.borderRadiusSm,
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: tokens.textSecondary,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Animated Microphone Ripple
                GestureDetector(
                  onTap: () {
                    if (_isListening) {
                      _voiceService.stopListening();
                      setState(() => _isListening = false);
                    } else {
                      _startListening();
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final scale = _isListening
                          ? (_pulseAnimation.value + (_soundLevel * 0.2))
                          : 1.0;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_isListening) ...[
                            Container(
                              width: 110 * scale,
                              height: 110 * scale,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                              ),
                            ),
                            Container(
                              width: 90 * scale,
                              height: 90 * scale,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.22,
                                ),
                              ),
                            ),
                          ],
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isListening
                                  ? theme.colorScheme.primary
                                  : tokens.surfaceCard,
                              border: Border.all(
                                color: tokens.borderFocus,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: _isListening ? 0.4 : 0.1,
                                  ),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isListening
                                  ? Icons.mic_rounded
                                  : Icons.mic_off_rounded,
                              color: _isListening
                                  ? theme.colorScheme.onPrimary
                                  : tokens.textMuted,
                              size: 34,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),

                // Status or Transcribed Text
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.surfaceCard,
                    borderRadius: tokens.borderRadiusMd,
                    border: Border.all(
                      color: _hasError
                          ? theme.colorScheme.error
                          : tokens.borderSubtle,
                    ),
                  ),
                  child: Text(
                    _hasError
                        ? _errorMessage
                        : (_spokenWords.isNotEmpty
                              ? _spokenWords
                              : (_isListening
                                    ? 'Listening... Speak now'
                                    : 'Tap mic to speak')),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: _spokenWords.isNotEmpty
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: _hasError
                          ? theme.colorScheme.error
                          : (_spokenWords.isNotEmpty
                                ? tokens.textPrimary
                                : tokens.textMuted),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Quick suggestions chips
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Try saying or selecting:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickSuggestions.map((suggestion) {
                    return TvFocusable(
                      scaleFactor: 1.05,
                      shape: tokens.shapeSm,
                      onTap: () => _submitQuery(suggestion),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surfaceCard,
                          borderRadius: tokens.borderRadiusSm,
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 14,
                              color: tokens.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              suggestion,
                              style: TextStyle(
                                fontSize: 13,
                                color: tokens.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TvFocusable(
                      scaleFactor: 1.04,
                      shape: tokens.shapeSm,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surfaceCard,
                          borderRadius: tokens.borderRadiusSm,
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TvFocusable(
                      autofocus: true,
                      scaleFactor: 1.04,
                      shape: tokens.shapeSm,
                      onTap: () {
                        if (_spokenWords.trim().isNotEmpty) {
                          _submitQuery(_spokenWords);
                        } else if (_isListening) {
                          _voiceService.stopListening();
                          setState(() => _isListening = false);
                        } else {
                          _startListening();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: tokens.borderRadiusSm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _spokenWords.trim().isNotEmpty
                                  ? Icons.search_rounded
                                  : Icons.mic_rounded,
                              size: 16,
                              color: theme.colorScheme.onPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _spokenWords.trim().isNotEmpty
                                  ? 'Search'
                                  : 'Listen',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
