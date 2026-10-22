import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/services/data_reset_service.dart';

/// "Erase all local data" is destructive and unrecoverable, so what matters is
/// that it removes what it claims and reports honestly when it cannot.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'user_device_name': 'Living Room TV',
      'user_only_show_available_on_providers': true,
    });
    tempDir = await Directory.systemTemp.createTemp('exalere_reset_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DataResetService.eraseAllLocalData', () {
    test('clears persisted preferences', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isNotEmpty);

      final result = await DataResetService.instance.eraseAllLocalData(
        deleteDownloads: false,
      );

      expect(result.preferencesCleared, isTrue);
      expect(
        (await SharedPreferences.getInstance()).getKeys(),
        isEmpty,
        reason: 'a reset must not leave stale settings behind',
      );
    });

    test('deletes downloaded files and counts what it freed', () async {
      final file = File('${tempDir.path}/movie.mkv');
      await file.writeAsBytes(List<int>.filled(2048, 0));
      final nested = Directory('${tempDir.path}/show');
      await nested.create();
      await File(
        '${nested.path}/ep1.mp4',
      ).writeAsBytes(List<int>.filled(1024, 0));

      final result = await DataResetService.instance.eraseAllLocalData(
        downloadsDirectoryOverride: tempDir,
      );

      expect(result.filesDeleted, 2, reason: 'the file and the subdirectory');
      expect(result.bytesFreed, 3072);
      expect(result.isClean, isTrue);
      expect(
        tempDir.listSync(),
        isEmpty,
        reason: 'the downloads folder should be left empty, not deleted',
      );
    });

    test('leaves downloads alone when asked to', () async {
      final file = File('${tempDir.path}/keep.mkv');
      await file.writeAsBytes(List<int>.filled(64, 0));

      final result = await DataResetService.instance.eraseAllLocalData(
        deleteDownloads: false,
        downloadsDirectoryOverride: tempDir,
      );

      expect(result.filesDeleted, 0);
      expect(
        await file.exists(),
        isTrue,
        reason: 'settings reset must not silently delete media when opted out',
      );
    });

    test('handles a missing downloads folder without failing', () async {
      final missing = Directory('${tempDir.path}/does_not_exist');

      final result = await DataResetService.instance.eraseAllLocalData(
        downloadsDirectoryOverride: missing,
      );

      expect(result.isClean, isTrue);
      expect(result.filesDeleted, 0);
      expect(result.preferencesCleared, isTrue);
    });
  });

  group('DataResetResult.summary', () {
    test('describes a full erase', () {
      const result = DataResetResult(
        preferencesCleared: true,
        filesDeleted: 3,
        bytesFreed: 5 * 1024 * 1024,
        errors: [],
      );

      expect(result.summary, contains('settings and lists reset'));
      expect(result.summary, contains('3 files removed'));
      expect(result.summary, contains('5.0 MB freed'));
      expect(result.isClean, isTrue);
    });

    test('uses the singular for one file', () {
      const result = DataResetResult(
        preferencesCleared: true,
        filesDeleted: 1,
        bytesFreed: 1024,
        errors: [],
      );
      expect(result.summary, contains('1 file removed'));
    });

    test('reports partial failure instead of claiming success', () {
      const result = DataResetResult(
        preferencesCleared: true,
        filesDeleted: 1,
        bytesFreed: 1024,
        errors: ['locked.mkv: permission denied'],
      );

      expect(result.isClean, isFalse);
      expect(result.summary, contains('could not be removed'));
    });

    test('formats byte sizes across units', () {
      expect(
        const DataResetResult(
          preferencesCleared: true,
          filesDeleted: 1,
          bytesFreed: 512,
          errors: [],
        ).formattedBytesFreed,
        '512 B',
      );
      expect(
        const DataResetResult(
          preferencesCleared: true,
          filesDeleted: 1,
          bytesFreed: 2048,
          errors: [],
        ).formattedBytesFreed,
        '2 KB',
      );
      expect(
        const DataResetResult(
          preferencesCleared: true,
          filesDeleted: 1,
          bytesFreed: 3 * 1024 * 1024 * 1024,
          errors: [],
        ).formattedBytesFreed,
        '3.00 GB',
      );
    });
  });
}
