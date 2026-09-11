import 'dart:io';

import 'package:flutter/services.dart';

/// Service for managing hardware device screen brightness and media volume
/// via native platform channels (Android WindowManager & AudioManager).
class DeviceControlsService {
  static const MethodChannel _channel = MethodChannel(
    'com.exalere/device_controls',
  );

  /// Retrieves the current screen brightness level (0.01 to 1.0).
  static Future<double> getBrightness() async {
    if (!Platform.isAndroid) return 1.0;
    try {
      final res = await _channel.invokeMethod<double>('getBrightness');
      return (res ?? 0.5).clamp(0.01, 1.0);
    } catch (_) {
      return 0.5;
    }
  }

  /// Sets the hardware window brightness override (0.01 to 1.0).
  static Future<void> setBrightness(double brightness) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setBrightness', {
        'brightness': brightness.clamp(0.01, 1.0),
      });
    } catch (_) {}
  }

  /// Resets the hardware window brightness override back to system default.
  static Future<void> resetBrightness() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('resetBrightness');
    } catch (_) {}
  }

  /// Retrieves the current media stream volume (0.0 to 1.0).
  static Future<double> getVolume() async {
    if (!Platform.isAndroid) return 0.5;
    try {
      final res = await _channel.invokeMethod<double>('getVolume');
      return (res ?? 0.5).clamp(0.0, 1.0);
    } catch (_) {
      return 0.5;
    }
  }

  /// Sets the hardware media stream volume (0.0 to 1.0).
  static Future<void> setVolume(double volume) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setVolume', {
        'volume': volume.clamp(0.0, 1.0),
      });
    } catch (_) {}
  }
}
