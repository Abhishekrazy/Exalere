import '../models/exalere_plugin.dart';
import '../services/media_provider_plugin.dart';
import 'circleftp/circleftp_plugin.dart';
import 'dramachi/dramachi_plugin.dart';
import 'fourkhdhub/fourkhdhub_plugin.dart';
import 'moviebox/moviebox_plugin.dart';
import 'stremio/stremio_addon_plugin.dart';
import 'vidsrc/vidsrc_plugin.dart';

export '../services/media_provider_plugin.dart';
export 'circleftp/circleftp_plugin.dart';
export 'dramachi/dramachi_plugin.dart';
export 'fourkhdhub/fourkhdhub_plugin.dart';
export 'moviebox/moviebox_plugin.dart';
export 'stremio/stremio_addon_plugin.dart';
export 'vidsrc/vidsrc_plugin.dart';

typedef PluginFactory = MediaProviderPlugin Function([
  ExalerePluginConfig? config,
]);

/// Registry of all built-in modular plugins supported natively by Exalere.
///
/// New plugins can be introduced by adding their implementation file under `lib/plugins/`
/// and registering their factory here, with zero modifications required in the player or UI code.
final Map<String, PluginFactory> builtInPluginFactories = {
  'fourkhdhub': ([config]) => FourKHdHubPlugin(),
  'moviebox': ([config]) => MovieBoxPlugin(),
  'vidsrc': ([config]) => VidSrcPlugin(),
  'dramachi': ([config]) => DramachiPlugin(),
  'circleftp': ([config]) => CircleFtpPlugin(),
};

/// Dynamically instantiate a [MediaProviderPlugin] from its persisted [ExalerePluginConfig].
/// Matches built-in plugin factories first, and falls back to [StremioAddonPlugin] for remote URLs.
MediaProviderPlugin createPlugin(ExalerePluginConfig config) {
  final factory = builtInPluginFactories[config.id];
  if (factory != null) {
    return factory(config);
  }
  return StremioAddonPlugin(config: config);
}

/// Default built-in plugins enabled on first launch or when missing from storage.
List<ExalerePluginConfig> get defaultBuiltInPluginConfigs => [
  ExalerePluginConfig(
    id: 'fourkhdhub',
    name: '4K HD Hub Engine',
    baseUrl: 'fourkhdhub://engine',
    isEnabled: true,
    addedAt: DateTime(2025, 1, 1),
    manifest: const ExalerePluginManifest(
      id: 'fourkhdhub',
      name: '4K HD Hub Engine',
      version: '1.0.0',
      description:
          'Direct high-speed 4K/1080p stream scraper for movies and TV series.',
      resources: ['stream'],
      types: ['movie', 'series'],
    ),
  ),
  ExalerePluginConfig(
    id: 'moviebox',
    name: 'MovieBox Engine',
    baseUrl: 'moviebox://engine',
    isEnabled: true,
    addedAt: DateTime(2025, 1, 1),
    manifest: const ExalerePluginManifest(
      id: 'moviebox',
      name: 'MovieBox Engine',
      version: '1.0.0',
      description: 'Community MovieBox engine scraper & stream resolver with dynamic endpoint sync.',
      resources: ['stream'],
      types: ['movie', 'series'],
    ),
  ),
  ExalerePluginConfig(
    id: 'vidsrc',
    name: 'VidSrc Engine',
    baseUrl: 'https://vidsrc.sh',
    isEnabled: true,
    addedAt: DateTime(2025, 1, 1),
    manifest: const ExalerePluginManifest(
      id: 'vidsrc',
      name: 'VidSrc Engine',
      version: '1.0.0',
      description: 'Multi-mirror streaming engine with fast embeds and resilient failover (vidsrc.sh).',
      resources: ['stream'],
      types: ['movie', 'series'],
    ),
  ),
  ExalerePluginConfig(
    id: 'dramachi',
    name: 'Dramachi Engine',
    baseUrl: 'dramachi://engine',
    isEnabled: true,
    addedAt: DateTime(2025, 1, 1),
    manifest: const ExalerePluginManifest(
      id: 'dramachi',
      name: 'Dramachi Engine',
      version: '1.0.0',
      description:
          'Asian drama, anime, and movies streaming with fast CDN links.',
      resources: ['stream'],
      types: ['movie', 'series'],
    ),
  ),
  ExalerePluginConfig(
    id: 'circleftp',
    name: 'CircleFTP (BDIX)',
    baseUrl: 'circleftp://engine',
    isEnabled: true,
    addedAt: DateTime(2025, 1, 1),
    manifest: const ExalerePluginManifest(
      id: 'circleftp',
      name: 'CircleFTP (BDIX)',
      version: '1.0.0',
      description:
          'High-speed local streaming on the Bangladesh Internet Exchange.',
      resources: ['stream'],
      types: ['movie', 'series'],
    ),
  ),
];
