import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import '../../../providers/app_provider.dart';

/// Mixin encapsulating controls visibility timers, HUD banners, touch-locking, and double-tap seeking.
mixin PlayerControlsVisibilityMixin<T extends StatefulWidget> on State<T> {
  Player get player;
  FocusNode get focusNode;
  FocusNode get playPauseTvFocusNode;

  bool showControls = true;
  Timer? hideTimer;
  bool isInteractingWithUi = false;

  bool isControlsLocked = false;
  bool showUnlockButton = false;
  Timer? unlockButtonTimer;

  int? doubleTapSeekDirection;
  Timer? doubleTapIndicatorTimer;

  String? toastMessage;
  Timer? toastTimer;

  Timer? resumeBannerTimer;
  bool showResumeBanner = false;
  int resumedFromSeconds = 0;

  void disposeControlsVisibility() {
    hideTimer?.cancel();
    unlockButtonTimer?.cancel();
    doubleTapIndicatorTimer?.cancel();
    toastTimer?.cancel();
    resumeBannerTimer?.cancel();
  }

  void showToast(String message) {
    if (!mounted) return;
    setState(() => toastMessage = message);
    toastTimer?.cancel();
    toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => toastMessage = null);
    });
  }

  void onUserActivity() {
    if (!showControls) {
      setState(() => showControls = true);
    }
    startHideTimer();
  }

  void startHideTimer() {
    if (isInteractingWithUi) return;
    hideTimer?.cancel();
    bool isTv = false;
    try {
      isTv = context.read<AppProvider>().isTvMode;
    } catch (_) {}
    final duration = isTv
        ? const Duration(seconds: 6)
        : const Duration(milliseconds: 3500);
    hideTimer = Timer(duration, () {
      if (mounted && player.state.playing && !isInteractingWithUi) {
        setState(() => showControls = false);
        focusNode.requestFocus();
      }
    });
  }

  void cancelHideTimer() {
    hideTimer?.cancel();
  }

  void toggleControls() {
    setState(() => showControls = !showControls);
    if (showControls) {
      startHideTimer();
    }
  }

  void revealTvControls() {
    setState(() => showControls = true);
    startHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && showControls) {
        playPauseTvFocusNode.requestFocus();
      }
    });
  }

  void hideTvControls() {
    setState(() => showControls = false);
    focusNode.requestFocus();
  }

  void triggerDoubleTapSeek(int seconds) {
    seekRelative(seconds);
    doubleTapIndicatorTimer?.cancel();
    setState(() => doubleTapSeekDirection = seconds);
    doubleTapIndicatorTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() => doubleTapSeekDirection = null);
      }
    });
  }

  void seekRelative(int seconds) {
    final current = player.state.position;
    final target = current + Duration(seconds: seconds);
    player.seek(target < Duration.zero ? Duration.zero : target);
    startHideTimer();
  }

  void showUnlockButtonTemporarily() {
    unlockButtonTimer?.cancel();
    setState(() => showUnlockButton = true);
    unlockButtonTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => showUnlockButton = false);
    });
  }

  void lockControls() {
    setState(() {
      isControlsLocked = true;
      showControls = false;
    });
    showToast('Screen locked (Touch resistant)');
  }

  void unlockControls() {
    setState(() {
      isControlsLocked = false;
      showUnlockButton = false;
      showControls = true;
    });
    showToast('Controls unlocked');
    startHideTimer();
  }

  void showResumeBannerFor(int seconds) {
    setState(() {
      showResumeBanner = true;
      resumedFromSeconds = seconds;
    });
    resumeBannerTimer?.cancel();
    resumeBannerTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => showResumeBanner = false);
    });
  }

  void restartPlayback() {
    player.seek(Duration.zero);
    setState(() => showResumeBanner = false);
    resumeBannerTimer?.cancel();
  }

  void dismissResumeBanner() {
    setState(() => showResumeBanner = false);
    resumeBannerTimer?.cancel();
  }

  void onPopInvoked() {
    if (isControlsLocked) {
      showUnlockButtonTemporarily();
      return;
    }
    if (showControls) {
      hideTvControls();
    } else {
      Navigator.of(context).pop();
    }
  }
}
