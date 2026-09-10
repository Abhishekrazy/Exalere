#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Initialize and protect libmpv-2.dll against libxml2 cleanup crashes on Windows 11.
  // 1. Initialize static critical sections (xmlMemMutex at 0x2082a60, xmlInitMutex at 0x2082d00, xmlDictMutex at 0x2082d60).
  // 2. Patch xmlCleanupParser (0xa2f7d0) and xmlDictCleanup (0xa48920) with 'ret' (0xc3) to prevent dash_close
  //    from destroying xmlDictMutex when switching servers or closing streams.
  // 3. NOP out the 5-byte call to xmlCleanupParser in dash_close (0x9a5f69).
  wchar_t exePath[MAX_PATH];
  if (::GetModuleFileNameW(nullptr, exePath, MAX_PATH) > 0) {
    wchar_t* lastSlash = wcsrchr(exePath, L'\\');
    if (lastSlash) {
      *lastSlash = L'\0';
      ::SetDllDirectoryW(exePath);
      std::wstring mpvPath = std::wstring(exePath) + L"\\libmpv-2.dll";
      HMODULE hMpv = ::LoadLibraryW(mpvPath.c_str());
      if (!hMpv) {
        hMpv = ::LoadLibraryW(L"libmpv-2.dll");
      }
      if (hMpv) {
        uintptr_t base = reinterpret_cast<uintptr_t>(hMpv);

        // 1. Initialize static critical sections
        const uintptr_t csOffsets[] = {0x2082a60, 0x2082d00, 0x2082d60};
        for (uintptr_t off : csOffsets) {
          auto pCs = reinterpret_cast<CRITICAL_SECTION*>(base + off);
          ::InitializeCriticalSection(pCs);
        }

        // 2. Patch xmlCleanupParser and xmlDictCleanup with 'ret' (0xc3)
        const uintptr_t patchOffsets[] = {0xa2f7d0, 0xa48920};
        for (uintptr_t off : patchOffsets) {
          void* addr = reinterpret_cast<void*>(base + off);
          DWORD oldProtect = 0;
          if (::VirtualProtect(addr, 1, PAGE_EXECUTE_READWRITE, &oldProtect)) {
            *reinterpret_cast<uint8_t*>(addr) = 0xc3; // ret
            ::VirtualProtect(addr, 1, oldProtect, &oldProtect);
          }
        }

        // 3. NOP out the call to xmlCleanupParser in dash_close (0x9a5f69, 5 bytes)
        void* dashCallAddr = reinterpret_cast<void*>(base + 0x9a5f69);
        DWORD oldProtect = 0;
        if (::VirtualProtect(dashCallAddr, 5, PAGE_EXECUTE_READWRITE, &oldProtect)) {
          memset(dashCallAddr, 0x90, 5); // NOP x5
          ::VirtualProtect(dashCallAddr, 5, oldProtect, &oldProtect);
        }
      }
    }
  }

  flutter::DartProject project(L"data");
  project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Exalere", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
