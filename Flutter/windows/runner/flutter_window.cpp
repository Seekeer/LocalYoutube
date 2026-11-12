#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>
#include <string>
#include <variant>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Fullscreen for the player: the window itself, not only the Flutter view.
constexpr char kWindowChannel[] = "org.localtube.app/window";

// The channel the player already uses on Android to send the app away.
constexpr char kAppControlChannel[] = "org.localtube.app/app_control";

}  // namespace

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
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kWindowChannel,
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) { HandleWindowMethodCall(call, std::move(result)); });
  app_control_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kAppControlChannel,
          &flutter::StandardMethodCodec::GetInstance());
  app_control_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "moveToBackground") {
          ShowWindow(GetHandle(), SW_MINIMIZE);
          result->Success();
          return;
        }
        result->NotImplemented();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

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
  window_channel_ = nullptr;
  app_control_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  const LRESULT result = HandleMessage(hwnd, message, wparam, lparam);
  switch (message) {
    // Win32Window and Windows resize the window for a new DPI or display
    // layout as if it still had a frame; fullscreen covers the monitor again.
    case WM_DPICHANGED:
    case WM_DISPLAYCHANGE:
      fullscreen_.FitToMonitor(hwnd);
      break;
  }
  return result;
}

LRESULT FlutterWindow::HandleMessage(HWND hwnd, UINT const message,
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
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::HandleWindowMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();
  if (method == "setFullScreen") {
    const auto* fullscreen = std::get_if<bool>(call.arguments());
    if (fullscreen == nullptr) {
      result->Error("invalid_arguments", "setFullScreen expects a bool");
      return;
    }
    if (!fullscreen_.Set(GetHandle(), *fullscreen)) {
      result->Error("unavailable", "The window could not change fullscreen");
      return;
    }
    result->Success(flutter::EncodableValue(fullscreen_.IsFullscreen()));
    return;
  }
  if (method == "isFullScreen") {
    result->Success(flutter::EncodableValue(fullscreen_.IsFullscreen()));
    return;
  }
  result->NotImplemented();
}
