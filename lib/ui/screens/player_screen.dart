import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
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
import '../../services/external_player_service.dart';
import '../../services/libmpv_helper.dart';
import '../../services/moviebox_provider.dart';
import '../../services/tmdb_service.dart';
import '../../services/window_service.dart';
import '../widgets/cast_dialog.dart';
import '../widgets/tv_focusable.dart';

class PlayerScreen extends StatefulWidget {
  final MediaItem mediaItem;
  final StreamSource streamSource;
  final List<StreamSource> availableSources;
  final int? season;
  final int? episode;
  final int? startPositionSeconds;

  const PlayerScreen({
    super.key,
    required this.mediaItem,
    required this.streamSource,
    this.availableSources = const [],
    this.season,
    this.episode,
    this.startPositionSeconds,
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
  final FocusNode _playPauseTvFocusNode = FocusNode(debugLabel: 'TvPlayPauseBtn');
  final FocusNode _seekbarTvFocusNode = FocusNode(debugLabel: 'TvSeekbar');

  // Multi-source state & watchdog
  late List<StreamSource> _sources;
  int _currentSourceIndex = 0;
  late StreamSource _activeSource;
  Timer? _sourceWatchdogTimer;

  // Controls & visibility
  bool _showControls = true;
  bool _isPlayerReady = false;
  String? _errorMessage;
  Timer? _hideTimer;
  Timer? _progressTimer;
  Timer? _frameCaptureTimer;
  Timer? _toastTimer;
  String? _toastMessage;

  // Resume banner
  Timer? _resumeBannerTimer;
  bool _showResumeBanner = false;
  int _resumedFromSeconds = 0;

  // Subtitles & Audio
  StreamSubscription? _errorSub;
  StreamSubscription? _tracksSub;
  StreamSubscription? _positionSub;
  Tracks _tracks = const Tracks();
  List<SubtitleOption> _externalSubtitles = [];
  bool _subtitlesEnabled = true;
  SubtitleTrack? _activeSubtitleTrack;
  List<AudioTrackOption> _availableDubs = [];
  bool _isSwitchingAudio = false;

  // Skip Intro / Outro
  List<SkipInterval> _skipIntervals = [];
  SkipInterval? _activeSkip;
  bool _hasSkippedIntro = false;
  bool _hasSkippedOutro = false;

  // Scrubbing frame preview
  bool _isHoveringSeekbar = false;
  double _hoverPositionFraction = 0.0;
  double _hoverLocalX = 0.0;
  final Map<int, Uint8List> _frameCache = {};

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
    _currentSourceIndex = _sources.indexWhere((s) => s.url == widget.streamSource.url);
    if (_currentSourceIndex < 0) _currentSourceIndex = 0;
    _activeSource = _sources[_currentSourceIndex];

    // Player setup
    _player = Player(
      configuration: const PlayerConfiguration(
        title: 'Exalere',
      ),
    );
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        hwdec: 'auto-safe',
      ),
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
      if (msg.contains('cache') || msg.contains('buffering') || msg.contains('audio-pts')) {
        return;
      }
      if (!_isPlayerReady || (_player.state.position == Duration.zero && !_player.state.playing)) {
        _handlePlaybackFailure('Playback issue encountered: $err');
      }
    });

    _positionSub = _player.stream.position.listen(_onPositionChanged);

    _initPlayer();
    _loadSubtitlesAndDubs();
    _loadSeriesSkipMarkers();
    _startHideTimer();
    _startFrameCapture();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
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
      final resumeSec = widget.startPositionSeconds ??
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
          DeviceOrientation.portraitUp,
        ]);
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
      _progressTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!mounted) return;
        final pos = _player.state.position.inSeconds;
        final dur = _player.state.duration.inSeconds;
        if (pos > 0 && dur > 0) {
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

  void _startSourceWatchdog() {
    _sourceWatchdogTimer?.cancel();
    // 8-second watchdog: if stream doesn't produce playback, attempt automatic fallback
    _sourceWatchdogTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      if (!_isPlayerReady || (_player.state.position == Duration.zero && !_player.state.playing)) {
        if (_currentSourceIndex + 1 < _sources.length) {
          _switchToNextSource('Source ${_currentSourceIndex + 1} timed out. Trying ${_sources[_currentSourceIndex + 1].quality}...');
        } else {
          _handlePlaybackFailure('Video stream could not be loaded or played. The server may be unreachable, expired, or offline.');
        }
      }
    });
  }

  void _handlePlaybackFailure(String reason) {
    if (!mounted) return;
    if (_currentSourceIndex + 1 < _sources.length) {
      _switchToNextSource('Stream issue encountered. Switching to backup ${_sources[_currentSourceIndex + 1].quality}...');
    } else {
      setState(() => _errorMessage = reason);
    }
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
      _errorMessage = null;
    });

    _showToast(customMessage ?? 'Switched to Server ${idx + 1} (${_activeSource.quality})');

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
    final details = await _movieBoxProvider.getDetails(widget.mediaItem.id);
    if (mounted && details != null && details.dubs.isNotEmpty) {
      setState(() => _availableDubs = details.dubs);
    }
  }

  Future<void> _loadSeriesSkipMarkers() async {
    if (widget.season == null || widget.episode == null) return;

    try {
      final details = await _movieBoxProvider.getDetails(widget.mediaItem.id);
      if (details != null && details.seasons.isNotEmpty) {
        final season = details.seasons.firstWhere(
          (s) => s.seasonNumber == widget.season,
          orElse: () => details.seasons.first,
        );
        final episode = season.episodes.firstWhere(
          (e) => e.episode == widget.episode,
          orElse: () => season.episodes.first,
        );

        if (episode.skipIntervals.isNotEmpty && mounted) {
          setState(() => _skipIntervals = episode.skipIntervals);
        }
      }
    } catch (_) {}

    // If provider did not supply verified intro skip markers, query real timestamps from TMDB / IntroDB
    if (_skipIntervals.where((s) => s.type == SkipType.intro).isEmpty && mounted) {
      try {
        final realIntro = await TmdbService().getEpisodeIntroSkip(
          title: widget.mediaItem.title,
          year: widget.mediaItem.year,
          season: widget.season!,
          episode: widget.episode!,
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
    if (active == null && app.enableSmartSkip && durSec > 180 && widget.season != null) {
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
      if (active.type == SkipType.intro && app.autoSkipIntro && !_hasSkippedIntro) {
        _hasSkippedIntro = true;
        _player.seek(Duration(seconds: active.endSeconds));
        _showToast('Auto-skipped Intro');
      } else if (active.type == SkipType.outro && app.autoSkipOutro && !_hasSkippedOutro) {
        _hasSkippedOutro = true;
        _showToast('Outro reached');
      }
    }
  }

  void _startFrameCapture() {
    // Capture real playback frames into cache periodically for hovering scrub previews
    _frameCaptureTimer = Timer.periodic(const Duration(seconds: 12), (timer) async {
      if (!mounted || !_player.state.playing) return;
      try {
        final posSec = _player.state.position.inSeconds;
        if (posSec > 0 && _frameCache.length < 60) {
          final bucket = posSec ~/ 10;
          if (!_frameCache.containsKey(bucket)) {
            final screenshot = await _player.screenshot();
            if (screenshot != null && mounted) {
              _frameCache[bucket] = screenshot;
            }
          }
        }
      } catch (_) {}
    });
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
    _hideTimer?.cancel();
    bool isTv = false;
    try {
      isTv = context.read<AppProvider>().isTvMode;
    } catch (_) {}
    final duration = isTv ? const Duration(seconds: 6) : const Duration(milliseconds: 3500);
    _hideTimer = Timer(duration, () {
      if (mounted && _player.state.playing && !_isHoveringSeekbar) {
        setState(() => _showControls = false);
        _focusNode.requestFocus();
      }
    });
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
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
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

        // 2. D-Pad Left: Rewind 10s & reveal controls briefly
        if (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.keyJ ||
            key == LogicalKeyboardKey.mediaRewind ||
            key == LogicalKeyboardKey.mediaTrackPrevious) {
          final cur = _player.state.position;
          final target = _clampDuration(cur - const Duration(seconds: 10), Duration.zero, _player.state.duration);
          _player.seek(target);
          _revealTvControls();
          _showToast('⏪ -10s (${_formatDuration(target)})');
          return KeyEventResult.handled;
        }

        // 3. D-Pad Right: Forward 10s & reveal controls briefly
        if (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.keyL ||
            key == LogicalKeyboardKey.mediaFastForward ||
            key == LogicalKeyboardKey.mediaTrackNext) {
          final cur = _player.state.position;
          final target = _clampDuration(cur + const Duration(seconds: 10), Duration.zero, _player.state.duration);
          _player.seek(target);
          _revealTvControls();
          _showToast('⏩ +10s (${_formatDuration(target)})');
          return KeyEventResult.handled;
        }
      } else {
        // When controls are visible on TV:
        _startHideTimer(); // Reset auto-hide timer on TV user remote interaction
        return KeyEventResult.ignored; // Let Flutter Focus traversal & button onTap handle!
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
      final cur = _player.state.position;
      _player.seek(cur - const Duration(seconds: 10));
      _onUserActivity();
      _showToast('Rewind 10s');
      return KeyEventResult.handled;
    }

    // Forward 10s (Right Arrow, L, TV Remote Fast Forward, Next Track)
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyL ||
        key == LogicalKeyboardKey.mediaFastForward ||
        key == LogicalKeyboardKey.mediaTrackNext) {
      final cur = _player.state.position;
      _player.seek(cur + const Duration(seconds: 10));
      _onUserActivity();
      _showToast('Forward 10s');
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
    final targetPoint = _activeSkip!.endSeconds;
    final label = _activeSkip!.label;
    _hasSkippedIntro = true;
    setState(() => _activeSkip = null);
    _player.seek(Duration(seconds: targetPoint));
    _showToast('Skipped $label to ${_formatDuration(Duration(seconds: targetPoint))}');
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
        season: widget.season ?? 0,
        episode: widget.episode ?? 0,
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
          content: const Text('Could not launch external player. Make sure MPV or VLC is installed.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _toggleAspectRatio() {
    setState(() {
      _videoFit = _videoFit == BoxFit.contain ? BoxFit.cover : BoxFit.contain;
    });
    _showToast(_videoFit == BoxFit.contain ? 'Aspect: Contain' : 'Aspect: Cover');
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _resumeBannerTimer?.cancel();
    _sourceWatchdogTimer?.cancel();
    _frameCaptureTimer?.cancel();
    _toastTimer?.cancel();
    _errorSub?.cancel();
    _tracksSub?.cancel();
    _positionSub?.cancel();
    _windowService.fullscreenNotifier.removeListener(_onFullscreenChanged);
    _focusNode.dispose();
    _playPauseTvFocusNode.dispose();
    _seekbarTvFocusNode.dispose();
    _player.dispose();

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Error State Fallback
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 580),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF14171E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline_rounded, color: Color(0xFFE50914), size: 48),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Stream Playback Issue',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    if (_currentSourceIndex + 1 < _sources.length)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.skip_next_rounded, size: 18),
                        label: Text('Try Source ${_currentSourceIndex + 2} (${_sources[_currentSourceIndex + 1].quality})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _switchToNextSource('Switching to next source...'),
                      ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE50914),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Open in VLC / External Player', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _openInExternalPlayer,
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _isPlayerReady = false;
                        });
                        _initPlayer();
                      },
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final app = context.watch<AppProvider>();
    final isTv = app.isTvMode;
    final cast = context.watch<CastProvider>();
    if (cast.isCasting && _player.state.playing) {
      _player.pause();
    }

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
          if (_showControls) {
            _hideTvControls();
          } else {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
        backgroundColor: Colors.black,
        body: MouseRegion(
          cursor: _showControls ? SystemMouseCursors.basic : SystemMouseCursors.none,
          onHover: (_) => _onUserActivity(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            onDoubleTap: _toggleFullscreen,
            child: Stack(
              children: [
                // Video Surface
                Center(
                  child: Video(
                    controller: _controller,
                    controls: NoVideoControls,
                    fit: _videoFit,
                  ),
                ),

                // Casting Overlay Banner (When Casting to TV/DLNA/AirPlay on Mobile/Desktop)
                if (cast.isCasting && !isTv)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14171E).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.7),
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
                              color: theme.colorScheme.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.cast_connected_rounded, color: theme.colorScheme.primary, size: 40),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Playing on ${cast.connectedDevice?.name ?? "Cast Device"}',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cast.isPlaying ? 'Streaming smoothly' : (cast.isPaused ? 'Paused on TV' : 'Connecting to TV...'),
                            style: const TextStyle(color: Colors.white60, fontSize: 13),
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
                                icon: const Icon(Icons.tune_rounded, size: 18),
                                label: const Text('Cast Controls'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await cast.disconnect();
                                  _player.play();
                                },
                                icon: const Icon(Icons.phone_android_rounded, size: 18, color: Colors.white),
                                label: const Text('Play Here', style: TextStyle(color: Colors.white)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white30),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                // Buffering Indicator
                if (!_isPlayerReady && !cast.isCasting)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: theme.colorScheme.primary),
                        const SizedBox(height: 18),
                        Text(
                          'Buffering "${widget.mediaItem.title}" (${_activeSource.quality})...',
                          style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          _toastMessage!,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),

                // Controls Overlay (Netflix Cinema Theme)
                AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.75),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.85),
                          ],
                          stops: const [0.0, 0.25, 0.7, 1.0],
                        ),
                      ),
                      child: SafeArea(
                        child: isTv
                            ? _buildTvPlayerControls(theme)
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Top Bar: Back, Title, Sources selector, Audio/Subs, Fullscreen
                                  _buildTopBar(theme),

                                  // Center Controls: Rewind 10s, Oversized Play/Pause, Forward 10s
                                  _buildCenterControls(),

                                  // Bottom Bar: Scrub bar with hover preview, time stamps & controls
                                  _buildBottomControls(theme),
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
                        child: InkWell(
                          onTap: _triggerSkip,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.7),
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
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.fast_forward_rounded, color: Colors.white, size: 18),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.history_rounded, color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Resumed at ${_formatDuration(Duration(seconds: _resumedFromSeconds))}',
                              style: const TextStyle(
                                color: Colors.white,
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
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.replay_rounded, size: 14, color: Colors.black),
                                    SizedBox(width: 4),
                                    Text(
                                      'Restart',
                                      style: TextStyle(
                                        color: Colors.black,
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
                              child: const Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Icon(Icons.close_rounded, size: 16, color: Colors.white54),
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

  Widget _buildTopBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.mediaItem.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                if (widget.season != null && widget.episode != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Season ${widget.season} • Episode ${widget.episode}',
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
          // Cast Action Button
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
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isCastingThis
                          ? theme.colorScheme.primary.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: isCastingThis
                          ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                          : null,
                    ),
                    child: Icon(
                      isCastingThis ? Icons.cast_connected_rounded : Icons.cast_rounded,
                      color: isCastingThis ? theme.colorScheme.primary : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              );
            },
          ),
          // External Player
          Tooltip(
            message: 'Open in External Player (VLC/MPV)',
            child: InkWell(
              onTap: _openInExternalPlayer,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
          // Aspect Ratio Toggle
          Tooltip(
            message: 'Aspect Ratio: ${_videoFit == BoxFit.contain ? "Contain" : "Cover"}',
            child: InkWell(
              onTap: _toggleAspectRatio,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.aspect_ratio_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
          // Fullscreen Toggle
          Tooltip(
            message: _isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
            child: InkWell(
              onTap: _toggleFullscreen,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
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
          scaleFactor: 1.1,
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            _hideTvControls();
            Navigator.of(context).pop();
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.mediaItem.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.season != null && widget.episode != null)
                Text(
                  'Season ${widget.season} • Episode ${widget.episode}',
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
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
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
        final curMs = position.inMilliseconds.toDouble().clamp(0.0, maxMs > 0 ? maxMs : 1.0);

        return Focus(
          focusNode: _seekbarTvFocusNode,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              final cur = _player.state.position;
              final target = _clampDuration(cur - const Duration(seconds: 10), Duration.zero, _player.state.duration);
              _player.seek(target);
              _startHideTimer();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              final cur = _player.state.position;
              final target = _clampDuration(cur + const Duration(seconds: 10), Duration.zero, _player.state.duration);
              _player.seek(target);
              _startHideTimer();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _playPauseTvFocusNode.requestFocus();
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFocused ? theme.colorScheme.primary : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.35),
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
                        color: isFocused ? theme.colorScheme.primary : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: isFocused ? 6 : 4,
                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: isFocused ? 9 : 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: isFocused ? Colors.white : theme.colorScheme.primary,
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
                      duration > Duration.zero ? _formatDuration(duration) : '00:00',
                      style: const TextStyle(
                        color: Colors.white70,
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
        // 1. Rewind 10s
        TvFocusable(
          scaleFactor: 1.12,
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            _player.seek(_player.state.position - const Duration(seconds: 10));
            _showToast('Rewind 10s');
            _startHideTimer();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.replay_10_rounded, color: Colors.white, size: 22),
                SizedBox(width: 6),
                Text('10s', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),

        // 2. Play / Pause (Autofocused, with up navigation to seekbar!)
        TvFocusable(
          focusNode: _playPauseTvFocusNode,
          autofocus: true,
          scaleFactor: 1.12,
          borderRadius: BorderRadius.circular(12),
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
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<bool>(
                  stream: _player.stream.playing,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data ?? _player.state.playing;
                    return Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.black,
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
                      style: const TextStyle(
                        color: Colors.black,
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

        // 3. Forward 10s
        TvFocusable(
          scaleFactor: 1.12,
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            _player.seek(_player.state.position + const Duration(seconds: 10));
            _showToast('Forward 10s');
            _startHideTimer();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('10s', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                SizedBox(width: 6),
                Icon(Icons.forward_10_rounded, color: Colors.white, size: 22),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),

        // 4. Episodes (TV Series only)
        if (widget.mediaItem.isSeries) ...[
          TvFocusable(
            scaleFactor: 1.12,
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              // Exits back cleanly to TvDetailsScreen where all episodes are available
              _hideTvControls();
              Navigator.of(context).pop();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.video_library_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 6),
                  Text('Episodes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],

        // 5. Audio & Dubs
        TvFocusable(
          scaleFactor: 1.12,
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            _startHideTimer();
            _showAudioAndSubtitleModal();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.audiotrack_rounded, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text('Audio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),

        // 6. Subtitles
        TvFocusable(
          scaleFactor: 1.12,
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            _startHideTimer();
            _showAudioAndSubtitleModal();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.subtitles_rounded, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text('Subs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),

        // 7. Server Switcher
        if (_sources.length > 1) ...[
          TvFocusable(
            scaleFactor: 1.12,
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              _startHideTimer();
              _showServerSelectionModal(theme);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.dns_rounded, color: theme.colorScheme.primary, size: 20),
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

  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 10s Rewind
        InkWell(
          onTap: () {
            final current = _player.state.position;
            _player.seek(current - const Duration(seconds: 10));
            _startHideTimer();
          },
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.4),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(width: 36),

        // Central Play / Pause Button
        StreamBuilder<bool>(
          stream: _player.stream.playing,
          builder: (context, snapshot) {
            final isPlaying = snapshot.data ?? _player.state.playing;
            return InkWell(
              onTap: () {
                _player.playOrPause();
                _startHideTimer();
              },
              borderRadius: BorderRadius.circular(40),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 46,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 36),

        // 10s Forward
        InkWell(
          onTap: () {
            final current = _player.state.position;
            _player.seek(current + const Duration(seconds: 10));
            _startHideTimer();
          },
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.4),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 30),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: StreamBuilder<Duration>(
        stream: _player.stream.position,
        builder: (context, snapshot) {
          final position = snapshot.data ?? _player.state.position;
          final duration = _player.state.duration;
          final remaining = duration > position ? duration - position : Duration.zero;

          final maxMs = duration.inMilliseconds.toDouble();
          final curMs = position.inMilliseconds.toDouble().clamp(0.0, maxMs > 0 ? maxMs : 1.0);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scrub bar with Netflix-style Hover Frame Preview Card
              LayoutBuilder(
                builder: (context, constraints) {
                  final barWidth = constraints.maxWidth;
                  final hoverMs = (maxMs * _hoverPositionFraction).toInt();
                  final hoverDuration = Duration(milliseconds: hoverMs);
                  final bucket = hoverDuration.inSeconds ~/ 10;
                  final cachedShot = _frameCache[bucket];

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Hover Preview Card Popup
                      if (_isHoveringSeekbar && duration > Duration.zero)
                        Positioned(
                          bottom: 34,
                          left: (_hoverLocalX - 80).clamp(0.0, (barWidth - 160).clamp(0.0, barWidth)),
                          child: Container(
                            width: 160,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14171E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24, width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: cachedShot != null
                                        ? Image.memory(cachedShot, fit: BoxFit.cover)
                                        : (widget.mediaItem.backdropUrl != null || widget.mediaItem.posterUrl != null)
                                            ? CachedNetworkImage(
                                                imageUrl: widget.mediaItem.backdropUrl ?? widget.mediaItem.posterUrl!,
                                                fit: BoxFit.cover,
                                                placeholder: (ctx, url) => Container(color: Colors.black54),
                                                errorWidget: (ctx, url, err) => Container(color: Colors.black54),
                                              )
                                            : Container(
                                                color: Colors.black87,
                                                child: const Icon(Icons.movie_rounded, color: Colors.white30, size: 28),
                                              ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDuration(hoverDuration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Mouse-tracked Slider Bar
                      MouseRegion(
                        onHover: (event) {
                          setState(() {
                            _isHoveringSeekbar = true;
                            _hoverLocalX = event.localPosition.dx;
                            _hoverPositionFraction = (_hoverLocalX / barWidth).clamp(0.0, 1.0);
                          });
                        },
                        onExit: (_) {
                          setState(() => _isHoveringSeekbar = false);
                        },
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFFE50914), // Netflix Crimson
                            inactiveTrackColor: Colors.white24,
                            thumbColor: const Color(0xFFE50914),
                            trackHeight: 3.5,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          ),
                          child: Slider(
                            value: curMs,
                            max: maxMs > 0 ? maxMs : 1.0,
                            onChanged: (val) {
                              _player.seek(Duration(milliseconds: val.toInt()));
                              _startHideTimer();
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              // Position & Remaining Duration Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(position),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      duration > Duration.zero ? '-${_formatDuration(remaining)}' : '0:00',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Action Bar: Playback tools & media controls
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Play / Pause
                      StreamBuilder<bool>(
                        stream: _player.stream.playing,
                        builder: (context, snapshot) {
                          final isPlaying = snapshot.data ?? _player.state.playing;
                          return IconButton(
                            tooltip: isPlaying ? 'Pause (Space)' : 'Play (Space)',
                            icon: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                            onPressed: () {
                              _player.playOrPause();
                              _startHideTimer();
                            },
                          );
                        },
                      ),

                      // 10s Rewind
                      IconButton(
                        tooltip: 'Rewind 10s (Left Arrow)',
                        icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 22),
                        onPressed: () {
                          final current = _player.state.position;
                          _player.seek(current - const Duration(seconds: 10));
                          _startHideTimer();
                        },
                      ),

                      // 10s Forward
                      IconButton(
                        tooltip: 'Forward 10s (Right Arrow)',
                        icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 22),
                        onPressed: () {
                          final current = _player.state.position;
                          _player.seek(current + const Duration(seconds: 10));
                          _startHideTimer();
                        },
                      ),

                      // Volume Mute / Unmute
                      IconButton(
                        tooltip: _player.state.volume > 0 ? 'Mute (M)' : 'Unmute (M)',
                        icon: Icon(
                          _player.state.volume > 0 ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                          color: Colors.white70,
                          size: 22,
                        ),
                        onPressed: () {
                          if (_player.state.volume > 0) {
                            _player.setVolume(0.0);
                            _showToast('Muted');
                          } else {
                            _player.setVolume(100.0);
                            _showToast('Unmuted');
                          }
                          setState(() {});
                          _startHideTimer();
                        },
                      ),

                      const SizedBox(width: 8),

                      // Elapsed / Total Duration timestamp
                      Text(
                        '${_formatDuration(position)} / ${duration > Duration.zero ? _formatDuration(duration) : "0:00"}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Server / Quality Switcher Pill Button
                      if (_sources.length > 1)
                        InkWell(
                          onTap: () => _showServerSelectionModal(theme),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(alpha: 0.45),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.dns_rounded, size: 14, color: theme.colorScheme.primary),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 160),
                                  child: Text(
                                    'Server ${_currentSourceIndex + 1}: ${_activeSource.quality}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Colors.white70),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.dns_rounded, size: 13, color: Colors.white70),
                              const SizedBox(width: 5),
                              Text(
                                'Server: ${_activeSource.quality.isNotEmpty ? _activeSource.quality : "Auto"}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Quick Subtitles Toggle
                      IconButton(
                        tooltip: _subtitlesEnabled ? 'Subtitles On (C)' : 'Subtitles Off (C)',
                        icon: Icon(
                          _subtitlesEnabled ? Icons.subtitles_rounded : Icons.subtitles_off_rounded,
                          color: _subtitlesEnabled ? Colors.white : Colors.white38,
                          size: 22,
                        ),
                        onPressed: _toggleSubtitleOnOff,
                      ),

                      // Audio & Subtitles Dialog
                      IconButton(
                        tooltip: 'Audio & Subtitle Options',
                        icon: const Icon(Icons.audiotrack_rounded, color: Colors.white, size: 22),
                        onPressed: _showAudioAndSubtitleModal,
                      ),

                      // Playback Speed
                      PopupMenuButton<double>(
                        tooltip: 'Playback Speed',
                        icon: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${_playbackSpeed}x',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onSelected: _setSpeed,
                        itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((rate) {
                          return PopupMenuItem<double>(
                            value: rate,
                            child: Text('${rate}x'),
                          );
                        }).toList(),
                      ),

                      // Aspect Ratio
                      IconButton(
                        tooltip: _videoFit == BoxFit.contain ? 'Fit to Screen' : 'Contain',
                        icon: Icon(
                          _videoFit == BoxFit.contain ? Icons.aspect_ratio_rounded : Icons.fit_screen_rounded,
                          color: Colors.white70,
                          size: 22,
                        ),
                        onPressed: _toggleAspectRatio,
                      ),

                      // External VLC / MPV Player
                      IconButton(
                        tooltip: 'Open in VLC / MPV',
                        icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 20),
                        onPressed: _openInExternalPlayer,
                      ),

                      // Fullscreen Toggle Button
                      IconButton(
                        tooltip: _isFullscreen ? 'Exit Fullscreen (F)' : 'Fullscreen (F)',
                        icon: Icon(
                          _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: _toggleFullscreen,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showServerSelectionModal(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14171E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.dns_rounded, color: theme.colorScheme.primary, size: 22),
                        const SizedBox(width: 10),
                        const Text(
                          'Streaming Servers & Quality',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _sources.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final src = _sources[idx];
                      final isSelected = idx == _currentSourceIndex;
                      final detailsList = [
                        if (src.formattedSize.isNotEmpty) src.formattedSize,
                        if (src.codec != null && src.codec!.isNotEmpty) src.codec!,
                      ];

                      return TvFocusable(
                        autofocus: isSelected,
                        scaleFactor: 1.04,
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          if (idx != _currentSourceIndex) {
                            _selectSource(idx);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? theme.colorScheme.primary : Colors.white12,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: isSelected ? theme.colorScheme.primary : Colors.white38,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Server ${idx + 1}',
                                          style: TextStyle(
                                            color: isSelected ? theme.colorScheme.primary : Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            src.quality,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (src.format.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              src.format,
                                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (detailsList.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          detailsList.join(' • '),
                                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAudioAndSubtitleModal() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14171E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return DefaultTabController(
              length: 2,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Audio & Subtitles',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white54),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TabBar(
                        indicatorColor: theme.colorScheme.primary,
                        labelColor: theme.colorScheme.primary,
                        unselectedLabelColor: Colors.white60,
                        tabs: const [
                          Tab(icon: Icon(Icons.audiotrack_rounded, size: 18), text: 'Audio Tracks'),
                          Tab(icon: Icon(Icons.subtitles_rounded, size: 18), text: 'Subtitles'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 340),
                        child: TabBarView(
                          children: [
                            // Audio Tracks Tab
                            ListView(
                              children: [
                                if (_tracks.audio.isNotEmpty) ...[
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Text('Embedded Audio Tracks', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  ..._tracks.audio.map((track) {
                                    final isSelected = _player.state.track.audio == track;
                                    final label = track.title ?? track.language ?? 'Audio Track (${track.id})';
                                    return TvFocusable(
                                      autofocus: isSelected,
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        Navigator.of(ctx).pop();
                                        _selectAudioTrack(track, label);
                                      },
                                      child: ListTile(
                                        leading: Icon(
                                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                          color: isSelected ? theme.colorScheme.primary : Colors.white54,
                                        ),
                                        title: Text(label, style: const TextStyle(color: Colors.white)),
                                      ),
                                    );
                                  }),
                                ],

                                if (_availableDubs.isNotEmpty) ...[
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Text('Provider Dubbed Versions', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  ..._availableDubs.map((dub) {
                                    return TvFocusable(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        Navigator.of(ctx).pop();
                                        _switchDubLanguage(dub);
                                      },
                                      child: ListTile(
                                        leading: const Icon(Icons.language_rounded, color: Colors.white70),
                                        title: Text(dub.label, style: const TextStyle(color: Colors.white)),
                                        subtitle: Text(dub.language, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                        trailing: const Icon(Icons.swap_horiz_rounded, color: Colors.white54),
                                      ),
                                    );
                                  }),
                                ],

                                if (_tracks.audio.isEmpty && _availableDubs.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Center(
                                      child: Text('Default Stream Audio (1 Audio Track Available)', style: TextStyle(color: Colors.white54)),
                                    ),
                                  ),
                              ],
                            ),

                            // Subtitles Tab
                            ListView(
                              children: [
                                TvFocusable(
                                  autofocus: !_subtitlesEnabled,
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    _player.setSubtitleTrack(SubtitleTrack.no());
                                    setState(() => _subtitlesEnabled = false);
                                    Navigator.of(ctx).pop();
                                    _showToast('Subtitles Off');
                                  },
                                  child: ListTile(
                                    leading: Icon(
                                      !_subtitlesEnabled ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                      color: !_subtitlesEnabled ? theme.colorScheme.primary : Colors.white54,
                                    ),
                                    title: const Text('Off', style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                                if (_tracks.subtitle.isNotEmpty) ...[
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Text('Embedded Subtitles', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  ..._tracks.subtitle.map((track) {
                                    final isSelected = _subtitlesEnabled && _player.state.track.subtitle == track;
                                    final label = track.title ?? track.language ?? 'Subtitle (${track.id})';
                                    return TvFocusable(
                                      autofocus: isSelected,
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        _player.setSubtitleTrack(track);
                                        setState(() {
                                          _subtitlesEnabled = true;
                                          _activeSubtitleTrack = track;
                                        });
                                        Navigator.of(ctx).pop();
                                        _showToast('Subtitle: $label');
                                      },
                                      child: ListTile(
                                        leading: Icon(
                                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                          color: isSelected ? theme.colorScheme.primary : Colors.white54,
                                        ),
                                        title: Text(label, style: const TextStyle(color: Colors.white)),
                                      ),
                                    );
                                  }),
                                ],
                                if (_externalSubtitles.isNotEmpty) ...[
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Text('Online Subtitles', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  ..._externalSubtitles.map((sub) {
                                    return TvFocusable(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        _selectExternalSubtitle(sub);
                                        Navigator.of(ctx).pop();
                                      },
                                      child: ListTile(
                                        leading: const Icon(Icons.subtitles_rounded, color: Colors.white70),
                                        title: Text(sub.name, style: const TextStyle(color: Colors.white)),
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
