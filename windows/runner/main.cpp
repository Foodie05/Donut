#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <shlobj.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

bool WriteRegistryValue(const std::wstring& subkey,
                        const std::wstring& value_name,
                        const std::wstring& data) {
  HKEY key = nullptr;
  const LONG create_result = RegCreateKeyExW(
      HKEY_CURRENT_USER, subkey.c_str(), 0, nullptr, 0, KEY_SET_VALUE, nullptr,
      &key, nullptr);
  if (create_result != ERROR_SUCCESS || key == nullptr) {
    return false;
  }

  const wchar_t* value_name_ptr = value_name.empty() ? nullptr : value_name.c_str();
  const LONG set_result = RegSetValueExW(
      key, value_name_ptr, 0, REG_SZ,
      reinterpret_cast<const BYTE*>(data.c_str()),
      static_cast<DWORD>((data.size() + 1) * sizeof(wchar_t)));
  RegCloseKey(key);
  return set_result == ERROR_SUCCESS;
}

void RegisterFileAssociations() {
  wchar_t exe_path[MAX_PATH];
  const DWORD len = GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  if (len == 0 || len >= MAX_PATH) {
    return;
  }

  const std::wstring exe(exe_path);
  const std::wstring command = L"\"" + exe + L"\" \"%1\"";

  WriteRegistryValue(L"Software\\Classes\\.dpdf", L"", L"Donut.dpdf");
  WriteRegistryValue(L"Software\\Classes\\Donut.dpdf", L"", L"Donut DPDF Document");
  WriteRegistryValue(L"Software\\Classes\\Donut.dpdf\\DefaultIcon", L"", exe + L",0");
  WriteRegistryValue(L"Software\\Classes\\Donut.dpdf\\shell\\open\\command", L"", command);

  WriteRegistryValue(L"Software\\Classes\\Applications\\Donut.exe", L"FriendlyAppName", L"Donut");
  WriteRegistryValue(L"Software\\Classes\\Applications\\Donut.exe\\shell\\open\\command", L"",
                     command);
  WriteRegistryValue(L"Software\\Classes\\Applications\\Donut.exe\\SupportedTypes", L".pdf", L"");
  WriteRegistryValue(L"Software\\Classes\\Applications\\Donut.exe\\SupportedTypes", L".dpdf", L"");

  SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);
}

}  // namespace

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
  RegisterFileAssociations();

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Donut", origin, size)) {
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
