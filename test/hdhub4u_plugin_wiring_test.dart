import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/exalere_plugin.dart';
import 'package:exalere/plugins/plugins.dart';
import 'package:exalere/services/hdhub4u_provider.dart';
import 'package:exalere/services/moviesdrive_provider.dart';
import 'package:exalere/services/moviesmod_provider.dart';
import 'package:exalere/services/uhdmovies_provider.dart';
import 'package:exalere/services/plugin_service.dart';
import 'package:exalere/services/provider_registry.dart';

/// HDHub4u ships as an *installable* built-in, not a default. A fresh install
/// must still have no playable provider, otherwise Home offers play buttons for
/// streams nothing can resolve.
void main() {
  group('built-in engine manifests', () {
    test('HDHub4u resolves from its private scheme', () {
      final manifest = PluginService.builtInEngineFor('hdhub4u://engine');
      expect(manifest, isNotNull);
      expect(manifest!.id, 'hdhub4u');
      expect(manifest.name, 'HDHub4u');
    });

    test('it advertises stream support but no catalogue', () {
      final manifest = PluginService.builtInEngineManifests['hdhub4u']!;
      expect(manifest.supportsStreams, isTrue);
      // A latest-additions grid is not a catalogue feed; claiming otherwise
      // would make Home source its shelves from a daily-changing page.
      expect(manifest.hasCatalogs, isFalse);
      expect(manifest.supportsCatalogResource, isFalse);
    });

    test('existing built-ins still resolve', () {
      expect(
        PluginService.builtInEngineFor('circleftp://engine')!.id,
        'circleftp',
      );
    });

    test('remote URLs are not treated as built-ins', () {
      expect(
        PluginService.builtInEngineFor('https://example.com/manifest.json'),
        isNull,
      );
      expect(PluginService.builtInEngineFor('hdhub4u'), isNull);
    });

    test('scheme matching is case insensitive and tolerates whitespace', () {
      expect(
        PluginService.builtInEngineFor('  HDHUB4U://engine  ')!.id,
        'hdhub4u',
      );
    });
  });

  group('plugin factory', () {
    ExalerePluginConfig configFor(String id, String baseUrl) =>
        ExalerePluginConfig(
          id: id,
          name: id,
          baseUrl: baseUrl,
          isEnabled: true,
          addedAt: DateTime(2026),
        );

    test('maps an HDHub4u config to the native scraper', () {
      final plugin = createPlugin(configFor('hdhub4u', 'hdhub4u://engine'));
      expect(plugin, isA<HDHub4uPlugin>());
      expect(plugin.id, HDHub4uProvider.providerId);
      expect(plugin.supportsStreams, isTrue);
      expect(plugin.supportsSearch, isTrue);
    });

    test('the scraper takes priority below metadata catalogues', () {
      final plugin = createPlugin(configFor('hdhub4u', 'hdhub4u://engine'));
      // Scraped sources are slower and can move, so they must not outrank the
      // stable metadata providers.
      expect(plugin.priority, greaterThan(50));
    });

    test('an unrelated config still becomes a Stremio addon', () {
      final plugin = createPlugin(
        configFor('com.example.addon', 'https://example.com'),
      );
      expect(plugin, isNot(isA<HDHub4uPlugin>()));
    });
  });

  group('scraped providers declare their real capabilities', () {
    test('every scraper reports no metadata capability', () {
      // The self-test would otherwise show a red "Metadata" failure for a
      // provider that never claimed to have metadata, which reads as a bug.
      final plugins = <MediaProviderPlugin>[
        HDHub4uPlugin(),
        MoviesModPlugin(),
        UhdMoviesPlugin(),
        MoviesDrivePlugin(),
      ];

      for (final plugin in plugins) {
        expect(plugin.supportsStreams, isTrue, reason: '${plugin.id} streams');
        expect(
          plugin.supportsMetadata,
          isFalse,
          reason: '${plugin.id} must not claim metadata it cannot return',
        );
        expect(
          plugin.supportsCatalogFeeds,
          isFalse,
          reason: '${plugin.id} listing is not a category catalogue',
        );
        expect(plugin.supportsSearch, isTrue, reason: '${plugin.id} search');
      }
    });

    test('all four are distinct providers', () {
      final ids = {
        HDHub4uPlugin().id,
        MoviesModPlugin().id,
        UhdMoviesPlugin().id,
        MoviesDrivePlugin().id,
      };
      expect(
        ids.length,
        4,
        reason: 'duplicate ids would collide in the registry',
      );
    });
  });

  group('fresh-install invariant', () {
    test(
      'a fresh registry has no playable provider until one is installed',
      () {
        final registry = ProviderRegistry();
        registry.clearAll();

        expect(
          registry.streamProviders,
          isEmpty,
          reason: 'installing nothing must not advertise playback',
        );
        expect(registry.hasStreamProviders, isFalse);
      },
    );
  });
}
