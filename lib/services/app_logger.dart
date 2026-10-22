import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How much the app records.
///
/// Declared most-severe-first so a numeric comparison can express "at least this
/// severe": with a level of [info], errors and warnings are kept but debug noise
/// is dropped.
enum LogLevel {
  /// Record nothing.
  off,

  /// Failures only.
  error,

  /// Failures and warnings.
  warn,

  /// Failures, warnings and ordinary events (the default).
  info,

  /// Everything, including chatty diagnostics.
  debug;

  String get label {
    switch (this) {
      case LogLevel.off:
        return 'Off';
      case LogLevel.error:
        return 'Errors only';
      case LogLevel.warn:
        return 'Warnings';
      case LogLevel.info:
        return 'Normal';
      case LogLevel.debug:
        return 'Verbose';
    }
  }

  String get description {
    switch (this) {
      case LogLevel.off:
        return 'Record nothing';
      case LogLevel.error:
        return 'Only failures';
      case LogLevel.warn:
        return 'Failures and warnings';
      case LogLevel.info:
        return 'Failures, warnings and events';
      case LogLevel.debug:
        return 'Everything, including diagnostics';
    }
  }

  static LogLevel fromName(String? raw) {
    for (final level in LogLevel.values) {
      if (level.name == raw) return level;
    }
    return LogLevel.info;
  }
}

/// One captured line.
class LogEntry {
  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String message;

  String get timeLabel {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get formatted => '[$timeLabel] ${level.name.toUpperCase()}: $message';
}

/// In-app logging with a user-selectable level.
///
/// The app already logs through `debugPrint` in well over a hundred places, so
/// rather than convert them all this intercepts `debugPrint` itself. Every
/// existing call site is then captured for free, and the previous handler is
/// still invoked so console/`flutter logs` output is unchanged.
///
/// Captured lines are held in a bounded in-memory buffer. Logs are diagnostic and
/// potentially large, so they are deliberately not written to preferences.
class AppLogger extends ChangeNotifier {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  static const String _levelKey = 'user_log_level';
  static const int maxEntries = 500;

  /// `debugPrint` carries no severity, so it is inferred from the text. Kept
  /// deliberately simple and documented so behaviour is predictable.
  static final RegExp _errorPattern = RegExp(
    r'\b(error|exception|failed|failure|fatal|refused|cannot|unable)\b',
    caseSensitive: false,
  );
  static final RegExp _warnPattern = RegExp(
    r'\b(warn|warning|timeout|timed out|retry|retrying|unavailable|skipped)\b',
    caseSensitive: false,
  );

  final List<LogEntry> _entries = [];
  LogLevel _level = LogLevel.info;
  bool _installed = false;
  DebugPrintCallback? _previousDebugPrint;

  LogLevel get level => _level;

  /// Captured lines, oldest first.
  List<LogEntry> get entries => List.unmodifiable(_entries);

  int get count => _entries.length;

  bool get hasEntries => _entries.isNotEmpty;

  bool get isCapturing => _installed;

  /// Loads the saved level. Safe to call more than once.
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _level = LogLevel.fromName(prefs.getString(_levelKey));
    } catch (e) {
      // A logging preference must never stop the app starting.
      debugPrint('[AppLogger] Could not load log level: $e');
    }
    notifyListeners();
  }

  Future<void> setLevel(LogLevel level) async {
    if (_level == level) return;
    _level = level;
    if (level == LogLevel.off) {
      _entries.clear();
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_levelKey, level.name);
    } catch (e) {
      debugPrint('[AppLogger] Could not save log level: $e');
    }
  }

  /// Starts capturing `debugPrint` output.
  ///
  /// Idempotent, so a hot reload or repeated bootstrap cannot stack handlers and
  /// duplicate every line.
  void installDebugPrintCapture() {
    if (_installed) return;
    _previousDebugPrint = debugPrint;
    debugPrint = _capture;
    _installed = true;

    // Uncaught Flutter errors are the most valuable lines in any log.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      record(details.exceptionAsString(), level: LogLevel.error);
      previousOnError?.call(details);
    };

    debugPrint('[AppLogger] Capture installed at level ${_level.name}.');
  }

  void _capture(String? message, {int? wrapWidth}) {
    if (message != null && message.isNotEmpty) {
      record(message);
    }
    _previousDebugPrint?.call(message, wrapWidth: wrapWidth);
  }

  /// Adds a line, inferring severity when none is given.
  void record(String message, {LogLevel? level}) {
    if (_level == LogLevel.off) return;
    if (message.trim().isEmpty) return;

    final severity = level ?? inferLevel(message);
    if (!_shouldRecord(severity)) return;

    _entries.add(
      LogEntry(
        timestamp: DateTime.now(),
        level: severity,
        message: message.trim(),
      ),
    );
    // Bounded buffer: drop the oldest rather than growing without limit.
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    notifyListeners();
  }

  bool _shouldRecord(LogLevel severity) {
    if (_level == LogLevel.off) return false;
    return severity.index <= _level.index;
  }

  /// Guesses a severity from the message text.
  static LogLevel inferLevel(String message) {
    if (_errorPattern.hasMatch(message)) return LogLevel.error;
    if (_warnPattern.hasMatch(message)) return LogLevel.warn;
    return LogLevel.info;
  }

  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }

  /// The whole buffer as text, for copying or sharing into a bug report.
  String exportText() {
    if (_entries.isEmpty) return '';
    return _entries.map((e) => e.formatted).join('\n');
  }
}
