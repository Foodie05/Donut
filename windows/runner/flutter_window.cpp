#include "flutter_window.h"

#include <algorithm>
#include <cctype>
#include <shellapi.h>
#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  SetupFileOpenChannel();
  DragAcceptFiles(GetHandle(), TRUE);

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (GetHandle()) {
    DragAcceptFiles(GetHandle(), FALSE);
  }
  file_open_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_DROPFILES:
      HandleDroppedFiles(reinterpret_cast<HDROP>(wparam));
      return 0;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::SetupFileOpenChannel() {
  file_open_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "donut/file_open",
          &flutter::StandardMethodCodec::GetInstance());

  file_open_channel_->SetMethodCallHandler(
      [this](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "consumeInitialFile") {
          if (pending_file_path_) {
            result->Success(flutter::EncodableValue(*pending_file_path_));
            pending_file_path_.reset();
          } else {
            result->Success(flutter::EncodableValue());
          }
          return;
        }
        result->NotImplemented();
      });

  if (pending_file_path_) {
    DispatchFileToFlutter(*pending_file_path_);
    pending_file_path_.reset();
  }
}

void FlutterWindow::DispatchFileToFlutter(const std::string& path) {
  if (!IsSupportedPath(path)) {
    return;
  }
  if (file_open_channel_) {
    file_open_channel_->InvokeMethod(
        "openFile", std::make_unique<flutter::EncodableValue>(path));
  } else {
    pending_file_path_ = path;
  }
}

void FlutterWindow::HandleDroppedFiles(HDROP drop_handle) {
  const UINT file_count = DragQueryFileW(drop_handle, 0xFFFFFFFF, nullptr, 0);
  for (UINT i = 0; i < file_count; ++i) {
    const UINT len = DragQueryFileW(drop_handle, i, nullptr, 0);
    if (len == 0) continue;
    std::wstring wide_path(len + 1, L'\0');
    DragQueryFileW(drop_handle, i, wide_path.data(), len + 1);
    const std::string utf8_path = Utf8FromUtf16(wide_path.c_str());
    if (!utf8_path.empty()) {
      DispatchFileToFlutter(utf8_path);
    }
  }
  DragFinish(drop_handle);
}

bool FlutterWindow::IsSupportedPath(const std::string& path) {
  std::string lower = path;
  std::transform(lower.begin(), lower.end(), lower.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return lower.size() > 4 &&
         (lower.rfind(".pdf") == lower.size() - 4 ||
          lower.rfind(".dpdf") == lower.size() - 5);
}
