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

/// Dynamically instantiate a [MediaProviderPlugin] from its persisted [ExalerePluginConfig].
/// For native engines (MovieBox, 4K HD Hub, Dramachi, VidSrc, CircleFTP), uses high-performance
/// built-in scraper engines. For external/community plugins, connects via remote [StremioAddonPlugin].
MediaProviderPlugin createPlugin(ExalerePluginConfig config) {
  final id = config.id.toLowerCase();
  final url = config.baseUrl.toLowerCase();

  if (id.contains('moviebox') || url.contains('moviebox')) {
    return MovieBoxPlugin(config: config);
  }
  if (id.contains('fourkhd') ||
      id.contains('4khd') ||
      url.contains('fourkhd') ||
      url.contains('4khd')) {
    return FourKHdHubPlugin(config: config);
  }
  if (id.contains('dramachi') || url.contains('dramachi')) {
    return DramachiPlugin(config: config);
  }
  if (id.contains('vidsrc') || url.contains('vidsrc')) {
    return VidSrcPlugin(config: config);
  }
  if (id.contains('circleftp') || url.contains('circleftp')) {
    return CircleFtpPlugin(config: config);
  }

  return StremioAddonPlugin(config: config);
}
