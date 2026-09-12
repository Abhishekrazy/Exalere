import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service managing Android Picture-in-Picture (PiP) capabilities.
class PipService {
  PipService._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static final PipService instance = PipService._internal();

  static const MethodChannel _channel = MethodChannel('com.exalere/pip');

  /// Notifies listeners when the Android activity enters or leaves PiP mode.
  final ValueNotifier<bool> isInPipMode = ValueNotifier<bool>(false);

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onPipModeChanged') {
      final inPip = call.arguments as bool? ?? false;
      isInPipMode.value = inPip;
    }
  }

  /// Checks if the current Android device/OS supports Picture-in-Picture.
  Future<bool> isPipSupported() async {
    if (!Platform.isAndroid) return false;
    try {
      final supported = await _channel.invokeMethod<bool>('isPipSupported');
      return supported ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Explicitly requests the host Android activity to enter Picture-in-Picture mode.
  Future<bool> enterPip({int numerator = 16, int denominator = 9}) async {
    if (!Platform.isAndroid) return false;
    try {
      final entered = await _channel.invokeMethod<bool>('enterPip', {
        'numerator': numerator,
        'denominator': denominator,
      });
      return entered ?? false;
    } catch (e) {
      debugPrint('PipService.enterPip error: $e');
      return false;
    }
  }

  /// Enables or disables automatic entry into PiP when the user swipes home or minimizes the app.
  Future<void> setAutoEnterEnabled(
    bool enabled, {
    int numerator = 16,
    int denominator = 9,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setPipAutoEnterEnabled', {
        'enabled': enabled,
        'numerator': numerator,
        'denominator': denominator,
      });
    } catch (e) {
      debugPrint('PipService.setAutoEnterEnabled error: $e');
    }
  }
}
