import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// --- Win32 Structs for FFI ---

final class RECT extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

final class POINT extends Struct {
  @Int32()
  external int x;
  @Int32()
  external int y;
}

final class WINDOWPLACEMENT extends Struct {
  @Uint32()
  external int length;
  @Uint32()
  external int flags;
  @Uint32()
  external int showCmd;
  external POINT ptMinPosition;
  external POINT ptMaxPosition;
  external RECT rcNormalPosition;
}

final class MONITORINFO extends Struct {
  @Uint32()
  external int cbSize;
  external RECT rcMonitor;
  external RECT rcWork;
  @Uint32()
  external int dwFlags;
}

/// Service to handle cross-platform fullscreen toggles, with true borderless fullscreen on Windows
class WindowService {
  static final WindowService _instance = WindowService._internal();
  factory WindowService() => _instance;
  WindowService._internal();

  bool _isFullscreen = false;
  bool get isFullscreen => _isFullscreen;

  // Saved window state on Windows
  int _savedStyle = 0;
  final ValueNotifier<bool> fullscreenNotifier = ValueNotifier<bool>(false);

  // Win32 function pointers (cached)
  DynamicLibrary? _user32;
  int Function(Pointer<Utf16>, Pointer<Utf16>)? _findWindowW;
  int Function()? _getForegroundWindow;
  int Function(int, int)? _getWindowLongPtrW;
  int Function(int, int, int)? _setWindowLongPtrW;
  int Function(int, Pointer<WINDOWPLACEMENT>)? _getWindowPlacement;
  int Function(int, Pointer<WINDOWPLACEMENT>)? _setWindowPlacement;
  int Function(int, int)? _monitorFromWindow;
  int Function(int, Pointer<MONITORINFO>)? _getMonitorInfoW;
  int Function(int, int, int, int, int, int, int)? _setWindowPos;

  Pointer<WINDOWPLACEMENT>? _savedPlacement;

  void _initWin32() {
    if (!Platform.isWindows || _user32 != null) return;
    try {
      _user32 = DynamicLibrary.open('user32.dll');

      _findWindowW = _user32!
          .lookupFunction<
            IntPtr Function(Pointer<Utf16>, Pointer<Utf16>),
            int Function(Pointer<Utf16>, Pointer<Utf16>)
          >('FindWindowW');

      _getForegroundWindow = _user32!
          .lookupFunction<IntPtr Function(), int Function()>(
            'GetForegroundWindow',
          );

      // On 64-bit Windows, GetWindowLongPtrW is exported as GetWindowLongPtrW
      try {
        _getWindowLongPtrW = _user32!
            .lookupFunction<
              IntPtr Function(IntPtr, Int32),
              int Function(int, int)
            >('GetWindowLongPtrW');
        _setWindowLongPtrW = _user32!
            .lookupFunction<
              IntPtr Function(IntPtr, Int32, IntPtr),
              int Function(int, int, int)
            >('SetWindowLongPtrW');
      } catch (_) {
        _getWindowLongPtrW = _user32!
            .lookupFunction<
              IntPtr Function(IntPtr, Int32),
              int Function(int, int)
            >('GetWindowLongW');
        _setWindowLongPtrW = _user32!
            .lookupFunction<
              IntPtr Function(IntPtr, Int32, IntPtr),
              int Function(int, int, int)
            >('SetWindowLongW');
      }

      _getWindowPlacement = _user32!
          .lookupFunction<
            Int32 Function(IntPtr, Pointer<WINDOWPLACEMENT>),
            int Function(int, Pointer<WINDOWPLACEMENT>)
          >('GetWindowPlacement');

      _setWindowPlacement = _user32!
          .lookupFunction<
            Int32 Function(IntPtr, Pointer<WINDOWPLACEMENT>),
            int Function(int, Pointer<WINDOWPLACEMENT>)
          >('SetWindowPlacement');

      _monitorFromWindow = _user32!
          .lookupFunction<
            IntPtr Function(IntPtr, Uint32),
            int Function(int, int)
          >('MonitorFromWindow');

      _getMonitorInfoW = _user32!
          .lookupFunction<
            Int32 Function(IntPtr, Pointer<MONITORINFO>),
            int Function(int, Pointer<MONITORINFO>)
          >('GetMonitorInfoW');

      _setWindowPos = _user32!
          .lookupFunction<
            Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
            int Function(int, int, int, int, int, int, int)
          >('SetWindowPos');

      _savedPlacement = calloc<WINDOWPLACEMENT>();
      _savedPlacement!.ref.length = sizeOf<WINDOWPLACEMENT>();
    } catch (e) {
      debugPrint('WindowService Win32 init error: $e');
    }
  }

  int _getHwnd() {
    _initWin32();
    if (!Platform.isWindows) return 0;
    try {
      final titlePtr = 'Exalere'.toNativeUtf16();
      int hwnd = _findWindowW != null ? _findWindowW!(nullptr, titlePtr) : 0;
      calloc.free(titlePtr);
      if (hwnd == 0 && _getForegroundWindow != null) {
        hwnd = _getForegroundWindow!();
      }
      return hwnd;
    } catch (e) {
      debugPrint('Error getting HWND: $e');
      return 0;
    }
  }

  Future<void> setFullscreen(bool fullscreen) async {
    if (_isFullscreen == fullscreen) return;

    if (Platform.isAndroid || Platform.isIOS) {
      if (fullscreen) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
      _isFullscreen = fullscreen;
      fullscreenNotifier.value = fullscreen;
      return;
    }

    if (Platform.isWindows) {
      _initWin32();
      final hwnd = _getHwnd();
      if (hwnd == 0) {
        _isFullscreen = fullscreen;
        fullscreenNotifier.value = fullscreen;
        return;
      }

      const int gwlStyle = -16;
      const int wsOverlappedWindow = 0x00CF0000;
      const int monitorDefaultToNearest = 2;
      const int swpNoOwnerZOrder = 0x0200;
      const int swpFrameChanged = 0x0020;

      if (fullscreen) {
        // Save current placement and style
        _savedStyle = _getWindowLongPtrW!(hwnd, gwlStyle);
        _savedPlacement!.ref.length = sizeOf<WINDOWPLACEMENT>();
        _getWindowPlacement!(hwnd, _savedPlacement!);

        final monitor = _monitorFromWindow!(hwnd, monitorDefaultToNearest);
        final monitorInfo = calloc<MONITORINFO>();
        monitorInfo.ref.cbSize = sizeOf<MONITORINFO>();

        if (_getMonitorInfoW!(monitor, monitorInfo) != 0) {
          // Borderless fullscreen: remove overlapped borders & title bar
          _setWindowLongPtrW!(
            hwnd,
            gwlStyle,
            _savedStyle & ~wsOverlappedWindow,
          );
          final rect = monitorInfo.ref.rcMonitor;
          _setWindowPos!(
            hwnd,
            0, // HWND_TOP
            rect.left,
            rect.top,
            rect.right - rect.left,
            rect.bottom - rect.top,
            swpNoOwnerZOrder | swpFrameChanged,
          );
        }
        calloc.free(monitorInfo);
        _isFullscreen = true;
      } else {
        // Restore previous style and placement
        if (_savedStyle != 0) {
          _setWindowLongPtrW!(hwnd, gwlStyle, _savedStyle);
        }
        if (_savedPlacement != null) {
          _setWindowPlacement!(hwnd, _savedPlacement!);
        }
        _setWindowPos!(
          hwnd,
          0,
          0,
          0,
          0,
          0,
          0x0001 | 0x0002 | 0x0004 | swpFrameChanged, // SWP_NOSIZE | SWP_NOMOVE | SWP_NOZORDER | SWP_FRAMECHANGED
        );
        _isFullscreen = false;
      }
      fullscreenNotifier.value = _isFullscreen;
    } else {
      _isFullscreen = fullscreen;
      fullscreenNotifier.value = fullscreen;
    }
  }

  Future<void> toggleFullscreen() async {
    await setFullscreen(!_isFullscreen);
  }
}
