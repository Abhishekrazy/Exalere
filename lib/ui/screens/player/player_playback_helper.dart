import '../../../models/media_details.dart';
import 'player_audio_subtitles_sheet.dart';

/// Helper utility for player duration formatting and math clamping.
class PlayerTimeHelper {
  const PlayerTimeHelper._();

  /// Formats duration into H:MM:SS or M:SS.
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  /// Clamps a Duration value between min and max.
  static Duration clampDuration(Duration val, Duration min, Duration max) {
    if (val < min) return min;
    if (val > max) return max;
    return val;
  }
}

/// Helper utility for language matching and alias resolution.
class LanguageMatcher {
  const LanguageMatcher._();

  static final Map<String, List<String>> languageCodeAliases = {
    'hindi': ['hi', 'hin', 'hindi'],
    'english': ['en', 'eng', 'english'],
    'tamil': ['ta', 'tam', 'tamil'],
    'telugu': ['te', 'tel', 'telugu'],
    'malayalam': ['ml', 'mal', 'malayalam'],
    'kannada': ['kn', 'kan', 'kannada'],
    'bengali': ['bn', 'ben', 'bengali'],
    'marathi': ['mr', 'mar', 'marathi'],
    'punjabi': ['pa', 'pan', 'punjabi'],
    'gujarati': ['gu', 'guj', 'gujarati'],
    'spanish': ['es', 'spa', 'spanish'],
    'french': ['fr', 'fra', 'fre', 'french'],
    'german': ['de', 'deu', 'ger', 'german'],
    'japanese': ['ja', 'jpn', 'japanese'],
    'korean': ['ko', 'kor', 'korean'],
    'chinese': ['zh', 'zho', 'chi', 'chinese'],
    'russian': ['ru', 'rus', 'russian'],
    'arabic': ['ar', 'ara', 'arabic'],
    'portuguese': ['pt', 'por', 'portuguese'],
    'italian': ['it', 'ita', 'italian'],
    'turkish': ['tr', 'tur', 'turkish'],
  };

  /// Checks if a track's title/language matches the user's preferred target language.
  static bool isLanguageMatch(
    String targetLang, {
    String? title,
    String? language,
    String? label,
  }) {
    final target = targetLang.trim().toLowerCase();
    final t = (title ?? '').toLowerCase();
    final l = (language ?? '').toLowerCase();
    final lbl = (label ?? '').toLowerCase();

    // Direct substring check
    if (t.contains(target) || l.contains(target) || lbl.contains(target)) {
      return true;
    }

    // Clean track name check
    final clean = PlayerAudioSubtitlesSheet.cleanTrackName(
      (title != null && title.isNotEmpty)
          ? title
          : ((label != null && label.isNotEmpty) ? label : language),
      isAudio: true,
    ).toLowerCase();
    if (clean.contains(target)) {
      return true;
    }

    // Alias / ISO code check
    final aliases = languageCodeAliases[target];
    if (aliases != null) {
      for (final alias in aliases) {
        if (l == alias ||
            l.startsWith('$alias-') ||
            l.startsWith('${alias}_') ||
            t.contains(alias) ||
            lbl.contains(alias)) {
          return true;
        }
      }
    }

    return false;
  }
}

/// Helper utility for finding next episode in a series.
class EpisodeHelper {
  const EpisodeHelper._();

  /// Finds the next episode chronologically following currentSeason/currentEpisode.
  static Episode? findNextEpisode({
    required MediaDetails? details,
    required int? currentSeason,
    required int? currentEpisode,
  }) {
    if (details == null || details.seasons.isEmpty) return null;

    final sNum = currentSeason ?? 1;
    final eNum = currentEpisode ?? 1;

    // 1. Look for next episode in the current season
    final currentSeasonList = details.seasons
        .where((s) => s.seasonNumber == sNum)
        .toList();
    if (currentSeasonList.isNotEmpty) {
      final currentSeason = currentSeasonList.first;
      final nextInSeason = currentSeason.episodes
          .where((e) => e.episode == eNum + 1)
          .toList();
      if (nextInSeason.isNotEmpty) {
        return nextInSeason.first;
      }
    }

    // 2. Otherwise, look for the first episode in the next available season
    final sortedSeasons = List<Season>.from(details.seasons)
      ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
    final nextSeason = sortedSeasons.firstWhere(
      (s) => s.seasonNumber > sNum && s.episodes.isNotEmpty,
      orElse: () =>
          const Season(seasonNumber: -1, episodeCount: 0, episodes: []),
    );
    if (nextSeason.seasonNumber != -1 && nextSeason.episodes.isNotEmpty) {
      return nextSeason.episodes.first;
    }

    return null;
  }
}
