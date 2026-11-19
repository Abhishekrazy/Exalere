import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Serialises network poster/thumb loading.
///
/// TV hardware chokes when a shelf asks for twenty large images at once. This
/// gate allows one in-flight image at a time: the next poster only starts after
/// the previous one has painted a frame.
class ImageLoadGate {
  ImageLoadGate._();

  static final ImageLoadGate instance = ImageLoadGate._();

  final List<Completer<void>> _waiting = <Completer<void>>[];
  int _active = 0;

  static const int maxConcurrent = 1;

  Future<void> acquire() {
    final completer = Completer<void>();
    _waiting.add(completer);
    _pump();
    return completer.future;
  }

  void release() {
    if (_active > 0) _active--;
    _pump();
  }

  void _pump() {
    while (_active < maxConcurrent && _waiting.isNotEmpty) {
      _active++;
      _waiting.removeAt(0).complete();
    }
  }
}

/// A network image that waits for its turn in [ImageLoadGate].
class QueuedCachedNetworkImage extends StatefulWidget {
  const QueuedCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.cacheManager,
    this.fit,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
    this.fadeInDuration,
    this.fadeOutDuration,
    this.placeholder,
    this.errorWidget,
    this.imageBuilder,
    this.color,
    this.colorBlendMode,
    this.filterQuality = FilterQuality.low,
  });

  final String imageUrl;
  final BaseCacheManager? cacheManager;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;

  /// Accepted for drop-in compatibility; the queue already serialises loads so
  /// a long fade would only delay the next poster.
  final Duration? fadeInDuration;
  final Duration? fadeOutDuration;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;
  final Widget Function(BuildContext, ImageProvider<Object>)? imageBuilder;
  final Color? color;
  final BlendMode? colorBlendMode;
  final FilterQuality filterQuality;

  @override
  State<QueuedCachedNetworkImage> createState() =>
      _QueuedCachedNetworkImageState();
}

class _QueuedCachedNetworkImageState extends State<QueuedCachedNetworkImage> {
  bool _ready = false;
  bool _granted = false;
  bool _released = false;
  bool _disposed = false;
  Timer? _safetyTimer;

  @override
  void initState() {
    super.initState();
    _requestSlot();
  }

  Future<void> _requestSlot() async {
    await ImageLoadGate.instance.acquire();
    _granted = true;
    if (_disposed) {
      _releaseSlot();
      return;
    }
    // A decode that never paints must not stall the whole queue.
    _safetyTimer = Timer(const Duration(seconds: 8), _releaseSlot);
    setState(() => _ready = true);
  }

  void _releaseSlot() {
    if (!_granted || _released) return;
    _released = true;
    _safetyTimer?.cancel();
    ImageLoadGate.instance.release();
  }

  @override
  void dispose() {
    _disposed = true;
    _safetyTimer?.cancel();
    _releaseSlot();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder =
        widget.placeholder?.call(context, widget.imageUrl) ??
        const SizedBox.shrink();

    if (!_ready) return placeholder;

    final provider = CachedNetworkImageProvider(
      widget.imageUrl,
      cacheManager: widget.cacheManager,
      maxWidth: widget.maxWidthDiskCache ?? widget.memCacheWidth,
      maxHeight: widget.maxHeightDiskCache ?? widget.memCacheHeight,
    );

    if (widget.imageBuilder != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _releaseSlot());
      return widget.imageBuilder!(context, provider);
    }

    return Image(
      image: provider,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      color: widget.color,
      colorBlendMode: widget.colorBlendMode,
      filterQuality: widget.filterQuality,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null || wasSynchronouslyLoaded) {
          // The poster is on screen; let the queue start the next one.
          _releaseSlot();
          return child;
        }
        return placeholder;
      },
      errorBuilder: (context, error, stackTrace) {
        _releaseSlot();
        return widget.errorWidget?.call(context, widget.imageUrl, error) ??
            const SizedBox.shrink();
      },
    );
  }
}
