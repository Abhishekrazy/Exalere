import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';

/// Helper service to detect whether the current runtime environment is Android TV / Google TV / Fire TV.
class TvService {
  static const MethodChannel _channel = MethodChannel('com.exalere/tv_mode');
  static bool? _isTvCache;

  /// Returns `true` if the device is identified as a TV platform.
  static Future<bool> isTvDevice() async {
    if (_isTvCache != null) return _isTvCache!;

    if (kIsWeb) {
      _isTvCache = false;
      return false;
    }

    if (!Platform.isAndroid) {
      _isTvCache = false;
      return false;
    }

    try {
      final bool? isTv = await _channel.invokeMethod<bool>('isTv');
      _isTvCache = isTv ?? false;
      debugPrint('TvService: Native TV detection result = $_isTvCache');
      return _isTvCache!;
    } catch (e) {
      debugPrint('TvService: Error invoking native isTv channel: $e');
      _isTvCache = false;
      return false;
    }
  }

  /// Manually override or reset the cached TV mode (e.g. for user preferences or testing).
  static void setOverride(bool? isTv) {
    _isTvCache = isTv;
  }
}
