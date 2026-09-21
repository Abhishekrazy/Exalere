import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../models/stream_source.dart';
import '../../providers/app_provider.dart';
import '../../services/direct_stream_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/tv_focusable.dart';
import 'player_screen.dart';

/// A direct URL stream player and video downloader screen.
///
/// Fully optimized for Android TV (10-foot D-Pad remote navigation),
/// Windows desktop, and mobile form factors.
class DirectStreamScreen extends StatefulWidget {
  final VoidCallback? onExitToSidebar;

  const DirectStreamScreen({super.key, this.onExitToSidebar});

  @override
  State<DirectStreamScreen> createState() => _DirectStreamScreenState();
}

class _DirectStreamScreenState extends State<DirectStreamScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  final FocusNode _urlFocusNode = FocusNode(debugLabel: 'DirectStream_Url');
  final FocusNode _pasteBtnFocusNode = FocusNode(
    debugLabel: 'DirectStream_Paste',
  );
  final FocusNode _clearBtnFocusNode = FocusNode(
    debugLabel: 'DirectStream_Clear',
  );
  final FocusNode _titleFocusNode = FocusNode(debugLabel: 'DirectStream_Title');
  final FocusNode _playBtnFocusNode = FocusNode(
    debugLabel: 'DirectStream_Play',
  );
  final FocusNode _downloadBtnFocusNode = FocusNode(
    debugLabel: 'DirectStream_Download',
  );

  List<RecentStreamUrl> _recentUrls = [];
  List<DownloadedVideoFile> _downloadedFiles = [];

  @override
  void initState() {
    super.initState();
    _refreshData();
    DirectStreamService.instance.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (!mounted) return;
    setState(() {});
    _loadDownloadedFiles();
  }

  Future<void> _refreshData() async {
    await Future.wait([_loadRecentUrls(), _loadDownloadedFiles()]);
  }

  Future<void> _loadRecentUrls() async {
    final list = await DirectStreamService.instance.getRecentUrls();
    if (mounted) {
      setState(() => _recentUrls = list);
    }
  }

  Future<void> _loadDownloadedFiles() async {
    final files = await DirectStreamService.instance.getDownloadedFiles();
    if (mounted) {
      setState(() => _downloadedFiles = files);
    }
  }

  @override
  void dispose() {
    DirectStreamService.instance.removeListener(_onServiceUpdate);
    _urlController.dispose();
    _titleController.dispose();
    _urlFocusNode.dispose();
    _pasteBtnFocusNode.dispose();
    _clearBtnFocusNode.dispose();
    _titleFocusNode.dispose();
    _playBtnFocusNode.dispose();
    _downloadBtnFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      final text = data.text!.trim();
      setState(() {
        _urlController.text = text;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pasted URL from clipboard'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Clipboard is empty or contains non-text data'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool _validateUrl(String url) {
    if (url.trim().isEmpty) {
      _showToast('Please enter or paste a valid stream URL');
      return false;
    }
    final lower = url.trim().toLowerCase();
    if (!lower.startsWith('http://') &&
        !lower.startsWith('https://') &&
        !lower.startsWith('rtsp://') &&
        !lower.startsWith('file://') &&
        !lower.startsWith('/')) {
      _showToast('URL must begin with http://, https://, or rtsp://');
      return false;
    }
    return true;
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _playStream({String? overrideUrl, String? overrideTitle}) {
    final rawUrl = overrideUrl ?? _urlController.text;
    if (!_validateUrl(rawUrl)) return;

    final url = rawUrl.trim();
    final title = overrideTitle ?? _titleController.text.trim();

    DirectStreamService.instance.recordRecentUrl(
      url: url,
      title: title.isNotEmpty ? title : null,
    );

    final mediaItem = DirectStreamService.instance.createMediaItem(
      url,
      title.isNotEmpty ? title : null,
    );
    final streamSource = DirectStreamService.instance.createStreamSource(url);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          mediaItem: mediaItem,
          streamSource: streamSource,
          availableSources: [streamSource],
        ),
      ),
    );
  }

  void _playLocalFile(DownloadedVideoFile file) {
    final mediaItem = MediaItem(
      id: 'local_${file.path.hashCode.abs()}',
      title: file.fileName,
      mediaType: MediaType.movie,
      posterUrl: '',
      year: file.modifiedAt.year.toString(),
      genre: 'Downloaded Video',
    );

    final streamSource = StreamSource(
      quality: 'Offline Download',
      resolution: 'Local',
      format: file.fileName.endsWith('.m3u8') ? 'HLS' : 'MP4',
      url: file.path,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          mediaItem: mediaItem,
          streamSource: streamSource,
          availableSources: [streamSource],
        ),
      ),
    );
  }

  Future<void> _startDownload() async {
    final rawUrl = _urlController.text;
    if (!_validateUrl(rawUrl)) return;

    final url = rawUrl.trim();
    final title = _titleController.text.trim();

    DirectStreamService.instance.recordRecentUrl(
      url: url,
      title: title.isNotEmpty ? title : null,
    );

    try {
      await DirectStreamService.instance.startDownload(
        url: url,
        title: title.isNotEmpty ? title : null,
      );
      _showToast('Video download started in background');
    } catch (e) {
      _showToast('Failed to start download: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final isTv = context.watch<AppProvider>().isTvMode;
    final allTasks = DirectStreamService.instance.tasks;

    return Scaffold(
      backgroundColor: tokens.canvasBackground,
      body: SafeArea(
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isTv ? 32 : 18,
              vertical: isTv ? 24 : 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(tokens, isTv),
                const SizedBox(height: 20),

                // Main Input Card
                _buildInputCard(theme, tokens, isTv),
                const SizedBox(height: 24),

                // Active Downloads Section
                if (allTasks.isNotEmpty) ...[
                  _buildActiveDownloadsSection(theme, tokens, isTv, allTasks),
                  const SizedBox(height: 24),
                ],

                // Downloaded Offline Videos Shelf
                if (_downloadedFiles.isNotEmpty) ...[
                  _buildDownloadedVideosSection(theme, tokens, isTv),
                  const SizedBox(height: 24),
                ],

                // Recent Stream URLs Shelf
                if (_recentUrls.isNotEmpty) ...[
                  _buildRecentUrlsSection(theme, tokens, isTv),
                  const SizedBox(height: 32),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppTokens tokens, bool isTv) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: tokens.getShapeDecoration(
            color: tokens.primaryAccent.withValues(alpha: 0.20),
            radius: (tokens.cardRadius * 0.4).clamp(4.0, 10.0),
            side: BorderSide(
              color: tokens.primaryAccent.withValues(alpha: 0.4),
              width: 1.0,
            ),
          ),
          child: Icon(
            Icons.link_rounded,
            color: tokens.textPrimary,
            size: isTv ? 24 : 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Direct Stream & Downloader',
                style: TextStyle(
                  fontSize: isTv ? 22 : 19,
                  fontWeight: FontWeight.w900,
                  color: tokens.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Stream or download videos directly from any HTTP, HLS, or direct media URL',
                style: TextStyle(
                  fontSize: isTv ? 12 : 11.5,
                  color: tokens.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard(ThemeData theme, AppTokens tokens, bool isTv) {
    return Container(
      padding: EdgeInsets.all(isTv ? 20 : 16),
      decoration: tokens.getShapeDecoration(
        color: tokens.surfaceCard,
        radius: tokens.cardRadius,
        side: BorderSide(color: tokens.borderSubtle, width: 1.0),
        shadows: tokens.getCardShadows(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // URL label & Paste shortcut
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STREAM / VIDEO URL',
                style: TextStyle(
                  fontSize: isTv ? 11.5 : 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: tokens.textSecondary,
                ),
              ),
              TvFocusable(
                focusNode: _pasteBtnFocusNode,
                scaleFactor: 1.06,
                borderRadius: tokens.borderRadiusSm,
                onTap: _pasteFromClipboard,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: tokens.getShapeDecoration(
                    color: tokens.surfaceElevated,
                    radius: tokens.borderRadiusSm.topLeft.x,
                    side: BorderSide(color: tokens.borderSubtle, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.content_paste_rounded,
                        color: tokens.textPrimary,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Paste URL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // URL Text Field
          Container(
            decoration: BoxDecoration(
              color: tokens.surfaceElevated,
              borderRadius: tokens.borderRadiusSm,
              border: Border.all(
                color: _urlFocusNode.hasFocus
                    ? tokens.primaryAccent
                    : tokens.borderSubtle,
                width: _urlFocusNode.hasFocus ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  Icons.link_rounded,
                  color: _urlFocusNode.hasFocus
                      ? tokens.primaryAccent
                      : tokens.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    focusNode: _urlFocusNode,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: isTv ? 13 : 13.5,
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'https://example.com/video.mp4 or .m3u8',
                      hintStyle: TextStyle(
                        color: tokens.textMuted,
                        fontSize: isTv ? 13 : 13.5,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_playBtnFocusNode);
                    },
                  ),
                ),
                if (_urlController.text.isNotEmpty)
                  TvFocusable(
                    focusNode: _clearBtnFocusNode,
                    scaleFactor: 1.1,
                    onTap: () {
                      setState(() {
                        _urlController.clear();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.close_rounded,
                        color: tokens.textSecondary,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Optional Title Field
          Text(
            'CUSTOM TITLE (OPTIONAL)',
            style: TextStyle(
              fontSize: isTv ? 11.5 : 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: tokens.surfaceElevated,
              borderRadius: tokens.borderRadiusSm,
              border: Border.all(
                color: _titleFocusNode.hasFocus
                    ? tokens.primaryAccent
                    : tokens.borderSubtle,
                width: _titleFocusNode.hasFocus ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  Icons.title_rounded,
                  color: _titleFocusNode.hasFocus
                      ? tokens.primaryAccent
                      : tokens.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: isTv ? 13 : 13.5,
                    ),
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'e.g. My Favorite Movie / Episode 1',
                      hintStyle: TextStyle(
                        color: tokens.textMuted,
                        fontSize: isTv ? 13 : 13.5,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_playBtnFocusNode);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons: Play Now & Download
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TvFocusable(
                  focusNode: _playBtnFocusNode,
                  autofocus: true,
                  scaleFactor: 1.04,
                  borderRadius: tokens.borderRadiusSm,
                  onTap: () => _playStream(),
                  child: Container(
                    height: isTv ? 46 : 48,
                    alignment: Alignment.center,
                    decoration: tokens.getShapeDecoration(
                      color: tokens.primaryAccent,
                      radius: tokens.borderRadiusSm.topLeft.x,
                      shadows: [
                        BoxShadow(
                          color: tokens.primaryAccent.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: theme.colorScheme.onPrimary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Play Now',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: isTv ? 14 : 14.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TvFocusable(
                  focusNode: _downloadBtnFocusNode,
                  scaleFactor: 1.04,
                  borderRadius: tokens.borderRadiusSm,
                  onTap: _startDownload,
                  child: Container(
                    height: isTv ? 46 : 48,
                    alignment: Alignment.center,
                    decoration: tokens.getShapeDecoration(
                      color: tokens.surfaceElevated,
                      radius: tokens.borderRadiusSm.topLeft.x,
                      side: BorderSide(
                        color: tokens.primaryAccent.withValues(alpha: 0.5),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.download_rounded,
                          color: tokens.textPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Download',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: isTv ? 13 : 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDownloadsSection(
    ThemeData theme,
    AppTokens tokens,
    bool isTv,
    List<VideoDownloadTask> tasks,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.downloading_rounded,
              color: tokens.primaryAccent,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Downloads & Tasks',
              style: TextStyle(
                fontSize: isTv ? 16 : 15,
                fontWeight: FontWeight.bold,
                color: tokens.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final task = tasks[index];
            return _buildTaskCard(theme, tokens, isTv, task);
          },
        ),
      ],
    );
  }

  Widget _buildTaskCard(
    ThemeData theme,
    AppTokens tokens,
    bool isTv,
    VideoDownloadTask task,
  ) {
    final isDownloading = task.status == DownloadTaskStatus.downloading;
    final isCompleted = task.status == DownloadTaskStatus.completed;
    final isFailed = task.status == DownloadTaskStatus.failed;
    final isCancelled = task.status == DownloadTaskStatus.cancelled;

    Color statusColor = tokens.primaryAccent;
    String statusLabel = 'Downloading';
    if (isCompleted) {
      statusColor = tokens.secondaryAccent;
      statusLabel = 'Completed';
    } else if (isFailed) {
      statusColor = tokens.vipColor;
      statusLabel = 'Failed';
    } else if (isCancelled) {
      statusColor = tokens.textMuted;
      statusLabel = 'Cancelled';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: tokens.getShapeDecoration(
        color: tokens.surfaceCard,
        radius: tokens.borderRadiusSm.topLeft.x,
        side: BorderSide(
          color: isDownloading
              ? tokens.primaryAccent.withValues(alpha: 0.4)
              : tokens.borderSubtle,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: isTv ? 13 : 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: isTv ? 11 : 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: tokens.borderRadiusSm,
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              if (isDownloading) ...[
                const SizedBox(width: 8),
                TvFocusable(
                  scaleFactor: 1.1,
                  borderRadius: tokens.borderRadiusSm,
                  onTap: () =>
                      DirectStreamService.instance.cancelDownload(task.id),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.cancel_rounded,
                      color: tokens.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ],
              if (isCompleted) ...[
                const SizedBox(width: 8),
                TvFocusable(
                  scaleFactor: 1.08,
                  borderRadius: tokens.borderRadiusSm,
                  onTap: () => _playStream(
                    overrideUrl: task.filePath,
                    overrideTitle: task.title,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.primaryAccent,
                      borderRadius: tokens.borderRadiusSm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: theme.colorScheme.onPrimary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Play',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task.progress > 0 ? task.progress : null,
                backgroundColor: tokens.surfaceElevated,
                valueColor: AlwaysStoppedAnimation<Color>(tokens.primaryAccent),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${task.formattedProgress} • ${task.formattedSize}',
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  task.formattedSpeed,
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadedVideosSection(
    ThemeData theme,
    AppTokens tokens,
    bool isTv,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.folder_rounded, color: tokens.textPrimary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Downloaded Videos (${_downloadedFiles.length})',
              style: TextStyle(
                fontSize: isTv ? 16 : 15,
                fontWeight: FontWeight.bold,
                color: tokens.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _downloadedFiles.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final file = _downloadedFiles[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: tokens.getShapeDecoration(
                color: tokens.surfaceCard,
                radius: tokens.borderRadiusSm.topLeft.x,
                side: BorderSide(color: tokens.borderSubtle, width: 0.8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.movie_rounded,
                    color: tokens.textPrimary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: isTv ? 13 : 13.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          file.formattedSize,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: isTv ? 11 : 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  TvFocusable(
                    scaleFactor: 1.08,
                    borderRadius: tokens.borderRadiusSm,
                    onTap: () => _playLocalFile(file),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.primaryAccent,
                        borderRadius: tokens.borderRadiusSm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: theme.colorScheme.onPrimary,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Play',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TvFocusable(
                    scaleFactor: 1.1,
                    borderRadius: tokens.borderRadiusSm,
                    onTap: () async {
                      await DirectStreamService.instance.deleteDownloadedFile(
                        file.path,
                      );
                      _loadDownloadedFiles();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: tokens.textMuted,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentUrlsSection(ThemeData theme, AppTokens tokens, bool isTv) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  color: tokens.textPrimary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent URLs',
                  style: TextStyle(
                    fontSize: isTv ? 16 : 15,
                    fontWeight: FontWeight.bold,
                    color: tokens.textPrimary,
                  ),
                ),
              ],
            ),
            TvFocusable(
              scaleFactor: 1.08,
              borderRadius: tokens.borderRadiusSm,
              onTap: () async {
                await DirectStreamService.instance.clearRecentUrls();
                _loadRecentUrls();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentUrls.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = _recentUrls[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: tokens.getShapeDecoration(
                color: tokens.surfaceCard,
                radius: tokens.borderRadiusSm.topLeft.x,
                side: BorderSide(color: tokens.borderSubtle, width: 0.8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TvFocusable(
                      scaleFactor: 1.02,
                      borderRadius: tokens.borderRadiusSm,
                      onTap: () {
                        setState(() {
                          _urlController.text = item.url;
                          _titleController.text = item.title;
                        });
                        FocusScope.of(context).requestFocus(_playBtnFocusNode);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: isTv ? 13 : 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: isTv ? 11 : 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TvFocusable(
                    scaleFactor: 1.08,
                    borderRadius: tokens.borderRadiusSm,
                    onTap: () => _playStream(
                      overrideUrl: item.url,
                      overrideTitle: item.title,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: tokens.primaryAccent.withValues(alpha: 0.15),
                        borderRadius: tokens.borderRadiusSm,
                        border: Border.all(
                          color: tokens.primaryAccent.withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: tokens.textPrimary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TvFocusable(
                    scaleFactor: 1.1,
                    borderRadius: tokens.borderRadiusSm,
                    onTap: () async {
                      await DirectStreamService.instance.removeRecentUrl(
                        item.url,
                      );
                      _loadRecentUrls();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.close_rounded,
                        color: tokens.textMuted,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
