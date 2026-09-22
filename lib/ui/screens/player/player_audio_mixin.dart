import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import '../../../models/media_details.dart';
import '../../../models/stream_source.dart';
import '../../../plugins/plugins.dart';
import '../../../providers/app_provider.dart';
import '../../../services/libmpv_helper.dart';
import '../../../services/opensubtitles_service.dart';
import '../../../services/provider_registry.dart';
import '../../../services/video_cache_service.dart';
import 'player_audio_subtitles_sheet.dart';
import 'player_playback_helper.dart';

/// Mixin encapsulating audio tracks, external subtitles, audio dubs, and default language auto-selection.
mixin PlayerAudioMixin<T extends StatefulWidget> on State<T> {
  Player get player;
  int? get currentSeason;

  int? get currentEpisode;
  MediaDetails? get mediaDetails;

  void showToast(String message);
  bool pauseForModal();
  void resumeAfterModal(bool wasPlaying);
  void onDubStreamsLoaded(List<StreamSource> newSources, StreamSource active);
  void onDubPlaybackReady();
  void handlePlaybackFailure(String reason);

  Tracks tracks = const Tracks();
  List<SubtitleOption> externalSubtitles = [];
  bool subtitlesEnabled = true;
  SubtitleTrack? activeSubtitleTrack;
  SubtitleOption? activeExternalSubtitle;
  List<AudioTrackOption> availableDubs = [];
  AudioTrack? activeAudioTrack;
  AudioTrackOption? activeDubOption;
  String? activeAudioLabel;
  bool isSwitchingAudio = false;
  bool hasAutoSelectedAudio = false;

  Future<void> loadSubtitlesAndDubs({
    required String mediaId,
    String? resourceId,
    int? season,
    int? episode,
    String? imdbId,
    List<SubtitleOption> initialSubtitles = const [],
  }) async {
    // 1. Pre-seed external subtitles if provided by stream source
    final List<SubtitleOption> collected = List.from(initialSubtitles);
    final Set<String> seenUrls = collected.map((s) => s.url).toSet();

    if (mounted && collected.isNotEmpty) {
      setState(() => externalSubtitles = List.unmodifiable(collected));
      checkAndApplyDefaultSubtitle();
    }

    // 2. Fetch external subtitles from MovieBox and OpenSubtitles in parallel
    final futures = <Future<List<SubtitleOption>>>[];

    // MovieBox captions (if MovieBox plugin is active)
    final mb = ProviderRegistry().getProvider('moviebox');
    if (mb is MovieBoxPlugin) {
      futures.add(
        mb.getSubtitles(
          subjectId: mediaId,
          resourceId: resourceId,
          season: season ?? currentSeason ?? 0,
          episode: episode ?? currentEpisode ?? 0,
        ),
      );
    }

    // OpenSubtitles v3 (if IMDb ID available)
    if (imdbId != null && imdbId.startsWith('tt')) {
      futures.add(
        OpenSubtitlesService().getSubtitles(
          imdbId: imdbId,
          isSeries: (season ?? currentSeason ?? 0) > 0,
          season: season ?? currentSeason,
          episode: episode ?? currentEpisode,
        ),
      );
    }

    try {
      final results = await Future.wait(futures);
      for (final list in results) {
        for (final sub in list) {
          if (seenUrls.add(sub.url)) {
            collected.add(sub);
          }
        }
      }
      if (mounted) {
        setState(() => externalSubtitles = List.unmodifiable(collected));
        checkAndApplyDefaultSubtitle();
      }
    } catch (e) {
      debugPrint('[PlayerAudioMixin] Error fetching subtitles: $e');
    }

    // 3. Load available audio dubs from details
    final details =
        mediaDetails ?? await ProviderRegistry().getDetails(mediaId);

    if (mounted && details != null && details.dubs.isNotEmpty) {
      setState(() => availableDubs = details.dubs);
    }
    if (mounted) {
      checkAndApplyDefaultAudioLanguage();
    }
  }

  void checkAndApplyDefaultSubtitle() {
    if (!mounted || !subtitlesEnabled) return;
    if (activeSubtitleTrack != null || activeExternalSubtitle != null) return;

    final validTracks = tracks.subtitle.where((t) {
      final l = (t.title ?? t.language ?? t.id).toLowerCase();
      return !l.contains('(no)') && l != 'no';
    }).toList();

    // 1. Try embedded track matching English
    for (final track in validTracks) {
      if (LanguageMatcher.isLanguageMatch(
        'English',
        title: track.title,
        language: track.language,
      )) {
        player.setSubtitleTrack(track);
        if (mounted) {
          setState(() {
            activeSubtitleTrack = track;
            activeExternalSubtitle = null;
          });
        }
        return;
      }
    }

    // 2. Try external subtitle matching English
    if (externalSubtitles.isNotEmpty) {
      final engSub = externalSubtitles.firstWhere(
        (s) => LanguageMatcher.isLanguageMatch(
          'English',
          title: s.name,
          language: s.language,
        ),
        orElse: () => externalSubtitles.first,
      );
      selectExternalSubtitle(engSub, showNotification: false);
      return;
    }

    // 3. Fallback to first available embedded track
    if (validTracks.isNotEmpty) {
      final first = validTracks.first;
      player.setSubtitleTrack(first);
      if (mounted) {
        setState(() {
          activeSubtitleTrack = first;
          activeExternalSubtitle = null;
        });
      }
    }
  }

  void toggleSubtitleOnOff() {
    if (subtitlesEnabled) {
      player.setSubtitleTrack(SubtitleTrack.no());
      setState(() {
        subtitlesEnabled = false;
        activeSubtitleTrack = null;
        activeExternalSubtitle = null;
      });
      showToast('Subtitles Off');
    } else {
      setState(() => subtitlesEnabled = true);
      if (activeExternalSubtitle != null) {
        selectExternalSubtitle(activeExternalSubtitle!);
      } else if (activeSubtitleTrack != null) {
        player.setSubtitleTrack(activeSubtitleTrack!);
        showToast('Subtitles On');
      } else {
        checkAndApplyDefaultSubtitle();
        showToast('Subtitles On');
      }
    }
  }

  Future<void> selectExternalSubtitle(
    SubtitleOption sub, {
    bool showNotification = true,
  }) async {
    try {
      final track = SubtitleTrack.uri(
        sub.url,
        title: sub.name,
        language: sub.language,
      );
      await player.setSubtitleTrack(track);
      if (mounted) {
        setState(() {
          subtitlesEnabled = true;
          activeSubtitleTrack = track;
          activeExternalSubtitle = sub;
        });
        if (showNotification) {
          showToast('Subtitle: ${sub.name}');
        }
      }
    } catch (e) {
      debugPrint('Error setting subtitle: $e');
    }
  }

  Future<void> selectAudioTrack(AudioTrack track, String label) async {
    if (isSwitchingAudio) return;
    setState(() => isSwitchingAudio = true);
    try {
      await player.setAudioTrack(track);
      if (mounted) {
        setState(() {
          activeAudioTrack = track;
          activeDubOption = null;
          activeAudioLabel = label;
        });
        showToast('Audio track: $label');
      }
    } catch (e) {
      debugPrint('Error selecting audio track: $e');
      if (mounted) {
        showToast('Could not switch audio: $e');
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => isSwitchingAudio = false);
      });
    }
  }

  Future<void> switchDubLanguage(AudioTrackOption dub) async {
    if (isSwitchingAudio) return;
    setState(() => isSwitchingAudio = true);
    showToast('Switching to ${dub.label} audio...');

    try {
      final currentPos = player.state.position.inSeconds;
      final dubStreams = await ProviderRegistry().resolveStreams(
        subjectId: dub.subjectId,
        season: currentSeason ?? 0,
        episode: currentEpisode ?? 0,
      );

      if (dubStreams.isNotEmpty && mounted) {
        final newSource = dubStreams.first;

        if (Platform.isWindows) {
          LibMpvHelper.ensureCriticalSectionsInitialized();
        }

        try {
          await player.stop();
        } catch (_) {}

        await Future.delayed(const Duration(milliseconds: 120));

        if (Platform.isWindows) {
          LibMpvHelper.ensureCriticalSectionsInitialized();
        }

        final media = Media(
          newSource.url,
          httpHeaders: newSource.headers,
          start: currentPos > 0 ? Duration(seconds: currentPos) : null,
        );

        if (player.platform is NativePlayer) {
          try {
            final native = player.platform as NativePlayer;
            final cacheProps = VideoCacheService.instance
                .getMpvCacheProperties();
            for (final entry in cacheProps.entries) {
              await native.setProperty(entry.key, entry.value);
            }
          } catch (_) {}
        }

        await player.open(media);

        // Notify screen state AFTER player.open() so the Video widget tree
        // is fully rebuilt before setState replaces _sources. Calling this
        // before/during open() caused a Duplicate-GlobalKey error from
        // media_kit_video's internal platform-view key.
        if (mounted) {
          onDubStreamsLoaded(dubStreams, newSource);
        }

        onDubPlaybackReady();
        if (mounted) {
          setState(() {
            activeDubOption = dub;
            activeAudioTrack = null;
            activeAudioLabel = dub.label;
          });
          showToast('Audio set to: ${dub.label}');
        }
      } else {
        if (mounted) {
          showToast('No stream available for ${dub.label}');
        }
      }
    } catch (e) {
      debugPrint('Error switching dub: $e');
      if (mounted) {
        showToast('Failed to switch dub: $e');
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => isSwitchingAudio = false);
      });
    }
  }

  void checkAndApplyDefaultAudioLanguage() {
    if (hasAutoSelectedAudio) return;
    // Guard against stale context - this can be called from stream subscriptions
    // that fire after a State rebuild or dispose. Without this guard, the
    // context.read call below throws the InheritedElement assertion failure.
    if (!mounted) return;
    // Suppress re-entry while a dub switch is already in progress
    if (isSwitchingAudio) return;

    final preferred = context.read<AppProvider>().defaultAudioLanguage;
    final isExplicitOriginal =
        preferred != null && preferred.toLowerCase().contains('original');

    // If user explicitly configured 'Original Audio' in settings, do not override
    if (isExplicitOriginal) {
      hasAutoSelectedAudio = true;
      return;
    }

    // Default language hierarchy:
    // 1. User preferred language (if explicitly set and not original/default)
    // 2. Hindi
    // 3. English
    final candidates = <String>[];
    if (preferred != null && preferred.trim().isNotEmpty) {
      final p = preferred.trim();
      final pLower = p.toLowerCase();
      if (!pLower.contains('original') && pLower != 'default') {
        candidates.add(p);
      }
    }
    if (!candidates.any((c) => c.toLowerCase() == 'hindi')) {
      candidates.add('Hindi');
    }
    if (!candidates.any((c) => c.toLowerCase() == 'english')) {
      candidates.add('English');
    }

    // 1. Check embedded audio tracks
    final validAudioTracks = tracks.audio.where((t) {
      final l = (t.title ?? t.language ?? t.id).toLowerCase();
      return !l.contains('(no)') && l != 'no';
    }).toList();

    for (final candidate in candidates) {
      for (final track in validAudioTracks) {
        if (LanguageMatcher.isLanguageMatch(
          candidate,
          title: track.title,
          language: track.language,
        )) {
          hasAutoSelectedAudio = true;
          final label = PlayerAudioSubtitlesSheet.cleanTrackName(
            track.title ?? track.language,
            isAudio: true,
          );
          if (player.state.track.audio != track) {
            debugPrint('Auto-selecting audio track: $label ($candidate)');
            selectAudioTrack(track, label);
          }
          return;
        }
      }

      // 2. Check provider dubbed audio options
      if (availableDubs.isNotEmpty) {
        for (final dub in availableDubs) {
          if (LanguageMatcher.isLanguageMatch(
            candidate,
            title: dub.label,
            language: dub.language,
            label: dub.label,
          )) {
            hasAutoSelectedAudio = true;
            debugPrint(
              'Auto-switching to dubbed stream: ${dub.label} ($candidate)',
            );
            switchDubLanguage(dub);
            return;
          }
        }
      }
    }

    if (mediaDetails != null && validAudioTracks.isNotEmpty) {
      hasAutoSelectedAudio = true;
    }
  }

  Future<void> showAudioAndSubtitleModal() async {
    final wasPlaying = pauseForModal();

    final validAudioTracks = tracks.audio.where((t) {
      final l = (t.title ?? t.language ?? t.id).toLowerCase();
      return !l.contains('(no)') && l != 'no';
    }).toList();

    final validSubtitleTracks = tracks.subtitle.where((t) {
      final l = (t.title ?? t.language ?? t.id).toLowerCase();
      return !l.contains('(no)') && l != 'no';
    }).toList();

    await PlayerAudioSubtitlesSheet.show(
      context: context,
      validAudioTracks: validAudioTracks,
      availableDubs: availableDubs,
      validSubtitleTracks: validSubtitleTracks,
      externalSubtitles: externalSubtitles,
      initialAudioTrack: activeAudioTrack ?? player.state.track.audio,
      initialDubOption: activeDubOption,
      initialAudioLabel: activeAudioLabel,
      initialSubtitlesEnabled: subtitlesEnabled,
      initialSubtitleTrack: activeSubtitleTrack ?? player.state.track.subtitle,
      initialExternalSubtitle: activeExternalSubtitle,
      onSelectDubOption: (dub) => switchDubLanguage(dub),
      onSelectAudioTrack: (track, label) {
        if (track != player.state.track.audio) {
          selectAudioTrack(track, label);
        }
      },
      onDisableSubtitles: () {
        if (subtitlesEnabled) {
          player.setSubtitleTrack(SubtitleTrack.no());
          setState(() {
            subtitlesEnabled = false;
            activeSubtitleTrack = null;
            activeExternalSubtitle = null;
          });
          showToast('Subtitles Off');
        }
      },
      onSelectExternalSubtitle: (sub) => selectExternalSubtitle(sub),
      onSelectSubtitleTrack: (track, label) {
        if (!subtitlesEnabled || track != player.state.track.subtitle) {
          player.setSubtitleTrack(track);
          setState(() {
            subtitlesEnabled = true;
            activeSubtitleTrack = track;
            activeExternalSubtitle = null;
          });
          showToast('Subtitle: $label');
        }
      },
    );

    resumeAfterModal(wasPlaying);
  }
}
