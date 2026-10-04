import 'dart:math';

import 'storage_service.dart';

/// Aggregated viewing statistics and user streaming habits.
class ViewingStats {
  final int totalMinutesWatched;
  final int totalUniqueTitles;
  final int moviesWatchedCount;
  final int episodesWatchedCount;
  final int completedCount;
  final Map<String, int> genreBreakdown;
  final String topDayOfWeek;
  final String peakTimeOfDay;
  final int activeStreakDays;

  const ViewingStats({
    required this.totalMinutesWatched,
    required this.totalUniqueTitles,
    required this.moviesWatchedCount,
    required this.episodesWatchedCount,
    required this.completedCount,
    required this.genreBreakdown,
    required this.topDayOfWeek,
    required this.peakTimeOfDay,
    required this.activeStreakDays,
  });

  String get formattedTotalTime {
    final hours = totalMinutesWatched ~/ 60;
    final mins = totalMinutesWatched % 60;
    if (hours > 0) {
      return '$hours hrs $mins mins';
    }
    return '$mins mins';
  }

  double get completionPercentage {
    if (totalUniqueTitles == 0) return 0.0;
    return (completedCount / totalUniqueTitles).clamp(0.0, 1.0);
  }

  static ViewingStats empty() {
    return const ViewingStats(
      totalMinutesWatched: 0,
      totalUniqueTitles: 0,
      moviesWatchedCount: 0,
      episodesWatchedCount: 0,
      completedCount: 0,
      genreBreakdown: {},
      topDayOfWeek: 'Weekend',
      peakTimeOfDay: 'Evening',
      activeStreakDays: 0,
    );
  }
}

/// Computes private, offline-first personal streaming habits & analytics.
class ViewingStatsService {
  static final ViewingStatsService _instance = ViewingStatsService._internal();
  factory ViewingStatsService() => _instance;
  ViewingStatsService._internal();

  final StorageService _storage = StorageService();

  Future<ViewingStats> computeStats({String? profileId}) async {
    final history = await _storage.getWatchHistory(profileId: profileId);
    final watchedEpisodesMap = await _storage.getAllWatchedEpisodes(
      profileId: profileId,
    );

    if (history.isEmpty) {
      return ViewingStats.empty();
    }

    int totalSeconds = 0;
    int movieCount = 0;
    int seriesTitleCount = 0;
    int completedCount = 0;
    final Map<String, int> genreCounts = {};
    final Map<int, int> dayOfWeekCounts = {}; // 1 (Mon) - 7 (Sun)
    final Map<int, int> hourOfDayCounts = {};
    final Set<String> uniqueMediaIds = {};
    final Set<String> activeDates = {};

    for (final item in history) {
      uniqueMediaIds.add(item.item.id);
      totalSeconds += item.positionSeconds;

      if (item.progress >= 0.88) {
        completedCount++;
      }

      if (item.item.isSeries) {
        seriesTitleCount++;
      } else {
        movieCount++;
      }

      // Tally genres
      if (item.item.genre != null && item.item.genre!.isNotEmpty) {
        final split = item.item.genre!.split(RegExp(r'[,/|]'));
        for (final g in split) {
          final trimmed = g.trim();
          if (trimmed.isNotEmpty) {
            genreCounts[trimmed] = (genreCounts[trimmed] ?? 0) + 1;
          }
        }
      }

      // Timestamp metrics
      final ts = item.lastWatchedTimestamp;
      final date = ts > 0
          ? DateTime.fromMillisecondsSinceEpoch(ts)
          : DateTime.now();
      dayOfWeekCounts[date.weekday] = (dayOfWeekCounts[date.weekday] ?? 0) + 1;
      hourOfDayCounts[date.hour] = (hourOfDayCounts[date.hour] ?? 0) + 1;
      activeDates.add('${date.year}-${date.month}-${date.day}');
    }

    // Tally watched episode count
    int totalEpisodes = 0;
    for (final epSet in watchedEpisodesMap.values) {
      totalEpisodes += epSet.length;
    }
    if (totalEpisodes == 0 && seriesTitleCount > 0) {
      totalEpisodes = seriesTitleCount;
    }

    // Top day of week
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    int bestDay = 5; // Friday default
    int maxDayCount = -1;
    dayOfWeekCounts.forEach((weekday, count) {
      if (count > maxDayCount) {
        maxDayCount = count;
        bestDay = weekday;
      }
    });
    final topDay = dayNames[(bestDay - 1).clamp(0, 6)];

    // Peak time of day
    int bestHour = 20; // 8 PM default
    int maxHourCount = -1;
    hourOfDayCounts.forEach((hour, count) {
      if (count > maxHourCount) {
        maxHourCount = count;
        bestHour = hour;
      }
    });

    String peakTime;
    if (bestHour >= 6 && bestHour < 12) {
      peakTime = 'Morning (6 AM - 12 PM)';
    } else if (bestHour >= 12 && bestHour < 17) {
      peakTime = 'Afternoon (12 PM - 5 PM)';
    } else if (bestHour >= 17 && bestHour < 22) {
      peakTime = 'Prime Evening (5 PM - 10 PM)';
    } else {
      peakTime = 'Late Night (10 PM - 4 AM)';
    }

    // Streak estimation
    final streak = min(activeDates.length, 14);

    return ViewingStats(
      totalMinutesWatched: (totalSeconds / 60).round(),
      totalUniqueTitles: uniqueMediaIds.length,
      moviesWatchedCount: movieCount,
      episodesWatchedCount: totalEpisodes,
      completedCount: completedCount,
      genreBreakdown: genreCounts,
      topDayOfWeek: topDay,
      peakTimeOfDay: peakTime,
      activeStreakDays: streak,
    );
  }
}
