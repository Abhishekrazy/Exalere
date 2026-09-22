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

/// All compiled-in plugin IDs available for user installation from the Plugin Store.
/// These are registered only when the user explicitly installs them — never auto-activated.
const List<String> availableBuiltInPluginIds = [
  'fourkhdhub',
  'moviebox',
  'vidsrc',
  'dramachi',
  'circleftp',
];
