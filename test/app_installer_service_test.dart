import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:exalere/services/app_installer_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class MockStreamingHttpClient extends http.BaseClient {
  final List<List<int>> chunks;
  final int statusCode;
  final int contentLength;

  MockStreamingHttpClient({
    required this.chunks,
    this.statusCode = 200,
    required this.contentLength,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final stream = Stream<List<int>>.fromIterable(chunks);
    return http.StreamedResponse(
      stream,
      statusCode,
      contentLength: contentLength,
      request: request,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DownloadProgress helper calculations', () {
    test('formats percentage correctly', () {
      const p1 = DownloadProgress(
        receivedBytes: 50,
        totalBytes: 100,
        progress: 0.5,
      );
      expect(p1.formattedProgress, '50%');

      const p2 = DownloadProgress(
        receivedBytes: 100,
        totalBytes: 100,
        progress: 1.0,
      );
      expect(p2.formattedProgress, '100%');
    });

    test('formats MB byte sizes correctly', () {
      const p = DownloadProgress(
        receivedBytes: 10 * 1024 * 1024,
        totalBytes: 20 * 1024 * 1024,
        progress: 0.5,
      );
      expect(p.formattedSize, '10.0 MB / 20.0 MB');
    });

    test('formats size gracefully when totalBytes is 0 or negative', () {
      const p = DownloadProgress(
        receivedBytes: 5 * 1024 * 1024,
        totalBytes: 0,
        progress: 0.0,
      );
      expect(p.formattedSize, '5.0 MB');
    });
  });

  group('DownloadCancelToken', () {
    test('starts uncancelled and updates on cancel()', () {
      final token = DownloadCancelToken();
      expect(token.isCancelled, isFalse);
      token.cancel();
      expect(token.isCancelled, isTrue);
    });
  });

  group('AppInstallerService MethodChannel interactions', () {
    const channel = MethodChannel(AppInstallerService.channelName);
    final List<MethodCall> methodCalls = [];

    setUp(() {
      methodCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            methodCalls.add(call);
            switch (call.method) {
              case 'canRequestPackageInstalls':
                return true;
              case 'openInstallPermissionSettings':
                return true;
              case 'getUpdateStorageDir':
                return Directory.systemTemp.path;
              case 'installApk':
                return true;
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'canRequestPackageInstalls invokes channel method on Android',
      () async {
        final service = AppInstallerService(channel: channel);
        final canInstall = await service.canRequestPackageInstalls();
        expect(canInstall, isTrue);
      },
    );

    test('openInstallPermissionSettings invokes channel method', () async {
      final service = AppInstallerService(channel: channel);
      final opened = await service.openInstallPermissionSettings();
      expect(opened, isTrue);
    });

    test('getUpdateDirectory returns a valid existing directory', () async {
      final service = AppInstallerService(channel: channel);
      final dir = await service.getUpdateDirectory();
      expect(await dir.exists(), isTrue);
    });
  });

  group('AppInstallerService downloading with progress', () {
    test(
      'streams chunks, fires onProgress, and writes file successfully',
      () async {
        final chunk1 = utf8.encode('chunk_part_1_');
        final chunk2 = utf8.encode('chunk_part_2');
        final totalLen = chunk1.length + chunk2.length;

        final mockClient = MockStreamingHttpClient(
          chunks: [chunk1, chunk2],
          contentLength: totalLen,
        );

        final service = AppInstallerService(client: mockClient);
        final List<DownloadProgress> progressUpdates = [];

        final downloadedFile = await service.downloadUpdate(
          url: 'https://github.com/Abhishekrazy/Exalere/releases/download/v0.5.3/test.apk',
          fileName: 'unit_test_update.apk',
          onProgress: (p) => progressUpdates.add(p),
        );

        expect(await downloadedFile.exists(), isTrue);
        expect(
          await downloadedFile.readAsString(),
          'chunk_part_1_chunk_part_2',
        );
        expect(progressUpdates.isNotEmpty, isTrue);
        expect(progressUpdates.last.progress, 1.0);

        // Clean up test file
        await downloadedFile.delete();
      },
    );

    test('aborts and cleans up file when cancelled', () async {
      final chunk1 = utf8.encode('initial_chunk');
      final chunk2 = utf8.encode('secondary_chunk');

      final token = DownloadCancelToken();
      final mockClient = MockStreamingHttpClient(
        chunks: [chunk1, chunk2],
        contentLength: 200,
      );

      final service = AppInstallerService(client: mockClient);

      expect(() async {
        await service.downloadUpdate(
          url: 'https://github.com/Abhishekrazy/Exalere/releases/download/v0.5.3/test.apk',
          fileName: 'cancelled_test.apk',
          cancelToken: token,
          onProgress: (_) {
            token.cancel();
          },
        );
      }, throwsA(isA<Exception>()));
    });
  });
}
