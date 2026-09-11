import 'dart:async';
import 'dart:io';

import 'package:exalere/services/app_installer_service.dart';
import 'package:exalere/services/update_service.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAppInstallerService extends AppInstallerService {
  final bool supported;
  final bool hasPermission;
  final bool shouldFail;
  final Completer<File>? downloadCompleter;
  final File? completedFile;

  FakeAppInstallerService({
    this.supported = true,
    this.hasPermission = true,
    this.shouldFail = false,
    this.downloadCompleter,
    this.completedFile,
  });

  @override
  bool get isSupported => supported;

  @override
  Future<bool> canRequestPackageInstalls() async => hasPermission;

  @override
  Future<bool> openInstallPermissionSettings() async => true;

  @override
  Future<File> downloadUpdate({
    required String url,
    required String fileName,
    void Function(DownloadProgress progress)? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    if (shouldFail) {
      throw Exception('Network connection timed out');
    }

    onProgress?.call(
      const DownloadProgress(
        receivedBytes: 15 * 1024 * 1024,
        totalBytes: 30 * 1024 * 1024,
        progress: 0.5,
      ),
    );

    if (downloadCompleter != null) {
      return downloadCompleter!.future;
    }

    return completedFile ??
        File('${Directory.systemTemp.path}/test_download.apk');
  }

  @override
  Future<bool> installPackage(String filePath) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File mockApkFile;

  setUpAll(() {
    mockApkFile = File('${Directory.systemTemp.path}/test_download_mock.apk');
    mockApkFile.writeAsStringSync('mock_apk_content');
  });

  tearDownAll(() {
    try {
      if (mockApkFile.existsSync()) {
        mockApkFile.deleteSync();
      }
    } catch (_) {}
  });

  Widget buildTestDialog({
    required UpdateInfo updateInfo,
    required String currentVersion,
    AppInstallerService? installerService,
  }) {
    return MaterialApp(
      theme: AppThemes.netflixBlack.themeData,
      home: Scaffold(
        body: UpdateDialog(
          updateInfo: updateInfo,
          currentVersion: currentVersion,
          installerService: installerService,
        ),
      ),
    );
  }

  group('UpdateDialog widget tests', () {
    const directApkInfo = UpdateInfo(
      tagName: 'v0.5.3',
      version: '0.5.3',
      releaseNotes: 'Fixed gestures and lock button in video player.',
      htmlUrl: 'https://github.com/Abhishekrazy/Exalere/releases/tag/v0.5.3',
      downloadUrl: 'https://github.com/Abhishekrazy/Exalere/releases/download/v0.5.3/Exalere-arm64-v8a.apk',
      assetName: 'Exalere-arm64-v8a.apk',
      assetSize: 31457280,
      isUpdateAvailable: true,
    );

    testWidgets('renders idle state with version badges and Update Now CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestDialog(
          updateInfo: directApkInfo,
          currentVersion: '0.5.2',
          installerService: FakeAppInstallerService(completedFile: mockApkFile),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Update Available!'), findsOneWidget);
      expect(find.text('v0.5.2'), findsOneWidget);
      expect(find.text('v0.5.3'), findsOneWidget);
      expect(find.text('RELEASE NOTES'), findsOneWidget);
      expect(
        find.text('Fixed gestures and lock button in video player.'),
        findsOneWidget,
      );
      expect(find.text('Update Now'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
    });

    testWidgets(
      'transitions to downloading state with progress and Cancel button',
      (tester) async {
        final completer = Completer<File>();
        await tester.pumpWidget(
          buildTestDialog(
            updateInfo: directApkInfo,
            currentVersion: '0.5.2',
            installerService: FakeAppInstallerService(
              downloadCompleter: completer,
              completedFile: mockApkFile,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Update Now
        await tester.tap(find.text('Update Now'));
        await tester.pump();

        // Verify downloading view is shown
        expect(find.text('Downloading Update'), findsOneWidget);
        expect(find.text('50%'), findsOneWidget);
        expect(find.text('15.0 MB / 30.0 MB'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        // Tap Cancel to abort download
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Should return to idle
        expect(find.text('Update Available!'), findsOneWidget);
        expect(find.text('Update Now'), findsOneWidget);
      },
    );

    testWidgets('shows permission required state when permission is missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestDialog(
          updateInfo: directApkInfo,
          currentVersion: '0.5.2',
          installerService: FakeAppInstallerService(
            hasPermission: false,
            completedFile: mockApkFile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Update Now
      await tester.tap(find.text('Update Now'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Installation Permission Required'), findsOneWidget);
      expect(find.text('Allow Permission'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
    });

    testWidgets('shows package ready when permission is already granted', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestDialog(
          updateInfo: directApkInfo,
          currentVersion: '0.5.2',
          installerService: FakeAppInstallerService(
            hasPermission: true,
            completedFile: mockApkFile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Update Now
      await tester.tap(find.text('Update Now'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Package Ready'), findsOneWidget);
      expect(find.text('Install Now'), findsOneWidget);
    });

    testWidgets('shows error state on failure with Retry and Browser options', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestDialog(
          updateInfo: directApkInfo,
          currentVersion: '0.5.2',
          installerService: FakeAppInstallerService(
            shouldFail: true,
            completedFile: mockApkFile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Update Now
      await tester.tap(find.text('Update Now'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Error Details'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Browser'), findsOneWidget);
    });
  });
}
