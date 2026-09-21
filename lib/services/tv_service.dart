import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';

/// Helper service to detect whether the current runtime environment is Android TV / Google TV / Fire TV.
class TvService {
  static const MethodChannel _channel = MethodChannel('com.exalere/tv_mode');
  static bool? _isTvCache;
  static bool? _nativeTvHardware;

  /// Returns `true` if the device is identified as a native TV platform hardware.
  static Future<bool> isNativeTvDevice() async {
    if (_nativeTvHardware != null) return _nativeTvHardware!;

    if (kIsWeb || !Platform.isAndroid) {
      _nativeTvHardware = false;
      return false;
    }

    try {
      final bool? isTv = await _channel.invokeMethod<bool>('isTv');
      _nativeTvHardware = isTv ?? false;
      debugPrint(
        'TvService: Native TV hardware detection = $_nativeTvHardware',
      );
      return _nativeTvHardware!;
    } catch (e) {
      debugPrint('TvService: Error invoking native isTv channel: $e');
      _nativeTvHardware = false;
      return false;
    }
  }

  /// Returns `true` if the device is identified as a TV platform (respecting overrides).
  static Future<bool> isTvDevice() async {
    if (_isTvCache != null) return _isTvCache!;
    final isNative = await isNativeTvDevice();
    _isTvCache = isNative;
    return _isTvCache!;
  }

  /// Manually override or reset the cached TV mode (e.g. for user preferences or testing).
  static void setOverride(bool? isTv) {
    _isTvCache = isTv;
  }

  /// Manually override or reset the native TV hardware detection (for unit tests).
  static void setNativeTvOverride(bool? isTv) {
    _nativeTvHardware = isTv;
  }

  static List<String>? _cachedAbis;

  /// Returns the device's supported ABIs in priority order from native Android.
  static Future<List<String>> getSupportedAbis() async {
    if (_cachedAbis != null) return _cachedAbis!;
    if (kIsWeb || !Platform.isAndroid) return const [];
    try {
      final List<dynamic>? list = await _channel.invokeMethod<List<dynamic>>(
        'getSupportedAbis',
      );
      _cachedAbis = list?.map((e) => e.toString()).toList() ?? const [];
      return _cachedAbis!;
    } catch (_) {
      return const [];
    }
  }

  /// Manually override or reset the cached ABIs (e.g. for unit testing).
  static void setSupportedAbisOverride(List<String>? abis) {
    _cachedAbis = abis;
  }
}
