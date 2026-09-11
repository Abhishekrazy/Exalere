import 'dart:ffi' show Abi;

import 'package:exalere/services/tv_service.dart';
import 'package:exalere/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpdateService semver comparator', () {
    test('detects newer minor and patch versions', () {
      expect(UpdateService.isNewerVersion('0.2.0', '0.2.1'), isTrue);
      expect(UpdateService.isNewerVersion('0.2.0', '0.3.0'), isTrue);
      expect(UpdateService.isNewerVersion('0.2.0', '1.0.0'), isTrue);
      expect(UpdateService.isNewerVersion('0.2.0', 'v0.2.1'), isTrue);
      expect(UpdateService.isNewerVersion('0.2.0', 'v1.0.0'), isTrue);
    });

    test('correctly identifies older or equal versions', () {
      expect(UpdateService.isNewerVersion('0.2.0', '0.2.0'), isFalse);
      expect(UpdateService.isNewerVersion('0.2.0', 'v0.2.0'), isFalse);
      expect(UpdateService.isNewerVersion('0.2.0', '0.1.0'), isFalse);
      expect(UpdateService.isNewerVersion('0.2.0', 'v0.1.9'), isFalse);
    });

    test('handles build metadata suffixes cleanly', () {
      expect(UpdateService.isNewerVersion('0.2.0+1', '0.2.1'), isTrue);
      expect(UpdateService.isNewerVersion('0.2.0+1', '0.2.0'), isFalse);
      expect(UpdateService.isNewerVersion('0.2.0-beta', '0.2.1'), isTrue);
    });
  });

  group('UpdateInfo architecture helpers', () {
    test('identifies v7 and v8 APKs correctly', () {
      const v7Info = UpdateInfo(
        tagName: 'v0.5.2',
        version: '0.5.2',
        releaseNotes: '',
        htmlUrl: '',
        assetName: 'Exalere-Android-armeabi-v7a-0.5.2.apk',
        isUpdateAvailable: true,
      );
      expect(v7Info.isV7Apk, isTrue);
      expect(v7Info.isV8Apk, isFalse);
      expect(v7Info.archLabel, 'ARMv7 (32-bit)');

      const v8Info = UpdateInfo(
        tagName: 'v0.5.2',
        version: '0.5.2',
        releaseNotes: '',
        htmlUrl: '',
        assetName: 'Exalere-Android-arm64-v8a-0.5.2.apk',
        isUpdateAvailable: true,
      );
      expect(v8Info.isV7Apk, isFalse);
      expect(v8Info.isV8Apk, isTrue);
      expect(v8Info.archLabel, 'ARM64 (64-bit)');

      const universalInfo = UpdateInfo(
        tagName: 'v0.5.2',
        version: '0.5.2',
        releaseNotes: '',
        htmlUrl: '',
        assetName: 'Exalere-Android-Universal-0.5.2.apk',
        isUpdateAvailable: true,
      );
      expect(universalInfo.isV7Apk, isFalse);
      expect(universalInfo.isV8Apk, isFalse);
      expect(universalInfo.archLabel, 'Universal');
    });
  });

  group('UpdateService.selectAndroidAsset architecture matching', () {
    final mockAssets = [
      {
        'name': 'Exalere-Android-arm64-v8a-0.5.2.apk',
        'browser_download_url': 'https://releases/arm64-v8a.apk',
        'size': 31000000,
      },
      {
        'name': 'Exalere-Android-armeabi-v7a-0.5.2.apk',
        'browser_download_url': 'https://releases/armeabi-v7a.apk',
        'size': 28000000,
      },
      {
        'name': 'Exalere-Android-Universal-0.5.2.apk',
        'browser_download_url': 'https://releases/universal.apk',
        'size': 85000000,
      },
      {
        'name': 'Exalere-Android-x86_64-0.5.2.apk',
        'browser_download_url': 'https://releases/x86_64.apk',
        'size': 32000000,
      },
      {
        'name': 'Exalere-Windows-Setup-0.5.2.exe',
        'browser_download_url': 'https://releases/setup.exe',
        'size': 45000000,
      },
    ];

    test('selects armeabi-v7a APK when targetAbi is armeabi-v7a', () {
      final selected = UpdateService.selectAndroidAsset(
        mockAssets,
        targetAbi: 'armeabi-v7a',
      );
      expect(selected, isNotNull);
      expect(selected!['name'], 'Exalere-Android-armeabi-v7a-0.5.2.apk');
      expect(
        selected['browser_download_url'],
        'https://releases/armeabi-v7a.apk',
      );
    });

    test('selects arm64-v8a APK when targetAbi is arm64-v8a', () {
      final selected = UpdateService.selectAndroidAsset(
        mockAssets,
        targetAbi: 'arm64-v8a',
      );
      expect(selected, isNotNull);
      expect(selected!['name'], 'Exalere-Android-arm64-v8a-0.5.2.apk');
    });

    test('selects x86_64 APK when targetAbi is x86_64', () {
      final selected = UpdateService.selectAndroidAsset(
        mockAssets,
        targetAbi: 'x86_64',
      );
      expect(selected, isNotNull);
      expect(selected!['name'], 'Exalere-Android-x86_64-0.5.2.apk');
    });

    test('falls back to Universal APK for armeabi-v7a if v7 is missing', () {
      final assetsWithoutV7 = mockAssets
          .where((a) => !a['name']!.toString().contains('armeabi-v7a'))
          .toList();

      final selected = UpdateService.selectAndroidAsset(
        assetsWithoutV7,
        targetAbi: 'armeabi-v7a',
      );
      expect(selected, isNotNull);
      expect(selected!['name'], 'Exalere-Android-Universal-0.5.2.apk');
    });

    test('never selects arm64-v8a APK for armeabi-v7a target even if universal is missing', () {
      final assetsOnlyArm64 = [
        {
          'name': 'Exalere-Android-arm64-v8a-0.5.2.apk',
          'browser_download_url': 'https://releases/arm64-v8a.apk',
        },
      ];

      final selected = UpdateService.selectAndroidAsset(
        assetsOnlyArm64,
        targetAbi: 'armeabi-v7a',
      );
      expect(selected, isNull);
    });
  });

  group('UpdateService target ABI resolution', () {
    tearDown(() {
      UpdateService.setOverrideAbi(null);
      TvService.setSupportedAbisOverride(null);
    });

    test('resolves to armeabi-v7a when running 32-bit ARM process', () async {
      UpdateService.setOverrideAbi(Abi.androidArm);
      final target = await UpdateService.getTargetAndroidAbi();
      expect(target, 'armeabi-v7a');
    });

    test('resolves to arm64-v8a when running 64-bit ARM process', () async {
      UpdateService.setOverrideAbi(Abi.androidArm64);
      final target = await UpdateService.getTargetAndroidAbi();
      expect(target, 'arm64-v8a');
    });

    test('resolves to x86_64 when running x86_64 process', () async {
      UpdateService.setOverrideAbi(Abi.androidX64);
      final target = await UpdateService.getTargetAndroidAbi();
      expect(target, 'x86_64');
    });
  });
}
