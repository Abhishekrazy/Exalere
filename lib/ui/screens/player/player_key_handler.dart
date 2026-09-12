import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

/// Handles physical keyboard events, media hardware buttons, and D-Pad remote controls for Player.
class PlayerKeyHandler {
  const PlayerKeyHandler._();

  static KeyEventResult handleKeyEvent({
    required KeyEvent event,
    required bool isTv,
    required bool isControlsLocked,
    required bool showControls,
    required bool isFullscreen,
    required Player player,
    required VoidCallback onShowUnlockButton,
    required VoidCallback onHideTvControls,
    required VoidCallback onRevealTvControls,
    required VoidCallback onToggleFullscreen,
    required VoidCallback onPop,
    required void Function(String) showToast,
    required void Function(int) onDoubleTapSeek,
    required VoidCallback onUserActivity,
    required VoidCallback onStartHideTimer,
    required VoidCallback onToggleSubtitle,
    required VoidCallback onTriggerSkip,
    required bool hasActiveSkip,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (isControlsLocked) {
      onShowUnlockButton();
      return KeyEventResult.handled;
    }

    final key = event.logicalKey;

    // TV Remote Back / Escape / Go Back
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.backspace) {
      if (showControls) {
        onHideTvControls();
        return KeyEventResult.handled;
      } else if (isFullscreen) {
        onToggleFullscreen();
        return KeyEventResult.handled;
      } else {
        if (Platform.isWindows ||
            Platform.isLinux ||
            Platform.isMacOS ||
            isTv) {
          onPop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored; // Handled by PopScope on Android
      }
    }

    // Direct hardware media buttons
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      player.playOrPause();
      showToast(player.state.playing ? 'Playing' : 'Paused');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPlay) {
      player.play();
      showToast('Playing');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPause) {
      player.pause();
      showToast('Paused');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaStop) {
      player.stop();
      onPop();
      return KeyEventResult.handled;
    }

    // TV Mode Special Handling
    if (isTv) {
      if (!showControls) {
        // Any D-Pad directional/action press reveals controls
        if (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.gameButtonA ||
            key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown) {
          onRevealTvControls();
          return KeyEventResult.handled;
        }

        // Left: Rewind 10s directly
        if (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.keyJ ||
            key == LogicalKeyboardKey.mediaRewind ||
            key == LogicalKeyboardKey.mediaTrackPrevious) {
          onDoubleTapSeek(-10);
          return KeyEventResult.handled;
        }

        // Right: Forward 10s directly
        if (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.keyL ||
            key == LogicalKeyboardKey.mediaFastForward ||
            key == LogicalKeyboardKey.mediaTrackNext) {
          onDoubleTapSeek(10);
          return KeyEventResult.handled;
        }
      } else {
        // Reset auto-hide timer on user interaction
        onStartHideTimer();
        return KeyEventResult.ignored;
      }
    }

    // Desktop: Play / Pause toggling (Space, K, Enter)
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.keyK ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA) {
      player.playOrPause();
      onUserActivity();
      return KeyEventResult.handled;
    }

    // Rewind 10s
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.keyJ ||
        key == LogicalKeyboardKey.mediaRewind ||
        key == LogicalKeyboardKey.mediaTrackPrevious) {
      onDoubleTapSeek(-10);
      onUserActivity();
      return KeyEventResult.handled;
    }

    // Forward 10s
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyL ||
        key == LogicalKeyboardKey.mediaFastForward ||
        key == LogicalKeyboardKey.mediaTrackNext) {
      onDoubleTapSeek(10);
      onUserActivity();
      return KeyEventResult.handled;
    }

    // Volume adjustments
    if (key == LogicalKeyboardKey.arrowUp) {
      if (!showControls) {
        onUserActivity();
      } else {
        final vol = (player.state.volume + 5.0).clamp(0.0, 100.0);
        player.setVolume(vol);
        showToast('Volume: ${vol.round()}%');
        onUserActivity();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      if (!showControls) {
        onUserActivity();
      } else {
        final vol = (player.state.volume - 5.0).clamp(0.0, 100.0);
        player.setVolume(vol);
        showToast('Volume: ${vol.round()}%');
        onUserActivity();
      }
      return KeyEventResult.handled;
    }

    // Mute
    if (key == LogicalKeyboardKey.keyM) {
      if (player.state.volume > 0) {
        player.setVolume(0.0);
        showToast('Muted');
      } else {
        player.setVolume(100.0);
        showToast('Unmuted');
      }
      onUserActivity();
      return KeyEventResult.handled;
    }

    // Fullscreen
    if (key == LogicalKeyboardKey.keyF) {
      onToggleFullscreen();
      onUserActivity();
      return KeyEventResult.handled;
    }

    // Subtitle Toggle
    if (key == LogicalKeyboardKey.keyC) {
      onToggleSubtitle();
      onUserActivity();
      return KeyEventResult.handled;
    }

    // Skip Intro / Outro
    if (key == LogicalKeyboardKey.keyS && hasActiveSkip) {
      onTriggerSkip();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
