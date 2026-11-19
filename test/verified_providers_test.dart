import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/exalere_plugin.dart';
import 'package:exalere/plugins/plugins.dart';
import 'package:exalere/services/plugin_service.dart';
import 'package:exalere/services/verified_providers.dart';

/// Packaging invariants for every live-verified provider.
///
/// A provider only earns a place in [VerifiedProviders] when the live probe
/// resolves a stream from it. This test keeps the rest of the add-on honest:
/// manifest, store entry, Pages docs, icon and a working createPlugin branch
/// must all exist, or the badge would be a lie.
void main() {
  group('verified providers are installable add-ons', () {
    for (final id in VerifiedProviders.ids) {
      test('$id has a manifest, store entry, docs and a registry branch', () {
        // 1. Built-in manifest.
        expect(
          PluginService.builtInEngineManifests.containsKey(id),
          isTrue,
          reason: '$id has no built-in manifest',
        );

        // 2. Community catalog entry with the Verified badge.
        final catalog = PluginService().getCommunityCatalog();
        final entry = catalog.firstWhere(
          (item) => item.id == id,
          orElse: () => throw StateError('$id missing from community catalog'),
        );
        expect(
          entry.manifestUrl,
          '$id://engine',
          reason: '$id must be installed through its engine scheme',
        );
        expect(
          entry.tags,
          contains('Verified'),
          reason: '$id should carry the Verified badge',
        );

        // 3. Pages docs + icon.
        final manifestFile = File('docs/plugins/$id/manifest.json');
        expect(
          manifestFile.existsSync(),
          isTrue,
          reason: '$id has no docs manifest',
        );
        expect(
          File('docs/plugins/$id/icon.png').existsSync() ||
              File('docs/plugins/$id/icon.jpg').existsSync(),
          isTrue,
          reason: '$id has no docs icon',
        );

        // 4. Published index.
        final index = File('docs/plugins.json').readAsStringSync();
        expect(
          index,
          contains('"$id"'),
          reason: '$id missing from plugins.json',
        );

        // 5. Registry branch actually instantiates the engine.
        final plugin = createPlugin(
          ExalerePluginConfig(
            id: id,
            name: id,
            baseUrl: 'https://example.com',
            addedAt: DateTime(2026),
          ),
        );
        expect(plugin.id, id);
        expect(
          plugin.supportsStreams,
          isTrue,
          reason: '$id claims no streams, so it could never play',
        );
      });
    }

    test('the id list has no duplicates and is lowercase', () {
      for (final id in VerifiedProviders.ids) {
        expect(id, id.toLowerCase());
      }
    });

    test('a random provider is not accidentally verified', () {
      expect(VerifiedProviders.isVerified('cinefreak'), isFalse);
      expect(VerifiedProviders.isVerified('zeefliz'), isTrue);
    });
  });
}
