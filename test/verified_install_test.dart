import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/services/plugin_service.dart';
import 'package:exalere/services/provider_registry.dart';
import 'package:exalere/services/verified_providers.dart';

/// Installs every verified add-on the way a user does — by its store
/// `manifestUrl` — and checks the install path end to end: manifest lookup,
/// persistence, registry registration, the plugin's claim to streams, and
/// clean uninstall. The parser and live tests prove a provider can resolve a
/// stream; this proves the thing a user taps actually becomes that provider.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final registry = ProviderRegistry();
    for (final provider in registry.activeProviders) {
      registry.unregisterProvider(provider.id);
    }
  });

  group('verified add-ons install through the store path', () {
    for (final id in VerifiedProviders.ids) {
      test('$id installs, registers and uninstalls cleanly', () async {
        final service = PluginService();
        final registry = ProviderRegistry();

        final config = await service.installPlugin('$id://engine');

        expect(config.id, id);
        expect(config.isEnabled, isTrue);
        expect(
          config.baseUrl,
          '$id://engine',
          reason: 'built-in engines keep their private scheme',
        );

        final installed = await service.loadInstalledPlugins();
        expect(
          installed.map((entry) => entry.id),
          contains(id),
          reason: '$id did not persist',
        );

        final registered = registry.activeProviders.where(
          (provider) => provider.id == id,
        );
        expect(registered, hasLength(1));
        expect(
          registered.single.supportsStreams,
          isTrue,
          reason: 'an installed add-on that cannot stream would be a lie',
        );

        // Reinstalling must not duplicate the entry or the registration.
        await service.installPlugin('$id://engine');
        final installedAgain = await service.loadInstalledPlugins();
        expect(installedAgain.where((entry) => entry.id == id), hasLength(1));
        expect(
          registry.activeProviders.where((provider) => provider.id == id),
          hasLength(1),
        );

        await service.uninstallPlugin(id);
        final afterRemoval = await service.loadInstalledPlugins();
        expect(afterRemoval.map((entry) => entry.id), isNot(contains(id)));
        expect(
          registry.activeProviders.where((provider) => provider.id == id),
          isEmpty,
        );
      });
    }

    test('an unknown scheme is rejected rather than half-installed', () async {
      final service = PluginService();
      await expectLater(
        service.installPlugin('not-a-real-provider://engine'),
        throwsA(anything),
      );
    });
  });
}
