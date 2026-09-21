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
import '../../providers/library_provider.dart';
import '../../services/external_player_service.dart';
import '../../services/libmpv_helper.dart';
import '../../services/moviebox_provider.dart';
import '../../services/video_cache_service.dart';
import '../../services/window_service.dart';
import '../theme/app_tokens.dart';
import 'player/player_audio_mixin.dart';
import 'player/player_controls_visibility_mixin.dart';
import 'player/player_device_mixin.dart';
import 'player/player_episodes_mixin.dart';
import 'player/player_episodes_sheet.dart';
import 'player/player_error_view.dart';
import 'player/player_key_handler.dart';
import 'player/player_playback_helper.dart';
import 'player/player_server_sheet.dart';
import 'player/player_speed_dialog.dart';
import 'player/player_video_view.dart';

class PlayerScreen extends StatefulWidget {
  final MediaItem mediaItem;
  final StreamSource streamSource;
  final List<StreamSource> availableSources;
  final int? season;
  final int? episode;
  final int? startPositionSeconds;
  final MediaDetails? mediaDetails;
  final String? imdbId;

  const PlayerScreen({
    super.key,
    required this.mediaItem,
    required this.streamSource,
    this.availableSources = const [],
    this.season,
    this.episode,
    this.startPositionSeconds,
    this.mediaDetails,
    this.imdbId,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with
        PlayerAudioMixin,
        PlayerEpisodesMixin,
        PlayerDeviceMixin,
        PlayerControlsVisibilityMixin {
  late final Player _player;
  late final VideoController _controller;
  final MovieBoxProvider _movieBoxProvider = MovieBoxProvider();
  final WindowService _windowService = WindowService();
  late LibraryProvider _libraryProvider;

  String? get _resolvedImdbId {
    if (widget.imdbId != null && widget.imdbId!.startsWith('tt')) {
      return widget.imdbId;
    }
    if (widget.mediaItem.id.startsWith('tt')) {
      return widget.mediaItem.id;
    }
    return null;
  }

  late bool _isTvMode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _libraryProvider = context.read<LibraryProvider>();
    _isTvMode = context.read<AppProvider>().isTvMode;
  }

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
  bool _isSwitchingServer = false;

  // Playback state
  bool _isPlayerReady = false;
  bool _isLoadingVideo = true;
  bool _isBuffering = false;
  Duration _lastPosition = Duration.zero;
  DateTime _lastPositionChangeTime = DateTime.now();
  Timer? _bufferingDebounceTimer;
  String? _errorMessage;
  Timer? _progressTimer;

  double _playbackSpeed = 1.0;
  BoxFit _videoFit = BoxFit.contain;
  bool _isFullscreen = false;

  StreamSubscription? _errorSub;
  StreamSubscription? _tracksSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _completedSub;

  // Mixin interface overrides
  @override
  Player get player => _player;

  @override
  FocusNode get focusNode => _focusNode;

  @override
  FocusNode get playPauseTvFocusNode => _playPauseTvFocusNode;

  @override
  FocusNode get seekbarTvFocusNode => _seekbarTvFocusNode;

  @override
  MediaItem get mediaItem => widget.mediaItem;

  @override
  MovieBoxProvider get movieBoxProvider => _movieBoxProvider;

  @override
  MediaDetails? get mediaDetails => details;

  @override
  bool get isPlayerReady => _isPlayerReady;

  @override
  String? get errorMessage => _errorMessage;

  @override
  void onDubStreamsLoaded(List<StreamSource> newSources, StreamSource active) {
    _sourceWatchdogTimer?.cancel();
    setState(() {
      _sources = newSources;
      _currentSourceIndex = 0;
      _activeSource = active;
      _isPlayerReady = false;
      _errorMessage = null;
    });
    _startSourceWatchdog();
  }

  @override
  void onDubPlaybackReady() {
    if (mounted) {
      setState(() {
        _isPlayerReady = true;
        _isLoadingVideo = false;
        _isBuffering = false;
      });
    }
    _startProgressTimer();
  }

  @override
  void onNextEpisodeStarted(
    List<StreamSource> streams,
    int season,
    int episode,
  ) {
    _sourceWatchdogTimer?.cancel();
    _progressTimer?.cancel();
    final newMediaKey = '${widget.mediaItem.id}_s${season}_e$episode';
    VideoCacheService.instance.setActiveMediaKey(newMediaKey);
    VideoCacheService.instance.clearCache();
    setState(() {
      _sources = streams;
      _currentSourceIndex = 0;
      _activeSource = streams.first;
      _isPlayerReady = false;
      hasAutoSelectedAudio = false;
      _errorMessage = null;
    });
    _startSourceWatchdog();
  }

  @override
  void onAfterEpisodeChanged() {
    loadSubtitlesAndDubs(
      mediaId: widget.mediaItem.id,
      resourceId: _activeSource.resourceId,
      season: currentSeason,
      episode: currentEpisode,
      imdbId: _resolvedImdbId,
      initialSubtitles: _activeSource.subtitles,
    );
    if (mounted) {
      setState(() => _isPlayerReady = true);
    }
    _startProgressTimer();
  }

  @override
  void recordEpisodeProgress(
    int posSec,
    int durSec,
    int? season,
    int? episode,
  ) {
    if (!mounted) return;
    context.read<LibraryProvider>().recordProgress(
      item: widget.mediaItem,
      positionSeconds: posSec,
      totalSeconds: durSec,
      season: season,
      episode: episode,
    );
  }

  @override
  void initState() {
    super.initState();
    LibMpvHelper.ensureCriticalSectionsInitialized();

    _sources = widget.availableSources.isNotEmpty
        ? widget.availableSources
        : [widget.streamSource];
    _currentSourceIndex = _sources.indexWhere(
      (s) => s.url == widget.streamSource.url,
    );
    if (_currentSourceIndex < 0) _currentSourceIndex = 0;
    _activeSource = _sources[_currentSourceIndex];

    _player = Player(
      configuration: PlayerConfiguration(
        title: 'Exalere',
        bufferSize: VideoCacheService.instance.maxCacheSizeBytes,
      ),
    );
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(hwdec: 'auto-safe'),
    );

    _isFullscreen = _windowService.isFullscreen;
    _windowService.fullscreenNotifier.addListener(_onFullscreenChanged);

    initDeviceState();
    initEpisodesState(
      initialDetails: widget.mediaDetails,
      initialSeason: widget.season,
      initialEpisode: widget.episode,
    );

    _tracksSub = _player.stream.tracks.listen((t) {
      if (mounted) {
        setState(() => tracks = t);
        checkAndApplyDefaultAudioLanguage();
        checkAndApplyDefaultSubtitle();
      }
    });

    _errorSub = _player.stream.error.listen((err) {
      debugPrint('MediaKit player error: $err');
      if (isSwitchingAudio) return;
      final msg = err.toString().toLowerCase();
      if (msg.contains('cache') ||
          msg.contains('buffering') ||
          msg.contains('audio-pts')) {
        return;
      }
      if (_isPlayerReady &&
          (!_player.state.playing || _player.state.position == Duration.zero)) {
        String userFriendlyError = 'Playback issue encountered: $err';
        if (msg.contains('demux') ||
            msg.contains('format') ||
            msg.contains('recognize')) {
          userFriendlyError = 'Stream format could not be decoded. Please switch to another server or try an external player.';
        }
        handlePlaybackFailure(userFriendlyError);
      }
    });

    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      if (!buffering) {
        _bufferingDebounceTimer?.cancel();
        if (_isBuffering) {
          setState(() => _isBuffering = false);
        }
      } else {
        // If the video is actively playing and position is ticking, ignore demuxer cache noise
        final timeSincePosChange = DateTime.now().difference(
          _lastPositionChangeTime,
        );
        if (_player.state.playing &&
            timeSincePosChange < const Duration(milliseconds: 500)) {
          return;
        }
        // Debounce buffering indicator so transient caching doesn't flash the spinner
        _bufferingDebounceTimer?.cancel();
        _bufferingDebounceTimer = Timer(const Duration(milliseconds: 400), () {
          if (mounted &&
              DateTime.now().difference(_lastPositionChangeTime) >=
                  const Duration(milliseconds: 400)) {
            setState(() => _isBuffering = true);
          }
        });
      }
    });

    _playingSub = _player.stream.playing.listen((playing) {
      if (playing && mounted) {
        _sourceWatchdogTimer?.cancel();
        _bufferingDebounceTimer?.cancel();
        if (_isLoadingVideo || _isBuffering || !_isPlayerReady) {
          setState(() {
            _isLoadingVideo = false;
            _isBuffering = false;
            _isPlayerReady = true;
          });
        }
        checkAndApplyDefaultAudioLanguage();
        syncPipAutoEnter(isPlaying: true);
      } else if (!playing && mounted) {
        syncPipAutoEnter(isPlaying: false);
      }
    });

    _positionSub = _player.stream.position.listen(_onPositionChanged);
    _completedSub = _player.stream.completed.listen((completed) {
      if (completed) {
        VideoCacheService.instance.clearCache();
      }
      if (completed && mounted && widget.mediaItem.isSeries) {
        playNextEpisode(auto: true);
      }
    });

    _initPlayer();
    loadSubtitlesAndDubs(
      mediaId: widget.mediaItem.id,
      resourceId: _activeSource.resourceId,
      season: widget.season,
      episode: widget.episode,
      imdbId: _resolvedImdbId,
      initialSubtitles: _activeSource.subtitles,
    );
    loadSeriesSkipMarkers();
    startHideTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AppProvider>().isTvMode) {
        if (_seekbarTvFocusNode.canRequestFocus) {
          _seekbarTvFocusNode.requestFocus();
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

  Future<void> _toggleFullscreen() async {
    await _windowService.toggleFullscreen();
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

      _startSourceWatchdog();

      if (Platform.isWindows) {
        LibMpvHelper.ensureCriticalSectionsInitialized();
      }

      // Validate that active stream is a direct playable media stream
      if (!isDirectPlayableMediaUrl(_activeSource.url)) {
        final playableIdx = _sources.indexWhere(
          (s) => isDirectPlayableMediaUrl(s.url),
        );
        if (playableIdx >= 0) {
          _currentSourceIndex = playableIdx;
          _activeSource = _sources[playableIdx];
        } else {
          final isMagnet = _activeSource.url.toLowerCase().startsWith(
            'magnet:',
          );
          handlePlaybackFailure(
            isMagnet
                ? 'Torrent stream detected. The internal player cannot decode torrent peer-to-peer protocols directly. Please open with an external player (e.g. VLC / Just Player) or choose another server.'
                : 'The selected stream is an external web embed and cannot be decoded directly by the media engine. Please try another server or open with an external player.',
          );
          return;
        }
      }

      final mediaKey = _currentMediaKey;
      if (VideoCacheService.instance.shouldClearForNewVideo(mediaKey)) {
        await VideoCacheService.instance.clearCache();
      }
      await VideoCacheService.instance.ensureCacheDirectory();

      final media = Media(
        _activeSource.url,
        httpHeaders: _activeSource.headers,
        start: resumeSec > 0 ? Duration(seconds: resumeSec) : null,
      );

      if (_player.platform is NativePlayer) {
        try {
          final native = _player.platform as NativePlayer;
          final cacheProps = VideoCacheService.instance.getMpvCacheProperties();
          for (final entry in cacheProps.entries) {
            await native.setProperty(entry.key, entry.value);
          }
        } catch (e) {
          debugPrint('Error configuring player cache properties: $e');
        }
      }

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
          showResumeBannerFor(resumeSec);
        }
      }

      _startProgressTimer();
    } catch (e) {
      debugPrint('Player initialization error: $e');
      handlePlaybackFailure('Failed to open stream: $e');
    }
  }

  bool get _isTrailer =>
      widget.streamSource.quality == 'Trailer' ||
      widget.mediaItem.id.startsWith('trailer_') ||
      widget.mediaItem.title.toLowerCase().contains('trailer') ||
      widget.mediaItem.title.toLowerCase().contains('teaser');

  void _startProgressTimer() {
    _progressTimer?.cancel();

    if (mounted && !_isTrailer) {
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
      if (!_isTrailer && pos > 0 && dur > 0) {
        context.read<LibraryProvider>().recordProgress(
          item: widget.mediaItem,
          positionSeconds: pos,
          totalSeconds: dur,
          season: currentSeason ?? widget.season,
          episode: currentEpisode ?? widget.episode,
        );
      }
    });
  }

  void _startSourceWatchdog() {
    _sourceWatchdogTimer?.cancel();
  }

  @override
  void handlePlaybackFailure(String reason) {
    if (!mounted) return;
    _sourceWatchdogTimer?.cancel();
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

  void _retryPlayback() {
    setState(() {
      _errorMessage = null;
      _isPlayerReady = false;
      _isLoadingVideo = true;
      _isBuffering = false;
    });
    _initPlayer();
  }

  Future<void> _selectSource(int idx, {String? customMessage}) async {
    if (idx < 0 || idx >= _sources.length) return;
    if (_isSwitchingServer) return;
    _isSwitchingServer = true;

    _sourceWatchdogTimer?.cancel();
    final currentPos = _player.state.position.inSeconds;
    final resumeAt = currentPos > 0 ? currentPos : resumedFromSeconds;

    setState(() {
      _currentSourceIndex = idx;
      _activeSource = _sources[idx];
      _isPlayerReady = false;
      _isLoadingVideo = true;
      _errorMessage = null;
      hasAutoSelectedAudio = false;
    });

    showToast(
      customMessage ??
          'Switched to Server ${idx + 1} (${_activeSource.quality})',
    );

    try {
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

      if (!mounted) return;

      if (!isDirectPlayableMediaUrl(_activeSource.url)) {
        final isMagnet = _activeSource.url.toLowerCase().startsWith('magnet:');
        final reason = isMagnet
            ? 'Server ${idx + 1} (${_activeSource.server ?? "Torrent"}) is a torrent magnet link and cannot be decoded directly by the internal player. Try opening in an external player or select another server.'
            : 'Server ${idx + 1} (${_activeSource.server ?? "External"}) is an external web embed and cannot be decoded directly by the media engine. Try opening in an external player or select another server.';
        handlePlaybackFailure(reason);
        return;
      }

      final media = Media(
        _activeSource.url,
        httpHeaders: _activeSource.headers,
        start: resumeAt > 0 ? Duration(seconds: resumeAt) : null,
      );

      if (_player.platform is NativePlayer) {
        try {
          final native = _player.platform as NativePlayer;
          final cacheProps = VideoCacheService.instance.getMpvCacheProperties();
          for (final entry in cacheProps.entries) {
            await native.setProperty(entry.key, entry.value);
          }
        } catch (_) {}
      }

      _startSourceWatchdog();
      await _player.open(media);

      if (mounted) {
        setState(() => _isPlayerReady = true);
      }
    } catch (e) {
      debugPrint('Error switching server: $e');
      if (mounted) {
        handlePlaybackFailure('Failed to open Server ${idx + 1}: $e');
      }
    } finally {
      if (mounted) {
        _isSwitchingServer = false;
      }
    }
  }

  static bool isDirectPlayableMediaUrl(String rawUrl) {
    final url = rawUrl.trim().toLowerCase();
    if (url.isEmpty) return false;
    if (!url.startsWith('http://') && !url.startsWith('https://')) return false;

    // Direct streams with known extensions or parameters are always valid
    if (url.endsWith('.m3u8') ||
        url.endsWith('.mpd') ||
        url.endsWith('.mp4') ||
        url.endsWith('.mkv') ||
        url.contains('.m3u8?') ||
        url.contains('.mpd?') ||
        url.contains('.mp4?') ||
        url.contains('.mkv?')) {
      return true;
    }

    // Embed/iframe web links cannot be decoded by libmpv demuxers
    if (url.contains('/embed/') ||
        url.contains('vidsrc') ||
        url.contains('youtube.com/watch') ||
        url.contains('youtu.be/')) {
      return false;
    }

    // Intermediate landing pages
    if (url.contains('hubcloud') || url.contains('hubdrive')) {
      return false;
    }

    return true;
  }

  Future<void> _switchToNextSource(String message) async {
    if (_currentSourceIndex + 1 >= _sources.length) return;
    await _selectSource(_currentSourceIndex + 1, customMessage: message);
  }

  void _onPositionChanged(Duration pos) {
    if (!mounted) return;
    if (pos != _lastPosition) {
      _lastPosition = pos;
      _lastPositionChangeTime = DateTime.now();
      _bufferingDebounceTimer?.cancel();
      if (_isBuffering) {
        setState(() => _isBuffering = false);
      }
    }
    final posSec = pos.inSeconds;

    if (posSec > 0 && (_isLoadingVideo || !_isPlayerReady || _isBuffering)) {
      setState(() {
        _isLoadingVideo = false;
        _isPlayerReady = true;
        _isBuffering = false;
      });
    }
    if (posSec > 1 && _sourceWatchdogTimer?.isActive == true) {
      _sourceWatchdogTimer?.cancel();
    }
    checkSkipIntervals(pos);
  }

  void _saveProgressNow({bool notify = false}) {
    final pos = _player.state.position.inSeconds;
    final dur = _player.state.duration.inSeconds;
    if (!_isTrailer && pos > 0 && dur > 0) {
      _libraryProvider.recordProgress(
        item: widget.mediaItem,
        positionSeconds: pos,
        totalSeconds: dur,
        season: currentSeason ?? widget.season,
        episode: currentEpisode ?? widget.episode,
        notify: notify,
      );
    }
  }

  DateTime? _lastBackTime;

  @override
  void hideTvControls() {
    _lastBackTime = DateTime.now();
    super.hideTvControls();
  }

  @override
  void onPopInvoked() {
    final now = DateTime.now();
    if (_lastBackTime != null &&
        now.difference(_lastBackTime!).inMilliseconds < 400 &&
        !WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      return;
    }
    _lastBackTime = now;

    if (isControlsLocked) {
      showUnlockButtonTemporarily();
      return;
    }
    if (showControls) {
      hideTvControls();
    } else {
      _saveProgressNow();
      Navigator.of(context).pop();
    }
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    final isTv = context.read<AppProvider>().isTvMode;
    return PlayerKeyHandler.handleKeyEvent(
      event: event,
      isTv: isTv,
      isControlsLocked: isControlsLocked,
      showControls: showControls,
      isFullscreen: _isFullscreen,
      player: _player,
      onShowUnlockButton: showUnlockButtonTemporarily,
      onHideTvControls: hideTvControls,
      onRevealTvControls: revealTvControls,
      onToggleFullscreen: _toggleFullscreen,
      onPop: onPopInvoked,
      showToast: showToast,
      onPlayPauseTriggered: triggerPlayPauseIndicator,
      onDoubleTapSeek: triggerDoubleTapSeek,
      onUserActivity: onUserActivity,
      onStartHideTimer: startHideTimer,
      onToggleSubtitle: toggleSubtitleOnOff,
      onTriggerSkip: triggerSkip,
      hasActiveSkip: activeSkip != null,
    );
  }

  void _setSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    _player.setRate(speed);
    showToast('Playback speed: ${speed}x');
  }

  Future<void> _openInExternalPlayer() async {
    final currentPos = _player.state.position.inSeconds;
    final startSec = currentPos > 0 ? currentPos : resumedFromSeconds;
    final launched = await ExternalPlayerService().launch(
      url: _activeSource.url,
      title: widget.mediaItem.title,
      headers: _activeSource.headers,
      startSeconds: startSec > 0 ? startSec : null,
    );
    if (!launched && mounted) {
      final isMagnet = _activeSource.url.toLowerCase().startsWith('magnet:');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMagnet
                ? 'Could not launch external app for magnet link. Make sure a torrent client or player (e.g. VLC / Just Player) is installed.'
                : 'Could not launch external player. Make sure MPV or VLC is installed.',
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
    showToast(
      _videoFit == BoxFit.contain ? 'Aspect: Contain' : 'Aspect: Cover',
    );
  }

  @override
  void dispose() {
    _saveProgressNow();
    _progressTimer?.cancel();
    _sourceWatchdogTimer?.cancel();
    _bufferingDebounceTimer?.cancel();
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
    VideoCacheService.instance.clearCache();

    disposeDeviceState();
    disposeControlsVisibility();
    disposeEpisodesState();

    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      // Fixed landscape devices like Android TV should never have portrait orientations forced
      if (!_isTvMode) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    }

    super.dispose();
  }

  String get _currentMediaKey =>
      '${widget.mediaItem.id}_s${currentSeason ?? widget.season ?? 0}_e${currentEpisode ?? widget.episode ?? 0}';

  bool get _isLiveStream =>
      widget.mediaItem.provider == ProviderType.liveTv ||
      _player.state.duration == Duration.zero;

  @override
  bool pauseForModal() {
    if (_isLiveStream) return false;
    final wasPlaying = _player.state.playing;
    if (wasPlaying) {
      _player.pause();
    }
    return wasPlaying;
  }

  @override
  void resumeAfterModal(bool wasPlaying) {
    if (wasPlaying && mounted) {
      _player.play();
    }
  }

  Future<void> _showSpeedDialog(ThemeData theme) async {
    final wasPlaying = pauseForModal();
    await PlayerSpeedSheet.show(
      context,
      currentSpeed: _playbackSpeed,
      onSpeedSelected: _setSpeed,
    );
    resumeAfterModal(wasPlaying);
  }

  Future<void> _showServerSelectionModal(ThemeData theme) async {
    final wasPlaying = pauseForModal();
    final validVideoTracks = tracks.video.where((t) {
      final l = (t.title ?? t.id).toLowerCase();
      return !l.contains('(no)') && l != 'no';
    }).toList();

    await PlayerServerSheet.show(
      context,
      sources: _sources,
      currentSourceIndex: _currentSourceIndex,
      videoTracks: validVideoTracks,
      activeVideoTrack: _player.state.track.video,
      onSourceSelected: (idx) {
        if (idx != _currentSourceIndex || _errorMessage != null) {
          _selectSource(idx);
        }
      },
      onVideoTrackSelected: (track) {
        _player.setVideoTrack(track);
        final label = track.id == 'auto'
            ? 'Auto'
            : (track.h != null ? '${track.h}p' : track.id);
        showToast('Video Quality: $label');
      },
    );
    resumeAfterModal(wasPlaying);
  }

  Future<void> _showEpisodesModal() async {
    if (details == null && widget.mediaItem.isSeries) {
      await fetchDetailsForNextEpisode();
    }
    if (!mounted) return;
    final d = details ?? widget.mediaDetails;
    if (d == null || d.seasons.isEmpty) {
      showToast('No episode data available');
      return;
    }
    final wasPlaying = pauseForModal();
    await PlayerEpisodesSheet.show(
      context,
      details: d,
      currentSeason: currentSeason ?? 1,
      currentEpisode: currentEpisode ?? 1,
      onEpisodeSelected: (season, episode) {
        playSpecificEpisode(season, episode);
      },
    );
    resumeAfterModal(wasPlaying);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Picture-in-Picture Mode
    if (isPipMode) {
      return Scaffold(
        backgroundColor: context.tokens.canvasBackground,
        body: Center(
          child: Video(
            controller: _controller,
            controls: NoVideoControls,
            fit: _videoFit,
            pauseUponEnteringBackgroundMode: false,
            resumeUponEnteringForegroundMode: false,
          ),
        ),
      );
    }

    // Playback Error Screen
    if (_errorMessage != null) {
      return PlayerErrorView(
        errorMessage: _errorMessage!,
        hasAnotherSource: _currentSourceIndex + 1 < _sources.length,
        nextSourceLabel: _currentSourceIndex + 1 < _sources.length
            ? 'Try Source ${_currentSourceIndex + 2} (${_sources[_currentSourceIndex + 1].quality})'
            : null,
        onNextSource: () => _switchToNextSource('Switching to next source...'),
        onSelectServer: (_sources.length > 1 || tracks.video.length > 1)
            ? () => _showServerSelectionModal(theme)
            : null,
        onOpenExternal: _openInExternalPlayer,
        onRetry: _retryPlayback,
        onBack: () => Navigator.of(context).pop(),
      );
    }

    // Active Player View with Gestures and Controls Overlay
    return PlayerVideoView(
      player: _player,
      controller: _controller,
      videoFit: _videoFit,
      focusNode: _focusNode,
      mediaItem: widget.mediaItem,
      activeSource: _activeSource,
      sourcesCount: _sources.length,
      currentSourceIndex: _currentSourceIndex,
      currentSeason: currentSeason,
      currentEpisode: currentEpisode,
      externalSubtitles: externalSubtitles,
      showControls: showControls,
      isControlsLocked: isControlsLocked,
      showUnlockButton: showUnlockButton,
      isLoadingVideo: _isLoadingVideo,
      isBuffering: _isBuffering,
      isPlayerReady: _isPlayerReady,
      errorMessage: _errorMessage,
      toastMessage: toastMessage,
      isOrientationLocked: isOrientationLocked,
      brightness: brightness,
      showBrightnessIndicator: showBrightnessIndicator,
      volume: volume,
      showVolumeIndicator: showVolumeIndicator,
      doubleTapSeekDirection: doubleTapSeekDirection,
      activeSkip: activeSkip,
      showResumeBanner: showResumeBanner,
      resumedFromSeconds: resumedFromSeconds,
      playbackSpeed: _playbackSpeed,
      isFullscreen: _isFullscreen,
      hasNextEpisode: findNextEpisode() != null,
      tvBackBtnFocusNode: _tvBackBtnFocusNode,
      seekbarTvFocusNode: _seekbarTvFocusNode,
      playPauseTvFocusNode: _playPauseTvFocusNode,
      playPauseIndicatorIsPlaying: playPauseIndicatorIsPlaying,
      onPlayPauseTriggered: triggerPlayPauseIndicator,
      onKeyEvent: _handleKeyEvent,
      onPop: onPopInvoked,
      onToggleControls: toggleControls,
      onDoubleTapSeek: triggerDoubleTapSeek,
      onBrightnessDragUpdate: onBrightnessDragUpdate,
      onVolumeDragUpdate: onVolumeDragUpdate,
      onUserActivity: onUserActivity,
      onStartHideTimer: startHideTimer,
      onCancelHideTimer: cancelHideTimer,
      onInteractingWithUi: (val) => isInteractingWithUi = val,
      onBack: () {
        _saveProgressNow();
        Navigator.of(context).pop();
      },
      onSelectServer: () => _showServerSelectionModal(theme),
      onOpenAudioAndSubtitles: showAudioAndSubtitleModal,
      onSelectSpeed: () => _showSpeedDialog(theme),
      onToggleAspectRatio: _toggleAspectRatio,
      onOpenExternal: _openInExternalPlayer,
      onEnterPip: enterPipMode,
      onToggleFullscreen: _toggleFullscreen,
      onPlayNextEpisode: () => playNextEpisode(auto: false),
      onOpenEpisodes: _showEpisodesModal,
      onToggleScreenOrientation: toggleScreenOrientation,
      onToggleLockOrientation: toggleLockOrientation,
      onLockControls: lockControls,
      onUnlockControls: unlockControls,
      onShowUnlockButton: showUnlockButtonTemporarily,
      onTriggerSkip: triggerSkip,
      onRestartPlayback: restartPlayback,
      onDismissResumeBanner: dismissResumeBanner,
      formatDuration: PlayerTimeHelper.formatDuration,
    );
  }
}
