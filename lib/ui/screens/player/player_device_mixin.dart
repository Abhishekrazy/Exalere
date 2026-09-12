import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import '../../../providers/app_provider.dart';
import '../../../services/device_controls_service.dart';
import '../../../services/pip_service.dart';

/// Mixin encapsulating brightness, volume gestures, screen rotation lock, and Picture-in-Picture (PiP).
mixin PlayerDeviceMixin<T extends StatefulWidget> on State<T> {
  Player get player;
  bool get isPlayerReady;
  String? get errorMessage;

  void showToast(String message);

  double brightness = 1.0;
  bool showBrightnessIndicator = false;
  Timer? brightnessHideTimer;

  double volume = 0.5;
  bool showVolumeIndicator = false;
  Timer? volumeHideTimer;

  bool isOrientationLocked = false;
  bool isPipMode = false;

  void initDeviceState() {
    isPipMode = PipService.instance.isInPipMode.value;
    PipService.instance.isInPipMode.addListener(onPipModeChanged);

    if (Platform.isAndroid) {
      DeviceControlsService.getBrightness().then((b) {
        if (mounted) setState(() => brightness = b);
      });
      DeviceControlsService.getVolume().then((v) {
        if (mounted) setState(() => volume = v);
      });
    }
  }

  void disposeDeviceState() {
    brightnessHideTimer?.cancel();
    volumeHideTimer?.cancel();
    PipService.instance.isInPipMode.removeListener(onPipModeChanged);
    PipService.instance.setAutoEnterEnabled(false);

    if (Platform.isAndroid) {
      DeviceControlsService.resetBrightness();
    }
  }

  void onPipModeChanged() {
    if (!mounted) return;
    setState(() => isPipMode = PipService.instance.isInPipMode.value);
  }

  void onBrightnessDragUpdate(double delta) {
    if (context.read<AppProvider>().isTvMode) return;
    final next = (brightness - delta / 180.0).clamp(0.01, 1.0);
    setState(() {
      brightness = next;
      showBrightnessIndicator = true;
    });
    DeviceControlsService.setBrightness(next);
    brightnessHideTimer?.cancel();
    brightnessHideTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => showBrightnessIndicator = false);
      }
    });
  }

  void onVolumeDragUpdate(double delta) {
    if (context.read<AppProvider>().isTvMode) return;
    final next = (volume - delta / 180.0).clamp(0.0, 1.0);
    setState(() {
      volume = next;
      showVolumeIndicator = true;
    });
    if (Platform.isAndroid) {
      DeviceControlsService.setVolume(next);
    } else {
      player.setVolume(next * 100.0);
    }
    volumeHideTimer?.cancel();
    volumeHideTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => showVolumeIndicator = false);
      }
    });
  }

  void toggleScreenOrientation() {
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

  void toggleLockOrientation() {
    setState(() => isOrientationLocked = !isOrientationLocked);
    if (isOrientationLocked) {
      final orientation = MediaQuery.of(context).orientation;
      if (orientation == Orientation.landscape) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
      showToast('Orientation locked');
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      showToast('Orientation auto-rotate restored');
    }
  }

  void syncPipAutoEnter({bool? isPlaying}) {
    if (!Platform.isAndroid) return;
    final playing = isPlaying ?? player.state.playing;
    bool pipEnabled = false;
    try {
      pipEnabled = context.read<AppProvider>().pipEnabled;
    } catch (_) {}
    if (pipEnabled && playing && isPlayerReady && errorMessage == null) {
      final w = player.state.width ?? 16;
      final h = player.state.height ?? 9;
      PipService.instance.setAutoEnterEnabled(
        true,
        numerator: w > 0 ? w : 16,
        denominator: h > 0 ? h : 9,
      );
    } else {
      PipService.instance.setAutoEnterEnabled(false);
    }
  }

  Future<void> enterPipMode() async {
    final supported = await PipService.instance.isPipSupported();
    if (!supported) {
      showToast('Picture-in-Picture is not supported on this device');
      return;
    }
    final w = player.state.width ?? 16;
    final h = player.state.height ?? 9;
    final entered = await PipService.instance.enterPip(
      numerator: w > 0 ? w : 16,
      denominator: h > 0 ? h : 9,
    );
    if (!entered && mounted) {
      showToast('Could not enter Picture-in-Picture');
    }
  }
}
