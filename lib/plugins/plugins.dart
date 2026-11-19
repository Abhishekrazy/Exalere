import '../models/exalere_plugin.dart';
import '../services/hdhub4u_provider.dart';
import '../services/movies4u_provider.dart';
import '../services/moviesdrive_provider.dart';
import '../services/moviesmod_provider.dart';
import '../services/rogmovies_provider.dart';
import '../services/uhdmovies_provider.dart';
import '../services/media_provider_plugin.dart';
import '../services/scrapers/vega_site_config.dart';
import '../services/scrapers/vega_site_scraper.dart';
import 'circleftp/circleftp_plugin.dart';
import 'dramachi/dramachi_plugin.dart';
import 'fourkhdhub/fourkhdhub_plugin.dart';
import 'internet_archive/internet_archive_plugin.dart';
import 'animesalt/animesalt_plugin.dart';
import 'animesub/animesub_plugin.dart';
import 'animeworld/animeworld_plugin.dart';
import 'animestream/animestream_plugin.dart';
import 'kickassanime/kickassanime_plugin.dart';
import 'kisskh/kisskh_plugin.dart';
import 'moviebox/moviebox_plugin.dart';
import 'stremio/stremio_addon_plugin.dart';
import 'tmdb/tmdb_plugin.dart';
import 'torrentio/torrentio_plugin.dart';
import 'vidsrc/vidsrc_plugin.dart';

export '../services/media_provider_plugin.dart';
export 'circleftp/circleftp_plugin.dart';
export 'dramachi/dramachi_plugin.dart';
export 'fourkhdhub/fourkhdhub_plugin.dart';
export 'internet_archive/internet_archive_plugin.dart';
export 'animesalt/animesalt_plugin.dart';
export 'animesub/animesub_plugin.dart';
export 'animeworld/animeworld_plugin.dart';
export 'animestream/animestream_plugin.dart';
export 'kickassanime/kickassanime_plugin.dart';
export 'kisskh/kisskh_plugin.dart';
export 'moviebox/moviebox_plugin.dart';
export 'stremio/stremio_addon_plugin.dart';
export 'tmdb/tmdb_plugin.dart';
export 'torrentio/torrentio_plugin.dart';
export 'vidsrc/vidsrc_plugin.dart';

/// Dynamically instantiate a [MediaProviderPlugin] from its persisted [ExalerePluginConfig].
/// For native engines (MovieBox, 4K HD Hub, Dramachi, VidSrc, CircleFTP), uses high-performance
/// built-in scraper engines. For external/community plugins, connects via remote [StremioAddonPlugin].
MediaProviderPlugin createPlugin(ExalerePluginConfig config) {
  final id = config.id.toLowerCase();
  final url = config.baseUrl.toLowerCase();

  if (id == 'tmdb' || id.contains('themoviedb')) {
    return TmdbPlugin(config: config);
  }
  // Ported Vega sites are data-driven: one branch covers every configured site.
  final vegaSite = VegaSiteConfig.byId(id);
  if (vegaSite != null) {
    return VegaSitePlugin(vegaSite);
  }

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
  // The native engine owns the bare id; the remote Stremio add-on
  // (`com.stremio.torrentio.addon`) keeps its own manifest URL route.
  if (id == 'animesub' || url == 'animesub://engine') {
    return AnimeSubPlugin(config: config);
  }
  if (id == 'animeworld' || url == 'animeworld://engine') {
    return AnimeWorldPlugin(config: config);
  }
  if (id == 'animesalt' || url == 'animesalt://engine') {
    return AnimeSaltPlugin(config: config);
  }
  if (id == 'animestream' || url == 'animestream://engine') {
    return AnimeStreamPlugin(config: config);
  }
  if (id == 'kickassanime' || url == 'kickassanime://engine') {
    return KickAssAnimePlugin(config: config);
  }
  if (id == 'kisskh' || url == 'kisskh://engine') {
    return KissKhPlugin(config: config);
  }
  if (id == 'torrentio' || url == 'torrentio://engine') {
    return TorrentioPlugin(config: config);
  }
  if (id.contains('internetarchive') ||
      id.contains('internet-archive') ||
      url.contains('archive.org')) {
    return InternetArchivePlugin(config: config);
  }
  if (id.contains('circleftp') || url.contains('circleftp')) {
    return CircleFtpPlugin(config: config);
  }
  if (id.contains('hdhub4u') || url.contains('hdhub4u')) {
    return HDHub4uPlugin();
  }
  if (id.contains('moviesmod') || url.contains('moviesmod')) {
    return MoviesModPlugin();
  }
  if (id.contains('uhdmovies') || url.contains('uhdmovies')) {
    return UhdMoviesPlugin();
  }
  if (id.contains('moviesdrive') || url.contains('moviesdrive')) {
    return MoviesDrivePlugin();
  }
  if (id.contains('movies4u') || url.contains('movies4u')) {
    return Movies4UPlugin();
  }
  if (id.contains('rogmovies') || url.contains('rogmovies')) {
    return RogMoviesPlugin();
  }

  return StremioAddonPlugin(config: config);
}
