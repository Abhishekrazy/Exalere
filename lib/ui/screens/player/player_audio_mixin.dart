import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import '../../../models/media_details.dart';
import '../../../models/stream_source.dart';
import '../../../providers/app_provider.dart';
import '../../../services/libmpv_helper.dart';
import '../../../services/moviebox_provider.dart';
import 'player_audio_subtitles_sheet.dart';
import 'player_playback_helper.dart';

/// Mixin encapsulating audio tracks, external subtitles, audio dubs, and default language auto-selection.
mixin PlayerAudioMixin<T extends StatefulWidget> on State<T> {
  Player get player;
  MovieBoxProvider get movieBoxProvider;
  int? get currentSeason;
  int? get currentEpisode;
  MediaDetails? get mediaDetails;

  void showToast(String message);
  bool pauseForModal();
  void resumeAfterModal(bool wasPlaying);
  void onDubStreamsLoaded(List<StreamSource> newSources, StreamSource active);
  void handlePlaybackFailure(String reason);

  Tracks tracks = const Tracks();
  List<SubtitleOption> externalSubtitles = [];
  bool subtitlesEnabled = true;
  SubtitleTrack? activeSubtitleTrack;
  List<AudioTrackOption> availableDubs = [];
  bool isSwitchingAudio = false;
  bool hasAutoSelectedAudio = false;

  Future<void> loadSubtitlesAndDubs({
    required String mediaId,
    String? resourceId,
  }) async {
    // 1. Load external subtitles
    if (resourceId != null && resourceId.isNotEmpty) {
      final subs = await movieBoxProvider.getSubtitles(
        subjectId: mediaId,
        resourceId: resourceId,
      );
      if (mounted) {
        setState(() => externalSubtitles = subs);
      }
    }

    // 2. Load available audio dubs from details
    final details = mediaDetails ?? await movieBoxProvider.getDetails(mediaId);
    if (mounted && details != null && details.dubs.isNotEmpty) {
      setState(() => availableDubs = details.dubs);
    }
    if (mounted) {
      checkAndApplyDefaultAudioLanguage();
    }
  }

  void toggleSubtitleOnOff() {
    if (subtitlesEnabled) {
      player.setSubtitleTrack(SubtitleTrack.no());
      setState(() => subtitlesEnabled = false);
      showToast('Subtitles Off');
    } else {
      if (activeSubtitleTrack != null) {
        player.setSubtitleTrack(activeSubtitleTrack!);
      } else if (tracks.subtitle.isNotEmpty) {
        player.setSubtitleTrack(tracks.subtitle.first);
      } else if (externalSubtitles.isNotEmpty) {
        selectExternalSubtitle(externalSubtitles.first);
      }
      setState(() => subtitlesEnabled = true);
      showToast('Subtitles On');
    }
  }

  Future<void> selectExternalSubtitle(SubtitleOption sub) async {
    try {
      final track = SubtitleTrack.uri(sub.url, title: sub.name);
      await player.setSubtitleTrack(track);
      if (mounted) {
        setState(() {
          subtitlesEnabled = true;
          activeSubtitleTrack = track;
        });
        showToast('Subtitle: ${sub.name}');
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
        setState(() {});
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
      final dubStreams = await movieBoxProvider.getStreams(
        subjectId: dub.subjectId,
        season: currentSeason ?? 0,
        episode: currentEpisode ?? 0,
      );

      if (dubStreams.isNotEmpty && mounted) {
        final newSource = dubStreams.first;
        onDubStreamsLoaded(dubStreams, newSource);

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
        await player.open(media);
        if (mounted) {
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

    final preferred = context.read<AppProvider>().defaultAudioLanguage;
    final isExplicitOriginal =
        preferred != null && preferred.toLowerCase().contains('original');

    // If user explicitly configured 'Original Audio' in settings, do not override
    if (isExplicitOriginal) {
      hasAutoSelectedAudio = true;
      return;
    }

    // Default language hierarchy:
    // 1. Hindi (default video language rather than original)
    // 2. English
    // 3. User preferred language (if explicitly set and not Hindi/English/original/default)
    final candidates = <String>['Hindi', 'English'];
    if (preferred != null && preferred.trim().isNotEmpty) {
      final p = preferred.trim();
      final pLower = p.toLowerCase();
      if (!pLower.contains('original') &&
          pLower != 'default' &&
          !candidates.any((c) => c.toLowerCase() == pLower)) {
        candidates.add(p);
      }
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
      initialAudioTrack: player.state.track.audio,
      initialSubtitlesEnabled: subtitlesEnabled,
      initialSubtitleTrack: activeSubtitleTrack ?? player.state.track.subtitle,
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
          });
          showToast('Subtitle: $label');
        }
      },
    );

    resumeAfterModal(wasPlaying);
  }
}
