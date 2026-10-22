import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/stream_source.dart';
import '../../providers/app_provider.dart';
import '../../services/direct_stream_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/downloads/download_task_card.dart';
import '../widgets/tv/tv_popup_scope.dart';
import '../widgets/tv_focusable.dart';
import 'player_screen.dart';

/// Downloads hub: everything in flight, plus everything already on disk.
///
/// The previous per-screen lists showed an icon and a percentage, which makes it
/// hard to answer the two questions a download list exists to answer: *what am I
/// downloading*, and *what file do I actually have*. So every row names the
/// show/movie, the episode and quality, and the file itself.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key, this.onExitToSidebar, this.fileLoader});

  final VoidCallback? onExitToSidebar;

  /// Overrides the on-device file scan. The real scan depends on a platform
  /// plugin, so tests inject their own listing to reach the empty and populated
  /// states deterministically.
  final Future<List<DownloadedVideoFile>> Function()? fileLoader;

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final DirectStreamService _service = DirectStreamService.instance;

  List<DownloadedVideoFile> _downloadedFiles = [];
  bool _isLoadingFiles = true;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
    _loadDownloadedFiles();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (!mounted) return;
    setState(() {});
    // A task finishing writes a file, so the disk listing must be re-read.
    _loadDownloadedFiles();
  }

  Future<void> _loadDownloadedFiles() async {
    final loader = widget.fileLoader;
    final files = loader != null
        ? await loader()
        : await _service.getDownloadedFiles();
    if (!mounted) return;
    setState(() {
      _downloadedFiles = files;
      _isLoadingFiles = false;
    });
  }

  void _playFile(String path, String label) {
    final mediaItem = _service.createMediaItem(path, label);
    final source = StreamSource(
      quality: 'Offline',
      resolution: '1080p',
      format: 'MP4',
      url: path,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          mediaItem: mediaItem,
          streamSource: source,
          availableSources: [source],
        ),
      ),
    );
  }

  Future<void> _exportFile(String path) async {
    final result = await _service.exportDownloadedFile(path);
    if (!mounted) return;
    if (result != null) {
      _toast('Exported to $result');
    }
  }

  Future<void> _confirmDelete(String path, String label) async {
    final tokens = context.tokens;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => TvPopupScope(
        child: AlertDialog(
          backgroundColor: tokens.surfaceElevated,
          title: Text(
            'Delete download?',
            style: TextStyle(color: tokens.textPrimary, fontSize: 16),
          ),
          content: Text(
            '"$label" will be removed from this device.',
            style: TextStyle(color: tokens.textSecondary, fontSize: 13),
          ),
          actions: [
            // Exactly one autofocus, and it is on the safe choice.
            TvFocusable(
              autofocus: true,
              borderRadius: tokens.borderRadiusSm,
              onTap: () => Navigator.of(ctx).pop(false),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                ),
              ),
            ),
            TvFocusable(
              borderRadius: tokens.borderRadiusSm,
              onTap: () => Navigator.of(ctx).pop(true),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Text(
                  'Delete',
                  style: TextStyle(
                    color: tokens.errorColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final deleted = await _service.deleteDownloadedFile(path);
    if (!mounted) return;
    if (deleted) {
      _toast('Deleted');
      await _loadDownloadedFiles();
    } else {
      _toast('Could not delete that file');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.tokens.surfaceElevated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isTv = context.watch<AppProvider>().isTvMode;

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
                _buildHeader(tokens, isTv),
                const SizedBox(height: 18),
                ..._buildBody(tokens, isTv),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppTokens tokens, bool isTv) {
    final active = _activeTasks.length;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Downloads',
                style: TextStyle(
                  fontSize: isTv ? 24 : 20,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                active > 0
                    ? '$active active · ${_downloadedFiles.length} on device'
                    : '${_downloadedFiles.length} on device',
                style: TextStyle(fontSize: 12, color: tokens.textMuted),
              ),
            ],
          ),
        ),
        TvFocusable(
          borderRadius: tokens.borderRadiusSm,
          onTap: _loadDownloadedFiles,
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: tokens.surfaceCard,
              borderRadius: tokens.borderRadiusSm,
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: tokens.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  List<VideoDownloadTask> get _activeTasks => _service.tasks
      .where(
        (t) =>
            t.status == DownloadTaskStatus.downloading ||
            t.status == DownloadTaskStatus.queued ||
            t.status == DownloadTaskStatus.paused ||
            t.status == DownloadTaskStatus.failed,
      )
      .toList();

  List<VideoDownloadTask> get _completedTasks => _service.tasks
      .where((t) => t.status == DownloadTaskStatus.completed)
      .toList();

  /// Files on disk that no completed task accounts for — imported or restored
  /// from a backup.
  List<DownloadedVideoFile> get _untrackedFiles {
    final known = _completedTasks
        .map((t) => t.filePath)
        .where((p) => p.isNotEmpty)
        .toSet();
    return _downloadedFiles.where((f) => !known.contains(f.path)).toList();
  }

  List<Widget> _buildBody(AppTokens tokens, bool isTv) {
    final active = _activeTasks;
    final completed = _completedTasks;
    final untracked = _untrackedFiles;

    if (active.isEmpty && completed.isEmpty && untracked.isEmpty) {
      return [_buildEmptyState(tokens)];
    }

    return [
      if (active.isNotEmpty) ...[
        _sectionHeader(tokens, 'In progress'),
        const SizedBox(height: 10),
        for (final task in active)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DownloadTaskCard(task: task),
          ),
        const SizedBox(height: 18),
      ],
      if (completed.isNotEmpty || untracked.isNotEmpty) ...[
        _sectionHeader(tokens, 'On this device'),
        const SizedBox(height: 10),
        for (final task in completed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DownloadTaskCard(
              task: task,
              onWatch: () =>
                  _playFile(task.filePath, task.mediaTitle ?? task.title),
              onExport: () => _exportFile(task.filePath),
              onDeleteFile: () => _confirmDelete(task.filePath, task.title),
            ),
          ),
        for (final file in untracked)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _UntrackedFileRow(
              file: file,
              onWatch: () => _playFile(file.path, file.fileName),
              onDelete: () => _confirmDelete(file.path, file.fileName),
            ),
          ),
      ],
    ];
  }

  Widget _sectionHeader(AppTokens tokens, String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: tokens.primaryAccent,
            borderRadius: tokens.borderRadiusXs,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: tokens.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(AppTokens tokens) {
    if (_isLoadingFiles) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(color: tokens.primaryAccent),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 44),
      decoration: tokens.getShapeDecoration(
        color: tokens.surfaceCard,
        radius: tokens.cardRadius,
        side: BorderSide(color: tokens.borderSubtle),
      ),
      child: Column(
        children: [
          Icon(
            Icons.download_for_offline_outlined,
            size: 40,
            color: tokens.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'No downloads yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use the download button on a movie or episode to save it for '
            'offline playback. Progress and the saved file will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: tokens.textMuted),
          ),
        ],
      ),
    );
  }
}

/// A file found on disk with no matching task record.
class _UntrackedFileRow extends StatelessWidget {
  const _UntrackedFileRow({
    required this.file,
    required this.onWatch,
    required this.onDelete,
  });

  final DownloadedVideoFile file;
  final VoidCallback onWatch;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: tokens.borderRadiusSm,
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(Icons.movie_outlined, size: 20, color: tokens.textMuted),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${file.formattedSize} · on this device',
                  style: TextStyle(fontSize: 11, color: tokens.textMuted),
                ),
              ],
            ),
          ),
          TvFocusable(
            borderRadius: tokens.borderRadiusXs,
            onTap: onWatch,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: tokens.primaryAccent.withValues(alpha: 0.16),
                borderRadius: tokens.borderRadiusXs,
                border: Border.all(
                  color: tokens.primaryAccent.withValues(alpha: 0.45),
                  width: 0.8,
                ),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 18,
                color: tokens.primaryAccent,
              ),
            ),
          ),
          const SizedBox(width: 6),
          TvFocusable(
            borderRadius: tokens.borderRadiusXs,
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: tokens.borderRadiusXs,
                border: Border.all(color: tokens.borderSubtle, width: 0.8),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: tokens.errorColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
