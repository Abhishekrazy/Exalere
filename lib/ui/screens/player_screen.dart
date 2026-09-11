import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../models/media_details.dart';
import '../../models/media_item.dart';
import '../../models/stream_source.dart';
import '../../providers/app_provider.dart';
import '../../providers/cast_provider.dart';
import '../../providers/library_provider.dart';
import '../../services/device_controls_service.dart';
import '../../services/external_player_service.dart';
import '../../services/libmpv_helper.dart';
import '../../services/moviebox_provider.dart';
import '../../services/tmdb_service.dart';
import '../../services/window_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/cast_dialog.dart';
import '../widgets/tv_focusable.dart';
import 'player/player_audio_subtitles_sheet.dart';
import 'player/player_error_view.dart';
import 'player/player_server_sheet.dart';
import 'player/player_speed_dialog.dart';

class PlayerScreen extends StatefulWidget {
  final MediaItem mediaItem;
  final StreamSource streamSource;
  final List<StreamSource> availableSources;
  final int? season;
  final int? episode;
  final int? startPositionSeconds;
  final MediaDetails? mediaDetails;

  const PlayerScreen({
    super.key,
    required this.mediaItem,
    required this.streamSource,
    this.availableSources = const [],
    this.season,
    this.episode,
    this.startPositionSeconds,
    this.mediaDetails,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  final MovieBoxProvider _movieBoxProvider = MovieBoxProvider();
  final WindowService _windowService = WindowService();
  final FocusNode _focusNode = FocusNode(debugLabel: 'PlayerRootFocus');
  final FocusNode _playPauseTvFocusNode = FocusNode(
    debugLabel: 'TvPlayPauseBtn',
  );
  final FocusNode _seekbarTvFocusNode = FocusNode(debugLabel: 'TvSeekbar');
  final FocusNode _tvBackBtnFocusNode = FocusNode(debugLabel: 'TvBackBtn');
  final FocusNode _errorRetryFocusNode = FocusNode(
    debugLabel: 'TvErrorRetryBtn',
  );

  // Multi-source state & watchdog
  late List<StreamSource> _sources;
  int _currentSourceIndex = 0;
  late StreamSource _activeSource;
  Timer? _sourceWatchdogTimer;

  // Controls & visibility
  bool _showControls = true;
  bool _isPlayerReady = false;
  bool _isLoadingVideo = true;
  bool _isBuffering = false;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<bool>? _playingSub;
  String? _errorMessage;
  Timer? _hideTimer;
  Timer? _progressTimer;
  Timer? _toastTimer;
  String? _toastMessage;

  // Screen lock & gestures
  bool _isControlsLocked = false;
  bool _showUnlockButton = false;
  Timer? _unlockButtonTimer;
  TapDownDetails? _doubleTapDetails;
  bool _isInteractingWithUi = false;
  bool _isOrientationLocked = false;
  int? _doubleTapSeekDirection;
  Timer? _doubleTapIndicatorTimer;

  // Resume banner
  Timer? _resumeBannerTimer;
  bool _showResumeBanner = false;
  int _resumedFromSeconds = 0;

  // Brightness gesture state
  double _brightness = 1.0;
  bool _showBrightnessIndicator = false;
  bool _isDraggingBrightness = false;
  Timer? _brightnessHideTimer;

  // Volume gesture state
  double _volume = 0.5;
  bool _showVolumeIndicator = false;
  bool _isDraggingVolume = false;
  Timer? _volumeHideTimer;

  void _onBrightnessDragUpdate(double delta) {
    if (context.read<AppProvider>().isTvMode) return;
    final next = (_brightness - delta / 180.0).clamp(0.01, 1.0);
    setState(() {
      _brightness = next;
      _showBrightnessIndicator = true;
    });
    DeviceControlsService.setBrightness(next);
    _brightnessHideTimer?.cancel();
    _brightnessHideTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _showBrightnessIndicator = false);
      }
    });
  }

  void _onVolumeDragUpdate(double delta) {
    if (context.read<AppProvider>().isTvMode) return;
    final next = (_volume - delta / 180.0).clamp(0.0, 1.0);
    setState(() {
      _volume = next;
      _showVolumeIndicator = true;
    });
    if (Platform.isAndroid) {
      DeviceControlsService.setVolume(next);
    } else {
      _player.setVolume(next * 100.0);
    }
    _volumeHideTimer?.cancel();
    _volumeHideTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _showVolumeIndicator = false);
      }
    });
  }

  // Subtitles & Audio
  StreamSubscription? _errorSub;
  StreamSubscription? _tracksSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _completedSub;
  Tracks _tracks = const Tracks();
  List<SubtitleOption> _externalSubtitles = [];
  bool _subtitlesEnabled = true;
  SubtitleTrack? _activeSubtitleTrack;
  List<AudioTrackOption> _availableDubs = [];
  bool _isSwitchingAudio = false;

  // Next Episode & Details
  MediaDetails? _details;
  int? _currentSeason;
  int? _currentEpisode;
  bool _isLoadingNextEpisode = false;

  // Skip Intro / Outro
  List<SkipInterval> _skipIntervals = [];
  SkipInterval? _activeSkip;
  bool _hasSkippedIntro = false;
  bool _hasSkippedOutro = false;

  // Playback settings
  double _playbackSpeed = 1.0;
  BoxFit _videoFit = BoxFit.contain;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();

    // Ensure Windows libmpv critical sections are initialized before player starts
    LibMpvHelper.ensureCriticalSectionsInitialized();

    // Source fallback setup
    _sources = widget.availableSources.isNotEmpty
        ? widget.availableSources
        : [widget.streamSource];
    _currentSourceIndex = _sources.indexWhere(
      (s) => s.url == widget.streamSource.url,
    );
    if (_currentSourceIndex < 0) _currentSourceIndex = 0;
    _activeSource = _sources[_currentSourceIndex];

    // Player setup
    _player = Player(
      configuration: const PlayerConfiguration(title: 'Exalere'),
    );
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(hwdec: 'auto-safe'),
    );

    // Fullscreen listener
    _isFullscreen = _windowService.isFullscreen;
    _windowService.fullscreenNotifier.addListener(_onFullscreenChanged);

    // Track streams
    _tracksSub = _player.stream.tracks.listen((tracks) {
      if (mounted) setState(() => _tracks = tracks);
    });

    _errorSub = _player.stream.error.listen((err) {
      debugPrint('MediaKit player error: $err');
      if (_isSwitchingAudio) return;
      final msg = err.toString().toLowerCase();
      // Only ignore benign MPV logs/notices
      if (msg.contains('cache') ||
          msg.contains('buffering') ||
          msg.contains('audio-pts')) {
        return;
      }
      if (!_isPlayerReady ||
          !_player.state.playing ||
          _player.state.position == Duration.zero) {
        _handlePlaybackFailure('Playback issue encountered: $err');
      }
    });

    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });

    _playingSub = _player.stream.playing.listen((playing) {
      if (playing && _isLoadingVideo && mounted) {
        setState(() => _isLoadingVideo = false);
      }
    });

    _details = widget.mediaDetails;
    _currentSeason = widget.season;
    _currentEpisode = widget.episode;
    if (_details == null && widget.mediaItem.isSeries) {
      _fetchDetailsForNextEpisode();
    }

    _positionSub = _player.stream.position.listen(_onPositionChanged);
    _completedSub = _player.stream.completed.listen((completed) {
      if (completed && mounted && widget.mediaItem.isSeries) {
        _playNextEpisode(auto: true);
      }
    });

    _initPlayer();
    _loadSubtitlesAndDubs();
    _loadSeriesSkipMarkers();
    _startHideTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isTv = context.read<AppProvider>().isTvMode;
      if (isTv) {
        if (_playPauseTvFocusNode.canRequestFocus) {
          _playPauseTvFocusNode.requestFocus();
        }
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  void _onFullscreenChanged() {
    if (mounted) {
      setState(() => _isFullscreen = _windowService.isFullscreen);
    }
  }

  Future<void> _initPlayer() async {
    try {
      final library = context.read<LibraryProvider>();
      final resumeSec =
          widget.startPositionSeconds ??
          library.getResumePosition(
            widget.mediaItem.id,
            season: widget.season,
            episode: widget.episode,
          );

      if (Platform.isAndroid || Platform.isIOS) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }

      if (Platform.isAndroid) {
        DeviceControlsService.getBrightness().then((b) {
          if (mounted) setState(() => _brightness = b);
        });
        DeviceControlsService.getVolume().then((v) {
          if (mounted) setState(() => _volume = v);
        });
      }

      _startSourceWatchdog();

      if (Platform.isWindows) {
        LibMpvHelper.ensureCriticalSectionsInitialized();
      }

      final media = Media(
        _activeSource.url,
        httpHeaders: _activeSource.headers,
        start: resumeSec > 0 ? Duration(seconds: resumeSec) : null,
      );

      await _player.open(media);

      if (mounted) {
        setState(() {
          _isPlayerReady = true;
          _errorMessage = null;
        });
      }

      if (resumeSec > 0) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted && _player.state.position.inSeconds < resumeSec - 2) {
            _player.seek(Duration(seconds: resumeSec));
          }
        });

        if (mounted) {
          setState(() {
            _showResumeBanner = true;
            _resumedFromSeconds = resumeSec;
          });
          _resumeBannerTimer?.cancel();
          _resumeBannerTimer = Timer(const Duration(seconds: 6), () {
            if (mounted) setState(() => _showResumeBanner = false);
          });
        }
      }

      _progressTimer?.cancel();
      // Record initial start immediately into local history (excluding trailers)
      final isTrailer =
          widget.streamSource.quality == 'Trailer' ||
          widget.mediaItem.id.startsWith('trailer_') ||
          widget.mediaItem.title.toLowerCase().contains('trailer') ||
          widget.mediaItem.title.toLowerCase().contains('teaser');

      if (mounted && !isTrailer) {
        context.read<LibraryProvider>().recordPlaybackStart(
          widget.mediaItem,
          season: widget.season,
          episode: widget.episode,
        );
      }
      _progressTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!mounted) return;
        final pos = _player.state.position.inSeconds;
        final dur = _player.state.duration.inSeconds;
        if (!isTrailer && pos > 0 && dur > 0) {
          context.read<LibraryProvider>().recordProgress(
            item: widget.mediaItem,
            positionSeconds: pos,
            totalSeconds: dur,
            season: widget.season,
            episode: widget.episode,
          );
        }
      });
    } catch (e) {
      debugPrint('Player initialization error: $e');
      _handlePlaybackFailure('Failed to open stream: $e');
    }
  }

  // Watchdog disabled: users switch servers manually via the server menu.
  void _startSourceWatchdog() {
    _sourceWatchdogTimer?.cancel();
  }

  void _handlePlaybackFailure(String reason) {
    if (!mounted) return;
    _sourceWatchdogTimer?.cancel();
    if (_currentSourceIndex + 1 < _sources.length) {
      _switchToNextSource(
        'Stream issue encountered. Switching to backup ${_sources[_currentSourceIndex + 1].quality}...',
      );
    } else {
      setState(() {
        _errorMessage = reason;
        _isPlayerReady = false;
        _isLoadingVideo = false;
        _isBuffering = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _errorRetryFocusNode.canRequestFocus) {
          _errorRetryFocusNode.requestFocus();
        }
      });
    }
  }

  void _retryPlayback() {
    setState(() {
      _errorMessage = null;
      _isPlayerReady = false;
      _isLoadingVideo = true;
      _isBuffering = false;
    });
    _initPlayer();
  }

  bool _isSwitchingServer = false;

  Future<void> _selectSource(int idx, {String? customMessage}) async {
    if (idx < 0 || idx >= _sources.length) return;
    if (_isSwitchingServer) return;
    _isSwitchingServer = true;

    _sourceWatchdogTimer?.cancel();
    final currentPos = _player.state.position.inSeconds;
    final resumeAt = currentPos > 0 ? currentPos : _resumedFromSeconds;

    setState(() {
      _currentSourceIndex = idx;
      _activeSource = _sources[idx];
      _isPlayerReady = false;
      _isLoadingVideo = true;
      _errorMessage = null;
    });

    _showToast(
      customMessage ??
          'Switched to Server ${idx + 1} (${_activeSource.quality})',
    );

    try {
      if (Platform.isWindows) {
        LibMpvHelper.ensureCriticalSectionsInitialized();
      }

      // Stop previous playback to release demuxer threads cleanly
      try {
        await _player.stop();
      } catch (_) {}

      // Short delay to let libmpv cleanup threads settle
      await Future.delayed(const Duration(milliseconds: 120));

      if (Platform.isWindows) {
        LibMpvHelper.ensureCriticalSectionsInitialized();
      }

      if (!mounted) return;

      final media = Media(
        _activeSource.url,
        httpHeaders: _activeSource.headers,
        start: resumeAt > 0 ? Duration(seconds: resumeAt) : null,
      );

      _startSourceWatchdog();
      await _player.open(media);

      if (mounted) {
        setState(() => _isPlayerReady = true);
      }
    } catch (e) {
      debugPrint('Error switching server: $e');
      if (mounted) {
        _handlePlaybackFailure('Failed to open Server ${idx + 1}: $e');
      }
    } finally {
      if (mounted) {
        _isSwitchingServer = false;
      }
    }
  }

  Future<void> _switchToNextSource(String message) async {
    if (_currentSourceIndex + 1 >= _sources.length) return;
    await _selectSource(_currentSourceIndex + 1, customMessage: message);
  }

  Future<void> _loadSubtitlesAndDubs() async {
    // Load external subtitles
    if (_activeSource.resourceId != null) {
      final subs = await _movieBoxProvider.getSubtitles(
        subjectId: widget.mediaItem.id,
        resourceId: _activeSource.resourceId!,
      );
      if (mounted) {
        setState(() => _externalSubtitles = subs);
      }
    }

    // Load available audio dubs from details
    _details ??= await _movieBoxProvider.getDetails(widget.mediaItem.id);
    final details = _details;
    if (mounted && details != null && details.dubs.isNotEmpty) {
      setState(() => _availableDubs = details.dubs);
    }
  }

  Future<void> _fetchDetailsForNextEpisode() async {
    try {
      final details = await _movieBoxProvider.getDetails(widget.mediaItem.id);
      if (mounted && details != null) {
        setState(() => _details = details);
      }
    } catch (_) {}
  }

  Episode? _findNextEpisode() {
    final details = _details;
    final sNum = _currentSeason ?? 1;
    final eNum = _currentEpisode ?? 1;

    if (details == null || details.seasons.isEmpty) return null;

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

  Future<void> _playNextEpisode({bool auto = false}) async {
    if (!widget.mediaItem.isSeries || _isLoadingNextEpisode) return;
    _isLoadingNextEpisode = true;

    try {
      if (_details == null) {
        _showToast(
          auto ? 'Checking next episode...' : 'Loading next episode...',
        );
        _details = await _movieBoxProvider.getDetails(widget.mediaItem.id);
      }

      final nextEp = _findNextEpisode();
      if (nextEp == null) {
        if (mounted) {
          _showToast('No more episodes');
        }
        _isLoadingNextEpisode = false;
        return;
      }

      if (!mounted) return;
      _showToast(
        '${auto ? 'Auto-playing' : 'Playing'} S${nextEp.season} E${nextEp.episode}: ${nextEp.title}',
      );

      final streams = await _movieBoxProvider.getStreams(
        subjectId: widget.mediaItem.id,
        season: nextEp.season,
        episode: nextEp.episode,
      );

      if (!mounted) return;

      if (streams.isEmpty) {
        _showToast('No streams found for next episode');
        _isLoadingNextEpisode = false;
        return;
      }

      final currentDur = _player.state.duration.inSeconds;
      if (currentDur > 0) {
        context.read<LibraryProvider>().recordProgress(
          item: widget.mediaItem,
          positionSeconds: currentDur,
          totalSeconds: currentDur,
          season: _currentSeason,
          episode: _currentEpisode,
        );
      }

      _sourceWatchdogTimer?.cancel();
      _progressTimer?.cancel();

      setState(() {
        _currentSeason = nextEp.season;
        _currentEpisode = nextEp.episode;
        _sources = streams;
        _currentSourceIndex = 0;
        _activeSource = streams.first;
        _isPlayerReady = false;
        _hasSkippedIntro = false;
        _hasSkippedOutro = false;
        _activeSkip = null;
        _errorMessage = null;
      });

      _startSourceWatchdog();

      if (Platform.isWindows) {
        LibMpvHelper.ensureCriticalSectionsInitialized();
      }

      try {
        await _player.stop();
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 150));

      final media = Media(
        _activeSource.url,
        httpHeaders: _activeSource.headers,
      );

      await _player.open(media);

      if (mounted) {
        setState(() => _isPlayerReady = true);
      }

      _loadSubtitlesAndDubs();
      _loadSeriesSkipMarkers();

      _progressTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!mounted) return;
        final pos = _player.state.position.inSeconds;
        final dur = _player.state.duration.inSeconds;
        if (pos > 0 && dur > 0) {
          context.read<LibraryProvider>().recordProgress(
            item: widget.mediaItem,
            positionSeconds: pos,
            totalSeconds: dur,
            season: _currentSeason,
            episode: _currentEpisode,
          );
        }
      });
    } catch (e) {
      debugPrint('Error playing next episode: $e');
      if (mounted) {
        _showToast('Could not play next episode: $e');
      }
    } finally {
      if (mounted) {
        _isLoadingNextEpisode = false;
      }
    }
  }

  Future<void> _loadSeriesSkipMarkers() async {
    final sNum = _currentSeason;
    final eNum = _currentEpisode;
    if (sNum == null || eNum == null) return;

    try {
      _details ??= await _movieBoxProvider.getDetails(widget.mediaItem.id);
      final details = _details;
      if (details != null && details.seasons.isNotEmpty) {
        final season = details.seasons.firstWhere(
          (s) => s.seasonNumber == sNum,
          orElse: () => details.seasons.first,
        );
        final episode = season.episodes.firstWhere(
          (e) => e.episode == eNum,
          orElse: () => season.episodes.first,
        );

        if (episode.skipIntervals.isNotEmpty && mounted) {
          setState(() => _skipIntervals = episode.skipIntervals);
        }
      }
    } catch (_) {}

    // If provider did not supply verified intro skip markers, query real timestamps from TMDB / IntroDB
    if (_skipIntervals.where((s) => s.type == SkipType.intro).isEmpty &&
        mounted) {
      try {
        final realIntro = await TmdbService().getEpisodeIntroSkip(
          title: widget.mediaItem.title,
          year: widget.mediaItem.year,
          season: sNum,
          episode: eNum,
        );
        if (realIntro != null && mounted) {
          setState(() {
            _skipIntervals = [..._skipIntervals, realIntro];
          });
        }
      } catch (e) {
        debugPrint('Could not fetch verified intro skip from IntroDB/TMDB: $e');
      }
    }

    // Note: If no verified skip markers are available from either provider or IntroDB,
    // _skipIntervals will remain empty of fake intro markers, and the Skip Intro button will not show.
  }

  void _onPositionChanged(Duration pos) {
    if (!mounted) return;
    final posSec = pos.inSeconds;
    final durSec = _player.state.duration.inSeconds;

    if (posSec > 0 && _isLoadingVideo) {
      setState(() => _isLoadingVideo = false);
    }

    // Watchdog cancellation once playback begins
    if (posSec > 1 && _sourceWatchdogTimer?.isActive == true) {
      _sourceWatchdogTimer?.cancel();
    }

    // Check intro / outro skip intervals
    final app = context.read<AppProvider>();
    SkipInterval? active;

    for (final interval in _skipIntervals) {
      if (interval.contains(posSec)) {
        active = interval;
        break;
      }
    }

    // Also check smart outro (last 75 seconds of series episode)
    if (active == null &&
        app.enableSmartSkip &&
        durSec > 180 &&
        _currentSeason != null) {
      if (posSec >= durSec - 75 && posSec < durSec - 5) {
        active = SkipInterval(
          type: SkipType.outro,
          startSeconds: durSec - 75,
          endSeconds: durSec,
          label: 'Next Episode',
        );
      }
    }

    if (active != _activeSkip) {
      setState(() => _activeSkip = active);
    }

    // Auto-skip handling
    if (active != null) {
      if (active.type == SkipType.intro &&
          app.autoSkipIntro &&
          !_hasSkippedIntro) {
        _hasSkippedIntro = true;
        _player.seek(Duration(seconds: active.endSeconds));
        _showToast('Auto-skipped Intro');
      } else if (active.type == SkipType.outro &&
          app.autoSkipOutro &&
          !_hasSkippedOutro) {
        _hasSkippedOutro = true;
        _playNextEpisode(auto: true);
      }
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    setState(() => _toastMessage = message);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  void _onUserActivity() {
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _startHideTimer();
  }

  void _startHideTimer() {
    if (_isInteractingWithUi) return;
    _hideTimer?.cancel();
    bool isTv = false;
    try {
      isTv = context.read<AppProvider>().isTvMode;
    } catch (_) {}
    final duration = isTv
        ? const Duration(seconds: 6)
        : const Duration(milliseconds: 3500);
    _hideTimer = Timer(duration, () {
      if (mounted && _player.state.playing && !_isInteractingWithUi) {
        setState(() => _showControls = false);
        _focusNode.requestFocus();
      }
    });
  }

  void _cancelHideTimer() {
    _hideTimer?.cancel();
  }

  void _triggerDoubleTapSeek(int seconds) {
    _seekRelative(seconds);
    _doubleTapIndicatorTimer?.cancel();
    setState(() {
      _doubleTapSeekDirection = seconds;
    });
    _doubleTapIndicatorTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() => _doubleTapSeekDirection = null);
      }
    });
  }

  void _toggleScreenOrientation() {
    final orientation = MediaQuery.of(context).orientation;
    if (orientation == Orientation.landscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _toggleLockOrientation() {
    setState(() => _isOrientationLocked = !_isOrientationLocked);
    if (_isOrientationLocked) {
      final orientation = MediaQuery.of(context).orientation;
      if (orientation == Orientation.landscape) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
      _showToast('Orientation locked');
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      _showToast('Orientation auto-rotate restored');
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideTimer();
    }
  }

  Future<void> _toggleFullscreen() async {
    await _windowService.toggleFullscreen();
    if (mounted) {
      setState(() => _isFullscreen = _windowService.isFullscreen);
    }
  }

  void _revealTvControls() {
    setState(() => _showControls = true);
    _startHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showControls) {
        _playPauseTvFocusNode.requestFocus();
      }
    });
  }

  void _hideTvControls() {
    setState(() => _showControls = false);
    _focusNode.requestFocus();
  }

  Duration _clampDuration(Duration val, Duration min, Duration max) {
    if (val < min) return min;
    if (val > max) return max;
    return val;
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (_isControlsLocked) {
      _showUnlockButtonTemporarily();
      return KeyEventResult.handled;
    }

    final key = event.logicalKey;
    bool isTv = false;
    try {
      isTv = context.read<AppProvider>().isTvMode;
    } catch (_) {}

    // TV Remote Back / Escape / Go Back
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.backspace) {
      if (_showControls) {
        _hideTvControls();
        return KeyEventResult.handled;
      } else if (_isFullscreen) {
        _toggleFullscreen();
        return KeyEventResult.handled;
      } else {
        if (Platform.isWindows ||
            Platform.isLinux ||
            Platform.isMacOS ||
            isTv) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored; // Handled by PopScope on Android/TV!
      }
    }

    // Direct hardware media buttons
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      _player.playOrPause();
      _showToast(_player.state.playing ? 'Playing' : 'Paused');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPlay) {
      _player.play();
      _showToast('Playing');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPause) {
      _player.pause();
      _showToast('Paused');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaStop) {
      _player.stop();
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    // TV Mode Special Handling
    if (isTv) {
      if (!_showControls) {
        // 1. Any D-Pad press (Up, Down, Center/Select, OK, Enter, Space) or Action reveals the controls!
        // Also allow direct Play/Pause on Center/Select, but REVEAL the controls so user can see what's happening!
        if (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.gameButtonA ||
            key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown) {
          _revealTvControls();
          return KeyEventResult.handled;
        }

        // 2. D-Pad Left: Rewind 10s directly without revealing controls
        if (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.keyJ ||
            key == LogicalKeyboardKey.mediaRewind ||
            key == LogicalKeyboardKey.mediaTrackPrevious) {
          _triggerDoubleTapSeek(-10);
          return KeyEventResult.handled;
        }

        // 3. D-Pad Right: Forward 10s directly without revealing controls
        if (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.keyL ||
            key == LogicalKeyboardKey.mediaFastForward ||
            key == LogicalKeyboardKey.mediaTrackNext) {
          _triggerDoubleTapSeek(10);
          return KeyEventResult.handled;
        }
      } else {
        // When controls are visible on TV:
        _startHideTimer(); // Reset auto-hide timer on TV user remote interaction
        return KeyEventResult
            .ignored; // Let Flutter Focus traversal & button onTap handle!
      }
    }

    // Desktop: Play / Pause toggling (Space, K, Enter)
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.keyK ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA) {
      _player.playOrPause();
      _onUserActivity();
      return KeyEventResult.handled;
    }

    // Rewind 10s (Left Arrow, J, TV Remote Rewind, Previous Track)
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.keyJ ||
        key == LogicalKeyboardKey.mediaRewind ||
        key == LogicalKeyboardKey.mediaTrackPrevious) {
      _triggerDoubleTapSeek(-10);
      _onUserActivity();
      return KeyEventResult.handled;
    }

    // Forward 10s (Right Arrow, L, TV Remote Fast Forward, Next Track)
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyL ||
        key == LogicalKeyboardKey.mediaFastForward ||
        key == LogicalKeyboardKey.mediaTrackNext) {
      _triggerDoubleTapSeek(10);
      _onUserActivity();
      return KeyEventResult.handled;
    }

    // D-Pad Up / Down (Shows controls if hidden, or changes volume)
    if (key == LogicalKeyboardKey.arrowUp) {
      if (!_showControls) {
        _onUserActivity();
      } else {
        final vol = (_player.state.volume + 5.0).clamp(0.0, 100.0);
        _player.setVolume(vol);
        _showToast('Volume: ${vol.round()}%');
        _onUserActivity();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      if (!_showControls) {
        _onUserActivity();
      } else {
        final vol = (_player.state.volume - 5.0).clamp(0.0, 100.0);
        _player.setVolume(vol);
        _showToast('Volume: ${vol.round()}%');
        _onUserActivity();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.mediaStop) {
      _player.stop();
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyM) {
      if (_player.state.volume > 0) {
        _player.setVolume(0.0);
        _showToast('Muted');
      } else {
        _player.setVolume(100.0);
        _showToast('Unmuted');
      }
      _onUserActivity();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
      _onUserActivity();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyC) {
      _toggleSubtitleOnOff();
      _onUserActivity();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyS && _activeSkip != null) {
      _triggerSkip();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _triggerSkip() {
    if (_activeSkip == null) return;
    final skip = _activeSkip!;
    if (skip.type == SkipType.outro) {
      _playNextEpisode(auto: false);
      return;
    }
    final targetPoint = skip.endSeconds;
    final label = skip.label;
    _hasSkippedIntro = true;
    setState(() => _activeSkip = null);
    _player.seek(Duration(seconds: targetPoint));
    _showToast(
      'Skipped $label to ${_formatDuration(Duration(seconds: targetPoint))}',
    );
  }

  void _toggleSubtitleOnOff() {
    if (_subtitlesEnabled) {
      _player.setSubtitleTrack(SubtitleTrack.no());
      setState(() => _subtitlesEnabled = false);
      _showToast('Subtitles Off');
    } else {
      if (_activeSubtitleTrack != null) {
        _player.setSubtitleTrack(_activeSubtitleTrack!);
      } else if (_tracks.subtitle.isNotEmpty) {
        _player.setSubtitleTrack(_tracks.subtitle.first);
      } else if (_externalSubtitles.isNotEmpty) {
        _selectExternalSubtitle(_externalSubtitles.first);
      }
      setState(() => _subtitlesEnabled = true);
      _showToast('Subtitles On');
    }
  }

  Future<void> _selectExternalSubtitle(SubtitleOption sub) async {
    try {
      final track = SubtitleTrack.uri(sub.url, title: sub.name);
      await _player.setSubtitleTrack(track);
      if (mounted) {
        setState(() {
          _subtitlesEnabled = true;
          _activeSubtitleTrack = track;
        });
        _showToast('Subtitle: ${sub.name}');
      }
    } catch (e) {
      debugPrint('Error setting subtitle: $e');
    }
  }

  Future<void> _selectAudioTrack(AudioTrack track, String label) async {
    if (_isSwitchingAudio) return;
    setState(() => _isSwitchingAudio = true);
    try {
      await _player.setAudioTrack(track);
      if (mounted) {
        setState(() {});
        _showToast('Audio track: $label');
      }
    } catch (e) {
      debugPrint('Error selecting audio track: $e');
      if (mounted) {
        _showToast('Could not switch audio: $e');
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _isSwitchingAudio = false);
      });
    }
  }

  Future<void> _switchDubLanguage(AudioTrackOption dub) async {
    if (_isSwitchingAudio) return;
    setState(() {
      _isSwitchingAudio = true;
      _isPlayerReady = false;
    });
    _sourceWatchdogTimer?.cancel();
    _showToast('Switching to ${dub.label} audio...');

    try {
      final currentPos = _player.state.position.inSeconds;
      final dubStreams = await _movieBoxProvider.getStreams(
        subjectId: dub.subjectId,
        season: _currentSeason ?? 0,
        episode: _currentEpisode ?? 0,
      );

      if (dubStreams.isNotEmpty && mounted) {
        final newSource = dubStreams.first;
        setState(() {
          _sources = dubStreams;
          _currentSourceIndex = 0;
          _activeSource = newSource;
        });

        _startSourceWatchdog();

        if (Platform.isWindows) {
          LibMpvHelper.ensureCriticalSectionsInitialized();
        }

        try {
          await _player.stop();
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
        await _player.open(media);
        if (mounted) {
          setState(() {
            _isPlayerReady = true;
            _errorMessage = null;
          });
          _showToast('Audio set to: ${dub.label}');
        }
      } else {
        if (mounted) {
          setState(() => _isPlayerReady = true);
          _showToast('No stream available for ${dub.label}');
        }
      }
    } catch (e) {
      debugPrint('Error switching dub: $e');
      if (mounted) {
        setState(() => _isPlayerReady = true);
        _showToast('Failed to switch dub: $e');
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _isSwitchingAudio = false);
      });
    }
  }

  void _setSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    _player.setRate(speed);
    _showToast('Playback speed: ${speed}x');
  }

  Future<void> _openInExternalPlayer() async {
    final currentPos = _player.state.position.inSeconds;
    final startSec = currentPos > 0 ? currentPos : _resumedFromSeconds;
    final launched = await ExternalPlayerService().launch(
      url: _activeSource.url,
      title: widget.mediaItem.title,
      headers: _activeSource.headers,
      startSeconds: startSec > 0 ? startSec : null,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not launch external player. Make sure MPV or VLC is installed.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _toggleAspectRatio() {
    setState(() {
      _videoFit = _videoFit == BoxFit.contain ? BoxFit.cover : BoxFit.contain;
    });
    _showToast(
      _videoFit == BoxFit.contain ? 'Aspect: Contain' : 'Aspect: Cover',
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _brightnessHideTimer?.cancel();
    _volumeHideTimer?.cancel();
    _progressTimer?.cancel();
    _resumeBannerTimer?.cancel();
    _sourceWatchdogTimer?.cancel();
    _toastTimer?.cancel();
    _unlockButtonTimer?.cancel();
    _doubleTapIndicatorTimer?.cancel();
    _errorSub?.cancel();
    _tracksSub?.cancel();
    _positionSub?.cancel();
    _completedSub?.cancel();
    _bufferingSub?.cancel();
    _playingSub?.cancel();
    _windowService.fullscreenNotifier.removeListener(_onFullscreenChanged);
    _focusNode.dispose();
    _playPauseTvFocusNode.dispose();
    _seekbarTvFocusNode.dispose();
    _tvBackBtnFocusNode.dispose();
    _errorRetryFocusNode.dispose();
    _player.dispose();

    if (Platform.isAndroid) {
      DeviceControlsService.resetBrightness();
    }

    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  void _showUnlockButtonTemporarily() {
    _unlockButtonTimer?.cancel();
    setState(() => _showUnlockButton = true);
    _unlockButtonTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showUnlockButton = false);
    });
  }

  void _seekRelative(int seconds) {
    final current = _player.state.position;
    final target = current + Duration(seconds: seconds);
    _player.seek(target < Duration.zero ? Duration.zero : target);
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Error State Fallback
    if (_errorMessage != null) {
      return PlayerErrorView(
        errorMessage: _errorMessage!,
        hasAnotherSource: _currentSourceIndex + 1 < _sources.length,
        nextSourceLabel: _currentSourceIndex + 1 < _sources.length
            ? 'Try Source ${_currentSourceIndex + 2} (${_sources[_currentSourceIndex + 1].quality})'
            : null,
        onNextSource: () => _switchToNextSource('Switching to next source...'),
        onOpenExternal: _openInExternalPlayer,
        onRetry: _retryPlayback,
        onBack: () => Navigator.of(context).pop(),
      );
    }

    final app = context.watch<AppProvider>();
    final isTv = app.isTvMode;
    final cast = context.watch<CastProvider>();
    if (cast.isCasting && _player.state.playing) {
      _player.pause();
    }
    final showLoadingSpinner =
        (_isLoadingVideo || _isBuffering || !_isPlayerReady) &&
        _errorMessage == null &&
        !cast.isCasting;

    // Active Player Body with Keyboard Focus & Mouse Hover Tracking
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      canRequestFocus: true,
      onKeyEvent: (node, event) => _handleKeyEvent(event),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_isControlsLocked) {
            _showUnlockButtonTemporarily();
            return;
          }
          if (_showControls) {
            _hideTvControls();
          } else {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          backgroundColor: context.tokens.canvasBackground,
          body: MouseRegion(
            cursor: _showControls
                ? SystemMouseCursors.basic
                : SystemMouseCursors.none,
            onHover: (_) => _onUserActivity(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_isControlsLocked) {
                  _showUnlockButtonTemporarily();
                } else {
                  _toggleControls();
                }
              },
              onDoubleTapDown: (details) {
                _doubleTapDetails = details;
              },
              onDoubleTap: () {
                if (_isControlsLocked) return;
                final screenWidth = MediaQuery.of(context).size.width;
                final tapX =
                    _doubleTapDetails?.localPosition.dx ?? (screenWidth / 2);
                if (tapX < screenWidth * 0.5) {
                  _triggerDoubleTapSeek(-10);
                } else {
                  _triggerDoubleTapSeek(10);
                }
              },
              onVerticalDragStart: (details) {
                if (isTv || _isControlsLocked) return;
                final screenWidth = MediaQuery.of(context).size.width;
                // Left 45% of the screen adjusts brightness
                if (details.localPosition.dx < screenWidth * 0.45) {
                  _isDraggingBrightness = true;
                  _isDraggingVolume = false;
                } else if (details.localPosition.dx > screenWidth * 0.55) {
                  // Right 45% of the screen adjusts volume
                  _isDraggingVolume = true;
                  _isDraggingBrightness = false;
                }
              },
              onVerticalDragUpdate: (details) {
                if (_isDraggingBrightness) {
                  _onBrightnessDragUpdate(details.primaryDelta ?? 0);
                } else if (_isDraggingVolume) {
                  _onVolumeDragUpdate(details.primaryDelta ?? 0);
                }
              },
              onVerticalDragEnd: (_) {
                _isDraggingBrightness = false;
                _isDraggingVolume = false;
              },
              child: Stack(
                children: [
                  // Video Surface
                  Center(
                    child: Video(
                      controller: _controller,
                      controls: NoVideoControls,
                      fit: _videoFit,
                      pauseUponEnteringBackgroundMode: false,
                      resumeUponEnteringForegroundMode: false,
                    ),
                  ),

                  // Casting Overlay Banner (When Casting to TV/DLNA/AirPlay on Mobile/Desktop)
                  if (cast.isCasting && !isTv)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 24,
                        ),
                        decoration: context.tokens.getShapeDecoration(
                          color: context.tokens.surfaceElevated.withValues(
                            alpha: 0.92,
                          ),
                          radius: context.tokens.cardRadius * 1.4,
                          side: BorderSide(
                            color: context.tokens.borderFocus.withValues(
                              alpha: 0.5,
                            ),
                            width: 1.5,
                          ),
                          shadows: [
                            BoxShadow(
                              color: context.tokens.shadowColor.withValues(
                                alpha: 0.7,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.15,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.cast_connected_rounded,
                                color: theme.colorScheme.primary,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Playing on ${cast.connectedDevice?.name ?? "Cast Device"}',
                              style: TextStyle(
                                color: context.tokens.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              cast.isPlaying
                                  ? 'Streaming smoothly'
                                  : (cast.isPaused
                                        ? 'Paused on TV'
                                        : 'Connecting to TV...'),
                              style: TextStyle(
                                color: context.tokens.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    CastDialog.show(
                                      context,
                                      mediaItem: widget.mediaItem,
                                      streamSource: _activeSource,
                                      startPosition: _player.state.position,
                                      subtitles: _externalSubtitles,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.tune_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Cast Controls'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor:
                                        theme.colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    shape: context.tokens.shapeSm,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await cast.disconnect();
                                    _player.play();
                                  },
                                  icon: Icon(
                                    Icons.phone_android_rounded,
                                    size: 18,
                                    color: context.tokens.textPrimary,
                                  ),
                                  label: Text(
                                    'Play Here',
                                    style: TextStyle(
                                      color: context.tokens.textPrimary,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: context.tokens.borderSubtle,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    shape: context.tokens.shapeSm,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Loading / Buffering Indicator
                  if (showLoadingSpinner)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _isLoadingVideo
                                ? 'Loading "${widget.mediaItem.cleanTitle}"…'
                                : 'Buffering…',
                            style: TextStyle(
                              color: context.tokens.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Toast Notification Overlay
                  if (_toastMessage != null)
                    Positioned(
                      top: 64,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: context.tokens.getShapeDecoration(
                            color: context.tokens.canvasBackground.withValues(
                              alpha: 0.8,
                            ),
                            radius: context.tokens.cardRadius * 2,
                            side: BorderSide(
                              color: context.tokens.borderSubtle,
                            ),
                          ),
                          child: Text(
                            _toastMessage!,
                            style: TextStyle(
                              color: context.tokens.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Floating Unlock Button on Right Middle Edge (when screen controls are locked)
                  if (_isControlsLocked && _showUnlockButton && !isTv)
                    Positioned(
                      right: 20,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: SafeArea(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isControlsLocked = false;
                                _showUnlockButton = false;
                                _showControls = true;
                              });
                              _showToast('Controls unlocked');
                              _startHideTimer();
                            },
                            borderRadius: context.tokens.borderRadiusPill,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: context.tokens.getShapeDecoration(
                                color: context.tokens.surfaceElevated
                                    .withValues(alpha: 0.95),
                                radius: context.tokens.cardRadius * 2,
                                side: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 1.5,
                                ),
                                shadows: [
                                  BoxShadow(
                                    color: context.tokens.shadowColor
                                        .withValues(alpha: 0.6),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_open_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Tap to Unlock',
                                    style: TextStyle(
                                      color: context.tokens.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Double Tap Skip Ripple / Badge Indicator
                  if (_doubleTapSeekDirection != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Align(
                          alignment: _doubleTapSeekDirection! < 0
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 56),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: context.tokens.getShapeDecoration(
                              color: context.tokens.surfaceElevated.withValues(
                                alpha: 0.85,
                              ),
                              radius: context.tokens.cardRadius * 2,
                              side: BorderSide(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.6,
                                ),
                                width: 1.2,
                              ),
                              shadows: [
                                BoxShadow(
                                  color: context.tokens.shadowColor.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_doubleTapSeekDirection! < 0) ...[
                                  Icon(
                                    Icons.fast_rewind_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '10s',
                                    style: TextStyle(
                                      color: context.tokens.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    '10s',
                                    style: TextStyle(
                                      color: context.tokens.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.fast_forward_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 22,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Floating Gesture HUD: Brightness (Left)
                  if (!isTv && !_isControlsLocked && _showBrightnessIndicator)
                    Positioned(
                      left: 36,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _buildGestureHud(
                          icon: _brightness > 0.6
                              ? Icons.wb_sunny_rounded
                              : (_brightness > 0.25
                                    ? Icons.brightness_medium_rounded
                                    : Icons.brightness_low_rounded),
                          value: _brightness,
                          label: '${(_brightness * 100).round()}%',
                          theme: theme,
                        ),
                      ),
                    ),

                  // Floating Gesture HUD: Volume (Right)
                  if (!isTv && !_isControlsLocked && _showVolumeIndicator)
                    Positioned(
                      right: 36,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _buildGestureHud(
                          icon: _volume == 0
                              ? Icons.volume_off_rounded
                              : (_volume < 0.5
                                    ? Icons.volume_down_rounded
                                    : Icons.volume_up_rounded),
                          value: _volume,
                          label: '${(_volume * 100).round()}%',
                          theme: theme,
                        ),
                      ),
                    ),

                  // Controls Overlay (Netflix Cinema Theme)
                  if (!_isControlsLocked)
                    AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: IgnorePointer(
                        ignoring: !_showControls,
                        child: ExcludeFocus(
                          excluding: !_showControls,
                          child: Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: (_) {
                              _isInteractingWithUi = true;
                              _cancelHideTimer();
                            },
                            onPointerUp: (_) {
                              _isInteractingWithUi = false;
                              _startHideTimer();
                            },
                            onPointerCancel: (_) {
                              _isInteractingWithUi = false;
                              _startHideTimer();
                            },
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        context.tokens.canvasBackground
                                            .withValues(alpha: 0.8),
                                        Colors.transparent,
                                        Colors.transparent,
                                        context.tokens.canvasBackground
                                            .withValues(alpha: 0.9),
                                      ],
                                      stops: const [0.0, 0.25, 0.7, 1.0],
                                    ),
                                  ),
                                  child: SafeArea(
                                    child: isTv
                                        ? _buildTvPlayerControls(theme)
                                        : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Top Bar: Back, Title, Cast, More Menu
                                              _buildTopBar(theme),

                                              // Center Controls
                                              _buildCenterControls(theme),

                                              // Bottom Bar: Scrub bar with time stamps & quick actions
                                              _buildBottomControls(theme),
                                            ],
                                          ),
                                  ),
                                ),

                                // Floating Action Buttons on Right Middle Edge (Rotate + Lock below it) (Non-TV only)
                                if (!isTv)
                                  Positioned(
                                    right: 16,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // 1. Screen Rotate Button
                                          Tooltip(
                                            message: _isOrientationLocked
                                                ? 'Orientation Locked (Hold to auto-rotate)'
                                                : 'Rotate Screen (Hold to lock)',
                                            child: InkWell(
                                              onTap: _toggleScreenOrientation,
                                              onLongPress:
                                                  _toggleLockOrientation,
                                              borderRadius: context
                                                  .tokens
                                                  .borderRadiusPill,
                                              child: Container(
                                                width: 44,
                                                height: 44,
                                                decoration: context.tokens
                                                    .getShapeDecoration(
                                                      color:
                                                          _isOrientationLocked
                                                          ? theme
                                                                .colorScheme
                                                                .primary
                                                                .withValues(
                                                                  alpha: 0.25,
                                                                )
                                                          : context
                                                                .tokens
                                                                .surfaceElevated
                                                                .withValues(
                                                                  alpha: 0.75,
                                                                ),
                                                      radius:
                                                          context
                                                              .tokens
                                                              .cardRadius *
                                                          2,
                                                      side: BorderSide(
                                                        color:
                                                            _isOrientationLocked
                                                            ? theme
                                                                  .colorScheme
                                                                  .primary
                                                            : context
                                                                  .tokens
                                                                  .borderSubtle,
                                                        width: 1,
                                                      ),
                                                      shadows: [
                                                        BoxShadow(
                                                          color: context
                                                              .tokens
                                                              .shadowColor
                                                              .withValues(
                                                                alpha: 0.35,
                                                              ),
                                                          blurRadius: 8,
                                                          offset: const Offset(
                                                            0,
                                                            2,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                child: Icon(
                                                  _isOrientationLocked
                                                      ? Icons
                                                            .screen_lock_rotation_rounded
                                                      : Icons
                                                            .screen_rotation_rounded,
                                                  color: _isOrientationLocked
                                                      ? theme
                                                            .colorScheme
                                                            .primary
                                                      : context
                                                            .tokens
                                                            .textPrimary,
                                                  size: 22,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          // 2. Screen Lock Button (Below Rotate Button)
                                          Tooltip(
                                            message: 'Lock Screen Controls',
                                            child: InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _isControlsLocked = true;
                                                  _showControls = false;
                                                });
                                                _showToast(
                                                  'Screen locked (Touch resistant)',
                                                );
                                              },
                                              borderRadius: context
                                                  .tokens
                                                  .borderRadiusPill,
                                              child: Container(
                                                width: 44,
                                                height: 44,
                                                decoration: context.tokens
                                                    .getShapeDecoration(
                                                      color: context
                                                          .tokens
                                                          .surfaceElevated
                                                          .withValues(
                                                            alpha: 0.75,
                                                          ),
                                                      radius:
                                                          context
                                                              .tokens
                                                              .cardRadius *
                                                          2,
                                                      side: BorderSide(
                                                        color: context
                                                            .tokens
                                                            .borderSubtle,
                                                        width: 1,
                                                      ),
                                                      shadows: [
                                                        BoxShadow(
                                                          color: context
                                                              .tokens
                                                              .shadowColor
                                                              .withValues(
                                                                alpha: 0.35,
                                                              ),
                                                          blurRadius: 8,
                                                          offset: const Offset(
                                                            0,
                                                            2,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                child: Icon(
                                                  Icons.lock_outline_rounded,
                                                  color: context
                                                      .tokens
                                                      .textPrimary,
                                                  size: 22,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Floating Skip Intro / Next Episode Overlay Button (Netflix Style)
                  // Positioned on TOP of Controls Overlay so it is ALWAYS clickable!
                  if (_activeSkip != null)
                    Positioned(
                      bottom: _showControls ? 116 : 42,
                      right: 24,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Material(
                          color: Colors.transparent,
                          child: isTv
                              ? TvFocusable(
                                  autofocus: true,
                                  scaleFactor: 1.08,
                                  shape: context.tokens.shapeSm,
                                  borderRadius: context.tokens.borderRadiusSm,
                                  onTap: _triggerSkip,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    decoration: context.tokens
                                        .getShapeDecoration(
                                          color: context.tokens.canvasBackground
                                              .withValues(alpha: 0.88),
                                          radius:
                                              context.tokens.cardRadius * 0.7,
                                          side: BorderSide(
                                            color: context.tokens.textPrimary,
                                            width: 1.5,
                                          ),
                                          shadows: [
                                            BoxShadow(
                                              color: context.tokens.shadowColor
                                                  .withValues(alpha: 0.7),
                                              blurRadius: 14,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _activeSkip!.label,
                                          style: TextStyle(
                                            color: context.tokens.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.fast_forward_rounded,
                                          color: context.tokens.textPrimary,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : InkWell(
                                  onTap: _triggerSkip,
                                  borderRadius: context.tokens.borderRadiusSm,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    decoration: context.tokens
                                        .getShapeDecoration(
                                          color: context.tokens.canvasBackground
                                              .withValues(alpha: 0.88),
                                          radius:
                                              context.tokens.cardRadius * 0.7,
                                          side: BorderSide(
                                            color: context.tokens.textPrimary,
                                            width: 1.5,
                                          ),
                                          shadows: [
                                            BoxShadow(
                                              color: context.tokens.shadowColor
                                                  .withValues(alpha: 0.7),
                                              blurRadius: 14,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _activeSkip!.label,
                                          style: TextStyle(
                                            color: context.tokens.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.fast_forward_rounded,
                                          color: context.tokens.textPrimary,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),

                  // Floating Resume Banner Toast
                  if (_showResumeBanner && _resumedFromSeconds > 0)
                    Positioned(
                      bottom: _showControls ? 110 : 36,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: context.tokens.getShapeDecoration(
                            color: context.tokens.canvasBackground.withValues(
                              alpha: 0.85,
                            ),
                            radius: context.tokens.cardRadius * 2,
                            side: BorderSide(
                              color: context.tokens.borderSubtle,
                            ),
                            shadows: [
                              BoxShadow(
                                color: context.tokens.shadowColor.withValues(
                                  alpha: 0.5,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history_rounded,
                                color: context.tokens.textSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Resumed at ${_formatDuration(Duration(seconds: _resumedFromSeconds))}',
                                style: TextStyle(
                                  color: context.tokens.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              InkWell(
                                onTap: () {
                                  _player.seek(Duration.zero);
                                  setState(() => _showResumeBanner = false);
                                  _resumeBannerTimer?.cancel();
                                },
                                borderRadius: context.tokens.borderRadiusPill,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: context.tokens.getShapeDecoration(
                                    color: theme.colorScheme.primary,
                                    radius: context.tokens.cardRadius * 2,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.replay_rounded,
                                        size: 14,
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Restart',
                                        style: TextStyle(
                                          color: theme.colorScheme.onPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  setState(() => _showResumeBanner = false);
                                  _resumeBannerTimer?.cancel();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: context.tokens.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOptionsMenu(ThemeData theme) {
    return PopupMenuButton<String>(
      tooltip: 'Playback Options',
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: context.tokens.getShapeDecoration(
          color: context.tokens.surfaceElevated.withValues(alpha: 0.6),
          radius: context.tokens.cardRadius * 2,
          side: BorderSide(color: context.tokens.borderSubtle, width: 1),
        ),
        child: Icon(
          Icons.more_vert_rounded,
          color: context.tokens.textPrimary,
          size: 20,
        ),
      ),
      color: context.tokens.surfaceElevated,
      shape: context.tokens.shapeMd,
      onSelected: (value) {
        _onUserActivity();
        switch (value) {
          case 'next_episode':
            _playNextEpisode(auto: false);
            break;
          case 'server':
            _showServerSelectionModal(theme);
            break;
          case 'audio':
            _showAudioAndSubtitleModal();
            break;
          case 'speed':
            _showSpeedDialog(theme);
            break;
          case 'aspect':
            _toggleAspectRatio();
            break;
          case 'external':
            _openInExternalPlayer();
            break;
          case 'fullscreen':
            _toggleFullscreen();
            break;
        }
      },
      itemBuilder: (context) => [
        if (widget.mediaItem.isSeries && _findNextEpisode() != null)
          PopupMenuItem(
            value: 'next_episode',
            child: Row(
              children: [
                Icon(
                  Icons.skip_next_rounded,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Next Episode',
                    style: TextStyle(
                      color: context.tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'server',
          child: Row(
            children: [
              Icon(
                Icons.dns_rounded,
                color: theme.colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Quality & Servers (${_activeSource.quality})',
                  style: TextStyle(
                    color: context.tokens.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'audio',
          child: Row(
            children: [
              Icon(
                Icons.subtitles_rounded,
                color: context.tokens.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Audio & Subtitles',
                  style: TextStyle(
                    color: context.tokens.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'speed',
          child: Row(
            children: [
              Icon(
                Icons.speed_rounded,
                color: context.tokens.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Playback Speed (${_playbackSpeed}x)',
                  style: TextStyle(
                    color: context.tokens.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'external',
          child: Row(
            children: [
              Icon(
                Icons.open_in_new_rounded,
                color: context.tokens.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Open in External Player (VLC / MPV)',
                  style: TextStyle(
                    color: context.tokens.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
          PopupMenuItem(
            value: 'fullscreen',
            child: Row(
              children: [
                Icon(
                  _isFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  color: context.tokens.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isFullscreen ? 'Exit Fullscreen' : 'Enter Fullscreen',
                    style: TextStyle(
                      color: context.tokens.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  bool get _isLiveStream =>
      widget.mediaItem.provider == ProviderType.liveTv ||
      _player.state.duration == Duration.zero;

  bool _pauseForModal() {
    if (_isLiveStream) return false;
    final wasPlaying = _player.state.playing;
    if (wasPlaying) {
      _player.pause();
    }
    return wasPlaying;
  }

  void _resumeAfterModal(bool wasPlaying) {
    if (wasPlaying && mounted) {
      _player.play();
    }
  }

  Future<void> _showSpeedDialog(ThemeData theme) async {
    final wasPlaying = _pauseForModal();
    await PlayerSpeedSheet.show(
      context,
      currentSpeed: _playbackSpeed,
      onSpeedSelected: _setSpeed,
    );
    _resumeAfterModal(wasPlaying);
  }

  Widget _buildTopBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: context.tokens.borderRadiusPill,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: context.tokens.getShapeDecoration(
                color: context.tokens.surfaceElevated.withValues(alpha: 0.6),
                radius: context.tokens.cardRadius * 2,
                side: BorderSide(color: context.tokens.borderSubtle, width: 1),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: context.tokens.textPrimary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.mediaItem.cleanTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.tokens.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                if (_currentSeason != null && _currentEpisode != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Season $_currentSeason • Episode $_currentEpisode',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Cast Action Button (Hide on TV)
          if (!context.watch<AppProvider>().isTvMode)
            Consumer<CastProvider>(
              builder: (context, cast, _) {
                final isCastingThis = cast.isConnected;
                return Tooltip(
                  message: isCastingThis
                      ? 'Casting to ${cast.connectedDevice?.name}'
                      : 'Cast to TV / Device',
                  child: InkWell(
                    onTap: () {
                      _onUserActivity();
                      CastDialog.show(
                        context,
                        mediaItem: widget.mediaItem,
                        streamSource: _activeSource,
                        startPosition: _player.state.position,
                        subtitles: _externalSubtitles,
                      );
                    },
                    borderRadius: context.tokens.borderRadiusPill,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: context.tokens.getShapeDecoration(
                        color: isCastingThis
                            ? theme.colorScheme.primary.withValues(alpha: 0.25)
                            : context.tokens.surfaceElevated.withValues(
                                alpha: 0.6,
                              ),
                        radius: context.tokens.cardRadius * 2,
                        side: BorderSide(
                          color: isCastingThis
                              ? theme.colorScheme.primary
                              : context.tokens.borderSubtle,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        isCastingThis
                            ? Icons.cast_connected_rounded
                            : Icons.cast_rounded,
                        color: isCastingThis
                            ? theme.colorScheme.primary
                            : context.tokens.textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                );
              },
            ),
          // More Options Dropdown Button
          _buildMoreOptionsMenu(theme),
        ],
      ),
    );
  }

  Widget _buildTvPlayerControls(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Top Bar: Back, Title, Season/Episode, Quality Badge
          _buildTvTopBar(theme),

          // 2. Bottom Controls: Focusable TV Seekbar + TV Action Buttons Row
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTvSeekbar(theme),
              const SizedBox(height: 16),
              _buildTvActionButtons(theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTvTopBar(ThemeData theme) {
    return Row(
      children: [
        TvFocusable(
          focusNode: _tvBackBtnFocusNode,
          scaleFactor: 1.1,
          shape: context.tokens.shapePill,
          borderRadius: context.tokens.borderRadiusPill,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _seekbarTvFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          onTap: () {
            _hideTvControls();
            Navigator.of(context).pop();
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: context.tokens.getShapeDecoration(
              color: context.tokens.surfaceElevated.withValues(alpha: 0.6),
              radius: context.tokens.cardRadius * 2,
              side: BorderSide(color: context.tokens.borderSubtle),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: context.tokens.textPrimary,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.mediaItem.cleanTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.tokens.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_currentSeason != null && _currentEpisode != null)
                Text(
                  'Season $_currentSeason • Episode $_currentEpisode',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: context.tokens.getShapeDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            radius: context.tokens.cardRadius * 0.5,
            side: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            _activeSource.quality.toUpperCase(),
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTvSeekbar(ThemeData theme) {
    return StreamBuilder<Duration>(
      stream: _player.stream.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? _player.state.position;
        final duration = _player.state.duration;
        final maxMs = duration.inMilliseconds.toDouble();
        final curMs = position.inMilliseconds.toDouble().clamp(
          0.0,
          maxMs > 0 ? maxMs : 1.0,
        );

        return Focus(
          focusNode: _seekbarTvFocusNode,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              final cur = _player.state.position;
              final target = _clampDuration(
                cur - const Duration(seconds: 10),
                Duration.zero,
                _player.state.duration,
              );
              _player.seek(target);
              _startHideTimer();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              final cur = _player.state.position;
              final target = _clampDuration(
                cur + const Duration(seconds: 10),
                Duration.zero,
                _player.state.duration,
              );
              _player.seek(target);
              _startHideTimer();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _playPauseTvFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _tvBackBtnFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA) {
              _player.playOrPause();
              _startHideTimer();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: AnimatedBuilder(
            animation: _seekbarTvFocusNode,
            builder: (context, _) {
              final isFocused = _seekbarTvFocusNode.hasFocus;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: context.tokens.getShapeDecoration(
                  radius: context.tokens.cardRadius * 0.7,
                  side: BorderSide(
                    color: isFocused
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                  shadows: isFocused
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Text(
                      _formatDuration(position),
                      style: TextStyle(
                        color: isFocused
                            ? theme.colorScheme.primary
                            : context.tokens.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: isFocused ? 6 : 4,
                          thumbShape: RoundSliderThumbShape(
                            enabledThumbRadius: isFocused ? 9 : 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor: context.tokens.borderSubtle
                              .withValues(alpha: 0.5),
                          thumbColor: isFocused
                              ? context.tokens.textPrimary
                              : theme.colorScheme.primary,
                        ),
                        child: Slider(
                          value: curMs,
                          min: 0.0,
                          max: maxMs > 0 ? maxMs : 1.0,
                          onChanged: (val) {
                            _player.seek(Duration(milliseconds: val.toInt()));
                            _startHideTimer();
                          },
                        ),
                      ),
                    ),
                    Text(
                      duration > Duration.zero
                          ? _formatDuration(duration)
                          : '00:00',
                      style: TextStyle(
                        color: context.tokens.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTvActionButtons(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 1. Play / Pause (Autofocused, with up navigation to seekbar!)
        TvFocusable(
          focusNode: _playPauseTvFocusNode,
          autofocus: true,
          scaleFactor: 1.12,
          shape: context.tokens.shapeMd,
          borderRadius: context.tokens.borderRadiusMd,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _seekbarTvFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          onTap: () {
            _player.playOrPause();
            _startHideTimer();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: context.tokens.getShapeDecoration(
              color: context.tokens.textPrimary,
              radius: context.tokens.cardRadius,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<bool>(
                  stream: _player.stream.playing,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data ?? _player.state.playing;
                    return Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: context.tokens.canvasBackground,
                      size: 26,
                    );
                  },
                ),
                const SizedBox(width: 8),
                StreamBuilder<bool>(
                  stream: _player.stream.playing,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data ?? _player.state.playing;
                    return Text(
                      isPlaying ? 'Pause' : 'Play',
                      style: TextStyle(
                        color: context.tokens.canvasBackground,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),

        // 2. Episodes (TV Series only)
        if (widget.mediaItem.isSeries) ...[
          TvFocusable(
            scaleFactor: 1.12,
            shape: context.tokens.shapeSm,
            borderRadius: context.tokens.borderRadiusSm,
            onTap: () {
              // Exits back cleanly to TvDetailsScreen where all episodes are available
              _hideTvControls();
              Navigator.of(context).pop();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: context.tokens.getShapeDecoration(
                color: context.tokens.surfaceCard.withValues(alpha: 0.5),
                radius: context.tokens.cardRadius * 0.7,
                side: BorderSide(color: context.tokens.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.video_library_rounded,
                    color: context.tokens.textPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Episodes',
                    style: TextStyle(
                      color: context.tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],

        // 5. Audio & Dubs
        TvFocusable(
          scaleFactor: 1.12,
          shape: context.tokens.shapeSm,
          borderRadius: context.tokens.borderRadiusSm,
          onTap: () {
            _startHideTimer();
            _showAudioAndSubtitleModal();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: context.tokens.getShapeDecoration(
              color: context.tokens.surfaceCard.withValues(alpha: 0.5),
              radius: context.tokens.cardRadius * 0.7,
              side: BorderSide(color: context.tokens.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.audiotrack_rounded,
                  color: context.tokens.textPrimary,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  'Audio',
                  style: TextStyle(
                    color: context.tokens.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),

        // 6. Subtitles
        TvFocusable(
          scaleFactor: 1.12,
          shape: context.tokens.shapeSm,
          borderRadius: context.tokens.borderRadiusSm,
          onTap: () {
            _startHideTimer();
            _showAudioAndSubtitleModal();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: context.tokens.getShapeDecoration(
              color: context.tokens.surfaceCard.withValues(alpha: 0.5),
              radius: context.tokens.cardRadius * 0.7,
              side: BorderSide(color: context.tokens.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.subtitles_rounded,
                  color: context.tokens.textPrimary,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  'Subs',
                  style: TextStyle(
                    color: context.tokens.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),

        // 7. Server Switcher
        if (_sources.length > 1) ...[
          TvFocusable(
            scaleFactor: 1.12,
            shape: context.tokens.shapeSm,
            borderRadius: context.tokens.borderRadiusSm,
            onTap: () {
              _startHideTimer();
              _showServerSelectionModal(theme);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: context.tokens.getShapeDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                radius: context.tokens.cardRadius * 0.7,
                side: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.dns_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Server ${_currentSourceIndex + 1}',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ],
    );
  }

  Widget _buildCenterControls(ThemeData theme) {
    return const SizedBox.shrink();
  }

  Widget _buildGestureHud({
    required IconData icon,
    required double value,
    required String label,
    required ThemeData theme,
  }) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: context.tokens.getShapeDecoration(
          color: context.tokens.surfaceElevated.withValues(alpha: 0.85),
          radius: context.tokens.cardRadius * 1.5,
          side: BorderSide(color: context.tokens.borderSubtle, width: 1),
          shadows: [
            BoxShadow(
              color: context.tokens.shadowColor.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(height: 10),
            Container(
              width: 5,
              height: 90,
              decoration: BoxDecoration(
                color: context.tokens.borderSubtle.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  FractionallySizedBox(
                    heightFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: context.tokens.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(ThemeData theme) {
    if (_isControlsLocked) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: StreamBuilder<Duration>(
        stream: _player.stream.position,
        builder: (context, snapshot) {
          final position = snapshot.data ?? _player.state.position;
          final duration = _player.state.duration;
          final maxMs = duration.inMilliseconds.toDouble();
          final curMs = position.inMilliseconds.toDouble().clamp(
            0.0,
            maxMs > 0 ? maxMs : 1.0,
          );

          return Row(
            children: [
              // 1. Play / Pause Button next to played time
              StreamBuilder<bool>(
                stream: _player.stream.playing,
                builder: (context, playingSnap) {
                  final isPlaying = playingSnap.data ?? _player.state.playing;
                  return InkWell(
                    onTap: () {
                      _player.playOrPause();
                      _startHideTimer();
                    },
                    borderRadius: context.tokens.borderRadiusPill,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: context.tokens.getShapeDecoration(
                        color: theme.colorScheme.primary,
                        radius: context.tokens.cardRadius * 2,
                        shadows: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: theme.colorScheme.onPrimary,
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),

              // 2. Played Time (Smaller text)
              Text(
                _formatDuration(position),
                style: TextStyle(
                  color: context.tokens.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 6),

              // 3. Slider Seekbar
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: theme.colorScheme.primary,
                    inactiveTrackColor: context.tokens.borderSubtle.withValues(
                      alpha: 0.5,
                    ),
                    thumbColor: theme.colorScheme.primary,
                    trackHeight: 3.0,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5.5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                  ),
                  child: Slider(
                    value: curMs,
                    max: maxMs > 0 ? maxMs : 1.0,
                    onChangeStart: (val) {
                      _isInteractingWithUi = true;
                      _cancelHideTimer();
                    },
                    onChangeEnd: (val) {
                      _isInteractingWithUi = false;
                      _startHideTimer();
                    },
                    onChanged: (val) {
                      _player.seek(Duration(milliseconds: val.toInt()));
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 4. Total Duration Time (Smaller text)
              Text(
                duration > Duration.zero ? _formatDuration(duration) : '00:00',
                style: TextStyle(
                  color: context.tokens.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 6),

              // 5. Fit Screen (Aspect Ratio) Button right of total time
              Tooltip(
                message: _videoFit == BoxFit.contain
                    ? 'Fit to Screen'
                    : 'Contain',
                child: InkWell(
                  onTap: _toggleAspectRatio,
                  borderRadius: context.tokens.borderRadiusPill,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: context.tokens.getShapeDecoration(
                      color: context.tokens.surfaceElevated.withValues(
                        alpha: 0.6,
                      ),
                      radius: context.tokens.cardRadius * 2,
                      side: BorderSide(
                        color: context.tokens.borderSubtle,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _videoFit == BoxFit.contain
                          ? Icons.aspect_ratio_rounded
                          : Icons.fit_screen_rounded,
                      color: context.tokens.textSecondary,
                      size: 17,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showServerSelectionModal(ThemeData theme) async {
    final wasPlaying = _pauseForModal();
    await PlayerServerSheet.show(
      context,
      sources: _sources,
      currentSourceIndex: _currentSourceIndex,
      onSourceSelected: (idx) {
        if (idx != _currentSourceIndex) {
          _selectSource(idx);
        }
      },
    );
    _resumeAfterModal(wasPlaying);
  }

  Future<void> _showAudioAndSubtitleModal() async {
    final wasPlaying = _pauseForModal();

    final validAudioTracks = _tracks.audio.where((t) {
      final l = (t.title ?? t.language ?? t.id).toLowerCase();
      return !l.contains('(no)') && l != 'no';
    }).toList();

    final validSubtitleTracks = _tracks.subtitle.where((t) {
      final l = (t.title ?? t.language ?? t.id).toLowerCase();
      return !l.contains('(no)') && l != 'no';
    }).toList();

    await PlayerAudioSubtitlesSheet.show(
      context: context,
      validAudioTracks: validAudioTracks,
      availableDubs: _availableDubs,
      validSubtitleTracks: validSubtitleTracks,
      externalSubtitles: _externalSubtitles,
      initialAudioTrack: _player.state.track.audio,
      initialSubtitlesEnabled: _subtitlesEnabled,
      initialSubtitleTrack:
          _activeSubtitleTrack ?? _player.state.track.subtitle,
      onSelectDubOption: (dub) => _switchDubLanguage(dub),
      onSelectAudioTrack: (track, label) {
        if (track != _player.state.track.audio) {
          _selectAudioTrack(track, label);
        }
      },
      onDisableSubtitles: () {
        if (_subtitlesEnabled) {
          _player.setSubtitleTrack(SubtitleTrack.no());
          setState(() {
            _subtitlesEnabled = false;
            _activeSubtitleTrack = null;
          });
          _showToast('Subtitles Off');
        }
      },
      onSelectExternalSubtitle: (sub) => _selectExternalSubtitle(sub),
      onSelectSubtitleTrack: (track, label) {
        if (!_subtitlesEnabled || track != _player.state.track.subtitle) {
          _player.setSubtitleTrack(track);
          setState(() {
            _subtitlesEnabled = true;
            _activeSubtitleTrack = track;
          });
          _showToast('Subtitle: $label');
        }
      },
    );

    _resumeAfterModal(wasPlaying);
  }
}
