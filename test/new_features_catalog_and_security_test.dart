import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/models/app_feature.dart';
import 'package:exalere/models/user_profile.dart';
import 'package:exalere/providers/profile_provider.dart';
import 'package:exalere/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Parental PIN Lock & UserProfile Model Tests', () {
    test('UserProfile PIN protection properties and helper check', () {
      final unencrypted = UserProfile.createDefault();
      expect(unencrypted.pin, isNull);
      expect(unencrypted.isPinProtected, isFalse);

      final protected = unencrypted.copyWith(pin: '1234');
      expect(protected.pin, equals('1234'));
      expect(protected.isPinProtected, isTrue);

      // Invalid length PIN should not be considered protected
      final invalidPin = unencrypted.copyWith(pin: '12');
      expect(invalidPin.isPinProtected, isFalse);
    });

    test('UserProfile JSON serialization preserves PIN', () {
      final profile = UserProfile(
        id: 'secure_parent',
        name: 'Parent Profile',
        pin: '9876',
        createdAt: 1000,
        lastActiveAt: 2000,
      );

      final json = profile.toJson();
      expect(json['pin'], equals('9876'));

      final restored = UserProfile.fromJson(json);
      expect(restored.pin, equals('9876'));
      expect(restored.isPinProtected, isTrue);
    });

    test('ProfileProvider creates profile with PIN', () async {
      final provider = ProfileProvider();
      await provider.init();

      final newProfile = await provider.createProfile(
        name: 'Restricted Vault',
        avatarIcon: 'shield',
        avatarColorIndex: 3,
        isKids: false,
        pin: '4321',
      );

      expect(newProfile.pin, equals('4321'));
      expect(newProfile.isPinProtected, isTrue);
      expect(
        provider.profiles.any((p) => p.id == newProfile.id && p.pin == '4321'),
        isTrue,
      );
    });
  });

  group('Live TV Channel Favorites & Custom M3U Playlists Tests', () {
    test('StorageService persists and toggles Live TV favorites', () async {
      final storage = StorageService();

      expect(await storage.getLiveTvFavoriteChannelIds(), isEmpty);
      expect(await storage.isLiveTvChannelFavorite('bbc_one'), isFalse);

      // Toggle ON
      await storage.toggleLiveTvFavoriteChannel('bbc_one');
      expect(await storage.isLiveTvChannelFavorite('bbc_one'), isTrue);

      // Toggle another channel
      await storage.toggleLiveTvFavoriteChannel('cnn_news');
      final favs = await storage.getLiveTvFavoriteChannelIds();
      expect(favs.length, equals(2));
      expect(favs.contains('bbc_one'), isTrue);
      expect(favs.contains('cnn_news'), isTrue);

      // Toggle OFF
      await storage.toggleLiveTvFavoriteChannel('bbc_one');
      expect(await storage.isLiveTvChannelFavorite('bbc_one'), isFalse);
      expect((await storage.getLiveTvFavoriteChannelIds()).length, equals(1));
    });

    test('StorageService manages custom IPTV M3U Playlists', () async {
      final storage = StorageService();

      // By default without saved playlists, empty list is returned
      final initialPlaylists = await storage.getIptvPlaylists();
      expect(initialPlaylists, isEmpty);

      // Save custom playlists
      final customList = [
        {'name': 'Sports Hub', 'url': 'https://example.com/sports.m3u'},
        {'name': 'News 24/7', 'url': 'https://example.com/news.m3u'},
      ];

      await storage.saveIptvPlaylists(customList);

      final loaded = await storage.getIptvPlaylists();
      expect(loaded.length, equals(2));
      expect(loaded.any((p) => p['name'] == 'Sports Hub'), isTrue);
      expect(
        loaded.any((p) => p['url'] == 'https://example.com/news.m3u'),
        isTrue,
      );
    });
  });

  group('AppFeaturesCatalog Showcase Tests', () {
    test('Catalog contains extensive feature list and valid metadata', () {
      final all = AppFeaturesCatalog.allFeatures;
      expect(all.length, greaterThanOrEqualTo(50));
      expect(AppFeaturesCatalog.totalCount, equals(all.length));

      for (final feature in all) {
        expect(feature.id, isNotEmpty);
        expect(feature.title, isNotEmpty);
        expect(feature.description, isNotEmpty);
      }
    });

    test('Category filtering covers all feature categories', () {
      for (final category in FeatureCategory.values) {
        final items = AppFeaturesCatalog.getBy(category);
        expect(
          items,
          isNotEmpty,
          reason: 'Category ${category.name} should have registered features',
        );
      }
    });

    test('Search filters features by title, description, and categories', () {
      final pinSearch = AppFeaturesCatalog.search('PIN');
      expect(pinSearch.any((f) => f.id == 'parental_pin_lock'), isTrue);

      final drcSearch = AppFeaturesCatalog.search('Dynamic Range');
      expect(drcSearch.any((f) => f.id == 'dialogue_boost'), isTrue);

      final nerdsSearch = AppFeaturesCatalog.search('Stats for Nerds');
      expect(nerdsSearch.any((f) => f.id == 'stats_for_nerds'), isTrue);

      final nonExistent = AppFeaturesCatalog.search('NonExistentKeywordXYZ123');
      expect(nonExistent, isEmpty);
    });
  });
}
