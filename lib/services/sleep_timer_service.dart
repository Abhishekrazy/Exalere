import 'dart:async';
import 'package:flutter/foundation.dart';

/// Manages an in-player sleep timer that automatically pauses playback
/// after a designated countdown or at the end of the current media.
class SleepTimerService extends ChangeNotifier {
  static final SleepTimerService _instance = SleepTimerService._internal();
  factory SleepTimerService() => _instance;
  SleepTimerService._internal();

  Timer? _countdownTimer;
  DateTime? _targetTime;
  String? _activeLabel;
  VoidCallback? _onTimerExpired;

  bool get isActive =>
      _targetTime != null && _targetTime!.isAfter(DateTime.now());

  Duration? get remainingTime {
    if (!isActive) return null;
    final diff = _targetTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String? get activeLabel => _activeLabel;

  /// Formats the remaining countdown as MM:SS or HH:MM:SS.
  String get formattedRemaining {
    final rem = remainingTime;
    if (rem == null) return '';
    final h = rem.inHours;
    final m = rem.inMinutes.remainder(60);
    final s = rem.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  /// Starts a countdown for [duration] with optional [label] description.
  void setTimer({
    required Duration duration,
    String? label,
    required VoidCallback onExpire,
  }) {
    cancelTimer();

    if (duration <= Duration.zero) return;

    _targetTime = DateTime.now().add(duration);
    _activeLabel = label ?? '${duration.inMinutes}m';
    _onTimerExpired = onExpire;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isActive) {
        timer.cancel();
        _triggerExpiration();
      } else {
        notifyListeners();
      }
    });

    notifyListeners();
  }

  /// Cancels any currently active countdown timer.
  void cancelTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _targetTime = null;
    _activeLabel = null;
    _onTimerExpired = null;
    notifyListeners();
  }

  void _triggerExpiration() {
    final callback = _onTimerExpired;
    cancelTimer();
    callback?.call();
  }

  @override
  void dispose() {
    cancelTimer();
    super.dispose();
  }
}
