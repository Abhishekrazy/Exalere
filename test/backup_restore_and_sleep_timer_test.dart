import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/subtitle_style_preferences.dart';
import 'package:exalere/models/user_profile.dart';
import 'package:exalere/services/backup_restore_service.dart';
import 'package:exalere/services/sleep_timer_service.dart';
import 'package:exalere/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SubtitleStylePreferences Tests', () {
    test('Default values are correct and stable', () {
      const prefs = SubtitleStylePreferences();
      expect(prefs.fontSize, 22.0);
      expect(prefs.colorPreset, 'white');
      expect(prefs.backgroundOpacity, 0.35);
      expect(prefs.shadowStrength, 'subtle');
    });

    test('toMpvProperties converts colors, fonts, and shadows correctly', () {
      const prefs = SubtitleStylePreferences(
        fontSize: 24.0,
        colorPreset: 'yellow',
        backgroundOpacity: 0.5,
        shadowStrength: 'strong',
      );

      final mpvMobile = prefs.toMpvProperties(isTv: false);
      expect(mpvMobile['sub-font-size'], '24');
      expect(mpvMobile['sub-color'], '#FFFFEB3B');
      expect(mpvMobile['sub-border-size'], '3');

      final mpvTv = prefs.toMpvProperties(isTv: true);
      expect(mpvTv['sub-font-size'], '30'); // 24 * 1.25 = 30
      expect(mpvTv['sub-color'], '#FFFFEB3B');
    });

    test('JSON serialization roundtrip works identically', () {
      const original = SubtitleStylePreferences(
        fontSize: 28.0,
        colorPreset: 'cyan',
        backgroundOpacity: 0.70,
        shadowStrength: 'none',
      );

      final json = original.toJson();
      final restored = SubtitleStylePreferences.fromJson(json);

      expect(restored.fontSize, 28.0);
      expect(restored.colorPreset, 'cyan');
      expect(restored.backgroundOpacity, 0.70);
      expect(restored.shadowStrength, 'none');

      final encoded = original.encode();
      final decoded = SubtitleStylePreferences.decode(encoded);
      expect(decoded.fontSize, original.fontSize);
      expect(decoded.colorPreset, original.colorPreset);
    });
  });

  group('SleepTimerService Tests', () {
    test('Timer start, formatted countdown, and cancel', () {
      final timer = SleepTimerService();
      expect(timer.isActive, isFalse);
      expect(timer.remainingTime, isNull);
      expect(timer.formattedRemaining, '');

      bool expired = false;
      timer.setTimer(
        duration: const Duration(minutes: 30),
        label: '30m',
        onExpire: () {
          expired = true;
        },
      );

      expect(timer.isActive, isTrue);
      expect(timer.remainingTime, isNotNull);
      expect(timer.remainingTime!.inMinutes, lessThanOrEqualTo(30));
      expect(timer.activeLabel, '30m');
      expect(timer.formattedRemaining.contains('m'), isTrue);

      timer.cancelTimer();
      expect(timer.isActive, isFalse);
      expect(timer.remainingTime, isNull);
      expect(expired, isFalse);
    });
  });

  group('BackupRestoreService Tests', () {
    late StorageService storage;

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'user_profiles_list': [
          jsonEncode(
            UserProfile(
              id: 'profile_1',
              name: 'Tester',
              avatarIcon: 'person',
              avatarColorIndex: 0,
              createdAt: 1000,
              lastActiveAt: 2000,
            ).toJson(),
          ),
        ],
        'user_active_profile_id': 'profile_1',
        'user_favorites_profile_1': [
          jsonEncode(
            const MediaItem(
              id: 'm1',
              title: 'Inception',
              mediaType: MediaType.movie,
              rating: 8.8,
            ).toJson(),
          ),
        ],
        'user_theme_index': 1,
        'user_ui_scale': 0.9,
      });
      storage = StorageService();
    });

    test('createBackupBundle captures profiles, items, and settings', () async {
      final backupService = BackupRestoreService();
      final bundle = await backupService.createBackupBundle();

      expect(bundle['app'], 'Exalere');
      expect(bundle['formatVersion'], 1);
      expect(bundle['activeProfileId'], 'profile_1');

      final profiles = bundle['profiles'] as List;
      expect(profiles.length, 1);

      final dataByProfile = bundle['dataByProfile'] as Map<String, dynamic>;
      expect(dataByProfile.containsKey('profile_1'), isTrue);

      final p1Data = dataByProfile['profile_1'] as Map<String, dynamic>;
      final favs = p1Data['favorites'] as List;
      expect(favs.length, 1);
      expect(favs[0]['title'], 'Inception');
    });

    test('validateBackupBundle accurately assesses validity', () {
      final backupService = BackupRestoreService();

      final invalidApp = {'app': 'NotExalere'};
      final res1 = backupService.validateBackupBundle(invalidApp);
      expect(res1.isValid, isFalse);

      final validBundle = {
        'app': 'Exalere',
        'profiles': [
          {
            'id': 'p1',
            'name': 'User',
            'avatarIcon': 'person',
            'avatarColorIndex': 0,
            'createdAt': 1,
            'lastActiveAt': 1,
          },
        ],
        'dataByProfile': {
          'p1': {
            'favorites': [
              {
                'id': 'fav1',
                'title': 'Test Movie',
                'overview': '...',
                'type': 'movie',
              },
            ],
            'watchHistory': [],
          },
        },
      };

      final res2 = backupService.validateBackupBundle(validBundle);
      expect(res2.isValid, isTrue);
      expect(res2.profileCount, 1);
      expect(res2.totalFavorites, 1);
    });

    test('restoreBackupBundle full replacement overwrites data', () async {
      final backupService = BackupRestoreService();

      final newBundle = {
        'app': 'Exalere',
        'formatVersion': 1,
        'activeProfileId': 'restored_profile',
        'profiles': [
          {
            'id': 'restored_profile',
            'name': 'Restored User',
            'avatarIcon': 'star',
            'avatarColorIndex': 2,
            'createdAt': 5000,
            'lastActiveAt': 6000,
          },
        ],
        'dataByProfile': {
          'restored_profile': {
            'favorites': [
              {
                'id': 'm2',
                'title': 'Interstellar',
                'overview': 'Space travel',
                'type': 'movie',
              },
            ],
            'alreadyWatched': [],
            'watchHistory': [],
            'watchedEpisodes': {},
          },
        },
        'settings': {'user_theme_index': 2, 'user_ui_scale': 1.1},
      };

      final result = await backupService.restoreBackupBundle(
        newBundle,
        mergeWithExisting: false,
      );
      expect(result.success, isTrue);

      final profiles = await storage.getProfiles();
      expect(profiles.length, 1);
      expect(profiles.first.id, 'restored_profile');
      expect(profiles.first.name, 'Restored User');

      final favs = await storage.getFavorites(profileId: 'restored_profile');
      expect(favs.length, 1);
      expect(favs.first.title, 'Interstellar');

      final theme = await storage.getThemeIndex();
      expect(theme, 2);
    });

    test('restoreBackupBundle merge unions profiles and favorites', () async {
      final backupService = BackupRestoreService();

      final mergeBundle = {
        'app': 'Exalere',
        'formatVersion': 1,
        'activeProfileId': 'profile_2',
        'profiles': [
          {
            'id': 'profile_2',
            'name': 'Merged User',
            'avatarIcon': 'person',
            'avatarColorIndex': 1,
            'createdAt': 3000,
            'lastActiveAt': 4000,
          },
        ],
        'dataByProfile': {
          'profile_2': {
            'favorites': [
              {
                'id': 'm3',
                'title': 'The Matrix',
                'overview': 'Red or Blue Pill',
                'type': 'movie',
              },
            ],
            'alreadyWatched': [],
            'watchHistory': [],
            'watchedEpisodes': {},
          },
        },
        'settings': {},
      };

      final result = await backupService.restoreBackupBundle(
        mergeBundle,
        mergeWithExisting: true,
      );
      expect(result.success, isTrue);

      final profiles = await storage.getProfiles();
      expect(profiles.length, 2);
      expect(profiles.any((p) => p.id == 'profile_1'), isTrue);
      expect(profiles.any((p) => p.id == 'profile_2'), isTrue);

      final p1Favs = await storage.getFavorites(profileId: 'profile_1');
      expect(p1Favs.length, 1);
      expect(p1Favs.first.title, 'Inception');

      final p2Favs = await storage.getFavorites(profileId: 'profile_2');
      expect(p2Favs.length, 1);
      expect(p2Favs.first.title, 'The Matrix');
    });
  });
}
