import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import '../../../models/media_details.dart';
import '../../../models/media_item.dart';
import '../../../models/stream_source.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/library_provider.dart';
import '../../../services/libmpv_helper.dart';
import '../../../services/provider_registry.dart';
import '../../../services/tmdb_service.dart';

import '../../../services/video_cache_service.dart';
import 'player_playback_helper.dart';

/// Mixin encapsulating series next episode auto-play, intro/outro skip intervals, and IntroDB timestamps.
mixin PlayerEpisodesMixin<T extends StatefulWidget> on State<T> {
  MediaItem get mediaItem;
  Player get player;

  void showToast(String message);
  void onNextEpisodeStarted(
    List<StreamSource> streams,
    int season,
    int episode, {
    StreamSource? selectedSource,
  });
  void recordEpisodeProgress(int posSec, int durSec, int? season, int? episode);
  void onAfterEpisodeChanged();
  void onUserActivity();

  MediaDetails? details;
  int? currentSeason;
  int? currentEpisode;
  bool isLoadingNextEpisode = false;

  List<SkipInterval> skipIntervals = [];
  SkipInterval? activeSkip;
  bool hasSkippedIntro = false;
  bool hasSkippedOutro = false;
  int? _lastActiveSkipStart;
  bool _hasDismissedCurrentSkip = false;
  Timer? _skipButtonAutoDismissTimer;

  void disposeEpisodesState() {
    _skipButtonAutoDismissTimer?.cancel();
  }

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
      final d = await ProviderRegistry().getDetails(
        mediaItem.id,
        providerId: mediaItem.effectiveProviderId,
        title: mediaItem.title,
      );
      if (mounted && d != null) {
        setState(() => details = d);
      }
    } catch (_) {}
  }

  Episode? get currentEpisodeData => EpisodeHelper.findCurrentEpisode(
    details: details,
    currentSeason: currentSeason,
    currentEpisode: currentEpisode,
  );

  Episode? findNextEpisode() => EpisodeHelper.findNextEpisode(
    details: details,
    currentSeason: currentSeason,
    currentEpisode: currentEpisode,
  );

  Future<void> playNextEpisode({bool auto = false}) async {
    if (!mediaItem.isSeries || isLoadingNextEpisode) return;
    final library = context.read<LibraryProvider>();
    isLoadingNextEpisode = true;

    try {
      if (details == null) {
        showToast(
          auto ? 'Checking next episode...' : 'Loading next episode...',
        );
        details = await ProviderRegistry().getDetails(
          mediaItem.id,
          providerId: mediaItem.effectiveProviderId,
          title: mediaItem.title,
        );
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

      final lastUsed = library.getLastUsedStream(mediaItem.id);

      final prefProvider =
          lastUsed?.effectiveProviderId ??
          ProviderRegistry().defaultProviderId ??
          mediaItem.effectiveProviderId;

      final streams = await ProviderRegistry().resolveStreams(
        subjectId: mediaItem.id,
        title: mediaItem.title,
        year: mediaItem.year,
        season: nextEp.season,
        episode: nextEp.episode,
        preferredProviderId: prefProvider,
      );

      if (!mounted) return;

      if (streams.isEmpty) {
        showToast('No streams found for next episode');
        isLoadingNextEpisode = false;
        return;
      }

      final active = library.pickBestMatchingStream(
        streams,
        preferredStream: lastUsed,
        preferredProviderId: prefProvider,
      );

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

      onNextEpisodeStarted(
        streams,
        nextEp.season,
        nextEp.episode,
        selectedSource: active,
      );

      if (Platform.isWindows) {
        LibMpvHelper.ensureCriticalSectionsInitialized();
      }

      try {
        await player.stop();
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 150));

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

  Future<void> playSpecificEpisode(int seasonNum, int episodeNum) async {
    if (!mediaItem.isSeries || isLoadingNextEpisode) return;
    final library = context.read<LibraryProvider>();
    isLoadingNextEpisode = true;

    try {
      showToast('Loading S$seasonNum E$episodeNum...');
      details ??= await ProviderRegistry().getDetails(
        mediaItem.id,
        providerId: mediaItem.effectiveProviderId,
        title: mediaItem.title,
      );

      final lastUsed = library.getLastUsedStream(mediaItem.id);

      final prefProvider =
          lastUsed?.effectiveProviderId ??
          ProviderRegistry().defaultProviderId ??
          mediaItem.effectiveProviderId;

      final streams = await ProviderRegistry().resolveStreams(
        subjectId: mediaItem.id,
        title: mediaItem.title,
        year: mediaItem.year,
        season: seasonNum,
        episode: episodeNum,
        preferredProviderId: prefProvider,
      );

      if (!mounted) return;

      if (streams.isEmpty) {
        showToast('No streams found for S$seasonNum E$episodeNum');
        isLoadingNextEpisode = false;
        return;
      }

      final active = library.pickBestMatchingStream(
        streams,
        preferredStream: lastUsed,
        preferredProviderId: prefProvider,
      );

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
        currentSeason = seasonNum;
        currentEpisode = episodeNum;
        hasSkippedIntro = false;
        hasSkippedOutro = false;
        activeSkip = null;
      });

      onNextEpisodeStarted(
        streams,
        seasonNum,
        episodeNum,
        selectedSource: active,
      );

      if (Platform.isWindows) {
        LibMpvHelper.ensureCriticalSectionsInitialized();
      }

      try {
        await player.stop();
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 150));

      final media = Media(active.url, httpHeaders: active.headers);

      if (player.platform is NativePlayer) {
        try {
          final native = player.platform as NativePlayer;
          final cacheProps = VideoCacheService.instance.getMpvCacheProperties();
          for (final entry in cacheProps.entries) {
            await native.setProperty(entry.key, entry.value);
          }
        } catch (_) {}
      }

      await player.open(media);

      loadSeriesSkipMarkers();
      onAfterEpisodeChanged();
    } catch (e) {
      debugPrint('Error playing episode: $e');
      if (mounted) {
        showToast('Could not play episode: $e');
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
      details ??= await ProviderRegistry().getDetails(
        mediaItem.id,
        providerId: mediaItem.effectiveProviderId,
        title: mediaItem.title,
      );
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
    _skipButtonAutoDismissTimer?.cancel();
    _hasDismissedCurrentSkip = true;
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

    if (active != null) {
      if (active.startSeconds != _lastActiveSkipStart) {
        _lastActiveSkipStart = active.startSeconds;
        _hasDismissedCurrentSkip = false;
        _skipButtonAutoDismissTimer?.cancel();
        // Auto-dismiss skip button after 6 seconds if not pressed
        _skipButtonAutoDismissTimer = Timer(const Duration(seconds: 6), () {
          if (mounted) {
            setState(() {
              _hasDismissedCurrentSkip = true;
              activeSkip = null;
            });
          }
        });
      }
      if (_hasDismissedCurrentSkip) {
        active = null;
      }
    } else {
      _lastActiveSkipStart = null;
      _hasDismissedCurrentSkip = false;
      _skipButtonAutoDismissTimer?.cancel();
    }

    if (active != activeSkip) {
      setState(() => activeSkip = active);
      if (active != null) {
        onUserActivity();
      }
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
