import '../models/exalere_plugin.dart';
import '../services/media_provider_plugin.dart';
import 'stremio/stremio_addon_plugin.dart';

export '../services/media_provider_plugin.dart';
export 'stremio/stremio_addon_plugin.dart';

/// Dynamically instantiate a [MediaProviderPlugin] from its persisted [ExalerePluginConfig].
/// Exalere is a pure media player host; all plugins are loaded dynamically over standard
/// remote protocols (Stremio / Exalere JSON manifest protocols).
MediaProviderPlugin createPlugin(ExalerePluginConfig config) {
  return StremioAddonPlugin(config: config);
}
