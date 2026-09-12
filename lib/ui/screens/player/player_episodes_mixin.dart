import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import '../../../models/media_details.dart';
import '../../../models/media_item.dart';
import '../../../models/stream_source.dart';
import '../../../providers/app_provider.dart';
import '../../../services/libmpv_helper.dart';
import '../../../services/moviebox_provider.dart';
import '../../../services/tmdb_service.dart';
import 'player_playback_helper.dart';

/// Mixin encapsulating series next episode auto-play, intro/outro skip intervals, and IntroDB timestamps.
mixin PlayerEpisodesMixin<T extends StatefulWidget> on State<T> {
  MediaItem get mediaItem;
  Player get player;
  MovieBoxProvider get movieBoxProvider;

  void showToast(String message);
  void onNextEpisodeStarted(
    List<StreamSource> streams,
    int season,
    int episode,
  );
  void recordEpisodeProgress(int posSec, int durSec, int? season, int? episode);
  void onAfterEpisodeChanged();

  MediaDetails? details;
  int? currentSeason;
  int? currentEpisode;
  bool isLoadingNextEpisode = false;

  List<SkipInterval> skipIntervals = [];
  SkipInterval? activeSkip;
  bool hasSkippedIntro = false;
  bool hasSkippedOutro = false;

  void initEpisodesState({
    required MediaDetails? initialDetails,
    required int? initialSeason,
    required int? initialEpisode,
  }) {
    details = initialDetails;
    currentSeason = initialSeason;
    currentEpisode = initialEpisode;
    if (details == null && mediaItem.isSeries) {
      fetchDetailsForNextEpisode();
    }
  }

  Future<void> fetchDetailsForNextEpisode() async {
    try {
      final d = await movieBoxProvider.getDetails(mediaItem.id);
      if (mounted && d != null) {
        setState(() => details = d);
      }
    } catch (_) {}
  }

  Episode? findNextEpisode() => EpisodeHelper.findNextEpisode(
    details: details,
    currentSeason: currentSeason,
    currentEpisode: currentEpisode,
  );

  Future<void> playNextEpisode({bool auto = false}) async {
    if (!mediaItem.isSeries || isLoadingNextEpisode) return;
    isLoadingNextEpisode = true;

    try {
      if (details == null) {
        showToast(
          auto ? 'Checking next episode...' : 'Loading next episode...',
        );
        details = await movieBoxProvider.getDetails(mediaItem.id);
      }

      final nextEp = findNextEpisode();
      if (nextEp == null) {
        if (mounted) {
          showToast('No more episodes');
        }
        isLoadingNextEpisode = false;
        return;
      }

      if (!mounted) return;
      showToast(
        '${auto ? 'Auto-playing' : 'Playing'} S${nextEp.season} E${nextEp.episode}: ${nextEp.title}',
      );

      final streams = await movieBoxProvider.getStreams(
        subjectId: mediaItem.id,
        season: nextEp.season,
        episode: nextEp.episode,
      );

      if (!mounted) return;

      if (streams.isEmpty) {
        showToast('No streams found for next episode');
        isLoadingNextEpisode = false;
        return;
      }

      final currentDur = player.state.duration.inSeconds;
      if (currentDur > 0) {
        recordEpisodeProgress(
          currentDur,
          currentDur,
          currentSeason,
          currentEpisode,
        );
      }

      setState(() {
        currentSeason = nextEp.season;
        currentEpisode = nextEp.episode;
        hasSkippedIntro = false;
        hasSkippedOutro = false;
        activeSkip = null;
      });

      onNextEpisodeStarted(streams, nextEp.season, nextEp.episode);

      if (Platform.isWindows) {
        LibMpvHelper.ensureCriticalSectionsInitialized();
      }

      try {
        await player.stop();
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 150));

      final active = streams.first;
      final media = Media(active.url, httpHeaders: active.headers);

      await player.open(media);

      loadSeriesSkipMarkers();
      onAfterEpisodeChanged();
    } catch (e) {
      debugPrint('Error playing next episode: $e');
      if (mounted) {
        showToast('Could not play next episode: $e');
      }
    } finally {
      if (mounted) {
        isLoadingNextEpisode = false;
      }
    }
  }

  Future<void> loadSeriesSkipMarkers() async {
    final sNum = currentSeason;
    final eNum = currentEpisode;
    if (sNum == null || eNum == null) return;

    try {
      details ??= await movieBoxProvider.getDetails(mediaItem.id);
      final d = details;
      if (d != null && d.seasons.isNotEmpty) {
        final season = d.seasons.firstWhere(
          (s) => s.seasonNumber == sNum,
          orElse: () => d.seasons.first,
        );
        final episode = season.episodes.firstWhere(
          (e) => e.episode == eNum,
          orElse: () => season.episodes.first,
        );

        if (episode.skipIntervals.isNotEmpty && mounted) {
          setState(() => skipIntervals = episode.skipIntervals);
        }
      }
    } catch (_) {}

    if (skipIntervals.where((s) => s.type == SkipType.intro).isEmpty &&
        mounted) {
      try {
        final realIntro = await TmdbService().getEpisodeIntroSkip(
          title: mediaItem.title,
          year: mediaItem.year,
          season: sNum,
          episode: eNum,
        );
        if (realIntro != null && mounted) {
          setState(() {
            skipIntervals = [...skipIntervals, realIntro];
          });
        }
      } catch (e) {
        debugPrint('Could not fetch verified intro skip from IntroDB/TMDB: $e');
      }
    }
  }

  void triggerSkip() {
    if (activeSkip == null) return;
    final skip = activeSkip!;
    if (skip.type == SkipType.outro) {
      playNextEpisode(auto: false);
      return;
    }
    final targetPoint = skip.endSeconds;
    final label = skip.label;
    hasSkippedIntro = true;
    setState(() => activeSkip = null);
    player.seek(Duration(seconds: targetPoint));
    showToast(
      'Skipped $label to ${PlayerTimeHelper.formatDuration(Duration(seconds: targetPoint))}',
    );
  }

  void checkSkipIntervals(Duration pos) {
    if (!mounted) return;
    final posSec = pos.inSeconds;
    final durSec = player.state.duration.inSeconds;

    final app = context.read<AppProvider>();
    SkipInterval? active;

    for (final interval in skipIntervals) {
      if (interval.contains(posSec)) {
        active = interval;
        break;
      }
    }

    if (active == null &&
        app.enableSmartSkip &&
        durSec > 180 &&
        currentSeason != null) {
      if (posSec >= durSec - 75 && posSec < durSec - 5) {
        active = SkipInterval(
          type: SkipType.outro,
          startSeconds: durSec - 75,
          endSeconds: durSec,
          label: 'Next Episode',
        );
      }
    }

    if (active != activeSkip) {
      setState(() => activeSkip = active);
    }

    if (active != null) {
      if (active.type == SkipType.intro &&
          app.autoSkipIntro &&
          !hasSkippedIntro) {
        hasSkippedIntro = true;
        player.seek(Duration(seconds: active.endSeconds));
        showToast('Auto-skipped Intro');
      } else if (active.type == SkipType.outro &&
          app.autoSkipOutro &&
          !hasSkippedOutro) {
        hasSkippedOutro = true;
        playNextEpisode(auto: true);
      }
    }
  }
}
