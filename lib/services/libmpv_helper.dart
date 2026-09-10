import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

class LibMpvHelper {
  static bool _patched = false;

  /// Fixes uninitialized static critical sections and prevents premature destruction
  /// in libmpv-2.dll (specifically libxml2's xmlMemMutex at 0x2082a60, xmlInitMutex at 0x2082d00,
  /// and xmlDictMutex at 0x2082d60).
  ///
  /// Also neutralizes xmlCleanupParser (0xa2f7d0) and xmlDictCleanup (0xa48920) so that
  /// FFmpeg's dash_close does NOT destroy xmlDictMutex when switching servers or closing streams,
  /// completely eliminating the STATUS_ACCESS_VIOLATION crash in ntdll!RtlEnterCriticalSection.
  static void ensureCriticalSectionsInitialized() {
    if (!Platform.isWindows) return;

    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final loadLibrary = kernel32.lookupFunction<
          Pointer<Void> Function(Pointer<Utf16>),
          Pointer<Void> Function(Pointer<Utf16>)>('LoadLibraryW');
      final getModuleHandle = kernel32.lookupFunction<
          Pointer<Void> Function(Pointer<Utf16>),
          Pointer<Void> Function(Pointer<Utf16>)>('GetModuleHandleW');
      final initCs = kernel32.lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)>('InitializeCriticalSection');
      final virtualProtect = kernel32.lookupFunction<
          Int32 Function(Pointer<Void>, IntPtr, Uint32, Pointer<Uint32>),
          int Function(Pointer<Void>, int, int, Pointer<Uint32>)>('VirtualProtect');
      final setDllDirectory = kernel32.lookupFunction<
          Int32 Function(Pointer<Utf16>),
          int Function(Pointer<Utf16>)>('SetDllDirectoryW');

      Pointer<Void> hMpv = nullptr;

      // 1. Check if already loaded in memory
      final dllName = 'libmpv-2.dll'.toNativeUtf16();
      hMpv = getModuleHandle(dllName);
      calloc.free(dllName);

      // 2. If not loaded, resolve from executable directory and candidate paths
      if (hMpv.address == 0) {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final exeDirPtr = exeDir.toNativeUtf16();
        setDllDirectory(exeDirPtr);
        calloc.free(exeDirPtr);

        final candidates = [
          '$exeDir\\libmpv-2.dll',
          'libmpv-2.dll',
        ];

        for (final p in candidates) {
          if (File(p).existsSync() || p == 'libmpv-2.dll') {
            final pPtr = p.toNativeUtf16();
            hMpv = loadLibrary(pPtr);
            calloc.free(pPtr);
            if (hMpv.address != 0) break;
          }
        }
      }

      if (hMpv.address != 0) {
        final base = hMpv.address;

        // 1. Neutralize cleanup routines so dash_close cannot destroy xmlDictMutex
        if (!_patched) {
          final oldProtect = calloc<Uint32>();

          // Patch xmlCleanupParser (0xa2f7d0) & xmlDictCleanup (0xa48920) with 'ret' (0xc3)
          const retOffsets = [0xa2f7d0, 0xa48920];
          for (final off in retOffsets) {
            final addr = Pointer<Uint8>.fromAddress(base + off);
            if (virtualProtect(addr.cast<Void>(), 1, 0x40, oldProtect) != 0) {
              addr.value = 0xc3; // ret
              virtualProtect(addr.cast<Void>(), 1, oldProtect.value, oldProtect);
            }
          }

          // NOP out the 5-byte call to xmlCleanupParser in dash_close (0x9a5f69)
          final dashCallAddr = Pointer<Uint8>.fromAddress(base + 0x9a5f69);
          if (virtualProtect(dashCallAddr.cast<Void>(), 5, 0x40, oldProtect) != 0) {
            for (var i = 0; i < 5; i++) {
              (dashCallAddr + i).value = 0x90; // NOP
            }
            virtualProtect(dashCallAddr.cast<Void>(), 5, oldProtect.value, oldProtect);
          }

          calloc.free(oldProtect);
          _patched = true;
          debugPrint('LibMpvHelper: Protected libxml2 from premature cleanup in libmpv-2.dll');
        }

        // 2. Ensure critical sections are properly initialized
        // RTL_CRITICAL_SECTION memory layout (64-bit Windows):
        // offset 0x00: DebugInfo (PRTL_CRITICAL_SECTION_DEBUG, 8 bytes)
        // offset 0x08: LockCount (LONG, 4 bytes)
        // If DebugInfo == 0 or LockCount == -6 (0xfffffffa), the CS is uninitialized or deleted!
        const csOffsets = [
          0x2082a60, // xmlMemMutex
          0x2082d00, // xmlInitMutex
          0x2082d60, // xmlDictMutex
        ];

        for (final off in csOffsets) {
          final csPtr = Pointer<Void>.fromAddress(base + off);
          final debugInfo = Pointer<Int64>.fromAddress(base + off).value;
          final lockCount = Pointer<Int32>.fromAddress(base + off + 8).value;

          if (debugInfo == 0 || lockCount == -6) {
            initCs(csPtr);
            debugPrint('LibMpvHelper: Initialized libmpv CS at 0x${(base + off).toRadixString(16)} (was debugInfo=$debugInfo, lockCount=$lockCount)');
          }
        }
      } else {
        debugPrint('LibMpvHelper: libmpv-2.dll not yet loaded, will re-attempt on player init');
      }
    } catch (e) {
      debugPrint('LibMpvHelper initialization error: $e');
    }
  }
}
