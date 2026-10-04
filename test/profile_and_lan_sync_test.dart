import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/user_profile.dart';
import 'package:exalere/providers/profile_provider.dart';
import 'package:exalere/services/lan_sync_service.dart';
import 'package:exalere/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserProfile Model Tests', () {
    test('createDefault produces a valid default profile', () {
      final p = UserProfile.createDefault();
      expect(p.id, equals('default'));
      expect(p.name, equals('Default'));
      expect(p.isKids, isFalse);
      expect(p.avatarIcon, equals('face'));
      expect(p.avatarColorIndex, equals(0));
    });

    test('Serialization and deserialization roundtrip preserves fields', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final original = UserProfile(
        id: 'kids_1',
        name: 'Little Ones',
        avatarIcon: 'kids',
        avatarColorIndex: 2,
        isKids: true,
        createdAt: now,
        lastActiveAt: now,
      );

      final json = original.toJson();
      final restored = UserProfile.fromJson(json);

      expect(restored.id, equals('kids_1'));
      expect(restored.name, equals('Little Ones'));
      expect(restored.avatarIcon, equals('kids'));
      expect(restored.avatarColorIndex, equals(2));
      expect(restored.isKids, isTrue);
      expect(restored.createdAt, equals(now));
      expect(restored.lastActiveAt, equals(now));
    });

    test('copyWith properly updates specified fields', () {
      final p = UserProfile.createDefault();
      final updated = p.copyWith(name: 'Updated Name', isKids: true);

      expect(updated.id, equals('default'));
      expect(updated.name, equals('Updated Name'));
      expect(updated.isKids, isTrue);
    });
  });

  group('StorageService Multi-Profile Isolation Tests', () {
    test('Stores and retrieves favorites scoped per profile', () async {
      final storage = StorageService();

      final movieA = MediaItem(
        id: 'movie_1',
        title: 'Inception',
        posterUrl: '/path1.jpg',
        backdropUrl: '/bg1.jpg',
        rating: 8.8,
        year: '2010',
        mediaType: MediaType.movie,
      );

      final movieB = MediaItem(
        id: 'movie_2',
        title: 'Frozen',
        posterUrl: '/path2.jpg',
        backdropUrl: '/bg2.jpg',
        rating: 7.5,
        year: '2013',
        mediaType: MediaType.movie,
      );

      // Save movieA to default profile
      await storage.toggleFavorite(movieA, profileId: 'default');

      // Save movieB to kids profile
      await storage.toggleFavorite(movieB, profileId: 'kids_profile');

      final defaultFavs = await storage.getFavorites(profileId: 'default');
      final kidsFavs = await storage.getFavorites(profileId: 'kids_profile');

      expect(defaultFavs.length, equals(1));
      expect(defaultFavs.first.id, equals('movie_1'));

      expect(kidsFavs.length, equals(1));
      expect(kidsFavs.first.id, equals('movie_2'));
    });

    test(
      'Backward compatibility: null profileId maps to default storage',
      () async {
        final storage = StorageService();

        final movie = MediaItem(
          id: 'legacy_movie',
          title: 'Legacy Title',
          posterUrl: '',
          backdropUrl: '',
          rating: 7.0,
          year: '2020',
          mediaType: MediaType.movie,
        );

        // Save with no profileId (null)
        await storage.toggleFavorite(movie);

        // Retrieve with 'default' profileId
        final favs = await storage.getFavorites(profileId: 'default');
        expect(favs.length, equals(1));
        expect(favs.first.id, equals('legacy_movie'));
      },
    );

    test('Profile CRUD in storage service works properly', () async {
      final storage = StorageService();

      // Initial profiles should contain default profile
      final initial = await storage.getProfiles();
      expect(initial.length, equals(1));
      expect(initial.first.id, equals('default'));

      // Save two profiles
      final p2 = UserProfile(
        id: 'profile_family',
        name: 'Family',
        createdAt: 100,
        lastActiveAt: 100,
      );
      await storage.saveProfiles([initial.first, p2]);

      final loaded = await storage.getProfiles();
      expect(loaded.length, equals(2));
      expect(loaded.any((p) => p.name == 'Family'), isTrue);

      // Active profile ID
      expect(await storage.getActiveProfileId(), equals('default'));
      await storage.setActiveProfileId('profile_family');
      expect(await storage.getActiveProfileId(), equals('profile_family'));
    });
  });

  group('ProfileProvider State Management Tests', () {
    test(
      'ProfileProvider creates, switches, updates, and deletes profiles',
      () async {
        final provider = ProfileProvider();
        await provider.init();

        expect(provider.profiles.length, equals(1));
        expect(provider.activeProfile.id, equals('default'));

        String? switchedProfileId;
        provider.onProfileChanged = (p) {
          switchedProfileId = p.id;
        };

        // Create new profile
        final newProfile = await provider.createProfile(
          name: 'Kids Corner',
          avatarIcon: 'kids',
          avatarColorIndex: 1,
          isKids: true,
        );

        expect(provider.profiles.length, equals(2));
        expect(newProfile.name, equals('Kids Corner'));
        expect(newProfile.isKids, isTrue);

        // Switch to new profile
        await provider.switchProfile(newProfile.id);
        expect(provider.activeProfile.id, equals(newProfile.id));
        expect(switchedProfileId, equals(newProfile.id));

        // Update profile
        final updated = newProfile.copyWith(name: 'Super Kids');
        await provider.updateProfile(updated);
        expect(provider.activeProfile.name, equals('Super Kids'));

        // Switch back and delete profile
        await provider.switchProfile('default');
        expect(provider.activeProfile.id, equals('default'));

        await provider.deleteProfile(newProfile.id);
        expect(provider.profiles.length, equals(1));
        expect(provider.profiles.first.id, equals('default'));
      },
    );

    test('Cannot delete the last remaining profile', () async {
      final provider = ProfileProvider();
      await provider.init();

      expect(provider.profiles.length, equals(1));
      await provider.deleteProfile('default');
      expect(provider.profiles.length, equals(1));
    });
  });

  group('LAN Sync Service Tests', () {
    test('DiscoveredPeer JSON serialization works correctly', () {
      final peer = DiscoveredPeer(
        id: 'peer_123',
        name: 'Living Room TV',
        deviceType: 'tv',
        address: '192.168.1.100',
        port: 8768,
        profileNames: ['Default', 'Kids'],
        lastSeen: DateTime.fromMillisecondsSinceEpoch(1000000),
      );

      final json = peer.toJson();
      expect(json['id'], equals('peer_123'));
      expect(json['name'], equals('Living Room TV'));
      expect(json['deviceType'], equals('tv'));
      expect(json['address'], equals('192.168.1.100'));
      expect(json['port'], equals(8768));
      expect(json['profileNames'], equals(['Default', 'Kids']));
      expect(json['lastSeen'], equals(1000000));
    });

    test('LanSyncService initializes and generates device info', () async {
      final lanSync = LanSyncService();
      await lanSync.init(isTv: false);

      expect(lanSync.deviceId, isNotEmpty);
      expect(lanSync.deviceName, isNotEmpty);
      expect(lanSync.isEnabled, isTrue);
      expect(lanSync.httpPort, greaterThan(0));

      await lanSync.setCustomDeviceName('My Custom Studio');
      expect(lanSync.deviceName, equals('My Custom Studio'));
    });
  });
}
