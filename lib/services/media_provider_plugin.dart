import '../models/media_item.dart';
import '../models/media_details.dart';
import '../models/stream_source.dart';

/// Standard interface for all media content and streaming providers in Exalere.
/// Allows dynamic plug-and-play backend support with zero breaking changes to the UI.
abstract class MediaProviderPlugin {
  /// Unique machine-readable identifier (e.g., 'moviebox', 'fourkhdhub', 'vidstream')
  String get id;

  /// User-friendly display name (e.g., 'MovieBox', '4K HD Hub')
  String get name;

  /// Priority of this provider for resolving streams (higher numbers attempted first)
  int get priority => 10;

  /// Whether this provider is enabled and active
  bool get isEnabled => true;

  /// Whether this provider supports search queries
  bool get supportsSearch => false;

  /// Whether this provider supports TV series with seasons/episodes
  bool get supportsSeries => false;

  /// Whether this provider supports standalone movies
  bool get supportsMovies => true;

  /// Initialize any required tokens, cryptographic keys, or remote configurations
  Future<void> init() async {}

  /// Search for items matching [query]
  Future<List<MediaItem>> search(String query) async => [];

  /// Get detailed information, synopsis, and season/episode lists
  Future<MediaDetails?> getDetails(String id) async => null;

  /// Resolve playable video streams for a movie or TV episode
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    int? season,
    int? episode,
  });
}
