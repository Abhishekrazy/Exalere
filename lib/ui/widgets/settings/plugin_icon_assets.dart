/// Bundled artwork for the first-party add-ons.
///
/// Vega ships provider icons inside the app and so do we: the add-on list must
/// not fall back to letter tiles just because a CDN request failed, and the TV
/// build has to look the same offline. Community entries without artwork keep
/// their network `icon` URL and the initials tile.
class PluginIconAssets {
  PluginIconAssets._();

  static const Map<String, String> _byId = {
    'moviebox': 'assets/images/addons/moviebox.png',
    'org.exalere.moviebox': 'assets/images/addons/moviebox.png',
    'fourkhd': 'assets/images/addons/fourkhd.png',
    'org.exalere.fourkhd': 'assets/images/addons/fourkhd.png',
    'dramachi': 'assets/images/addons/dramachi.png',
    'org.exalere.dramachi': 'assets/images/addons/dramachi.png',
    'vidsrc': 'assets/images/addons/vidsrc.png',
    'org.exalere.vidsrc': 'assets/images/addons/vidsrc.png',
    'circleftp': 'assets/images/addons/circleftp.png',
    'hdhub4u': 'assets/images/addons/hdhub4u.png',
    'movies4u': 'assets/images/addons/movies4u.png',
    'moviesmod': 'assets/images/addons/moviesmod.png',
    'uhdmovies': 'assets/images/addons/uhdmovies.png',
    'moviesdrive': 'assets/images/addons/moviesdrive.png',
    'rogmovies': 'assets/images/addons/rogmovies.png',
  };

  /// Bundled icon for [pluginId], or null when the add-on is not first-party.
  static String? assetFor(String pluginId) => _byId[pluginId];

  /// Bundled icon by display name, for store rows that only expose a name.
  static String? assetForName(String name) {
    final normalised = name.toLowerCase();
    if (normalised.contains('moviebox')) return _byId['moviebox'];
    if (normalised.contains('4k')) return _byId['fourkhd'];
    if (normalised.contains('dramachi')) return _byId['dramachi'];
    if (normalised.contains('vidsrc')) return _byId['vidsrc'];
    if (normalised.contains('circleftp')) return _byId['circleftp'];
    if (normalised.contains('hdhub4u')) return _byId['hdhub4u'];
    if (normalised.contains('movies4u')) return _byId['movies4u'];
    if (normalised.contains('moviesmod')) return _byId['moviesmod'];
    if (normalised.contains('uhdmovies')) return _byId['uhdmovies'];
    if (normalised.contains('moviesdrive')) return _byId['moviesdrive'];
    if (normalised.contains('rogmovies')) return _byId['rogmovies'];
    return null;
  }
}
