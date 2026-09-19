import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Service managing device speech recognition for voice search across
/// Android TV, Android Mobile, and supported desktop environments.
class VoiceSearchService {
  static final VoiceSearchService _instance = VoiceSearchService._internal();
  factory VoiceSearchService() => _instance;
  VoiceSearchService._internal();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _hasPermission = false;
  bool _isAvailable = false;

  bool get isAvailable => _isAvailable;
  bool get isListening => _speech.isListening;
  bool get hasPermission => _hasPermission;

  /// Initializes the speech recognizer engine and checks microphone availability.
  Future<bool> initialize({
    Function(SpeechRecognitionError error)? onError,
    Function(String status)? onStatus,
  }) async {
    if (_isInitialized) return _isAvailable;
    try {
      _isAvailable = await _speech.initialize(
        onError: (err) {
          debugPrint(
            'VoiceSearchService error: ${err.errorMsg} (permanent: ${err.permanent})',
          );
          onError?.call(err);
        },
        onStatus: (status) {
          debugPrint('VoiceSearchService status: $status');
          onStatus?.call(status);
        },
        debugLogging: kDebugMode,
      );
      _hasPermission = await _speech.hasPermission;
      _isInitialized = true;
      return _isAvailable;
    } catch (e) {
      debugPrint('VoiceSearchService init failed: $e');
      _isAvailable = false;
      _isInitialized = true;
      return false;
    }
  }

  /// Begins listening for voice commands and streaming intermediate/final results.
  Future<void> startListening({
    required Function(String words, bool isFinal) onResult,
    Function(SpeechRecognitionError error)? onError,
    Function(String status)? onStatus,
    Function(double level)? onSoundLevelChange,
  }) async {
    if (!_isInitialized) {
      final available = await initialize(onError: onError, onStatus: onStatus);
      if (!available) {
        onError?.call(
          SpeechRecognitionError(
            'Speech recognition is not available or microphone permission was denied.',
            true,
          ),
        );
        return;
      }
    }

    if (_speech.isListening) {
      await stopListening();
    }

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: onSoundLevelChange,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        cancelOnError: true,
        partialResults: true,
      );
    } catch (e) {
      debugPrint('VoiceSearchService listen failed: $e');
      onError?.call(
        SpeechRecognitionError('Failed to start listening: $e', false),
      );
    }
  }

  /// Stops listening and processes final speech segment.
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  /// Cancels active listening without processing results.
  Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }
}
