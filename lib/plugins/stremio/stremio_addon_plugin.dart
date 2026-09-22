import '../../services/exalere_plugin_adapter.dart';

/// Stremio / Exalere remote protocol addon plugin adapter.
///
/// Implements [MediaProviderPlugin] by querying remote Stremio v3 manifest endpoints
/// (stream, catalog, subtitle) and translating them to native player models.
class StremioAddonPlugin extends ExalerePluginAdapter {
  StremioAddonPlugin({required super.config, super.client});
}
