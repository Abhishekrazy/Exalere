import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/services/app_logger.dart';

/// The log is a diagnostic tool, so the behaviour that matters is: the level
/// really filters, severity inference is predictable, and the buffer cannot grow
/// without bound.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final logger = AppLogger.instance;
    logger.clear();
    await logger.setLevel(LogLevel.info);
    logger.clear();
  });

  group('LogLevel', () {
    test('defaults to info for unknown or missing values', () {
      expect(LogLevel.fromName(null), LogLevel.info);
      expect(LogLevel.fromName('nonsense'), LogLevel.info);
      expect(LogLevel.fromName('debug'), LogLevel.debug);
      expect(LogLevel.fromName('off'), LogLevel.off);
    });

    test('every level has a label and description', () {
      for (final level in LogLevel.values) {
        expect(level.label, isNotEmpty);
        expect(level.description, isNotEmpty);
      }
    });
  });

  group('severity inference', () {
    test('recognises failures', () {
      expect(AppLogger.inferLevel('Provider error: timed out'), LogLevel.error);
      expect(AppLogger.inferLevel('Exception while parsing'), LogLevel.error);
      expect(AppLogger.inferLevel('Stream resolution failed'), LogLevel.error);
      expect(AppLogger.inferLevel('UNABLE TO RESOLVE'), LogLevel.error);
    });

    test('recognises warnings', () {
      expect(AppLogger.inferLevel('Warning: retrying'), LogLevel.warn);
      expect(AppLogger.inferLevel('Request timed out'), LogLevel.warn);
      expect(AppLogger.inferLevel('Engine unavailable'), LogLevel.warn);
    });

    test('treats everything else as informational', () {
      expect(AppLogger.inferLevel('Home feeds loaded'), LogLevel.info);
      expect(AppLogger.inferLevel('Plugin installed'), LogLevel.info);
    });
  });

  group('level filtering', () {
    test('Off records nothing at all', () async {
      final logger = AppLogger.instance;
      await logger.setLevel(LogLevel.off);

      logger.record('error: something broke');
      logger.record('ordinary event');

      expect(logger.count, 0);
    });

    test('Errors only keeps failures but drops ordinary lines', () async {
      final logger = AppLogger.instance;
      await logger.setLevel(LogLevel.error);

      logger.record('error: something broke');
      logger.record('warning: slow');
      logger.record('ordinary event');

      expect(logger.count, 1);
      expect(logger.entries.single.message, contains('broke'));
    });

    test('Warnings keeps warnings and errors', () async {
      final logger = AppLogger.instance;
      await logger.setLevel(LogLevel.warn);

      logger.record('error: broke');
      logger.record('warning: slow');
      logger.record('ordinary event');

      expect(logger.count, 2);
      expect(logger.entries.map((e) => e.level), [
        LogLevel.error,
        LogLevel.warn,
      ]);
    });

    test('Verbose keeps everything', () async {
      final logger = AppLogger.instance;
      await logger.setLevel(LogLevel.debug);

      logger.record('error: broke');
      logger.record('warning: slow');
      logger.record('ordinary event');
      logger.record('chatty diagnostic', level: LogLevel.debug);

      expect(logger.count, 4);
    });

    test('an explicit level overrides inference', () async {
      final logger = AppLogger.instance;
      await logger.setLevel(LogLevel.error);

      // Text says "error", but the caller asserted it is informational, so it is
      // dropped at this level.
      logger.record('error count is zero', level: LogLevel.info);
      expect(logger.count, 0);
    });

    test('switching to Off clears what was already captured', () async {
      final logger = AppLogger.instance;
      logger.record('one');
      expect(logger.count, 1);

      await logger.setLevel(LogLevel.off);
      expect(logger.count, 0);
    });
  });

  group('buffer behaviour', () {
    test('ignores blank messages', () async {
      final logger = AppLogger.instance;
      logger.record('');
      logger.record('   ');
      expect(logger.count, 0);
    });

    test('trims whitespace', () async {
      final logger = AppLogger.instance;
      logger.record('  padded  ');
      expect(logger.entries.single.message, 'padded');
    });

    test('is bounded and keeps the newest lines', () async {
      final logger = AppLogger.instance;
      await logger.setLevel(LogLevel.debug);

      for (var i = 0; i < AppLogger.maxEntries + 25; i++) {
        logger.record('line $i');
      }

      expect(logger.count, AppLogger.maxEntries);
      expect(logger.entries.last.message, 'line ${AppLogger.maxEntries + 24}');
      // The oldest were evicted, not the newest.
      expect(logger.entries.first.message, isNot('line 0'));
    });
  });

  group('export and clear', () {
    test('exports formatted lines oldest first', () async {
      final logger = AppLogger.instance;
      await logger.setLevel(LogLevel.debug);
      logger.record('first');
      logger.record('second');

      final text = logger.exportText();
      expect(text, contains('first'));
      expect(text, contains('second'));
      expect(
        text.indexOf('first'),
        lessThan(text.indexOf('second')),
        reason: 'a log read top-down must be chronological',
      );
      expect(text.split('\n').length, 2);
    });

    test('exports empty text when nothing is captured', () {
      expect(AppLogger.instance.exportText(), '');
    });

    test('clear empties the buffer', () async {
      final logger = AppLogger.instance;
      logger.record('something');
      logger.clear();
      expect(logger.count, 0);
      expect(logger.hasEntries, isFalse);
    });
  });

  group('persistence', () {
    test('the chosen level survives a reload', () async {
      await AppLogger.instance.setLevel(LogLevel.debug);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_log_level'), 'debug');
    });
  });
}
