import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/services/plugin_service.dart';
import 'package:exalere/services/provider_registry.dart';

const String _pluginsKey = 'exalere_installed_plugins_v1';
const String _seedMarkerKey = 'exalere_plugins_seeded_v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProviderRegistry().clearAll();
  });

  group('first-launch defaults', () {
    test('seeds TMDB so a fresh install has a catalogue', () async {
      final configs = await PluginService().loadInstalledPlugins();

      expect(configs, hasLength(1));
      final tmdb = configs.single;
      expect(tmdb.id, 'tmdb');
      expect(tmdb.isEnabled, isTrue);
      expect(tmdb.name, contains('TMDB'));
    });

    test(
      'the seeded plugin is metadata only, never a playback source',
      () async {
        final configs = await PluginService().loadInstalledPlugins();
        final manifest = configs.single.manifest;

        expect(manifest, isNotNull);
        expect(
          manifest!.supportsStreams,
          isFalse,
          reason: 'TMDB must never make a title look playable',
        );
        expect(manifest.resources, contains('catalog'));
        expect(manifest.resources, isNot(contains('stream')));
      },
    );

    test('seeding does not create a stream provider', () async {
      await PluginService().loadInstalledPlugins();

      expect(
        ProviderRegistry().hasStreamProviders,
        isFalse,
        reason: 'a fresh install must still report no playable provider',
      );
      expect(ProviderRegistry().streamProviders, isEmpty);
    });

    test('the seeded plugin is persisted, not just in memory', () async {
      await PluginService().loadInstalledPlugins();

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pluginsKey);
      expect(raw, isNotNull);

      final decoded = json.decode(raw!) as List<dynamic>;
      final ids = decoded.map((e) => (e as Map)['id']).toList();
      expect(ids, ['tmdb']);
    });
  });

  group('seeding is one-shot', () {
    test('an uninstalled TMDB does not come back on the next launch', () async {
      // First launch seeds it.
      final first = await PluginService().loadInstalledPlugins();
      expect(first, hasLength(1));

      // The user removes it; the stored list becomes empty.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pluginsKey, '[]');
      expect(prefs.getBool(_seedMarkerKey), isTrue);

      final second = await PluginService().loadInstalledPlugins();
      expect(
        second,
        isEmpty,
        reason: 'removal must be permanent, not undone on every launch',
      );
    });

    test('an existing plugin list is never overwritten by seeding', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pluginsKey,
        json.encode([
          {
            'id': 'hdhub4u',
            'name': 'HDHub4u',
            'baseUrl': 'hdhub4u://engine',
            'isEnabled': true,
            'addedAt': DateTime.now().toIso8601String(),
          },
        ]),
      );

      final configs = await PluginService().loadInstalledPlugins();

      expect(configs, hasLength(1));
      expect(configs.single.id, 'hdhub4u');
      expect(
        configs.any((c) => c.id == 'tmdb'),
        isFalse,
        reason: 'seeding must not add TMDB over a real list',
      );
    });
  });
}
